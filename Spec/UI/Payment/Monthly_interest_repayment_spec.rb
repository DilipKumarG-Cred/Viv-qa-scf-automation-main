require './spec_helper'
describe 'Payment: Monthly Interest Repayment', :scf, :payments, :monthly_interest_repayment do
  before(:all) do
    @anchor_actor = 'mi_anchor'
    @vendor_actor = 'monthly_interest_cp'
    @program_name = 'Invoice Financing - Vendor'
    @counterparty_gstn = $conf['users'][@vendor_actor]['gstn']
    @party_gstn = $conf['users'][@anchor_actor]['gstn']
    @vendor_name = $conf['users'][@vendor_actor]['name']
    @anchor_name = $conf['users'][@anchor_actor]['name']
    @vendor_pan = $conf['users']['monthly_interest_cp']['pan']
    @anchor_pan = $conf['users']['mi_anchor']['pan']
    @investor_id = $conf['users']['user_feedback_investor']['id']
    @invoice_file = "#{Dir.pwd}/test-data/attachments/dealer_invoice.pdf"
    @payment_proof = "#{Dir.pwd}/test-data/attachments/payment_proof.pdf"
    @erb_file = File.read("#{Dir.pwd}/test-data/erb/testbed_data.erb")
    @upload_doc = "#{Dir.pwd}/test-data/attachments/repayment_upload.xlsx"
  end

  before(:each) do
    clear_all_overdues({ anchor: @anchor_name, vendor: $conf['monthly_interest_cp'], investor: 'user_feedback_investor' })
    @driver = Tarspect::Browser.new($conf['browser']).invoke
    @tarspect_methods = Common::Methods.new(@driver)
    @common_pages = Pages::CommonMethods.new(@driver)
    @transactions_page = Pages::Trasactions.new(@driver)
    @disbursement_page = Pages::Disbursement.new(@driver)
    @payments_page = Pages::Payment.new(@driver)
    @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
    @tenor = $conf['vendor_tenor']
  end

  after(:each) do |e|
    snap_screenshot(e)
    quit_browser
  end

  after(:all) do
    clear_all_overdues({ anchor: $conf['mi_anchor_name'], vendor: $conf['mi_cp_name'], investor: 'user_feedback_investor' })
  end

  it 'Payment : Monthly Interest Repayment: Bullet payment', :sanity, :bullet_payment do |e|
    e.run_step 'Create a complete transaction as Anchor(Draft -> Released)' do
      @testdata['Invoice Details']['Invoice Date'] = (Date.today - @tenor).strftime('%d-%b-%Y')
      @testdata['Invoice Details']['GSTN of Anchor'] = $conf['users']['mi_anchor']['gstn']
      @transaction_id = seed_transaction({
                                           actor: @anchor_actor,
                                           counter_party: @vendor_actor,
                                           invoice_details: @testdata['Invoice Details'],
                                           invoice_file: @invoice_file,
                                           program: @program_name,
                                           program_group: 'invoice'
                                         })
      expect(@transaction_id).not_to include('Error while creating transaction')
    end

    e.run_step 'Disburse the amount for this transaction' do
      details = disburse_transaction({
                                       transaction_id: @transaction_id,
                                       invoice_value: @testdata['Invoice Details']['Invoice Value'],
                                       tenor: @tenor,
                                       type: 'monthly',
                                       date_of_payment: @testdata['Invoice Details']['Invoice Date'],
                                       payment_proof: @payment_proof,
                                       program: @program_name,
                                       investor_actor: 'user_feedback_investor'
                                     })
      expect(details).not_to include('Error while disbursements')
      @transaction_values = details[0]
      @disbursement_values = details[1]
      @testdata['Transaction List']['Instrument Value'] = "₹#{comma_seperated_value(@transaction_values[0])}"
      @testdata['Transaction List']['Status'] = 'Upcoming'
    end

    e.run_step 'Verify Monthly Interest is generated properly' do
      values = {
        transaction_values: @transaction_values,
        tenor: @tenor,
        due_date: Date.today.strftime('%d-%b-%Y'),
        type: 'monthly',
        payment_date: Date.today
      }
      @outstanding_values = @payments_page.calculate_outstanding_value(values)
      resp = get_transaction_details(@transaction_id)
      expect(resp[:body][:is_monthly_strategy]).to eq(true), 'Monthly Interest Strategy is not set'
      @demanded_interest = calculate_demanded_interest(@transaction_values[0], @testdata['Invoice Details']['Invoice Date'], Date.today.strftime('%d-%b-%Y'))
      expect(resp[:body][:interest_accrued]).to eq(@demanded_interest)
      expect(@outstanding_values[1] - resp[:body][:interest_outstanding].round(2)).to eq(0)
      expect(resp[:body][:total_outstanding]).to eq(@outstanding_values[0])
    end

    e.run_step 'Login as Investor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['user_feedback_investor']['email'], $conf['users']['user_feedback_investor']['password'])).to be true
    end

    e.run_step 'Single View Borrower - Verification of Interest value' do
      sleep 20 # Wait for data to reflect in Borrowers Summary
      @common_pages.click_menu(MENU_BORROWER_LIST)
      hash = {
        'Anchors' => @anchor_name,
        'Channel Partners' => @vendor_name,
        'Program' => 'Vendor Financing'
      }
      @common_pages.apply_list_filter(hash)
      Tarspect::Locator.new(:xpath, "//button[text()='Show More']").click
      @interest_after = Tarspect::Locator.new(:xpath, "//p[contains(text(),' Interest Due as of ')]/preceding-sibling::p").text
      interest_value_in_row = Tarspect::Locator.new(:xpath, "//div[contains(@class,'borrowers-table')]//li[text()='#{@vendor_name}']/../li[14]").text
      expect(@interest_after).to eq interest_value_in_row
      expect(remove_comma_in_numbers(@interest_after).to_f).to eq rounded_half_down_value(@demanded_interest.to_f)
    end

    e.run_step 'Logout as Investor' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Anchor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['mi_anchor']['email'], $conf['users']['mi_anchor']['password'])).to be true
    end

    e.run_step 'Verify the calculation of Outstanding value and demanded interest in the Due for payments page' do
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @common_pages.click_transactions_tab(DUE_FOR_REPAYMENT)
      @payments_page.select_overdue_details(@vendor_name.capitalize)
      @testdata['Transaction List']['Status'] = 'Upcoming'
      post_interest_generation_payment_details = {
        'Status' => @testdata['Transaction List']['Status'],
        'Vendor Name' => @testdata['Transaction List']['Vendor Name'].capitalize,
        'Due date' => Date.today.strftime('%d %b, %Y'),
        'Principal' => "₹#{comma_seperated_value(@transaction_values[0])}",
        'Interest' => "₹#{comma_seperated_value(@outstanding_values[1])}",
        'Charges' => '₹0',
        'Total Outstanding' => "₹#{comma_seperated_value(@outstanding_values[0])}",
        'Demanded Interest' => "₹#{comma_seperated_value(@demanded_interest)}"
      }
      result = @payments_page.verify_transaction_in_due_for_payments(post_interest_generation_payment_details.values)
      expect(result).to eq true
    end

    e.run_step 'Logout as Anchor' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Investor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['user_feedback_investor']['email'], $conf['users']['user_feedback_investor']['password'])).to be true
    end

    e.run_step 'Record current outstanding amount as pre-payment as anchor' do
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @payment = (@outstanding_values[0]).round(2)
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
  end

  first_of_month = Date.parse("1/#{Date.today.month}/#{Date.today.year}")
  unless first_of_month == Date.today
    it 'Payment : Demanaded Interest: Verification on Prepayment', :di_prepayment do |e|
      e.run_step 'Create a complete transaction as Anchor(Draft -> Released)' do
        @first_of_month = Date.parse("1/#{Date.today.month}/#{Date.today.year}")
        @testdata['PO Details']['PO Date'] = @first_of_month.strftime('%d-%b-%Y')
        @testdata['PO Details']['GSTN of Anchor'] = $conf['users']['anchor']['gstn']
        @transaction_id = seed_transaction({
                                             actor: 'anchor',
                                             counter_party: 'zudio_vendor',
                                             po_details: @testdata['PO Details'],
                                             po_file: @invoice_file,
                                             program: 'PO Financing - Vendor',
                                             program_group: 'purchase_order'
                                           })
        expect(@transaction_id).not_to include('Error while creating transaction')
      end

      e.run_step 'Disburse the amount for this transaction' do
        details = disburse_transaction({
                                         transaction_id: @transaction_id,
                                         invoice_value: @testdata['PO Details']['Requested Disbursement Value'],
                                         tenor: 60,
                                         type: 'frontend',
                                         date_of_payment: @testdata['PO Details']['PO Date'],
                                         payment_proof: @payment_proof,
                                         program: 'PO Financing - Vendor',
                                         strategy: 'simple_interest'
                                       })
        expect(details).not_to eq 'Error while disbursements'
        @transaction_values = details[0]
        @disbursement_values = details[1]
        @testdata['Transaction List']['Transaction Value'] = "₹#{comma_seperated_value(@transaction_values[0])}"
        @testdata['Transaction List']['Status'] = 'Upcoming'
      end

      e.run_step 'Verify Monthly Interest Generation is generated properly' do
        values = {
          transaction_values: @transaction_values,
          tenor: $conf['vendor_tenor'],
          due_date: (@first_of_month + 60).strftime('%d-%b-%Y'),
          type: 'monthly',
          payment_date: Date.today
        }
        @outstanding_values = @payments_page.calculate_outstanding_value(values)
        resp = get_po_details(@transaction_id)
        expect(resp[:body][:is_monthly_strategy]).to eq(true), 'Monthly Interest Strategy is not set'
        expect(resp[:body][:interest_outstanding]).to eq(@outstanding_values[1])
        expect(resp[:body][:total_outstanding]).to eq(@outstanding_values[0])
      end

      e.run_step 'Login as Anchor' do
        navigate_to($conf['base_url'])
        expect(@tarspect_methods.login($conf['users']['anchor']['email'], $conf['users']['anchor']['password'])).to be true
      end

      e.run_step 'Partial Repayment - before Demanded Interest generation' do
        @common_pages.click_menu(MENU_PO_FINANCING)
        @common_pages.click_transactions_tab(DUE_FOR_REPAYMENT)
        @payments_page.select_overdue_details(@vendor_name)
        disbursal_date = Date.parse(@testdata['PO Details']['PO Date'])
        values = {
          payment_date: Date.today,
          disbursement_date: disbursal_date,
          transaction_value: @transaction_values[0],
          tenor: 60
        }
        @prepayment_charges = @payments_page.calculate_prepayment_value(values)
        @pre_pay_demanded_interest = @payments_page.calculate_demanded_interest(@transaction_values[0], @testdata['PO Details']['PO Date'], Date.today.strftime('%d-%b-%Y'))
        expect(@pre_pay_demanded_interest).to eq 0
      end

      e.run_step 'Logout as Anchor' do
        expect(@common_pages.logout).to eq true
      end

      e.run_step 'Login as Investor' do
        navigate_to($conf['base_url'])
        expect(@tarspect_methods.login($conf['users']['investor']['email'], $conf['users']['investor']['password'])).to be true
      end

      e.run_step 'Record payment' do
        @common_pages.click_menu(MENU_PO_FINANCING)
        @common_pages.click_transactions_tab(DUE_FOR_PAYMENT)
        @payments_page.select_overdue_details(@vendor_name)
        @payment_details = {
          'UTR Number' => "UTR#{DateTime.now.to_time.to_i}#{rand(1..999)}",
          'Date of Payment' => Date.today.strftime('%d-%b-%Y'),
          'Payment Amount' => (@transaction_values[0] + @prepayment_charges).round(2),
          'Payment Account Number' => Faker::Number.number(digits: 10)
        }
        @payments_page.record_payment(
          @payment_details,
          @payment_proof
        )
        expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['PaymentsSuccess']
        @testdata['Transaction List']['Status'] = 'Upcoming'
      end

      e.run_step 'Verify Payment summary modal' do
        expect(@transactions_page.transaction_summary_present?).to eq true
        expect(@transactions_page.verify_summary('Total Value')).to eq "₹#{comma_seperated_value(@payment_details['Payment Amount'])}"
        expect(@transactions_page.verify_summary('Principal Paid')).to eq "₹#{comma_seperated_value(@transaction_values[0])}"
        expect(@transactions_page.verify_summary('Interest Paid')).to eq '₹0'
        expect(@transactions_page.verify_summary('Charges')).to eq "₹#{comma_seperated_value(@prepayment_charges)}"
        @tarspect_methods.click_button('close')
      end

      e.run_step 'Verify Transction is present in Due for Re-payment after partial payment success' do
        post_partial_payment_details = {
          'Status' => @testdata['Transaction List']['Status'],
          'Vendor Name' => @testdata['Transaction List']['Vendor Name'],
          'Due date' => (@first_of_month + @tenor).strftime('%d %b, %Y'),
          'Principal' => '₹0',
          'Interest' => "₹#{comma_seperated_value(@outstanding_values[1])}",
          'Charges' => '₹0',
          'Total Outstanding' => "₹#{comma_seperated_value(@outstanding_values[1])}",
          'Demanded Interest' => 'NA'
        }
        result = @payments_page.verify_transaction_in_due_for_payments(post_partial_payment_details.values)
        expect(result).to eq true
      end
    end
  end

  it 'Payment : Monthly Interest Repayment: Principal Knock Off before Due Date' do |e|
    @anchor_actor = 'mi_anchor'
    @vendor_actor = 'monthly_interest_vendor'
    @vendor_id = $conf['users'][@vendor_actor]['id']
    @anchor_id = $conf['users'][@anchor_actor]['id']
    @anchor_name = $conf['users'][@anchor_actor]['name']
    @vendor_name = $conf['users'][@vendor_actor]['name']

    @this_day_previous_month = Date.parse("#{Date.today.day}/#{Date.today.prev_month}/#{Date.today.year}")
    e.run_step 'Clear refunds' do
      values = { anchor: @anchor_name, vendor: @vendor_name, payment_date: @this_day_previous_month }
      clear_all_overdues(values)
    end

    e.run_step 'Create a complete transaction as Anchor(Draft -> Released)' do
      @counterparty_gstn = $conf['users'][@vendor_actor]['gstn']
      @anchor_gstn = $conf['users'][@anchor_actor]['gstn']
      @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
      @testdata['Invoice Details']['Invoice Date'] = (Date.today - @tenor).strftime('%d-%b-%Y')
      values = {
        actor: @vendor_actor, counter_party: @anchor_actor,
        invoice_details: @testdata['Invoice Details'], invoice_file: @invoice_file, program: 'Invoice Financing - Vendor', investor_id: @investor_id, program_group: 'invoice'
      }
      @transaction_id = seed_transaction(values)
      expect(@transaction_id).not_to include('Error while creating transaction')
    end

    e.run_step 'Disburse the amount for this transaction' do
      values = {
        transaction_id: @transaction_id, invoice_value: @testdata['Invoice Details']['Invoice Value'], tenor: @tenor, type: 'rearend',
        date_of_payment: @testdata['Invoice Details']['Invoice Date'], payment_proof: @payment_proof, program: 'Invoice Financing - Vendor'
      }
      details = @disbursement_page.disburse_transaction(values)
      expect(details).not_to include('Error while disbursements')
      @transaction_values = details[0]
      @disbursement_values = details[1]
    end

    e.run_step 'Verify Monthly Interest is generated properly' do
      values = { transaction_values: @transaction_values, tenor: @tenor, due_date: Date.today.strftime('%d-%b-%Y'), type: 'monthly', payment_date: Date.today }
      @outstanding_values = @payments_page.calculate_outstanding_value(values)
      @invoice_response = get_transaction_details(@transaction_id)
      expect(@invoice_response[:body][:is_monthly_strategy]).to eq(true), 'Monthly Interest Strategy is not set'
      @demanded_interest = @payments_page.calculate_demanded_interest(@transaction_values[0], @testdata['Invoice Details']['Invoice Date'], Date.today.strftime('%d-%b-%Y'))
      expect(@invoice_response[:body][:interest_accrued]).to eq(@demanded_interest)
      expect(@outstanding_values[1] - @invoice_response[:body][:interest_outstanding].round(2)).to eq(0)
      expect(@invoice_response[:body][:total_outstanding]).to eq(@outstanding_values[0])
    end

    e.run_step 'Knock off Principal before Due date' do
      values = { payment_date: @this_day_previous_month, disbursement_date: Date.parse(@testdata['Invoice Details']['Invoice Date']), transaction_value: @transaction_values[0], tenor: 60 }
      @prepayment_charges = @payments_page.calculate_prepayment_value(values)
      interest_this_day_previous_month = @payments_page.calculate_demanded_interest(@transaction_values[0], @testdata['Invoice Details']['Invoice Date'], @this_day_previous_month.strftime('%d-%b-%Y'))
      amount_to_knock_off_principal = interest_this_day_previous_month + @invoice_response[:body][:principal_outstanding] + @prepayment_charges
      @amount_without_charges = (amount_to_knock_off_principal - @prepayment_charges).round(2)
      repay_hash = { overdue_amount: amount_to_knock_off_principal, investor_id: @investor_id, program_id: $conf['programs']['Invoice Financing - Vendor'],
                     vendor_id: @vendor_id, anchor_id: @anchor_id, payment_date: @this_day_previous_month.strftime('%Y-%m-%d') }
      resp = repay(repay_hash, 'investor')
      expect(resp[:code]).to eq(200), resp.to_s
    end

    e.run_step 'Verify Principal amount is knocked off' do
      @invoice_response = get_transaction_details(@transaction_id)
      expect(@invoice_response[:body][:principal_outstanding]).to eq(0.0)
    end

    e.run_step 'Verify Demanded Interest is calculated as Interest on Interest' do
      # For First Month
      initiation_date = Date.today - @tenor
      total_days_in_first_month = Date.new(initiation_date.strftime('%Y').to_i, initiation_date.strftime('%m').to_i, -1).day
      days_in_first_month = total_days_in_first_month - initiation_date.day

      @outstanding_hash_values = { transaction_values: @transaction_values, due_date: @this_day_previous_month.strftime('%d-%b-%Y'),
                                   type: 'monthly', payment_date: @this_day_previous_month, tenor: days_in_first_month }
      @outstanding_values = @payments_page.calculate_outstanding_value(@outstanding_hash_values)
      outstanding_for_first_month = @outstanding_values[0]

      # For Second Month
      total_days_in_previous_month_before_knocking_off_principal = 1
      if @this_day_previous_month > Date.parse("2/#{@this_day_previous_month.month}/#{@this_day_previous_month.year}")
        total_days_in_previous_month_before_knocking_off_principal = (@this_day_previous_month - Date.parse("2/#{@this_day_previous_month.month}/#{@this_day_previous_month.year}")).numerator + 1
      end

      @outstanding_hash_values.merge!(transaction_values: [outstanding_for_first_month], tenor: total_days_in_previous_month_before_knocking_off_principal)
      @outstanding_values = @payments_page.calculate_outstanding_value(@outstanding_hash_values)
      @interest_no1 = @outstanding_values[1]

      total_days_in_second_month = Date.new(@this_day_previous_month.strftime('%Y').to_i, @this_day_previous_month.strftime('%m').to_i, -1).day
      total_days_in_previous_month_after_knocking_off_principal = total_days_in_second_month - total_days_in_previous_month_before_knocking_off_principal

      @outstanding_hash_values.merge!(transaction_values: [@interest_no1], tenor: total_days_in_previous_month_after_knocking_off_principal)
      @outstanding_values = @payments_page.calculate_outstanding_value(@outstanding_hash_values)
      interest_accrued = @outstanding_values[0]
      expect(@invoice_response[:body][:interest_accrued] - interest_accrued).to be_between(-0.3, 0.3).inclusive
    end

    e.run_step 'Verify Total Outstanding is calculated properly' do
      remaining_days_after_principal_knocked_out = (Date.today - @this_day_previous_month).numerator
      values = { transaction_values: [@interest_no1], tenor: remaining_days_after_principal_knocked_out,
                 due_date: Date.today.strftime('%d-%b-%Y'), type: 'monthly', payment_date: Date.today }
      @outstanding_values = @payments_page.calculate_outstanding_value(values)
      expect(@invoice_response[:body][:total_outstanding] - @outstanding_values[0]).to be_between(-0.3, 0.3)
      expect(@invoice_response[:body][:interest_outstanding] - @outstanding_values[0]).to be_between(-0.3, 0.3)
    end

    e.run_step 'Verify whether Transaction not moved to Matured State' do
      @invoice_response = get_transaction_details(@transaction_id)
      expect(@invoice_response[:body][:display_status]).to eq('Settled')
    end

    e.run_step 'Pay pending dues' do
      values = { anchor: @anchor_name, vendor: @vendor_name, payment_date: @this_day_previous_month }
      clear_all_overdues(values)
    end

    e.run_step 'Verify whether Transaction moved to Matured State' do
      @invoice_response = get_transaction_details(@transaction_id)
      expect(@invoice_response[:body][:display_status]).to eq('Matured')
    end
  end

  it 'Payment : Verification of Monthly Interest Overdue Status' do |e|
    @anchor_actor = 'mi_anchor'
    @vendor_actor = 'monthly_interest_stg_vendor'
    @vendor_id = $conf['users'][@vendor_actor]['id']
    @anchor_id = $conf['users'][@anchor_actor]['id']
    @anchor_name = $conf['users'][@anchor_actor]['name']
    @vendor_name = $conf['users'][@vendor_actor]['name']
    e.run_step 'Clear refunds' do
      values = { anchor: @anchor_name, vendor: @vendor_name, payment_date: Date.today.strftime('%d-%b-%Y') }
      clear_all_overdues(values)
    end

    e.run_step 'Create a complete transaction as Anchor(Draft -> Released)' do
      @counterparty_gstn = $conf['users'][@vendor_actor]['gstn']
      @anchor_gstn = $conf['users'][@anchor_actor]['gstn']
      @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
      @testdata['Invoice Details']['Invoice Date'] = (Date.today - @tenor).strftime('%d-%b-%Y')
      values = {
        actor: @vendor_actor, counter_party: @anchor_actor,
        invoice_details: @testdata['Invoice Details'], invoice_file: @invoice_file, program: 'Invoice Financing - Vendor', investor_id: @investor_id, program_group: 'invoice'
      }
      @transaction_id = seed_transaction(values)
      expect(@transaction_id).not_to include('Error while creating transaction')
    end

    e.run_step 'Disburse the amount for this transaction' do
      values = {
        transaction_id: @transaction_id, invoice_value: @testdata['Invoice Details']['Invoice Value'], tenor: @tenor, type: 'rearend',
        date_of_payment: @testdata['Invoice Details']['Invoice Date'], payment_proof: @payment_proof, program: 'Invoice Financing - Vendor'
      }
      details = @disbursement_page.disburse_transaction(values)
      expect(details).not_to include('Error while disbursements')
      @transaction_values = details[0]
      @disbursement_values = details[1]
      @demanded_interest = @payments_page.calculate_demanded_interest(@transaction_values[0], @testdata['Invoice Details']['Invoice Date'], Date.today.strftime('%d-%b-%Y')).round(2)
    end

    e.run_step 'Login as investor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['investor']['email'], $conf['users']['investor']['password'])).to eq true
    end

    e.run_step 'Verify the monthly interest is leived on first of every month' do
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @common_pages.click_transactions_tab(DUE_FOR_PAYMENT)
      @common_pages.apply_list_filter({ 'Vendor/Dealer' => @vendor_name.capitalize })
      @payments_page.select_overdue_details(@vendor_name)
      expect(@payments_page.check_transaction_status(Date.parse("1/#{Date.today.month}/#{Date.today.year}").strftime('%d %b, %Y'), 11)).to eq true
    end

    e.run_step 'Verify the demanded interest is taken first from the payment and the transaction should be in overdue status even after paying the demanded interest alone if the due date is in past date' do
      repay_hash = { overdue_amount: @demanded_interest, investor_id: @investor_id, program_id: $conf['programs']['Invoice Financing - Vendor'],
                     vendor_id: @vendor_id, anchor_id: @anchor_id, payment_date: Date.today.strftime('%d-%b-%Y') }
      resp = repay(repay_hash, 'investor')
      expect(resp[:code]).to eq(200), resp.to_s
      refresh_page
      expect(@payments_page.check_transaction_status('NA', 10)).to eq true
      expect(@payments_page.check_transaction_status('Overdue', 0)).to eq true
    end

    e.run_step 'Verify whether the transaction is moved to upcoming status if the demanded interest and the principal outstanding is knocked off and the repayment is done in the order Demanded interest, Principal outstanding' do
      repay_hash = { overdue_amount: @transaction_values[0], investor_id: @investor_id, program_id: $conf['programs']['Invoice Financing - Vendor'],
                     vendor_id: @vendor_id, anchor_id: @anchor_id, payment_date: Date.today.strftime('%d-%b-%Y') }
      resp = repay(repay_hash, 'investor')
      expect(resp[:code]).to eq(200), resp.to_s
      refresh_page
      expect(@payments_page.check_transaction_status('Upcoming', 0)).to eq true
    end

    e.run_step 'Verify the charges are knocked off in the order after the demanded interest and principal outstanding' do
      charges_outstanding = @common_pages.payment_list.fetch_elements[0].text.split("\n")[8].gsub('₹', '').to_f
      repay_hash = { overdue_amount: charges_outstanding,
                     investor_id: @investor_id, program_id:
                     $conf['programs']['Invoice Financing - Vendor'],
                     vendor_id: @vendor_id,
                     anchor_id: @anchor_id,
                     payment_date: Date.today.strftime('%d-%b-%Y') }
      resp = repay(repay_hash, 'investor')
      expect(resp[:code]).to eq(200), resp.to_s
      refresh_page
    end

    e.run_step 'Verify whether the transaction will not be there in Due for Payment page if the principal and interest overdue is paid' do
      interest_outstanding = (@transaction_values[2] - @demanded_interest).round(2)
      repay_hash = { overdue_amount: interest_outstanding + 1000, investor_id: @investor_id, program_id: $conf['programs']['Invoice Financing - Vendor'],
                     vendor_id: @vendor_id, anchor_id: @anchor_id, payment_date: Date.today.strftime('%d-%b-%Y') }
      resp = repay(repay_hash, 'investor')
      expect(resp[:code]).to eq(200), resp.to_s
      expect(@payments_page.check_transaction_status('Upcoming', 0, false)).to eq false
    end

    e.run_step 'Verify the transaction is moved to matured state when the demanded interest, principal outstanding, charges and interest outstanding of the transaction is paid' do
      @invoice_response = get_transaction_details(@transaction_id)
      expect(@invoice_response[:body][:display_status]).to eq('Matured')
    end
  end

  it 'Verification of Demanded interest overdue status' do |e|
    @anchor_actor = 'mi_anchor'
    @vendor_actor = 'demanded_interest_vendor'
    @vendor_id = $conf['users'][@vendor_actor]['id']
    @anchor_id = $conf['users'][@anchor_actor]['id']
    @anchor_name = $conf['users'][@anchor_actor]['name']
    @vendor_name = $conf['users'][@vendor_actor]['name']
    e.run_step 'Clear refunds' do
      values = { anchor: @anchor_name, vendor: @vendor_name, payment_date: Date.parse("1/#{Date.today.month}/#{Date.today.year}") }
      clear_all_overdues(values)
    end

    e.run_step 'Create a complete transaction as Anchor(Draft -> Released)' do
      @counterparty_gstn = $conf['users'][@vendor_actor]['gstn']
      @anchor_gstn = $conf['users'][@anchor_actor]['gstn']
      @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
      @testdata['Invoice Details']['Invoice Date'] = (Date.today - @tenor).strftime('%d-%b-%Y')
      values = {
        actor: @vendor_actor, counter_party: @anchor_actor,
        invoice_details: @testdata['Invoice Details'], invoice_file: @invoice_file, program: 'Invoice Financing - Vendor', investor_id: @investor_id, program_group: 'invoice'
      }
      @transaction_id = seed_transaction(values)
      expect(@transaction_id).not_to include('Error while creating transaction')
    end

    e.run_step 'Disburse the amount for this transaction' do
      values = {
        transaction_id: @transaction_id, invoice_value: @testdata['Invoice Details']['Invoice Value'], tenor: @tenor, type: 'rearend',
        date_of_payment: @testdata['Invoice Details']['Invoice Date'], payment_proof: @payment_proof, program: 'Invoice Financing - Vendor'
      }
      details = @disbursement_page.disburse_transaction(values)
      expect(details).not_to include('Error while disbursements')
      @transaction_values = details[0]
      @demanded_interest = @payments_page.calculate_demanded_interest(@transaction_values[0], @testdata['Invoice Details']['Invoice Date'], Date.today.strftime('%d-%b-%Y')).round(2)
    end

    e.run_step 'Login as investor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['investor']['email'], $conf['users']['investor']['password'])).to eq true
    end

    e.run_step 'Verify the transaction will be moved to upcoming status if the demanded interest is paid on that date and the due date is in future date' do
      repay_hash = { overdue_amount: @demanded_interest, investor_id: @investor_id, program_id: $conf['programs']['Invoice Financing - Vendor'],
                     vendor_id: @vendor_id, anchor_id: @anchor_id, payment_date: Date.parse("1/#{Date.today.month}/#{Date.today.year}").strftime('%d-%b-%Y') }
      resp = repay(repay_hash, 'investor')
      expect(resp[:code]).to eq(200), resp.to_s
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @common_pages.click_transactions_tab(DUE_FOR_PAYMENT)
      @common_pages.apply_list_filter({ 'Vendor/Dealer' => @vendor_name.capitalize })
      @payments_page.select_overdue_details(@vendor_name)
      expect(@payments_page.check_transaction_status('NA', 10)).to eq true
      expect(@payments_page.check_transaction_status('Upcoming', 0)).to eq true
    end
  end
end
