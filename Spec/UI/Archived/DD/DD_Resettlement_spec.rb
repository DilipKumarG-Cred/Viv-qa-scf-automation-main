require './spec_helper'
describe 'DD Transactions: Settlements', :scf, :payments, :dd, :no_run do
  before(:all) do
    @anchor_gstn = $conf['users']['anchor']['gstn']
    @vendor_gstn = $conf['users']['dd_vendor']['gstn']
    @vendor_actor = 'dd_vendor'
    @vendor_name = $conf['users'][@vendor_actor]['name']
    @invoice_file = "#{Dir.pwd}/test-data/attachments/anchor_invoice.pdf"
    @payment_proof = "#{Dir.pwd}/test-data/attachments/payment_proof.pdf"
    @file_name = 'anchor_invoice.pdf'
    @erb_file = File.read("#{Dir.pwd}/test-data/erb/testbed_data.erb")
    @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
    @today_date = Date.today.strftime('%d %b, %Y')
  end

  before(:each) do
    @driver = Tarspect::Browser.new($conf['browser']).invoke
    @tarspect_methods = Common::Methods.new(@driver)
    @common_pages = Pages::CommonMethods.new(@driver)
    @transactions_page = Pages::Trasactions.new(@driver)
    @disbursement_page = Pages::Disbursement.new(@driver)
    @payments_page = Pages::Payment.new(@driver)
  end

  after(:each) do |e| # Captures screenshot of the current page when failure happens
    snap_screenshot(e)
    quit_browser
  end

  it 'DD Transaction : Settlement for single invoice', :sanity do |e|
    @due_date = Date.today + 30
    @desired_date = Date.today + 10
    @discount = 10
    @tds = 8
    @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
    @invoice_value = @testdata['DD Invoice Details']['Invoice Value'] < @testdata['DD Invoice Details']['GRN'] ? @testdata['DD Invoice Details']['Invoice Value'] : @testdata['DD Invoice Details']['GRN']

    e.run_step 'Create a DD transaction as Anchor(Draft -> Settled)' do
      @transaction_id = seed_transaction({
                                           actor: 'anchor',
                                           counter_party: 'dd_vendor',
                                           invoice_details: @testdata['DD Invoice Details'],
                                           invoice_file: @invoice_file,
                                           program: 'Dynamic Discounting - Vendor'
                                         })
      expect(@transaction_id).not_to include('Error while creating transaction')
    end

    e.run_step 'Login as Anchor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['anchor']['email'], $conf['users']['anchor']['password'])).to be true
    end

    e.run_step 'Navigate to the transaction and verify record payment not available(from home page)' do
      calculated_values = @transactions_page.calculate_payable_value({
                                                                       invoice_value: @invoice_value,
                                                                       discount: @discount,
                                                                       gst: $conf['gst'],
                                                                       tds: @tds
                                                                     })
      @total_payable = calculated_values[0]
      @gst_amount = calculated_values[1]
      @common_pages.click_menu(MENU_DYNAMIC_DISCOUNTING)
      @common_pages.navigate_to_transaction(@transaction_id)
      expect(@payments_page.record_payment_available?).to eq false
    end

    e.run_step 'Navigate to the transaction verify Record payment available(from Due for Settlement page)' do
      @common_pages.click_menu(MENU_DYNAMIC_DISCOUNTING)
      @common_pages.click_transactions_tab(DUE_FOR_SETTLEMENT)
      @disbursement_page.select_vendor(@vendor_name)
      @common_pages.navigate_to_transaction(@transaction_id)
      expect(@payments_page.record_payment_available?).to eq true
    end

    e.run_step 'Verify Record Payment modal values(Summary and Bank details of Vendor)' do # need to be changed after bug fix # vendor gstn should be changed instead of anchor gstn
      expected_summary = {
        'Total Due' => "₹#{comma_seperated_value(@total_payable)}",
        'GSTN' => $conf['users']['anchor']['gstn'],
        'PAN' => $conf['users']['anchor']['gstn'][2..11]
      }
      bank_details = {
        'Bank Name' => $conf['users']['dd_vendor']['bank_name'],
        'Account Number' => $conf['users']['dd_vendor']['account_number'],
        'IFSC Code' => $conf['users']['dd_vendor']['ifsc_code']
      }
      @payments_page.record_payment_icon.click
      expect(@disbursement_page.verify_summary_details(expected_summary)).to eq true
      expect(@disbursement_page.verify_summary_details(bank_details)).to eq true
      @common_pages.close_modal
    end

    e.run_step 'Record payment' do
      @payment_details = {
        'UTR Number' => "UTR#{DateTime.now.to_time.to_i}#{rand(1..999)}",
        'Date of Payment' => Date.today.strftime('%d-%b-%Y')
      }
      @payments_page.record_payment(
        @payment_details,
        @payment_proof
      )
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['PaymentsSuccess']
    end

    e.run_step 'Verify payment details and proofs in the payments tab' do
      @tarspect_methods.click_link('Payment')
      expect(@disbursement_page.disbursement_amount).to eq "₹ #{comma_seperated_value(@total_payable)}"
      expected_values = {
        'Date of Payment' => @today_date,
        'Amount' => "₹ #{comma_seperated_value(@total_payable)}",
        'UTR Number' => @payment_details['UTR Number'],
        'Discrepancy Reason' => '-',
        'Discrepancy Receipt' => 'View Document  ',
        'Payment Receipt' => 'View Receipt'
      }
      actual_values = @disbursement_page.get_payment_details
      expect(actual_values).to eq expected_values
      expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq true
    end

    e.run_step 'Verify Transaction moved to Matured after Resettlement' do
      @common_pages.click_menu(MENU_DYNAMIC_DISCOUNTING)
      @common_pages.click_transactions_tab(MATURED)
      expect(@common_pages.transaction_listed?(@transaction_id)).to eq(true), "Transaction #{@transaction_id} is not listed"
    end

    e.run_step 'Verify Transaction status in Detail page' do
      @common_pages.navigate_to_transaction(@transaction_id)
      expect(@transactions_page.verify_transaction_status('Matured')).to eq true
    end

    e.run_step 'Verify Payment history for Settlement(From Due For Settlement page)' do
      expected_values = {
        'Payment Status' => 'Success',
        'Paid By' => $conf['users']['anchor']['name'],
        'Paid To' => @vendor_name,
        'Date of Payment' => @today_date,
        'UTR Number' => @payment_details['UTR Number'],
        'Type of Payment' => 'Settlement',
        'Amount' => "₹ #{comma_seperated_value(@total_payable)}"
      }
      @common_pages.click_menu(MENU_DYNAMIC_DISCOUNTING)
      @common_pages.click_transactions_tab(DUE_FOR_SETTLEMENT)
      @disbursement_page.select_vendor(@vendor_name)
      @payments_page.select_payment_history_tab
      filter = {
        'Type Of Payment' => 'Settlement'
      }
      @common_pages.apply_filter(filter)
      result = @payments_page.verify_transaction_in_payment_history(expected_values.values)
      expect(result).to eq true
    end

    e.run_step 'Anchor logs out' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Vendor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['dd_vendor']['email'], $conf['users']['dd_vendor']['password'])).to be true
    end

    e.run_step 'Verify Payment history for Settlement as Vendor' do
      expected_values = {
        'Paid By' => $conf['users']['anchor']['name'],
        'Paid To' => @vendor_name,
        'Date of Payment' => @today_date,
        'UTR Number' => @payment_details['UTR Number'],
        'Type of Payment' => 'Settlement',
        'Amount' => "₹ #{comma_seperated_value(@total_payable)}"
      }
      @common_pages.click_menu(MENU_PAYMENT_HISTORY)
      @payments_page.toggle_investor_payments(true)
      result = @payments_page.verify_transaction_in_payment_history(expected_values.values)
      expect(result).to eq true
    end
  end

  it 'DD Transaction : Settlement for Multiple invoices', :sanity do |e|
    @due_date = Date.today + 30
    @desired_date = Date.today + 10
    @discount = 10
    @tds = 8
    @testdata1 = JSON.parse(ERB.new(@erb_file).result(binding))
    @invoice_value1 = @testdata1['DD Invoice Details']['Invoice Value'] < @testdata1['DD Invoice Details']['GRN'] ? @testdata1['DD Invoice Details']['Invoice Value'] : @testdata1['DD Invoice Details']['GRN']
    @testdata2 = JSON.parse(ERB.new(@erb_file).result(binding))
    @invoice_value2 = @testdata2['DD Invoice Details']['Invoice Value'] < @testdata2['DD Invoice Details']['GRN'] ? @testdata2['DD Invoice Details']['Invoice Value'] : @testdata2['DD Invoice Details']['GRN']

    e.run_step 'Create 2 DD transaction as Anchor(Draft -> Settled)' do
      @transaction_id1 = seed_transaction({
                                            actor: 'anchor',
                                            counter_party: 'dd_vendor',
                                            invoice_details: @testdata1['DD Invoice Details'],
                                            invoice_file: @invoice_file,
                                            program: 'Dynamic Discounting - Vendor'
                                          })
      expect(@transaction_id1).not_to include('Error while creating transaction')
      @transaction_id2 = seed_transaction({
                                            actor: 'anchor',
                                            counter_party: 'dd_vendor',
                                            invoice_details: @testdata2['DD Invoice Details'],
                                            invoice_file: @invoice_file,
                                            program: 'Dynamic Discounting - Vendor'
                                          })
      expect(@transaction_id2).not_to include('Error while creating transaction')
    end

    e.run_step 'Login as Anchor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['anchor']['email'], $conf['users']['anchor']['password'])).to be true
    end

    e.run_step 'Navigate to the transaction and Select multiple transactions' do
      calculated_values = @transactions_page.calculate_payable_value({
                                                                       invoice_value: @invoice_value1,
                                                                       discount: @discount,
                                                                       gst: $conf['gst'],
                                                                       tds: @tds
                                                                     })
      @total_payable1 = calculated_values[0]
      calculated_values = @transactions_page.calculate_payable_value({
                                                                       invoice_value: @invoice_value2,
                                                                       discount: @discount,
                                                                       gst: $conf['gst'],
                                                                       tds: @tds
                                                                     })
      @total_payable2 = calculated_values[0]
      @common_pages.click_menu(MENU_DYNAMIC_DISCOUNTING)
      @common_pages.click_transactions_tab(DUE_FOR_SETTLEMENT)
      @disbursement_page.select_vendor(@vendor_name)
      @disbursement_page.select_transactions([@transaction_id1, @transaction_id2])
      expect(@disbursement_page.resettlement_banner.text).to include '2 Transactions selected!'
    end

    e.run_step 'Verify Record Payment modal values after selecting multiple transactions(Summary and Bank details of Vendor)' do # need to be changed after bug fix # vendor gstn should be changed instead of anchor gstn
      expected_summary = {
        'Total Due' => "₹#{comma_seperated_value(@total_payable1 + @total_payable2)}",
        'GSTN' => $conf['users']['anchor']['gstn'],
        'PAN' => $conf['users']['anchor']['gstn'][2..11]
      }
      bank_details = {
        'Bank Name' => $conf['users']['dd_vendor']['bank_name'],
        'Account Number' => $conf['users']['dd_vendor']['account_number'],
        'IFSC Code' => $conf['users']['dd_vendor']['ifsc_code']
      }
      @payments_page.record_payment_icon.click
      expect(@disbursement_page.verify_summary_details(expected_summary)).to eq true
      expect(@disbursement_page.verify_summary_details(bank_details)).to eq true
      @common_pages.close_modal
    end

    e.run_step 'Verify Clear function works after selecting multiple transactions' do
      @tarspect_methods.click_button('Clear')
      expect(@disbursement_page.resettlement_banner.is_displayed?(2)).to eq false
      expect(@payments_page.record_payment_available?).to eq false
    end

    e.run_step 'Record Payment after selecting multiple transactions' do
      @payment_details = {
        'UTR Number' => "UTR#{DateTime.now.to_time.to_i}#{rand(1..999)}",
        'Date of Payment' => Date.today.strftime('%d-%b-%Y')
      }
      @disbursement_page.select_transactions([@transaction_id1, @transaction_id2])
      @payments_page.record_payment(
        @payment_details,
        @payment_proof
      )
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['PaymentsSuccess']
    end

    e.run_step 'Verify Payment summary modal' do
      @total_invoice_value = @disbursement_page.calculate_total_value_in_words([@testdata1['DD Invoice Details']['Invoice Value'].to_s, @testdata2['DD Invoice Details']['Invoice Value'].to_s])
      expect(@transactions_page.transaction_summary_present?).to eq true
      expect(@disbursement_page.no_of_transactions_in_summary(2)).to eq true
      expect(@transactions_page.verify_summary('Total Value')).to eq "₹#{@total_invoice_value[1].delete(' ')}"
      expect(@transactions_page.verify_summary('Vendor')).to eq @vendor_name
      @tarspect_methods.click_button('close')
    end

    e.run_step 'Verify payment details and proofs in the payments tab - For Transaction 1' do
      @common_pages.click_menu(MENU_DYNAMIC_DISCOUNTING)
      @common_pages.click_transactions_tab(MATURED)
      @common_pages.navigate_to_transaction(@transaction_id1)
      expect(@transactions_page.verify_transaction_status('Matured')).to eq true
      @tarspect_methods.click_link('Payment')
      expect(@disbursement_page.disbursement_amount).to eq "₹ #{comma_seperated_value(@total_payable1)}"
      expected_values = {
        'Date of Payment' => @today_date,
        'Amount' => "₹ #{comma_seperated_value(@total_payable1)}",
        'UTR Number' => @payment_details['UTR Number'],
        'Discrepancy Reason' => '-',
        'Discrepancy Receipt' => 'View Document  ',
        'Payment Receipt' => 'View Receipt'
      }
      actual_values = @disbursement_page.get_payment_details
      expect(actual_values).to eq expected_values
      expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq true
    end

    e.run_step 'Verify payment details and proofs in the payments tab - For Transaction 2' do
      @common_pages.click_menu(MENU_DYNAMIC_DISCOUNTING)
      @common_pages.click_transactions_tab(MATURED)
      @common_pages.navigate_to_transaction(@transaction_id2)
      expect(@transactions_page.verify_transaction_status('Matured')).to eq true
      @tarspect_methods.click_link('Payment')
      expect(@disbursement_page.disbursement_amount).to eq "₹ #{comma_seperated_value(@total_payable2)}"
      expected_values = {
        'Date of Payment' => @today_date,
        'Amount' => "₹ #{comma_seperated_value(@total_payable2)}",
        'UTR Number' => @payment_details['UTR Number'],
        'Discrepancy Reason' => '-',
        'Discrepancy Receipt' => 'View Document  ',
        'Payment Receipt' => 'View Receipt'
      }
      actual_values = @disbursement_page.get_payment_details
      expect(actual_values).to eq expected_values
      expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq true
    end

    e.run_step 'Verify Payment history for Settlement for multiple transactions(From Payment histort menu)' do
      @total_payable_value = @disbursement_page.calculate_total_value_in_words([@total_payable1.to_s, @total_payable2.to_s])
      expected_values = {
        'Payment Status' => 'Success',
        'Paid By' => $conf['users']['anchor']['name'],
        'Paid To' => @vendor_name,
        'Date of Payment' => @today_date,
        'UTR Number' => @payment_details['UTR Number'],
        'Type of Payment' => 'Settlement',
        'Amount' => "₹ #{@total_payable_value[1]}"
      }
      @common_pages.click_menu(MENU_PAYMENT_HISTORY)
      result = @payments_page.verify_transaction_in_payment_history(expected_values.values)
      expect(result).to eq true
    end
  end
end
