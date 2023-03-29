require './spec_helper'
describe 'Payment: CIP Strategy', :scf, :payments, :cip_payments, :hover do
  before(:all) do
    @dealer_gstn = $conf['ramkay_gstn']
    @counterparty_gstn = $conf['tvs_gstn']
    @vendor_name = $conf['grn_dealer_name']
    @anchor_name = $conf['grn_anchor_name']
    @vendor_pan = $conf['users']['grn_dealer']['pan']
    @anchor_pan = $conf['users']['grn_anchor']['pan']
    @vendor_actor = 'Ramkay tvs'
    @invoice_file = "#{Dir.pwd}/test-data/attachments/dealer_invoice.pdf"
    @payment_proof = "#{Dir.pwd}/test-data/attachments/payment_proof.pdf"
    @erb_file = File.read("#{Dir.pwd}/test-data/erb/testbed_data.erb")
    @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
    @invoice_value = comma_seperated_value(@testdata['Dealer Invoice Details']['Invoice Value'])
    @testdata['Transaction List']['Instrument Value'] = "₹#{@invoice_value}"
    @today_date = Date.today.strftime('%d %b, %Y')
    @upcoming_date = (Date.today + 10).strftime('%d %b, %Y')
    @current_due_date = (Date.today - $conf['dealer_tenor']).strftime('%d-%b-%Y')
    @prepayment_date = (Date.today - $conf['dealer_tenor'] + 10).strftime('%d-%b-%Y')
    @overdue_date = (Date.today - $conf['dealer_tenor'] - 10).strftime('%d-%b-%Y')
    @upload_doc = "#{Dir.pwd}/test-data/attachments/repayment_upload.xlsx"
    @outstanding_values_hash = {
      transaction_values: '',
      tenor: nil,
      due_date: '',
      type: 'rearend',
      payment_date: nil
    }
  end

  before(:each) do
    clear_all_overdues({ anchor: $conf['grn_anchor_name'], vendor: $conf['grn_dealer_name'] })
    @driver = Tarspect::Browser.new($conf['browser']).invoke
    @tarspect_methods = Common::Methods.new(@driver)
    @common_pages = Pages::CommonMethods.new(@driver)
    @transactions_page = Pages::Trasactions.new(@driver)
    @disbursement_page = Pages::Disbursement.new(@driver)
    @payments_page = Pages::Payment.new(@driver)
    @commercials_page = Pages::Commercials.new(@driver)
    @common_api = Api::Pages::Common.new
  end

  after(:each) do |e| # Captures screenshot of the current page when failure happens
    snap_screenshot(e)
    quit_browser
  end

  after(:all) do
    clear_all_overdues({ anchor: $conf['grn_anchor_name'], vendor: $conf['grn_dealer_name'] })
  end

  it 'Payment: CIP: Partial amount(Current outstanding with pre-payment pending)', :sanity, :cip_partial do |e|
    e.run_step 'Create a complete transaction as Dealer(Draft -> Released) and disburse the transaction' do
      @transaction_id = seed_transaction({
                                           actor: 'grn_dealer',
                                           counter_party: 'grn_anchor',
                                           invoice_details: @testdata['Dealer Invoice Details'],
                                           invoice_file: @invoice_file,
                                           program: 'Invoice Financing - Dealer',
                                           program_group: 'invoice'
                                         })
      expect(@transaction_id).not_to include('Error while creating transaction')
      details = disburse_transaction({
                                       transaction_id: @transaction_id,
                                       invoice_value: @testdata['Dealer Invoice Details']['Invoice Value'],
                                       type: 'rearend',
                                       date_of_payment: @prepayment_date,
                                       payment_proof: @payment_proof,
                                       program: 'Invoice Financing - Dealer'
                                     })
      expect(details).not_to eq 'Error while disbursements'
      @transaction_values = details[0]
      @disbursement_values = details[1]
      @testdata['Transaction List']['Transaction Value'] = "₹#{comma_seperated_value(@transaction_values[0])}"
      @testdata['Transaction List']['Status'] = 'Upcoming'
    end

    e.run_step 'Login as Anchor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['grn_anchor']['email'], $conf['users']['grn_anchor']['password'])).to eq true
    end

    e.run_step "Verify transaction in the 'Due for payments' as Anchor" do
      @outstanding_values_hash[:transaction_values] = @transaction_values
      @outstanding_values_hash[:due_date] = (Date.parse(@prepayment_date) + $conf['dealer_tenor']).strftime('%d-%b-%Y')
      calculated_values = @payments_page.calculate_outstanding_value(@outstanding_values_hash)
      @outstanding_value = calculated_values[0]
      @interest = calculated_values[1]

      @repayment_list_details = {
        'Status' => @testdata['Transaction List']['Status'],
        'Vendor Name' => @testdata['Transaction List']['Vendor Name'],
        'Due date' => @upcoming_date,
        'Principal' => @testdata['Transaction List']['Transaction Value'],
        'Interest' => "₹#{comma_seperated_value(@interest)}",
        'Charges' => '₹0',
        'Total Outstanding' => "₹#{comma_seperated_value(@outstanding_value)}",
        'Demanded Interest' => 'NA'
      }
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @common_pages.click_transactions_tab(DUE_FOR_REPAYMENT)
      @payments_page.select_overdue_details(@testdata['Investor Commercials']['investor'])
      result = @payments_page.verify_transaction_in_due_for_payments(@repayment_list_details.values)
      expect(result).to eq true
    end

    e.run_step 'Anchor logs out' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Investor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['investor']['email'], $conf['users']['investor']['password'])).to eq true
    end

    e.run_step 'Record current outstanding amount as pre-payment as anchor' do
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @payment = @outstanding_value
      @tarspect_methods.click_button('Add Settlement details')
      @utr = @payments_page.repay_amount(@payment, @upload_doc, @vendor_pan, 'Dealer Finance', @anchor_pan)
      @actual_summary, @report_link = @disbursement_page.upload_bulk_disbursement(@upload_doc, 'Repayment')
      expect(@report_link.empty?).to eq(false), 'Report link is empty'
    end

    e.run_step 'Verify report of repayment' do
      expected_report = @payments_page.create_expected_data_for_repayment(@utr)
      actual_report = @disbursement_page.verify_bulk_disbursment_summary_report(@report_link, 'Repayment')
      expect(actual_report).to eq(expected_report)
    end

    e.run_step 'Verify summary report of repayment' do
      formatted_amount = if @payment > 100_000
                           "₹ #{get_formatted_amount(@payment)} LAC"
                         else
                           "₹ #{get_formatted_amount(@payment)}"
                         end
      expected_summary = { 'Total Repayment Value' => formatted_amount, 'Payment accepted' => '1', 'Payment rejected' => '-' }
      expect(@actual_summary).to eq(expected_summary)
    end

    e.run_step 'Verify the transaction details in Payments tab - Recorded Payment' do
      navigate_to($conf['base_url'])
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @common_pages.click_transactions_tab(MATURED)
      @common_pages.navigate_to_transaction(@transaction_id)
      @tarspect_methods.click_link('Payment')
      expected_values = {
        'Date of Payment' => @today_date,
        'UTR Number' => @utr,
        'Type of Payment' => 'Pre-Payment',
        'Principal Paid' => "₹#{comma_seperated_value(@transaction_values[0])}",
        'Interest Paid' => "₹#{comma_seperated_value(@interest)}",
        'Accured Interest Paid' => '₹0',
        'Charges Paid' => '₹0',
        'Total Amount Paid' => "₹#{comma_seperated_value(@payment)}",
        'Payment Receipt' => 'View  '
      }
      actual_values = @payments_page.get_recorded_payment_details
      expect(actual_values).to eq expected_values
    end

    e.run_step 'Verify the transaction is moved to matured state after re-payment success' do
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @common_pages.click_transactions_tab(MATURED)
      expect(@common_pages.transaction_listed?(@transaction_id)).to eq(true), "Transaction #{@transaction_id} is not listed"
      expect(@transactions_page.status_timeline_on_hover(@transaction_id, @today_date, 'CA Approval')).to eq true
      expect(@transactions_page.status_timeline_on_hover(@transaction_id, @today_date, 'Anchor Approval')).to eq true
      expect(@transactions_page.status_timeline_on_hover(@transaction_id, @today_date, 'CA Approval (Level 2)')).to eq true
      expect(@transactions_page.status_timeline_on_hover(@transaction_id, @today_date, 'Settled')).to eq true
      expect(@transactions_page.status_timeline_on_hover(@transaction_id, @today_date, 'Matured')).to eq true
    end

    e.run_step 'Verify Payment history of the recorded payment as Anchor(Current Due payments)' do
      expected_values = {
        'Payment Status' => 'Success',
        'Paid By' => @anchor_name,
        'Date of Payment' => @today_date,
        'UTR Number' => @utr,
        'Payment Type' => 'Repayment',
        'Amount' => "₹ #{comma_seperated_value(@payment)}"
      }
      payment_breakup = {
        'Instrument Number' => @testdata['Dealer Invoice Details']['Invoice Number'],
        'Due of Payment' => @today_date,
        'Date of Payment' => @today_date,
        'DPD' => '-',
        'Payment Type' => 'Pre-Payment',
        'Principal Paid' => "₹ #{comma_seperated_value(@transaction_values[0])}",
        'Interest Paid' => "₹ #{comma_seperated_value(@interest)}",
        'Total Amount Paid' => "₹ #{comma_seperated_value(@payment)}",
        'Payment Charges' => '₹ 0'
      }
      @common_pages.click_menu(MENU_PAYMENT_HISTORY)
      result = @payments_page.verify_transaction_in_payment_history(expected_values.values)
      expect(result).to eq true
      @payments_page.view_detailed_breakup(@utr)
      result = @payments_page.verify_transaction_in_payment_history(payment_breakup.values)
      expect(result).to eq true
    end

    e.run_step 'Investor logs out' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Anchor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['grn_anchor']['email'], $conf['users']['grn_anchor']['password'])).to eq true
    end

    e.run_step 'Verify Payment history after pre-payment' do
      expected_values = {
        'Payment Status' => 'Success',
        'Paid By' => @anchor_name,
        'Date of Payment' => @today_date,
        'UTR Number' => @utr,
        'Payment Type' => 'Repayment',
        'Amount' => "₹ #{comma_seperated_value(@payment)}"
      }
      payment_breakup = {
        'Instrument Number' => @testdata['Dealer Invoice Details']['Invoice Number'],
        'Due of Payment' => @upcoming_date,
        'Date of Payment' => @today_date,
        'DPD' => '-',
        'Payment Type' => 'Pre-Payment',
        'Principal Paid' => "₹ #{comma_seperated_value(@transaction_values[0])}",
        'Interest Paid' => "₹ #{comma_seperated_value(@interest)}",
        'Total Amount Paid' => "₹ #{comma_seperated_value(@payment)}",
        'Payment Charges' => "₹ #{comma_seperated_value(@prepayment_charges)}"
      }
      @common_pages.click_menu(MENU_PAYMENT_HISTORY)
      @common_pages.apply_list_filter({ 'Type Of Payment' => 'Repayment' })
      result = @payments_page.verify_transaction_in_payment_history(expected_values.values)
      expect(result).to eq true
      @payments_page.view_detailed_breakup(@utr)
      result = @payments_page.verify_transaction_in_payment_history(payment_breakup.values)
      expect(result).to eq true
    end
  end

  it 'Payment: CIP: Excess amount(Investor Refund Scenario)', :sanity, :inv_refund_scenario, :no_run do |e|
    e.run_step 'Clear all refunds' do
      expect(clear_refunds(@anchor_name)).to eq true
    end

    e.run_step 'Create a complete transaction as Dealer(Draft -> Released) and disburse the transaction' do
      @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
      @invoice_value = comma_seperated_value(@testdata['Dealer Invoice Details']['Invoice Value'])
      @testdata['Transaction List']['Instrument Value'] = "₹#{@invoice_value}"
      @transaction_id = seed_transaction({
                                           actor: 'grn_dealer',
                                           counter_party: 'grn_anchor',
                                           invoice_details: @testdata['Dealer Invoice Details'],
                                           invoice_file: @invoice_file,
                                           program: 'Invoice Financing - Dealer',
                                           program_group: 'invoice'
                                         })
      expect(@transaction_id).not_to include('Error while creating transaction')
      details = disburse_transaction({
                                       transaction_id: @transaction_id,
                                       invoice_value: @testdata['Dealer Invoice Details']['Invoice Value'],
                                       type: 'rearend',
                                       date_of_payment: @prepayment_date,
                                       payment_proof: @payment_proof,
                                       program: 'Invoice Financing - Dealer'
                                     })
      expect(details).not_to eq 'Error while disbursements'
      @transaction_values = details[0]
      @disbursement_values = details[1]
      @testdata['Transaction List']['Transaction Value'] = "₹#{comma_seperated_value(@transaction_values[0])}"
      @testdata['Transaction List']['Status'] = 'Upcoming'
    end

    e.run_step 'Login as Investor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['investor']['email'], $conf['users']['investor']['password'])).to eq true
    end

    e.run_step 'Record Excess amount as pre-payment as anchor' do
      @outstanding_values_hash[:transaction_values] = @transaction_values
      @outstanding_values_hash[:due_date] = (Date.parse(@prepayment_date) + $conf['dealer_tenor']).strftime('%d-%b-%Y')
      calculated_values = @payments_page.calculate_outstanding_value(@outstanding_values_hash)
      @outstanding_value = calculated_values[0]
      @interest = calculated_values[1]
      @payment = @outstanding_value + 1000
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @tarspect_methods.click_button('Add Settlement details')
      @utr = @payments_page.repay_amount(@payment, @upload_doc, @vendor_pan, 'Dealer Finance', @anchor_pan)
      @actual_summary, @report_link = @disbursement_page.upload_bulk_disbursement(@upload_doc, 'Repayment')
      expect(@report_link.empty?).to eq(false), 'Report link is empty'
    end

    e.run_step 'Verify report of repayment' do
      expected_report = @payments_page.create_expected_data_for_repayment(@utr)
      actual_report = @disbursement_page.verify_bulk_disbursment_summary_report(@report_link, 'Repayment')
      expect(actual_report).to eq(expected_report)
    end

    e.run_step 'Verify summary report of repayment' do
      formatted_amount = if @payment > 100_000
                           "₹ #{get_formatted_amount(@payment)} LAC"
                         else
                           "₹ #{get_formatted_amount(@payment)}"
                         end
      expected_summary = { 'Total Repayment Value' => formatted_amount, 'Payment accepted' => '1', 'Payment rejected' => '-' }
      expect(@actual_summary).to eq(expected_summary)
    end

    e.run_step 'Verify No Upcoming Transaction dues after Excess Payment' do
      navigate_to($conf['base_url'])
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @common_pages.click_transactions_tab(DUE_FOR_PAYMENT)
      @common_pages.apply_list_filter({ 'Vendor/Dealer' => @vendor_actor })
      expect(@payments_page.overdue_available(@vendor_name)).to eq false
      calculated_values1 = @payments_page.calculate_prepayment_values(
        transaction_value: @transaction_values[0],
        payment_value: @payment,
        tenor: $conf['dealer_tenor'],
        disbursement_date: Date.today - $conf['dealer_tenor'] + 10
      )
      @outstanding_value = calculated_values1[0]
      @interest_1 = calculated_values1[1]
      @prepayment_charges = calculated_values1[2]
      @refund_amount = calculated_values1[3]
      sleep 5
      expect(@payments_page.no_invoices_to_payment?).to eq true
    end

    e.run_step 'Verify the transaction details in Payments tab - Due for Payment' do
      expected_values = {
        'Due Date' => @upcoming_date,
        'Principal Paid / Outstanding' => "₹ #{comma_seperated_value(@transaction_values[0])}  /  ₹ 0",
        'Interest Paid / Outstanding' => "₹ #{comma_seperated_value(@interest)}  /  ₹ 0",
        'Charges Outstanding' => '₹ 0',
        'Total Outstanding' => '₹ 0'
      }
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @common_pages.click_transactions_tab(MATURED)
      @common_pages.navigate_to_transaction(@transaction_id)
      @tarspect_methods.click_link('Payment')
      actual_values = @disbursement_page.get_due_for_payment_details
      expect(actual_values).to eq expected_values
    end

    e.run_step 'Verify the transaction details in Payments tab - Recorded Payment' do
      expected_values = {
        'Date of Payment' => @today_date,
        'UTR Number' => @utr,
        'Type of Payment' => 'Pre-Payment',
        'Principal Paid' => "₹#{comma_seperated_value(@transaction_values[0])}",
        'Interest Paid' => "₹#{comma_seperated_value(@interest)}",
        'Accured Interest Paid' => '₹0',
        'Charges Paid' => '₹0',
        'Total Amount Paid' => "₹#{comma_seperated_value(@transaction_values[0] + @interest)}",
        'Payment Receipt' => 'View  '
      }
      actual_values = @payments_page.get_recorded_payment_details
      expect(actual_values).to eq expected_values
    end

    e.run_step 'Investor logs out' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Anchor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['grn_anchor']['email'], $conf['users']['grn_anchor']['password'])).to eq true
    end

    e.run_step 'Verify Payment history after pre-payment as Anchor' do # need to confirm which payment is showing here... paid amount or principal + interest # check
      expected_values = {
        'Payment Status' => 'Success',
        'Paid By' => @anchor_name,
        'Date of Payment' => @today_date,
        'UTR Number' => @utr,
        'Payment Type' => 'Repayment',
        'Amount' => "₹ #{comma_seperated_value(@payment)}"
      }
      payment_breakup = {
        'Instrument Number' => @testdata['Dealer Invoice Details']['Invoice Number'],
        'Due of Payment' => @upcoming_date,
        'Date of Payment' => @today_date,
        'DPD' => '-',
        'Payment Type' => 'Pre-Payment',
        'Principal Paid' => "₹ #{comma_seperated_value(@transaction_values[0])}",
        'Interest Paid' => "₹ #{comma_seperated_value(@interest)}",
        'Total Amount Paid' => "₹ #{comma_seperated_value(@payment - 1000)}",
        'Payment Charges' => '₹ 0'
      }
      @common_pages.click_menu(MENU_PAYMENT_HISTORY)
      @common_pages.apply_list_filter({ 'Type Of Payment' => 'Repayment' })
      result = @payments_page.verify_transaction_in_payment_history(expected_values.values)
      expect(result).to eq true
      @payments_page.view_detailed_breakup(@utr)
      result = @payments_page.verify_transaction_in_payment_history(payment_breakup.values)
      expect(result).to eq true
    end

    e.run_step 'Anchor logs out' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Product' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['product']['email'], $conf['users']['product']['password'])).to eq true
    end

    e.run_step "Verify Refund status #{@anchor_name} for excess payment as Product" do
      @common_pages.click_menu(MENU_REFUND)
      @common_pages.apply_filter({ 'Entity Name' => @anchor_name })
      @tarspect_methods.wait_for_loader_to_disappear(MAX_LOADER_TIME)
      refund_details = @payments_page.get_refund_details(@anchor_name)[-1]
      expect(refund_details).to eq "₹ #{comma_seperated_value(@refund_amount)}"
    end

    e.run_step 'Product logs out' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Investor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['investor']['email'], $conf['users']['investor']['password'])).to eq true
    end

    e.run_step 'Verify Payment history of the recorded payment as Investor' do # need to confirm which payment is showing here... paid amount or principal + interest # check
      expected_values = {
        'Payment Status' => 'Success',
        'Paid By' => @anchor_name,
        'Date of Payment' => @today_date,
        'UTR Number' => @payment_details['UTR Number'],
        'Payment Type' => 'Repayment',
        'Amount' => "₹ #{comma_seperated_value(@payment_details['Payment Amount'])}"
      }
      payment_breakup = {
        'Instrument Number' => @testdata['Dealer Invoice Details']['Invoice Number'],
        'Due of Payment' => @upcoming_date,
        'Date of Payment' => @today_date,
        'DPD' => '-',
        'Payment Type' => 'Pre-Payment',
        'Principal Paid' => "₹ #{comma_seperated_value(@transaction_values[0])}",
        'Interest Paid' => "₹ #{comma_seperated_value(@interest)}",
        'Total Amount Paid' => "₹ #{comma_seperated_value(@payment_details['Payment Amount'] - @refund_amount)}",
        'Payment Charges' => "₹ #{comma_seperated_value(@prepayment_charges)}"
      }
      @common_pages.click_menu('Payment History')
      @common_pages.apply_list_filter(
        {
          'Type Of Payment' => 'Repayment',
          'Paid By' => 'Tvs - Anchor',
          'date_range' => [{ 'Date Range' => @today_date }, { 'Date Range' => @today_date }]
        }
      )
      result = @payments_page.verify_transaction_in_payment_history(expected_values.values)
      expect(result).to eq true
      @payments_page.view_detailed_breakup(@payment_details['UTR Number'])
      result = @payments_page.verify_transaction_in_payment_history(payment_breakup.values)
      expect(result).to eq true
    end

    e.run_step 'Verify Refund status for excess payment as Investor' do
      @common_pages.click_menu(MENU_REFUND)
      @common_pages.apply_filter({ 'Entity Name' => @anchor_name })
      @tarspect_methods.wait_for_loader_to_disappear(MAX_LOADER_TIME)
      refund_details = @payments_page.get_refund_details(@anchor_name)[-2]
      expect(refund_details).to eq "₹ #{comma_seperated_value(@refund_amount)}"
    end

    # Bug 90416: Error in fetching bank details
    # e.run_step 'Verify Liability account details are shown up while Refund' do
    #   bank_details = {
    #     'Bank Name' => $conf['users']['grn_anchor']['bank_name'],
    #     'Account Number' => $conf['users']['grn_anchor']['account_number'],
    #     'IFSC Code' => $conf['users']['grn_anchor']['ifsc_code']
    #   }
    #   @payments_page.open_refund(@anchor_name)
    #   expect(@disbursement_page.verify_summary_details(bank_details)).to eq true
    #   @common_pages.close_modal
    # end

    e.run_step 'Investor makes refund to the liability' do
      @refund_details = {
        'UTR Number' => "UTR#{DateTime.now.to_time.to_i}#{rand(1..999)}",
        'Date of Payment' => Date.today.strftime('%d-%b-%Y'),
        'Refund Amount' => @refund_amount
      }
      @payments_page.record_refund(
        @anchor_name,
        @refund_details
      )
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['PaymentsSuccess']
    end

    e.run_step 'Verify Payment summary modal for Refund' do
      expect(@transactions_page.transaction_summary_present?).to eq true
      expect(@transactions_page.verify_summary('Total Value')).to eq "₹ #{comma_seperated_value(@refund_amount)}"
      expect(@transactions_page.verify_summary('Entity')).to eq @anchor_name
      @tarspect_methods.click_button('close')
    end

    e.run_step 'Verify liabilty not listing in Refund list post refund success' do
      expect(@payments_page.get_refund_details(@anchor_name)).to eq []
    end

    e.run_step 'Verify Payment-history for Refund as Investor' do
      expected_values = {
        'UTR Number' => @refund_details['UTR Number'],
        'Date of Payment' => @today_date,
        'Dealers/Vendors/Anchor' => @anchor_name,
        'Payment Type' => 'Refund',
        'Total Amount Paid' => "₹ #{comma_seperated_value(@refund_details['Refund Amount'])}"
      }
      @common_pages.click_menu(MENU_PAYMENT_HISTORY)
      @payments_page.toggle_investor_payments(true)
      @common_pages.apply_list_filter({ 'Type Of Payment' => 'Refund' })
      result = @payments_page.verify_transaction_in_payment_history(expected_values.values)
      expect(result).to eq true
    end
  end

  it 'Payment: CIP: Bullet payment a transaction on current due date', :sanity, :bullet_payment_cip do |e|
    e.run_step 'Create a complete transaction as Dealer(Draft -> Released)' do
      @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
      @invoice_value = comma_seperated_value(@testdata['Dealer Invoice Details']['Invoice Value'])
      @testdata['Transaction List']['Instrument Value'] = "₹#{@invoice_value}"
      @transaction_id = seed_transaction({
                                           actor: 'grn_dealer',
                                           counter_party: 'grn_anchor',
                                           invoice_details: @testdata['Dealer Invoice Details'],
                                           invoice_file: @invoice_file,
                                           program: 'Invoice Financing - Dealer',
                                           program_group: 'invoice'
                                         })
      expect(@transaction_id).not_to include('Error while creating transaction')
    end

    e.run_step 'Login as Investor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['investor']['email'], $conf['users']['investor']['password'])).to eq true
    end

    e.run_step "Disburse and Verify transaction listed in the 'Due for payments' as Investor" do
      details = disburse_transaction({
                                       transaction_id: @transaction_id,
                                       invoice_value: @testdata['Dealer Invoice Details']['Invoice Value'],
                                       type: 'rearend',
                                       date_of_payment: @current_due_date,
                                       payment_proof: @payment_proof,
                                       program: 'Invoice Financing - Dealer'
                                     })
      expect(details).not_to eq 'Error while disbursements'
      @transaction_values = details[0]
      @disbursement_values = details[1]
      @testdata['Transaction List']['Transaction Value'] = "₹#{comma_seperated_value(@transaction_values[0])}"
      @testdata['Transaction List']['Status'] = 'Current Due'
      @testdata['Transaction List'].delete('Anchor Name')
      @testdata['Transaction List'].delete('Date of Initiation')
      @testdata['Transaction List']['Due Date'] = @today_date
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @common_pages.click_transactions_tab('Due For Payment')
      @common_pages.apply_list_filter({ 'Vendor/Dealer' => @vendor_actor })
      @payments_page.select_overdue_details(@vendor_name)
      result = @payments_page.verify_transaction_in_due_for_payments(
        @testdata['Transaction List']['Status'],
        @testdata['Dealer Invoice Details']['Invoice Number'],
        @testdata['Transaction List']['Transaction Value']
      )
      expect(result).to eq true
    end

    e.run_step 'Investor logs out' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Dealer' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['grn_dealer']['email'], $conf['users']['grn_dealer']['password'])).to eq true
    end

    e.run_step "Verify transaction not listed in the 'Due for payments' as non-liable actor - Dealer" do
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @common_pages.click_transactions_tab(DUE_FOR_REPAYMENT)
      expect(@payments_page.overdue_available(@vendor_name)).to eq false
    end

    e.run_step 'Dealer logs out' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Anchor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['grn_anchor']['email'], $conf['users']['grn_anchor']['password'])).to eq true
    end

    e.run_step "Verify transaction in the 'Due for payments' as Anchor" do
      @outstanding_values_hash[:transaction_values] = @transaction_values
      @outstanding_values_hash[:due_date] = @outstanding_values_hash[:due_date] = (Date.parse(@current_due_date) + $conf['dealer_tenor']).strftime('%d-%b-%Y')
      calculated_values = @payments_page.calculate_outstanding_value(@outstanding_values_hash)
      @outstanding_value = calculated_values[0]
      @interest = calculated_values[1]
      @penal_charges = calculated_values[2]
      @repayment_list_details = {
        'Status' => @testdata['Transaction List']['Status'],
        'Vendor Name' => @testdata['Transaction List']['Vendor Name'],
        'Due date' => @today_date,
        'Principal' => @testdata['Transaction List']['Transaction Value'],
        'Interest' => "₹#{comma_seperated_value(@interest)}",
        'Charges' => "₹#{comma_seperated_value(@penal_charges)}",
        'Total Outstanding' => "₹#{comma_seperated_value(@outstanding_value)}",
        'Demanded Interest' => 'NA'
      }
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @common_pages.click_transactions_tab(DUE_FOR_REPAYMENT)
      @payments_page.select_overdue_details(@testdata['Investor Commercials']['investor'])
      result = @payments_page.verify_transaction_in_due_for_payments(@repayment_list_details.values)
      expect(result).to eq true
    end

    e.run_step "Verify 'Record payment' not available for the liable actor - Anchor" do
      expect(@payments_page.record_payment_available?).to eq false
    end

    e.run_step 'Anchor logs out' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Investor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['investor']['email'], $conf['users']['investor']['password'])).to eq true
    end

    # e.run_step 'Verify Investor account details are shown up while record payment' do
    #   # Bug 73306
    #   # bank_details = {
    #   #   'Bank Name' => 'HDFC',
    #   #   'Account Number' => '12321312312',
    #   #   'IFSC Code' => 'HDFC0000002'
    #   # }
    #   @payments_page.record_payment_icon.click
    #   sleep 2
    #   # expect(@disbursement_page.verify_summary_details(bank_details)).to eq true
    #   @common_pages.close_modal
    # end

    e.run_step 'Record payment for the Current due date transaction' do
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @tarspect_methods.click_button('Add Settlement details')
      @payment = @outstanding_value
      @utr = @payments_page.repay_amount(@payment, @upload_doc, @vendor_pan, 'Dealer Finance', @anchor_pan)
      @actual_summary, @report_link = @disbursement_page.upload_bulk_disbursement(@upload_doc, 'Repayment')
      expect(@report_link.empty?).to eq(false), 'Report link is empty'
    end

    e.run_step 'Verify report of repayment' do
      expected_report = @payments_page.create_expected_data_for_repayment(@utr)
      actual_report = @disbursement_page.verify_bulk_disbursment_summary_report(@report_link, 'Repayment')
      expect(actual_report).to eq(expected_report)
    end

    e.run_step 'Verify summary report of repayment' do
      formatted_amount = if @payment > 100_000
                           "₹ #{get_formatted_amount(@payment)} LAC"
                         else
                           "₹ #{get_formatted_amount(@payment)}"
                         end
      expected_summary = { 'Total Repayment Value' => formatted_amount, 'Payment accepted' => '1', 'Payment rejected' => '-' }
      expect(@actual_summary).to eq(expected_summary)
    end

    e.run_step 'Verify Transction is not present in Due for Re-payment after payment success' do
      sleep 5
      navigate_to($conf['base_url'])
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @common_pages.click_transactions_tab(DUE_FOR_PAYMENT)
      expect(@payments_page.overdue_available(@vendor_name)).to eq false
    end

    e.run_step 'Verify transaction is moved to matured after payment' do
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @common_pages.click_transactions_tab(MATURED)
      expect(@common_pages.transaction_listed?(@transaction_id)).to eq(true), "Transaction #{@transaction_id} is not listed"
      expect(@transactions_page.status_timeline_on_hover(@transaction_id, @today_date, 'CA Approval')).to eq true
      expect(@transactions_page.status_timeline_on_hover(@transaction_id, @today_date, 'Anchor Approval')).to eq true
      expect(@transactions_page.status_timeline_on_hover(@transaction_id, @today_date, 'CA Approval (Level 2)')).to eq true
      expect(@transactions_page.status_timeline_on_hover(@transaction_id, @today_date, 'Settled')).to eq true
      expect(@transactions_page.status_timeline_on_hover(@transaction_id, @today_date, 'Matured')).to eq true
    end

    e.run_step 'Verify the transaction status and timeline status' do
      @common_pages.navigate_to_transaction(@transaction_id)
      expect(@transactions_page.verify_transaction_status('Matured')).to eq true
      expect(@transactions_page.status_timeline_present?(@today_date, 'CA Approval')).to eq true
      expect(@transactions_page.status_timeline_present?(@today_date, 'Anchor Approval')).to eq true
      expect(@transactions_page.status_timeline_present?(@today_date, 'CA Approval (Level 2)')).to eq true
      expect(@transactions_page.status_timeline_present?(@today_date, 'Settled')).to eq true
      expect(@transactions_page.status_timeline_present?(@today_date, 'Matured')).to eq true
    end

    e.run_step 'Verify Due for Payment details' do
      expected_values = {
        'Due Date' => @today_date,
        'Principal Paid / Outstanding' => "₹ #{comma_seperated_value(@transaction_values[0])}  /  ₹ 0",
        'Interest Paid / Outstanding' => "₹ #{comma_seperated_value(@transaction_values[2])}  /  ₹ 0",
        'Charges Outstanding' => '₹ 0',
        'Total Outstanding' => '₹ 0'
      }
      @tarspect_methods.click_link('Payment')
      actual_values = @disbursement_page.get_due_for_payment_details
      expect(actual_values).to eq expected_values
    end

    e.run_step 'Verify Recorded payment details' do
      expected_values = {
        'Date of Payment' => @today_date,
        'UTR Number' => @utr,
        'Type of Payment' => 'On-Payment',
        'Principal Paid' => @repayment_list_details['Principal'],
        'Interest Paid' => @repayment_list_details['Interest'],
        'Accured Interest Paid' => '₹0',
        'Charges Paid' => @repayment_list_details['Charges'],
        'Total Amount Paid' => "₹#{comma_seperated_value(@payment)}",
        'Payment Receipt' => 'View  '
      }
      actual_values = @payments_page.get_recorded_payment_details
      expect(actual_values).to eq expected_values
    end

    e.run_step 'Verify Payment history of the recorded payment as Anchor(Current Due payments)' do
      expected_values = {
        'Payment Status' => 'Success',
        'Paid By' => @anchor_name,
        'Date of Payment' => @today_date,
        'UTR Number' => @utr,
        'Payment Type' => 'Repayment',
        'Amount' => "₹ #{comma_seperated_value(@payment)}"
      }
      payment_breakup = {
        'Instrument Number' => @testdata['Dealer Invoice Details']['Invoice Number'],
        'Due of Payment' => @today_date,
        'Date of Payment' => @today_date,
        'DPD' => '0',
        'Payment Type' => 'On-Payment',
        'Principal Paid' => "₹ #{comma_seperated_value(@transaction_values[0])}",
        'Interest Paid' => "₹ #{comma_seperated_value(@interest)}",
        'Total Amount Paid' => "₹ #{comma_seperated_value(@payment)}",
        'Payment Charges' => '₹ 0'
      }
      @common_pages.click_menu(MENU_PAYMENT_HISTORY)
      result = @payments_page.verify_transaction_in_payment_history(expected_values.values)
      expect(result).to eq true
      @payments_page.view_detailed_breakup(@utr)
      result = @payments_page.verify_transaction_in_payment_history(payment_breakup.values)
      expect(result).to eq true
    end

    e.run_step 'Anchor logs out' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Dealer' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['grn_dealer']['email'], $conf['users']['grn_dealer']['password'])).to eq true
    end

    e.run_step 'Verify transaction is moved to matured after payment as non-liable actor - Dealer' do
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @common_pages.click_transactions_tab(MATURED)
      expect(@common_pages.transaction_listed?(@transaction_id)).to eq(true), "Transaction #{@transaction_id} is not listed"
      expect(@transactions_page.status_timeline_on_hover(@transaction_id, @today_date, 'CA Approval')).to eq true
      expect(@transactions_page.status_timeline_on_hover(@transaction_id, @today_date, 'Anchor Approval')).to eq true
      expect(@transactions_page.status_timeline_on_hover(@transaction_id, @today_date, 'CA Approval (Level 2)')).to eq true
      expect(@transactions_page.status_timeline_on_hover(@transaction_id, @today_date, 'Settled')).to eq true
      expect(@transactions_page.status_timeline_on_hover(@transaction_id, @today_date, 'Matured')).to eq true
    end

    e.run_step 'Verify the transaction status and timeline status as non-liable actor - Dealer' do
      @common_pages.navigate_to_transaction(@transaction_id)
      expect(@transactions_page.verify_transaction_status('Matured')).to eq true
      expect(@transactions_page.status_timeline_present?(@today_date, 'CA Approval')).to eq true
      expect(@transactions_page.status_timeline_present?(@today_date, 'Anchor Approval')).to eq true
      expect(@transactions_page.status_timeline_present?(@today_date, 'CA Approval (Level 2)')).to eq true
      expect(@transactions_page.status_timeline_present?(@today_date, 'Settled')).to eq true
      expect(@transactions_page.status_timeline_present?(@today_date, 'Matured')).to eq true
    end

    e.run_step 'Verify Due for Payment details as non-liable actor - Dealer' do
      expected_values = {
        'Due Date' => @today_date,
        'Principal Paid / Outstanding' => "₹ #{comma_seperated_value(@transaction_values[0])}  /  ₹ 0",
        'Interest Paid / Outstanding' => "₹ #{comma_seperated_value(@transaction_values[2])}  /  ₹ 0",
        'Charges Outstanding' => '₹ 0',
        'Total Outstanding' => '₹ 0'
      }
      @tarspect_methods.click_link('Payment')
      actual_values = @disbursement_page.get_due_for_payment_details
      expect(actual_values).to eq expected_values
    end

    e.run_step 'Verify Recorded payment details as non-liable actor - Dealer' do
      expected_values = {
        'Date of Payment' => @today_date,
        'UTR Number' => @utr,
        'Type of Payment' => 'On-Payment',
        'Principal Paid' => @repayment_list_details['Principal'],
        'Interest Paid' => @repayment_list_details['Interest'],
        'Accured Interest Paid' => '₹0',
        'Charges Paid' => @repayment_list_details['Charges'],
        'Total Amount Paid' => "₹#{comma_seperated_value(@payment)}",
        'Payment Receipt' => 'View  '
      }
      actual_values = @payments_page.get_recorded_payment_details
      expect(actual_values).to eq expected_values
    end
  end

  it 'Payment: CIP: Partial payment an overdue transaction', :sanity, :cip_partial_overdue do |e|
    e.run_step 'Create a complete transaction as Dealer(Draft -> Released)' do
      @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
      @invoice_value = comma_seperated_value(@testdata['Dealer Invoice Details']['Invoice Value'])
      @testdata['Transaction List']['Instrument Value'] = "₹#{@invoice_value}"
      @transaction_id = seed_transaction({
                                           actor: 'grn_dealer',
                                           counter_party: 'grn_anchor',
                                           invoice_details: @testdata['Dealer Invoice Details'],
                                           invoice_file: @invoice_file,
                                           program: 'Invoice Financing - Dealer',
                                           program_group: 'invoice'
                                         })
      expect(@transaction_id).not_to include('Error while creating transaction')
    end

    e.run_step 'Disburse the transaction' do
      details = disburse_transaction({
        transaction_id: @transaction_id,
        invoice_value: @testdata['Dealer Invoice Details']['Invoice Value'],
        type: 'rearend',
        date_of_payment: @overdue_date,
        payment_proof: @payment_proof,
        program: 'Invoice Financing - Dealer'
      })
      expect(details).not_to eq 'Error while disbursements'
      @transaction_values = details[0]
      @disbursement_values = details[1]
      @testdata['Transaction List']['Transaction Value'] = "₹#{comma_seperated_value(@transaction_values[0])}"
      @testdata['Transaction List']['Status'] = 'Overdue'
      @testdata['Transaction List'].delete('Anchor Name')
      @testdata['Transaction List'].delete('Date of Initiation')
      @testdata['Transaction List']['Due Date'] = (Date.today - 10).strftime('%d %b, %Y')
    end

    e.run_step 'Login as Anchor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['grn_anchor']['email'], $conf['users']['grn_anchor']['password'])).to eq true
    end

    e.run_step 'Verify transaction in the Due for payments as Anchor' do
      @outstanding_values_hash[:transaction_values] = @transaction_values
      @outstanding_values_hash[:due_date] = @outstanding_values_hash[:due_date] = (Date.parse(@overdue_date) + $conf['dealer_tenor']).strftime('%d-%b-%Y')
      calculated_values = @payments_page.calculate_outstanding_value(@outstanding_values_hash)
      @outstanding_value = calculated_values[0]
      @interest = calculated_values[1]
      @penal_charges = calculated_values[2]
      @repayment_list_details = {
        'Status' => @testdata['Transaction List']['Status'],
        'Vendor Name' => @testdata['Transaction List']['Vendor Name'],
        'Due date' => (Date.today - 10).strftime('%d %b, %Y'),
        'Principal' => @testdata['Transaction List']['Transaction Value'],
        'Interest' => "₹#{comma_seperated_value(@interest)}",
        'Charges' => "₹#{comma_seperated_value(@penal_charges)}",
        'Total Outstanding' => "₹#{comma_seperated_value(@outstanding_value)}",
        'Demanded Interest' => 'NA'
      }
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @common_pages.click_transactions_tab(DUE_FOR_REPAYMENT)
      @payments_page.select_overdue_details(@testdata['Investor Commercials']['investor'])
      result = @payments_page.verify_transaction_in_due_for_payments(@repayment_list_details.values)
      expect(result).to eq true
    end

    e.run_step 'Anchor logs out' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Investor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['investor']['email'], $conf['users']['investor']['password'])).to eq true
    end

    e.run_step 'Disburse and Verify transaction in the Due for payments as Investor' do
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @common_pages.click_transactions_tab(DUE_FOR_PAYMENT)
      @common_pages.apply_list_filter({ 'Vendor/Dealer' => @vendor_actor, 'Anchor' => 'Tvs' })
      @payments_page.select_overdue_details(@vendor_name)
      result = @payments_page.verify_transaction_in_due_for_payments(
        @testdata['Transaction List']['Status'],
        @testdata['Dealer Invoice Details']['Invoice Number'],
        @testdata['Transaction List']['Transaction Value']
      )
      expect(result).to eq true
    end

    e.run_step 'Record partial payment for the Overdue transaction' do
      @payment = @outstanding_value.round(2) - 100
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @tarspect_methods.click_button('Add Settlement details')
      @utr = @payments_page.repay_amount(@payment, @upload_doc, @vendor_pan, 'Dealer Finance', @anchor_pan)
      @actual_summary, @report_link = @disbursement_page.upload_bulk_disbursement(@upload_doc, 'Repayment')
      expect(@report_link.empty?).to eq(false), 'Report link is empty'
    end

    e.run_step 'Verify report of repayment' do
      expected_report = @payments_page.create_expected_data_for_repayment(@utr)
      actual_report = @disbursement_page.verify_bulk_disbursment_summary_report(@report_link, 'Repayment')
      expect(actual_report).to eq(expected_report)
    end

    e.run_step 'Verify summary report of repayment' do
      formatted_amount = if @payment > 100_000
                           "₹ #{get_formatted_amount(@payment)} LAC"
                         else
                           "₹ #{get_formatted_amount(@payment)}"
                         end
      expected_summary = { 'Total Repayment Value' => formatted_amount, 'Payment accepted' => '1', 'Payment rejected' => '-' }
      expect(@actual_summary).to eq(expected_summary)
    end

    e.run_step 'Verify Transction is present in Due for Re-payment after partial payment success' do
      navigate_to($conf['base_url'])
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @common_pages.click_transactions_tab(DUE_FOR_PAYMENT)
      @common_pages.apply_list_filter({ 'Vendor/Dealer' => @vendor_actor, 'Anchor' => 'Tvs' })
      @payments_page.select_overdue_details(@vendor_name)
      sleep 5
      # @payments_page.select_overdue_details(@testdata['Investor Commercials']['investor'])
      post_partial_payment_details = {
        'Status' => @testdata['Transaction List']['Status'],
        'Vendor Name' => @testdata['Transaction List']['Vendor Name'],
        'Due date' => (Date.today - 10).strftime('%d %b, %Y'),
        'Principal' => '₹100',
        'Interest' => '₹0',
        'Charges' => '₹0',
        'Total Outstanding' => '₹100',
        'Demanded Interest' => 'NA'
      }
      result = @payments_page.verify_transaction_in_due_for_payments(post_partial_payment_details.values)
      expect(result).to eq true
    end

    e.run_step 'Verify transaction is not moved to matured after partial payment' do
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @common_pages.click_transactions_tab(MATURED)
      expect(@common_pages.transaction_listed?(@transaction_id)).to eq(false), "Transaction #{@transaction_id} is listed, Ideally it should not be present"
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @common_pages.click_transactions_tab(SHOW_ALL)
      @common_pages.navigate_to_transaction(@transaction_id)
      expect(@transactions_page.verify_transaction_status('Settled')).to eq true
    end

    e.run_step 'Verify Due for Payment details with partial payment charges' do
      expected_values = {
        'Due Date' => (Date.today - 10).strftime('%d %b, %Y'),
        'Principal Paid / Outstanding' => "₹ #{comma_seperated_value(@transaction_values[0] - 100)}  /  ₹ 100",
        'Interest Paid / Outstanding' => "₹ #{comma_seperated_value(@interest)}  /  ₹ 0",
        'Charges Outstanding' => '₹ 0',
        'Total Outstanding' => '₹ 100'
      }
      @tarspect_methods.click_link('Payment')
      actual_values = @disbursement_page.get_due_for_payment_details
      expect(actual_values).to eq expected_values
    end

    e.run_step 'Verify Recorded payment details for the partial payment' do
      expected_values = {
        'Date of Payment' => @today_date,
        'UTR Number' => @utr,
        'Type of Payment' => 'Late-Payment',
        'Principal Paid' => "₹#{comma_seperated_value(@transaction_values[0] - 100)}",
        'Interest Paid' => @repayment_list_details['Interest'],
        'Accured Interest Paid' => '₹0',
        'Charges Paid' => "₹#{comma_seperated_value(@penal_charges)}",
        'Total Amount Paid' => "₹#{comma_seperated_value(@payment)}",
        'Payment Receipt' => 'View  '
      }
      actual_values = @payments_page.get_recorded_payment_details
      expect(actual_values).to eq expected_values
    end
  end

  it 'Payment: CIP: Check Multiple partial payment scenario', :sanity, :cip_multiple_partial_payments do |e|
    e.run_step 'Create and disburse 3 complete transaction as Dealer(Draft -> Released)' do
      @dealer_gstn = $conf['ramkay_gstn']
      @counterparty_gstn = $conf['tvs_gstn']
      @vendor_name = $conf['grn_dealer_name']
      @overdue_date1 = (Date.today - $conf['dealer_tenor'] - 10).strftime('%d-%b-%Y')
      @testdata1 = JSON.parse(ERB.new(@erb_file).result(binding))
      @invoice_value1 = comma_seperated_value(@testdata1['Dealer Invoice Details']['Invoice Value'])
      @testdata1['Transaction List']['Invoice Value'] = "₹#{@invoice_value1}"
      @transaction_id1 = seed_transaction({
                                            actor: 'grn_dealer',
                                            counter_party: 'grn_anchor',
                                            invoice_details: @testdata1['Dealer Invoice Details'],
                                            invoice_file: @invoice_file,
                                            program: 'Invoice Financing - Dealer',
                                            program_group: 'invoice'
                                          })
      expect(@transaction_id1).not_to include('Error while creating transaction')

      @testdata2 = JSON.parse(ERB.new(@erb_file).result(binding))
      @invoice_value2 = comma_seperated_value(@testdata2['Dealer Invoice Details']['Invoice Value'])
      @testdata2['Transaction List']['Invoice Value'] = "₹#{@invoice_value2}"
      @transaction_id2 = seed_transaction({
                                            actor: 'grn_dealer',
                                            counter_party: 'grn_anchor',
                                            invoice_details: @testdata2['Dealer Invoice Details'],
                                            invoice_file: @invoice_file,
                                            program: 'Invoice Financing - Dealer',
                                            program_group: 'invoice'
                                          })
      expect(@transaction_id2).not_to include('Error while creating transaction')

      @overdue_date2 = (Date.today - $conf['dealer_tenor'] - 8).strftime('%d-%b-%Y')
      @testdata3 = JSON.parse(ERB.new(@erb_file).result(binding))
      @invoice_value3 = comma_seperated_value(@testdata3['Dealer Invoice Details']['Invoice Value'])
      @testdata3['Transaction List']['Invoice Value'] = "₹#{@invoice_value3}"
      @transaction_id3 = seed_transaction({
                                            actor: 'grn_dealer',
                                            counter_party: 'grn_anchor',
                                            invoice_details: @testdata3['Dealer Invoice Details'],
                                            invoice_file: @invoice_file,
                                            program: 'Invoice Financing - Dealer',
                                            program_group: 'invoice'
                                          })
      expect(@transaction_id3).not_to include('Error while creating transaction')

      details1 = disburse_transaction({
                                        transaction_id: @transaction_id1,
                                        invoice_value: @testdata1['Dealer Invoice Details']['Invoice Value'],
                                        type: 'rearend',
                                        date_of_payment: @overdue_date1,
                                        payment_proof: @payment_proof,
                                        program: 'Invoice Financing - Dealer'
                                      })
      expect(details1).not_to eq 'Error while disbursements'
      details2 = disburse_transaction({
                                        transaction_id: @transaction_id2,
                                        invoice_value: @testdata2['Dealer Invoice Details']['Invoice Value'],
                                        type: 'rearend',
                                        date_of_payment: @overdue_date1,
                                        payment_proof: @payment_proof,
                                        program: 'Invoice Financing - Dealer'
                                      })
      expect(details2).not_to eq 'Error while disbursements'
      details3 = disburse_transaction({
                                        transaction_id: @transaction_id3,
                                        invoice_value: @testdata3['Dealer Invoice Details']['Invoice Value'],
                                        type: 'rearend',
                                        date_of_payment: @overdue_date2,
                                        payment_proof: @payment_proof,
                                        program: 'Invoice Financing - Dealer'
                                      })
      expect(details3).not_to eq 'Error while disbursements'
      @transaction_values1 = details1[0]
      @transaction_values2 = details2[0]
      @transaction_values3 = details3[0]
      @outstanding_values_hash[:transaction_values] = @transaction_values1
      @outstanding_values_hash[:due_date] = (Date.parse(@overdue_date1) + $conf['dealer_tenor']).strftime('%d-%b-%Y')
      calculated_values1 = @payments_page.calculate_outstanding_value(@outstanding_values_hash)
      @outstanding_values_hash[:transaction_values] = @transaction_values2
      @outstanding_values_hash[:due_date] = (Date.parse(@overdue_date1) + $conf['dealer_tenor']).strftime('%d-%b-%Y')
      calculated_values2 = @payments_page.calculate_outstanding_value(@outstanding_values_hash)
      @outstanding_values_hash[:transaction_values] = @transaction_values3
      @outstanding_values_hash[:due_date] = (Date.parse(@overdue_date2) + $conf['dealer_tenor']).strftime('%d-%b-%Y')
      calculated_values3 = @payments_page.calculate_outstanding_value(@outstanding_values_hash)
      @outstanding_value1, @interest1, @penal_charges1 = calculated_values1
      @outstanding_value2, @interest2, @penal_charges2 = calculated_values2
      @outstanding_value3, @interest3, @penal_charges3 = calculated_values3
      @total_outstanding_value = rounded_half_down_value(@outstanding_value1 + @outstanding_value2 + @outstanding_value3)
    end

    e.run_step 'Verify transaction in the Due for payments as Anchor' do
      params = { 'program_group' => 'invoice', 'page' => 1 }
      resp = @common_api.perform_get_action('pending_dues_entity', params, 'grn_anchor')
      matching_record = resp[:body][:investor_vendors].select { |r| r[:vendor][:name] == @vendor_name }
      expect(matching_record.empty?).to eq(false), "Record not found for #{@vendor_name}"
      expect(matching_record[0][:total_amount_due] - @total_outstanding_value).to be <= (0.1), "#{matching_record[0][:total_amount_due]} <> #{@total_outstanding_value}"
    end

    e.run_step 'Login as Investor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['investor']['email'], $conf['users']['investor']['password'])).to eq true
    end

    e.run_step 'Record partial payment for current overdue charges, interest and check the Due for payment values' do
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @payment_value = @penal_charges1 + @interest1
      @payment = @payment_value.round(2)
      @tarspect_methods.click_button('Add Settlement details')
      @utr = @payments_page.repay_amount(@payment, @upload_doc, @vendor_pan, 'Dealer Finance', @anchor_pan)
      @actual_summary, @report_link = @disbursement_page.upload_bulk_disbursement(@upload_doc, 'Repayment')
      expect(@report_link.empty?).to eq(false), 'Report link is empty'
    end

    e.run_step 'Verify report of repayment' do
      expected_report = @payments_page.create_expected_data_for_repayment(@utr)
      actual_report = @disbursement_page.verify_bulk_disbursment_summary_report(@report_link, 'Repayment')
      expect(actual_report).to eq(expected_report)
    end

    e.run_step 'Verify summary report of repayment' do
      formatted_amount = if @payment > 100_000
                           "₹ #{get_formatted_amount(@payment)} LAC"
                         else
                           "₹ #{get_formatted_amount(@payment)}"
                         end
      expected_summary = { 'Total Repayment Value' => formatted_amount, 'Payment accepted' => '1', 'Payment rejected' => '-' }
      expect(@actual_summary).to eq(expected_summary)
    end

    e.run_step 'Verify Payment history of the recorded payment as Anchor(Overdue payments and multiple payments)' do
      expected_values = {
        'Payment Status' => 'Success',
        'Paid By' => @anchor_name,
        'Date of Payment' => @today_date,
        'UTR Number' => @utr,
        'Payment Type' => 'Repayment',
        'Amount' => "₹ #{comma_seperated_value(@payment)}"
      }
      payment_breakup_1 = {
        'Instrument Number' => @testdata1['Dealer Invoice Details']['Invoice Number'],
        'Due of Payment' => (Date.today - 10).strftime('%d %b, %Y'),
        'Date of Payment' => @today_date,
        'DPD' => '10',
        'Payment Type' => 'Late-Payment',
        'Principal Paid' => '₹ 0',
        'Interest Paid' => "₹ #{comma_seperated_value(@interest1)}",
        'Total Amount Paid' => "₹ #{comma_seperated_value(@payment_value)}",
        'Payment Charges' => "₹ #{comma_seperated_value(@penal_charges1)}"
      }
      navigate_to($conf['base_url'])
      @common_pages.click_menu(MENU_PAYMENT_HISTORY)
      result = @payments_page.verify_transaction_in_payment_history(expected_values.values)
      expect(result).to eq true
      @payments_page.view_detailed_breakup(@utr)
      result = @payments_page.verify_transaction_in_payment_history(payment_breakup_1.values)
      expect(result).to eq true
    end

    e.run_step 'Verify Transction is present in Due for Re-payment after partial payment success' do
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @common_pages.click_transactions_tab(DUE_FOR_PAYMENT)
      @common_pages.apply_list_filter({ 'Vendor/Dealer' => @vendor_actor })
      @payments_page.select_overdue_details(@vendor_name)
      @outstanding_value1 = rounded_half_down_value(@outstanding_value1 - @payment_value)
      post_partial_payment_details1 = {
        'Status' => 'Overdue',
        'Vendor Name' => @testdata1['Transaction List']['Vendor Name'],
        'Due date' => (Date.today - 10).strftime('%d %b, %Y'),
        'Principal' => "₹#{comma_seperated_value(rounded_half_down_value(@transaction_values1[0]))}",
        'Interest' => '₹0',
        'Charges' => '₹0',
        'Total Outstanding' => "₹#{comma_seperated_value(rounded_half_down_value(@outstanding_value1))}",
        'Demanded Interest' => 'NA'
      }
      result = @payments_page.verify_transaction_in_due_for_payments(post_partial_payment_details1.values)
      expect(result).to eq true

      @outstanding_value2 = rounded_half_down_value(@outstanding_value2)
      post_partial_payment_details2 = {
        'Status' => 'Overdue',
        'Vendor Name' => @testdata2['Transaction List']['Vendor Name'],
        'Due date' => (Date.today - 10).strftime('%d %b, %Y'),
        'Principal' => "₹#{comma_seperated_value(@transaction_values2[0])}",
        'Interest' => "₹#{comma_seperated_value(@interest2)}",
        'Charges' => "₹#{comma_seperated_value(@penal_charges2)}",
        'Total Outstanding' => "₹#{comma_seperated_value(@outstanding_value2)}",
        'Demanded Interest' => 'NA'
      }
      result = @payments_page.verify_transaction_in_due_for_payments(post_partial_payment_details2.values)
      expect(result).to eq true

      post_partial_payment_details3 = {
        'Status' => 'Overdue',
        'Vendor Name' => @testdata3['Transaction List']['Vendor Name'],
        'Due date' => (Date.today - 8).strftime('%d %b, %Y'),
        'Principal' => "₹#{comma_seperated_value(@transaction_values3[0])}",
        'Interest' => "₹#{comma_seperated_value(@interest3)}",
        'Charges' => "₹#{comma_seperated_value(@penal_charges3)}",
        'Total Outstanding' => "₹#{comma_seperated_value(@outstanding_value3)}",
        'Demanded Interest' => 'NA'
      }
      result = @payments_page.verify_transaction_in_due_for_payments(post_partial_payment_details3.values)
      expect(result).to eq true
    end

    e.run_step 'Record partial payment for oldest 2 same date transactions and check the Due for payment values' do
      @payment_value = rounded_half_down_value(@outstanding_value1 + @outstanding_value2)
      @payment = @payment_value
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @tarspect_methods.click_button('Add Settlement details')
      @utr = @payments_page.repay_amount(@payment, @upload_doc, @vendor_pan, 'Dealer Finance', @anchor_pan)
      @actual_summary, @report_link = @disbursement_page.upload_bulk_disbursement(@upload_doc, 'Repayment')
      expect(@report_link.empty?).to eq(false), 'Report link is empty'
    end

    e.run_step 'Verify report of repayment' do
      expected_report = @payments_page.create_expected_data_for_repayment(@utr)
      actual_report = @disbursement_page.verify_bulk_disbursment_summary_report(@report_link, 'Repayment')
      expect(actual_report).to eq(expected_report)
    end

    e.run_step 'Verify summary report of repayment' do
      formatted_amount = if @payment > 100_000
                           "₹ #{get_formatted_amount(@payment)} LAC"
                         else
                           "₹ #{get_formatted_amount(@payment)}"
                         end
      expected_summary = { 'Total Repayment Value' => formatted_amount, 'Payment accepted' => '1', 'Payment rejected' => '-' }
      expect(@actual_summary).to eq(expected_summary)
    end

    e.run_step 'Verify newest overdue transction is still present in Due for Re-payment after partial payment success' do
      navigate_to($conf['base_url'])
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @common_pages.click_transactions_tab(DUE_FOR_PAYMENT)
      @common_pages.apply_list_filter({ 'Vendor/Dealer' => @vendor_actor })
      @payments_page.select_overdue_details(@vendor_name)
      post_partial_payment_details3 = {
        'Status' => 'Overdue',
        'Vendor Name' => @testdata3['Transaction List']['Vendor Name'],
        'Due date' => (Date.today - 8).strftime('%d %b, %Y'),
        'Principal' => "₹#{comma_seperated_value(@transaction_values3[0])}",
        'Interest' => "₹#{comma_seperated_value(@interest3)}",
        'Charges' => "₹#{comma_seperated_value(@penal_charges3)}",
        'Total Outstanding' => "₹#{comma_seperated_value(@outstanding_value3)}",
        'Demanded Interest' => 'NA'
      }
      result = @payments_page.verify_transaction_in_due_for_payments(post_partial_payment_details3.values)
      expect(result).to eq true
    end
  end
end
