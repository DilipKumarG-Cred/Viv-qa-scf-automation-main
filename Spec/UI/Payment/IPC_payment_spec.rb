require './spec_helper'
describe 'Payment: IPC Strategy', :scf, :payments, :ipc_payments, :hover do
  before(:all) do
    @anchor_gstn = $conf['tvs_gstn']
    @counterparty_gstn = $conf['dozco_gstn']
    @vendor_name = $conf['grn_vendor_name']
    @anchor_name = $conf['grn_anchor_name']
    @anchor_pan = $conf['users']['grn_anchor']['pan']
    @vendor_pan = $conf['users']['grn_vendor']['pan']
    @invoice_file = "#{Dir.pwd}/test-data/attachments/anchor_invoice.pdf"
    @payment_proof = "#{Dir.pwd}/test-data/attachments/payment_proof.pdf"
    @erb_file = File.read("#{Dir.pwd}/test-data/erb/testbed_data.erb")
    @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
    @invoice_value = comma_seperated_value(@testdata['Invoice Details']['Invoice Value'])
    @testdata['Transaction List']['Instrument Value'] = "₹#{@invoice_value}"
    @today_date = Date.today.strftime('%d %b, %Y')
    @current_due_date = (Date.today - $conf['vendor_tenor']).strftime('%d-%b-%Y')
    @overdue_date = (Date.today - $conf['vendor_tenor'] - 10).strftime('%d-%b-%Y')
    @upload_doc = "#{Dir.pwd}/test-data/attachments/repayment_upload.xlsx"
    @outstanding_values_hash = {
      transaction_values: '',
      tenor: nil,
      due_date: '',
      type: 'frontend',
      payment_date: nil
    }
  end

  before(:each) do
    clear_all_overdues({ anchor: $conf['grn_anchor_name'], vendor: $conf['grn_vendor_name'] })
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
    clear_all_overdues({ anchor: $conf['grn_anchor_name'], vendor: $conf['grn_vendor_name'] })
  end

  it 'Payment : IPC : Bullet payment a transaction on current due date', :sanity do |e|
    e.run_step 'Create a complete transaction as Anchor(Draft -> Released)' do
      @transaction_id = seed_transaction({
                                           actor: 'grn_anchor',
                                           counter_party: 'grn_vendor',
                                           invoice_details: @testdata['Invoice Details'],
                                           invoice_file: @invoice_file,
                                           program: 'Invoice Financing - Vendor',
                                           investor_id: 7,
                                           program_group: 'invoice'
                                         })
      expect(@transaction_id).not_to include('Error while creating transaction')
    end

    e.run_step 'Login as Investor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['investor']['email'], $conf['users']['investor']['password'])).to eq true
    end

    e.run_step "Disburse and verify the transaction in the 'Due for payments' as Investor" do
      details = disburse_transaction({
                                       transaction_id: @transaction_id,
                                       invoice_value: @testdata['Invoice Details']['Invoice Value'],
                                       type: 'frontend',
                                       date_of_payment: @current_due_date,
                                       payment_proof: @payment_proof,
                                       program: 'Invoice Financing - Vendor'
                                     })
      expect(details).not_to include 'Error while disbursements'
      @transaction_values = details[0]
      @disbursement_values = details[1]
      @testdata['Transaction List']['Transaction Value'] = "₹#{comma_seperated_value(@transaction_values[0])}"
      @testdata['Transaction List']['Status'] = 'Current Due'
      @testdata['Transaction List'].delete('Date of Initiation')
      @testdata['Transaction List'].delete('Anchor Name')
      @testdata['Transaction List']['Due Date'] = @today_date
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @common_pages.click_transactions_tab('Due For Payment')
      @common_pages.apply_list_filter({ 'Vendor/Dealer' => $conf['grn_vendor_name'] })
      @payments_page.select_overdue_details($conf['grn_vendor_name'])
      result = @payments_page.verify_transaction_in_due_for_payments(
        @testdata['Transaction List']['Status'],
        @testdata['Invoice Details']['Invoice Number'],
        @testdata['Transaction List']['Transaction Value']
      )
      expect(result).to eq true
    end

    e.run_step "Verify 'Record payment' not available for actor - Investor" do
      expect(@payments_page.record_payment_available?).to eq false
    end

    e.run_step 'Investor logs out' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Anchor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['grn_anchor']['email'], $conf['users']['grn_anchor']['password'])).to eq true
    end

    e.run_step "Verify transaction not listed in the 'Due for payments' as non-liable actor - Anchor" do
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @common_pages.click_transactions_tab(DUE_FOR_REPAYMENT)
      expect(@payments_page.overdue_available(@vendor_name)).to eq false
    end

    e.run_step 'Anchor logs out' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Vendor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['grn_vendor']['email'], $conf['users']['grn_vendor']['password'])).to eq true
    end

    e.run_step "Verify transaction in the 'Due for payments' as Vendor" do
      @outstanding_values_hash[:transaction_values] = @transaction_values
      @outstanding_values_hash[:due_date] = (Date.parse(@current_due_date) + $conf['vendor_tenor']).strftime('%d-%b-%Y')
      calculated_values = @payments_page.calculate_outstanding_value(@outstanding_values_hash)
      @outstanding_value = calculated_values[0]
      @interest = calculated_values[1]
      @penal_charges = calculated_values[2]
      @repayment_list_details = {
        'Status' => @testdata['Transaction List']['Status'],
        'Anchor Name' => @anchor_name,
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

    e.run_step "Verify 'Record payment' available for the liable actor - Vendor" do
      expect(@payments_page.record_payment_available?).to eq false
    end

    e.run_step 'Vendor logs out' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Investor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['investor']['email'], $conf['users']['investor']['password'])).to eq true
    end

    e.run_step 'Verify Investor account details are shown up while record payment' do
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @payment = @outstanding_value
      @tarspect_methods.click_button('Add Settlement details')
      @utr = @payments_page.repay_amount(@payment, @upload_doc, @vendor_pan, 'Vendor Finance', @anchor_pan)
      @actual_summary, @report_link = @disbursement_page.upload_bulk_disbursement(@upload_doc, 'Repayment')
      expect(@report_link.empty?).to eq(false), 'Report link is empty'
      navigate_to($conf['base_url'])
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
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @common_pages.click_transactions_tab(DUE_FOR_PAYMENT)
      expect(@payments_page.overdue_available(@vendor_name)).to eq false
    end

    e.run_step 'Verify transaction is moved to matured after payment' do
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @common_pages.click_transactions_tab(MATURED)
      expect(@common_pages.transaction_listed?(@transaction_id)).to eq(true), "Transaction #{@transaction_id} is not listed"
      expect(@transactions_page.status_timeline_on_hover(@transaction_id, @today_date, 'CA Approval')).to eq true
      expect(@transactions_page.status_timeline_on_hover(@transaction_id, @today_date, 'Vendor/Dealer Approval')).to eq true
      expect(@transactions_page.status_timeline_on_hover(@transaction_id, @today_date, 'CA Approval (Level 2)')).to eq true
      expect(@transactions_page.status_timeline_on_hover(@transaction_id, @today_date, 'Settled')).to eq true
      expect(@transactions_page.status_timeline_on_hover(@transaction_id, @today_date, 'Matured')).to eq true
    end

    e.run_step 'Verify the transaction status and timeline status' do
      @common_pages.navigate_to_transaction(@transaction_id)
      expect(@transactions_page.verify_transaction_status('Matured')).to eq true
      expect(@transactions_page.status_timeline_present?(@today_date, 'CA Approval')).to eq true
      expect(@transactions_page.status_timeline_present?(@today_date, 'Vendor/Dealer Approval')).to eq true
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

    e.run_step 'Investor logs out' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Vendor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['grn_vendor']['email'], $conf['users']['grn_vendor']['password'])).to eq true
    end

    e.run_step 'Verify Payment history of the recorded payment as Vendor(Current Due payments)' do
      expected_values = {
        'Payment Status' => 'Success',
        'Paid By' => @vendor_name,
        'Date of Payment' => @today_date,
        'UTR Number' => @utr,
        'Payment Type' => 'Repayment',
        'Amount' => "₹ #{comma_seperated_value(@payment)}"
      }
      payment_breakup = {
        'Instrument Number' => @testdata['Invoice Details']['Invoice Number'],
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
  end

  it 'Payment : IPC : Partial payment an overdue transaction', :sanity, :partpay_overdue_txn do |e|
    e.run_step 'Create a complete transaction as Anchor(Draft -> Released)' do
      @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
      @invoice_value = comma_seperated_value(@testdata['Invoice Details']['Invoice Value'])
      @testdata['Transaction List']['Instrument Value'] = "₹#{@invoice_value}"
      @transaction_id = seed_transaction({
                                           actor: 'grn_anchor',
                                           counter_party: 'grn_vendor',
                                           invoice_details: @testdata['Invoice Details'],
                                           invoice_file: @invoice_file,
                                           program: 'Invoice Financing - Vendor',
                                           investor_id: 7,
                                           program_group: 'invoice'
                                         })
      expect(@transaction_id).not_to include('Error while creating transaction')
    end

    e.run_step 'Login as Investor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['investor']['email'], $conf['users']['investor']['password'])).to eq true
    end

    e.run_step 'Disburse and Verify transaction in the Due for payments as Investor' do
      details = disburse_transaction({
                                       transaction_id: @transaction_id,
                                       invoice_value: @testdata['Invoice Details']['Invoice Value'],
                                       type: 'frontend',
                                       date_of_payment: @overdue_date,
                                       payment_proof: @payment_proof,
                                       program: 'Invoice Financing - Vendor'
                                     })
      expect(details).not_to include 'Error while disbursements'
      @transaction_values = details[0]
      @disbursement_values = details[1]
      @testdata['Transaction List']['Transaction Value'] = "₹#{comma_seperated_value(@transaction_values[0])}"
      @testdata['Transaction List']['Status'] = 'Overdue'
      @testdata['Transaction List'].delete('Date of Initiation')
      @testdata['Transaction List'].delete('Anchor Name')
      @testdata['Transaction List']['Due Date'] = (Date.today - 10).strftime('%d %b, %Y')
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @common_pages.click_transactions_tab('Due For Payment')
      @common_pages.apply_list_filter({ 'Vendor/Dealer' => $conf['grn_vendor_name'], 'Anchor' => 'Tvs' })
      @payments_page.select_overdue_details($conf['grn_vendor_name'])
      result = @payments_page.verify_transaction_in_due_for_payments(
        @testdata['Transaction List']['Status'],
        @testdata['Invoice Details']['Invoice Number'],
        @testdata['Transaction List']['Transaction Value']
      )
      expect(result).to eq true
    end

    e.run_step 'Investor logs out' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Vendor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['grn_vendor']['email'], $conf['users']['grn_vendor']['password'])).to eq true
    end

    e.run_step 'Verify transaction in the Due for payments as Vendor' do
      @outstanding_values_hash[:transaction_values] = @transaction_values
      @outstanding_values_hash[:due_date] = (Date.parse(@overdue_date) + $conf['vendor_tenor']).strftime('%d-%b-%Y')
      calculated_values = @payments_page.calculate_outstanding_value(@outstanding_values_hash)
      @outstanding_value = calculated_values[0]
      @interest = calculated_values[1]
      @penal_charges = calculated_values[2]
      @repayment_list_details = {
        'Status' => @testdata['Transaction List']['Status'],
        'Anchor Name' => @anchor_name,
        'Due date' => (Date.today - 10).strftime('%d %b, %Y'),
        'Principal' => @testdata['Transaction List']['Transaction Value'],
        'Interest' => "₹#{comma_seperated_value(@interest)}",
        'Charges' => "₹#{comma_seperated_value(@penal_charges)}",
        'Total Outstanding' => "₹#{comma_seperated_value(@outstanding_value)}",
        'Demanded Interest' => 'NA'
      }
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @common_pages.click_transactions_tab(DUE_FOR_REPAYMENT)
      @payments_page.select_overdue_details($conf['investor_name'])
      result = @payments_page.verify_transaction_in_due_for_payments(@repayment_list_details.values)
      expect(result).to eq true
    end

    e.run_step 'Vendor logs out' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Investor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['investor']['email'], $conf['users']['investor']['password'])).to eq true
    end

    e.run_step 'Record partial payment for the Overdue transaction' do
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @payment = (@outstanding_value - @penal_charges).round(2) - 100
      @tarspect_methods.click_button('Add Settlement details')
      @utr = @payments_page.repay_amount(@payment, @upload_doc, @vendor_pan, 'Vendor Finance', @anchor_pan)
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
      post_partial_payment_details = {
        'Status' => @testdata['Transaction List']['Status'],
        'Anchor Name' => @anchor_name,
        'Due date' => (Date.today - 10).strftime('%d %b, %Y'),
        'Principal' => '₹100',
        'Interest' => '₹0',
        'Charges' => "₹#{comma_seperated_value(@penal_charges)}",
        'Total Outstanding' => "₹#{comma_seperated_value(@penal_charges + 100)}",
        'Demanded Interest' => 'NA'
      }
      navigate_to($conf['base_url'])
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @common_pages.click_transactions_tab('Due For Payment')
      @common_pages.apply_list_filter({ 'Vendor/Dealer' => $conf['grn_vendor_name'], 'Anchor' => 'Tvs' })
      @payments_page.select_overdue_details($conf['grn_vendor_name'])
      result = @payments_page.verify_transaction_in_due_for_payments(post_partial_payment_details.values)
      expect(result).to eq true
    end

    e.run_step 'Verify transaction is not moved to matured after partial payment' do
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @common_pages.click_transactions_tab(MATURED)
      expect(@common_pages.transaction_listed?(@transaction_id)).to eq(false), "Transaction #{@transaction_id} is listed, Ideally it should not be present"
      @common_pages.click_transactions_tab(SHOW_ALL)
      @common_pages.navigate_to_transaction(@transaction_id)
      expect(@transactions_page.verify_transaction_status('Settled')).to eq true
    end

    e.run_step 'Verify Due for Payment details with partial payment charges' do
      @paid_interest = rounded_half_down_value(@transaction_values[2] + @interest)
      expected_values = {
        'Due Date' => (Date.today - 10).strftime('%d %b, %Y'),
        'Principal Paid / Outstanding' => "₹ #{comma_seperated_value(@transaction_values[0] - 100)}  /  ₹ 100",
        'Interest Paid / Outstanding' => "₹ #{comma_seperated_value(@paid_interest)}  /  ₹ 0",
        'Charges Outstanding' => "₹ #{comma_seperated_value(@penal_charges)}",
        'Total Outstanding' => "₹ #{comma_seperated_value(@penal_charges + 100)}"
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
        'Accured Interest Paid' => '₹0',
        'Interest Paid' => @repayment_list_details['Interest'],
        'Charges Paid' => '₹0',
        'Total Amount Paid' => "₹#{comma_seperated_value(@payment)}",
        'Payment Receipt' => 'View  '
      }
      actual_values = @payments_page.get_recorded_payment_details
      expect(actual_values).to eq expected_values
    end
  end

  it 'Payment : IPC : Check Multiple partial payment scenario (IPC)', :sanity, :monthly_payment_strategy do |e|
    e.run_step 'Create 3 complete transaction as Anchor(Draft -> Released)' do
      @anchor_gstn = $conf['tvs_gstn']
      @counterparty_gstn = $conf['dozco_gstn']
      @vendor_name = $conf['grn_vendor_name']
      @overdue_date1 = (Date.today - $conf['vendor_tenor'] - 10).strftime('%d-%b-%Y')

      @testdata1 = JSON.parse(ERB.new(@erb_file).result(binding))
      @invoice_value1 = comma_seperated_value(@testdata1['Invoice Details']['Invoice Value'])
      @testdata1['Transaction List']['Invoice Value'] = "₹#{@invoice_value1}"
      @transaction_id1 = seed_transaction({
                                            actor: 'grn_anchor',
                                            counter_party: 'grn_vendor',
                                            invoice_details: @testdata1['Invoice Details'],
                                            invoice_file: @invoice_file,
                                            program: 'Invoice Financing - Vendor',
                                            investor_id: 7,
                                            program_group: 'invoice'
                                          })
      expect(@transaction_id1).not_to include('Error while creating transaction')

      @testdata2 = JSON.parse(ERB.new(@erb_file).result(binding))
      @invoice_value2 = comma_seperated_value(@testdata2['Invoice Details']['Invoice Value'])
      @testdata2['Transaction List']['Invoice Value'] = "₹#{@invoice_value2}"
      @transaction_id2 = seed_transaction({
                                            actor: 'grn_anchor',
                                            counter_party: 'grn_vendor',
                                            invoice_details: @testdata2['Invoice Details'],
                                            invoice_file: @invoice_file,
                                            program: 'Invoice Financing - Vendor',
                                            investor_id: 7,
                                            program_group: 'invoice'
                                          })
      expect(@transaction_id2).not_to include('Error while creating transaction')

      @overdue_date2 = (Date.today - $conf['vendor_tenor'] - 8).strftime('%d-%b-%Y')
      @testdata3 = JSON.parse(ERB.new(@erb_file).result(binding))
      @invoice_value3 = comma_seperated_value(@testdata3['Invoice Details']['Invoice Value'])
      @testdata3['Transaction List']['Invoice Value'] = "₹#{@invoice_value3}"
      @transaction_id3 = seed_transaction({
                                            actor: 'grn_anchor',
                                            counter_party: 'grn_vendor',
                                            invoice_details: @testdata3['Invoice Details'],
                                            invoice_file: @invoice_file,
                                            program: 'Invoice Financing - Vendor',
                                            investor_id: 7,
                                            program_group: 'invoice'
                                          })
      expect(@transaction_id3).not_to include('Error while creating transaction')

      details1 = disburse_transaction({
                                        transaction_id: @transaction_id1,
                                        invoice_value: @testdata1['Invoice Details']['Invoice Value'],
                                        type: 'frontend',
                                        date_of_payment: @overdue_date1,
                                        payment_proof: @payment_proof,
                                        program: 'Invoice Financing - Vendor'
                                      })
      expect(details1).not_to include 'Error while disbursements'
      details2 = disburse_transaction({
                                        transaction_id: @transaction_id2,
                                        invoice_value: @testdata2['Invoice Details']['Invoice Value'],
                                        type: 'frontend',
                                        date_of_payment: @overdue_date1,
                                        payment_proof: @payment_proof,
                                        program: 'Invoice Financing - Vendor'
                                      })
      expect(details2).not_to include 'Error while disbursements'
      details3 = disburse_transaction({
                                        transaction_id: @transaction_id3,
                                        invoice_value: @testdata3['Invoice Details']['Invoice Value'],
                                        type: 'frontend',
                                        date_of_payment: @overdue_date2,
                                        payment_proof: @payment_proof,
                                        program: 'Invoice Financing - Vendor'
                                      })
      expect(details3).not_to include 'Error while disbursements'
      @transaction_values1 = details1[0]
      @transaction_values2 = details2[0]
      @transaction_values3 = details3[0]
    end

    e.run_step 'Login as Vendor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['grn_vendor']['email'], $conf['users']['grn_vendor']['password'])).to eq true
    end

    e.run_step 'Verify transaction in the Due for payments as vendor' do
      @outstanding_values_hash[:transaction_values] = @transaction_values1
      @outstanding_values_hash[:due_date] = (Date.parse(@overdue_date1) + $conf['vendor_tenor']).strftime('%d-%b-%Y')
      calculated_values1 = @payments_page.calculate_outstanding_value(@outstanding_values_hash)
      @outstanding_values_hash[:transaction_values] = @transaction_values2
      @outstanding_values_hash[:due_date] = (Date.parse(@overdue_date1) + $conf['vendor_tenor']).strftime('%d-%b-%Y')
      calculated_values2 = @payments_page.calculate_outstanding_value(@outstanding_values_hash)
      @outstanding_values_hash[:transaction_values] = @transaction_values3
      @outstanding_values_hash[:due_date] = (Date.parse(@overdue_date2) + $conf['vendor_tenor']).strftime('%d-%b-%Y')
      calculated_values3 = @payments_page.calculate_outstanding_value(@outstanding_values_hash)
      @outstanding_value1, @interest1, @penal_charges1 = calculated_values1
      @outstanding_value2, @interest2, @penal_charges2 = calculated_values2
      @outstanding_value3, @interest3, @penal_charges3 = calculated_values3
      @total_outstanding_value = rounded_half_down_value(@outstanding_value1 + @outstanding_value2 + @outstanding_value3)
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @common_pages.click_transactions_tab(DUE_FOR_REPAYMENT)
      params = { 'program_group' => 'invoice', 'page' => 1 }
      resp = @common_api.perform_get_action('vendor_pending_dues_entity', params, 'grn_vendor')
      matching_record = resp[:body][:investor_anchors].select { |r| r[:anchor][:name] == @anchor_name }
      expect(matching_record.empty?).to eq(false)
      expect(matching_record[0][:total_amount_due]).to eq(@total_outstanding_value)
    end

    e.run_step 'Vendor logs out' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Investor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['investor']['email'], $conf['users']['investor']['password'])).to eq true
    end

    e.run_step 'Record partial payment for current overdue interest, principal and check the Due for payment values' do
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @payment = rounded_half_down_value(@interest1 + @interest2 + (@transaction_values1[0] - 100))
      @tarspect_methods.click_button('Add Settlement details')
      @utr = @payments_page.repay_amount(@payment, @upload_doc, @vendor_pan, 'Vendor Finance', @anchor_pan)
      @actual_summary, @report_link = @disbursement_page.upload_bulk_disbursement(@upload_doc, 'Repayment')
      expect(@report_link.empty?).to eq(false), 'Report link is empty'
      navigate_to($conf['base_url'])
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

    e.run_step 'Investor logs out' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Vendor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['grn_vendor']['email'], $conf['users']['grn_vendor']['password'])).to eq true
    end

    e.run_step 'Verify Payment history of the recorded payment as Vendor(Overdue payments and multiple payments)' do
      expected_values = {
        'Payment Status' => 'Success',
        'Paid By' => @vendor_name,
        'Date of Payment' => @today_date,
        'UTR Number' => @utr,
        'Payment Type' => 'Repayment',
        'Amount' => "₹ #{comma_seperated_value(@payment)}"
      }
      payment_breakup_1 = {
        'Instrument Number' => @testdata1['Invoice Details']['Invoice Number'],
        'Due of Payment' => (Date.today - 10).strftime('%d %b, %Y'),
        'Date of Payment' => @today_date,
        'DPD' => '10',
        'Payment Type' => 'Late-Payment',
        'Principal Paid' => "₹ #{comma_seperated_value(@transaction_values1[0] - 100)}",
        'Interest Paid' => "₹ #{comma_seperated_value(@interest1)}",
        'Total Amount Paid' => "₹ #{comma_seperated_value(@transaction_values1[0] + @interest1 - 100)}",
        'Payment Charges' => '₹ 0'
      }
      payment_breakup_2 = {
        'Instrument Number' => @testdata2['Invoice Details']['Invoice Number'],
        'Due of Payment' => (Date.today - 10).strftime('%d %b, %Y'),
        'Date of Payment' => @today_date,
        'DPD' => '10',
        'Payment Type' => 'Late-Payment',
        'Principal Paid' => '₹ 0',
        'Interest Paid' => "₹ #{comma_seperated_value(@interest2)}",
        'Total Amount Paid' => "₹ #{comma_seperated_value(@interest2)}",
        'Payment Charges' => '₹ 0'
      }
      @common_pages.click_menu(MENU_PAYMENT_HISTORY)
      result = @payments_page.verify_transaction_in_payment_history(expected_values.values)
      expect(result).to eq true
      @payments_page.view_detailed_breakup(@utr)
      result = @payments_page.verify_transaction_in_payment_history(payment_breakup_1.values)
      expect(result).to eq true
      result = @payments_page.verify_transaction_in_payment_history(payment_breakup_2.values)
      expect(result).to eq true
    end

    e.run_step 'Verify Transction is present in Due for Re-payment after partial payment success' do
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @common_pages.click_transactions_tab(DUE_FOR_REPAYMENT)
      @payments_page.select_overdue_details($conf['investor_name'])
      @outstanding_value1 = rounded_half_down_value(@outstanding_value1 - @interest1 - (@transaction_values1[0] - 100))
      post_partial_payment_details1 = {
        'Status' => 'Overdue',
        'Anchor Name' => @anchor_name,
        'Due date' => (Date.today - 10).strftime('%d %b, %Y'),
        'Principal' => '₹100',
        'Interest' => '₹0',
        'Charges' => "₹#{comma_seperated_value(@penal_charges1)}",
        'Total Outstanding' => "₹#{comma_seperated_value(@outstanding_value1)}",
        'Demanded Interest' => 'NA'
      }
      result = @payments_page.verify_transaction_in_due_for_payments(post_partial_payment_details1.values)
      expect(result).to eq true

      @outstanding_value2 = rounded_half_down_value(@outstanding_value2 - @interest2)
      post_partial_payment_details2 = {
        'Status' => 'Overdue',
        'Anchor Name' => @testdata2['Transaction List']['Anchor Name'],
        'Due date' => (Date.today - 10).strftime('%d %b, %Y'),
        'Principal' => "₹#{comma_seperated_value(@transaction_values2[0])}",
        'Interest' => '₹0',
        'Charges' => "₹#{comma_seperated_value(@penal_charges2)}",
        'Total Outstanding' => "₹#{comma_seperated_value(@outstanding_value2)}",
        'Demanded Interest' => 'NA'
      }
      result = @payments_page.verify_transaction_in_due_for_payments(post_partial_payment_details2.values)
      expect(result).to eq true

      post_partial_payment_details3 = {
        'Status' => 'Overdue',
        'Anchor Name' => @testdata3['Transaction List']['Anchor Name'],
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

    e.run_step 'Vendor logs out' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Investor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['investor']['email'], $conf['users']['investor']['password'])).to eq true
    end

    e.run_step 'Record partial payment for oldest 2 same date transactions and check the Due for payment values' do
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @payment = rounded_half_down_value(@outstanding_value1 + @outstanding_value2)
      @tarspect_methods.click_button('Add Settlement details')
      @utr = @payments_page.repay_amount(@payment, @upload_doc, @vendor_pan, 'Vendor Finance', @anchor_pan)
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
      sleep 5
      post_partial_payment_details3 = {
        'Status' => 'Overdue',
        'Anchor Name' => @testdata3['Transaction List']['Anchor Name'],
        'Due date' => (Date.today - 8).strftime('%d %b, %Y'),
        'Principal' => "₹#{comma_seperated_value(@transaction_values3[0])}",
        'Interest' => "₹#{comma_seperated_value(@interest3)}",
        'Charges' => "₹#{comma_seperated_value(@penal_charges3)}",
        'Total Outstanding' => "₹#{comma_seperated_value(@outstanding_value3)}",
        'Demanded Interest' => 'NA'
      }
      navigate_to($conf['base_url'])
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @common_pages.click_transactions_tab(DUE_FOR_PAYMENT)
      @common_pages.apply_list_filter({ 'Vendor/Dealer' => $conf['users']['grn_vendor']['name'] })
      @payments_page.select_overdue_details($conf['users']['grn_vendor']['name'])
      result = @payments_page.verify_transaction_in_due_for_payments(post_partial_payment_details3.values)
      expect(result).to eq true
    end
  end
end
