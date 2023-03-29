require './spec_helper'
require 'erb'
describe 'Disbursement: Rearend', :scf, :disbursements, :rear_end_disbursement, :hover do
  before(:all) do
    @dealer_gstn = $conf['trends_gstn']
    @counterparty_gstn = $conf['myntra_gstn']
    @anchor_gstn = $conf['myntra_gstn']
    @vendor_name = $conf['dealer_name']
    @anchor_name = $conf['anchor_name']
    @investor_name = $conf['investor_name']
    @invoice_file = "#{Dir.pwd}/test-data/attachments/dealer_invoice.pdf"
    @payment_proof = "#{Dir.pwd}/test-data/attachments/payment_proof.pdf"
    @erb_file = File.read("#{Dir.pwd}/test-data/erb/testbed_data.erb")
    @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
    @invoice_value = @testdata['Dealer Invoice Details']['Invoice Value'].to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
    @testdata['Transaction List']['Instrument Value'] = "₹#{@invoice_value}"
    @today_date = Date.today.strftime('%d %b, %Y')
    @due_date = (Date.today + $conf['dealer_tenor']).strftime('%d %b, %Y')
    @calculate_hash = {
      invoice_value: '',
      margin: $conf['margin'],
      yield: $conf['yield'],
      tenor: $conf['dealer_tenor'],
      type: 'rearend'
    }
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

  it 'Disbursement: Rearend with Invoice Value(Single)', :sanity, :disbursement_invoice_value do |e|
    e.run_step 'Create a complete transaction as Dealer(Draft -> Released)' do
      @transaction_id = seed_transaction({
                                           actor: 'dealer',
                                           counter_party: 'anchor',
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

    e.run_step 'Verify the transaction details in list page' do
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @testdata['Transaction List']['Status'] = 'Released'
      @calculate_hash[:invoice_value] = @testdata['Dealer Invoice Details']['Invoice Value']
      @transaction_values = calculate_transaction_values(@calculate_hash)
      @testdata['Transaction List']['Transaction Value'] = "₹#{comma_seperated_value(@transaction_values[0])}"
      @tran_resp = get_transaction_details(@transaction_id, actor: 'investor')
      expect(api_verify_transaction_in_list_page(@tran_resp[:body], @testdata['Transaction List'])).to eq(true)
    end

    e.run_step 'Verify disbursement modal values(Summary and Bank details of Anchor)' do
      expected_summary = {
        'Total Value' => "₹#{@invoice_value}",
        'Disbursement Amount' => "₹#{comma_seperated_value(@transaction_values[1].to_i)}",
        'Anchor' => @anchor_name,
        'GSTN' => @anchor_gstn
      }
      bank_details = {
        'Bank Name' => 'SOABANK',
        'Account Number' => '12321312312',
        'IFSC Code' => 'SOAA0000002'
      }
      @common_pages.apply_filter({ 'Instrument Number' => @testdata['Dealer Invoice Details']['Invoice Number'] })
      @common_pages.navigate_to_transaction(@transaction_id)
      @disbursement_page.click_disbursement
      expect(@disbursement_page.verify_summary_details(expected_summary)).to eq true
      expect(@disbursement_page.verify_summary_details(bank_details)).to eq true
    end

    e.run_step 'Disburse the amount' do
      @disbursement_details = {
        'UTR Number' => "UTR#{DateTime.now.to_time.to_i}#{rand(1..999)}",
        'Date of Payment' => Date.today.strftime('%d-%b-%Y'),
        'Disbursement Amount' => @transaction_values[1],
        'Disbursement Account Number' => Faker::Number.number(digits: 10)
      }
      @disbursement_page.disburse(@payment_proof, @disbursement_details)
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['DisburseSuccess']
    end

    e.run_step 'Verify the transaction status and timeline status' do
      expect(@transactions_page.verify_transaction_status('Settled')).to eq true
      expect(@transactions_page.status_timeline_present?(@today_date, 'CA Approval')).to eq true
      expect(@transactions_page.status_timeline_present?(@today_date, 'Anchor Approval')).to eq true
      expect(@transactions_page.status_timeline_present?(@today_date, 'CA Approval (Level 2)')).to eq true
      expect(@transactions_page.status_timeline_present?(@today_date, 'Settled')).to eq true
    end

    e.run_step 'Verify status timeline in the hovercard after disbursement' do
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @common_pages.click_transactions_tab(SETTLED)
      expect(@transactions_page.status_timeline_on_hover(@transaction_id, @today_date, 'CA Approval')).to eq true
      expect(@transactions_page.status_timeline_on_hover(@transaction_id, @today_date, 'Anchor Approval')).to eq true
      expect(@transactions_page.status_timeline_on_hover(@transaction_id, @today_date, 'CA Approval (Level 2)')).to eq true
      expect(@transactions_page.status_timeline_on_hover(@transaction_id, @today_date, 'Settled')).to eq true
    end

    e.run_step 'Verify payment details and proofs in the payments tab' do
      @common_pages.navigate_to_transaction(@transaction_id)
      @tarspect_methods.click_link('Payment')
      expect(@disbursement_page.account_number).to eq @disbursement_details['Disbursement Account Number'].to_s
      expect(@disbursement_page.disbursement_amount).to eq "₹ #{comma_seperated_value(@transaction_values[1].to_i)}"
      expected_values = {
        'Date of Payment' => @today_date,
        'Amount' => "₹ #{comma_seperated_value(@transaction_values[1].to_i)}",
        'UTR Number' => @disbursement_details['UTR Number'],
        'Discrepancy Reason' => '-',
        'Discrepancy Receipt' => 'View Document  ',
        'Payment Receipt' => 'View Receipt'
      }
      actual_values = @disbursement_page.get_payment_details
      expect(actual_values).to eq expected_values
      expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq true
    end

    e.run_step 'Verify Due for Payment details' do
      expected_values = {
        'Due Date' => @due_date,
        'Principal Paid / Outstanding' => "₹ 0  /  ₹ #{comma_seperated_value(rounded_half_down_value(@transaction_values[0].to_f))}",
        'Interest Paid / Outstanding' => '₹ 0  /  ₹ 0',
        'Charges Outstanding' => '₹ 0',
        'Total Outstanding' => "₹ #{comma_seperated_value(rounded_half_down_value(@transaction_values[0].to_f))}"
      }
      actual_values = @disbursement_page.get_due_for_payment_details
      expect(actual_values).to eq expected_values
    end

    e.run_step 'Verify Payment history for Disbursement as investor' do
      expected_values = {
        'Paid By' => $conf['investor_name'],
        'Paid To' => @anchor_name,
        'Date of Payment' => @today_date,
        'UTR Number' => @disbursement_details['UTR Number'],
        'Payment Type' => 'Funding',
        'Amount' => "₹ #{comma_seperated_value(@transaction_values[1].to_i)}"
      }
      @common_pages.click_menu(MENU_PAYMENT_HISTORY)
      @payments_page.toggle_investor_payments(true)
      filter = {
        'Paid To' => "#{@anchor_name} - Anchor",
        'date_range' => [
          { 'Date Range' => @today_date },
          { 'Date Range' => @today_date }
        ],
        'Type Of Payment' => 'Funding'
      }
      @common_pages.apply_list_filter(filter)
      result = @payments_page.verify_transaction_in_payment_history(expected_values.values)
      expect(result).to eq true
    end

    e.run_step 'Investor logs out' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Dealer' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['dealer']['email'], $conf['users']['dealer']['password'])).to eq true
    end

    e.run_step 'Verify status timeline in the hovercard after disbursement as Dealer' do
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @common_pages.click_transactions_tab(SETTLED)
      p @testdata['Dealer Invoice Details']
      expect(@transactions_page.status_timeline_on_hover(@transaction_id, @today_date, 'CA Approval')).to eq true
      expect(@transactions_page.status_timeline_on_hover(@transaction_id, @today_date, 'Anchor Approval')).to eq true
      expect(@transactions_page.status_timeline_on_hover(@transaction_id, @today_date, 'CA Approval (Level 2)')).to eq true
      expect(@transactions_page.status_timeline_on_hover(@transaction_id, @today_date, 'Settled')).to eq true
    end

    e.run_step 'Verify payment details and proofs in the payments tab as Dealer' do
      @common_pages.navigate_to_transaction(@transaction_id)
      @tarspect_methods.click_link('Payment')
      expect(@disbursement_page.account_number).to eq @disbursement_details['Disbursement Account Number'].to_s
      expect(@disbursement_page.disbursement_amount).to eq "₹ #{comma_seperated_value(@transaction_values[1].to_i)}"
      expected_values = {
        'Date of Payment' => @today_date,
        'Amount' => "₹ #{comma_seperated_value(@transaction_values[1].to_i)}",
        'UTR Number' => @disbursement_details['UTR Number'],
        'Discrepancy Reason' => '-',
        'Discrepancy Receipt' => 'View Document  ',
        'Payment Receipt' => 'View Receipt'
      }
      actual_values = @disbursement_page.get_payment_details
      expect(actual_values).to eq expected_values
      expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq true
    end

    e.run_step 'Verify Due for Payment details as Dealer' do
      expected_values = {
        'Due Date' => @due_date,
        'Principal Paid / Outstanding' => "₹ 0  /  ₹ #{comma_seperated_value(rounded_half_down_value(@transaction_values[0].to_f))}",
        'Interest Paid / Outstanding' => '₹ 0  /  ₹ 0',
        'Charges Outstanding' => '₹ 0',
        'Total Outstanding' => "₹ #{comma_seperated_value(rounded_half_down_value(@transaction_values[0].to_f))}"
      }
      actual_values = @disbursement_page.get_due_for_payment_details
      expect(actual_values).to eq expected_values
    end

    e.run_step 'Dealer logs out' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Anchor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['anchor']['email'], $conf['users']['anchor']['password'])).to eq true
    end

    e.run_step 'Verify Payment history for Disbursement as Anchor(Dealer disbursements will be recorded under Anchor login)' do
      expected_values = {
        'Paid By' => $conf['investor_name'],
        'Paid To' => @anchor_name,
        'Date of Payment' => @today_date,
        'UTR Number' => @disbursement_details['UTR Number'],
        'Payment Type' => 'Funding',
        'Amount' => "₹ #{comma_seperated_value(@transaction_values[1].to_i)}"
      }
      @common_pages.click_menu(MENU_PAYMENT_HISTORY)
      @payments_page.toggle_investor_payments(true)
      filter = {
        'Paid To' => "#{@anchor_name} - Anchor",
        'date_range' => [
          { 'Date Range' => @today_date },
          { 'Date Range' => @today_date }
        ],
        'Type Of Payment' => 'Funding'
      }
      @common_pages.apply_list_filter(filter)
      result = @payments_page.verify_transaction_in_payment_history(expected_values.values)
      expect(result).to eq true
    end
  end

  it 'Disbursement: Rearend with Invoice Value(Multiple)', :sanity, :rear_end_multiple do |e|
    e.run_step 'Create 2 complete transactions as Dealer(Draft -> Released)' do
      @testdata_1 = JSON.parse(ERB.new(@erb_file).result(binding))
      @invoice_value_1 = @testdata_1['Dealer Invoice Details']['Invoice Value'].to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
      @testdata_1['Transaction List']['Instrument Value'] = "₹#{@invoice_value_1}"
      @testdata_2 = JSON.parse(ERB.new(@erb_file).result(binding))
      @invoice_value_2 = @testdata_2['Dealer Invoice Details']['Invoice Value'].to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
      @testdata_2['Transaction List']['Instrument Value'] = "₹#{@invoice_value_2}"
      @transaction_1 = seed_transaction({
                                          actor: 'dealer',
                                          counter_party: 'anchor',
                                          invoice_details: @testdata_1['Dealer Invoice Details'],
                                          invoice_file: @invoice_file,
                                          program: 'Invoice Financing - Dealer',
                                          program_group: 'invoice'
                                        })
      expect(@transaction_1).not_to include('Error while creating transaction')
      @transaction_2 = seed_transaction({
                                          actor: 'dealer',
                                          counter_party: 'anchor',
                                          invoice_details: @testdata_2['Dealer Invoice Details'],
                                          invoice_file: @invoice_file,
                                          program: 'Invoice Financing - Dealer',
                                          program_group: 'invoice'
                                        })
      expect(@transaction_2).not_to include('Error while creating transaction')
    end

    e.run_step 'Login as Investor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['investor']['email'], $conf['users']['investor']['password'])).to eq true
    end

    e.run_step 'Verify the transaction details in list page' do
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @common_pages.click_transactions_tab(SHOW_ALL)
      @testdata_1['Transaction List']['Status'] = 'Released'
      @testdata_2['Transaction List']['Status'] = 'Released'
      @calculate_hash[:invoice_value] = @testdata_1['Dealer Invoice Details']['Invoice Value']
      @transaction_values_1 = calculate_transaction_values(@calculate_hash)
      @calculate_hash[:invoice_value] = @testdata_2['Dealer Invoice Details']['Invoice Value']
      @transaction_values_2 = calculate_transaction_values(@calculate_hash)
      @testdata_1['Transaction List']['Transaction Value'] = "₹#{comma_seperated_value(@transaction_values_1[0])}"
      @testdata_2['Transaction List']['Transaction Value'] = "₹#{comma_seperated_value(@transaction_values_2[0])}"
      @tran_resp = get_transaction_details(@transaction_1, actor: 'investor')
      expect(api_verify_transaction_in_list_page(@tran_resp[:body], @testdata_1['Transaction List'])).to eq(true)
      @tran_resp = get_transaction_details(@transaction_2, actor: 'investor')
      expect(api_verify_transaction_in_list_page(@tran_resp[:body], @testdata_2['Transaction List'])).to eq(true)
    end

    e.run_step "Verify transactions in 'Up For disbursement' tab" do
      @testdata_1['Transaction List'].delete('Status')
      @testdata_2['Transaction List'].delete('Status')
      @testdata_1['Transaction List'].delete('Anchor Name')
      @testdata_2['Transaction List'].delete('Anchor Name')
      @testdata_1['Transaction List']['Disbursement Value'] = "₹#{comma_seperated_value(@transaction_values_1[1].to_i)}"
      @testdata_2['Transaction List']['Disbursement Value'] = "₹#{comma_seperated_value(@transaction_values_2[1].to_i)}"
      resp = get_transaction_details(@transaction_1)
      expect(resp[:body][:vendor][:name]).to eq(@testdata_1['Transaction List']['Vendor Name'])
      expect(resp[:body][:transaction_value]).to eq(@transaction_values_1[1])
      expect(resp[:body][:disbursement_amount]).to eq(@transaction_values_1[1])
      expect(resp[:body][:invoice_value]).to eq(@testdata_1['Dealer Invoice Details']['Invoice Value'].to_f)
      resp = get_transaction_details(@transaction_2)
      expect(resp[:body][:vendor][:name]).to eq(@testdata_2['Transaction List']['Vendor Name'])
      expect(resp[:body][:transaction_value]).to eq(@transaction_values_2[1])
      expect(resp[:body][:disbursement_amount]).to eq(@transaction_values_2[1])
      expect(resp[:body][:invoice_value]).to eq(@testdata_2['Dealer Invoice Details']['Invoice Value'].to_f)
    end

    e.run_step 'Disburse Multiple transactions' do
      @total_invoice_amount = @disbursement_page.calculate_total_value_in_words([@testdata_1['Transaction List']['Instrument Value'], @testdata_2['Transaction List']['Instrument Value']])
      @total_disbursement_amount = @disbursement_page.calculate_total_value_in_words([@testdata_1['Transaction List']['Disbursement Value'], @testdata_2['Transaction List']['Disbursement Value']])
      @disbursement_details = {
        'UTR Number' => "UTR#{DateTime.now.to_time.to_i}#{rand(1..999)}",
        'Date of Payment' => Date.today.strftime('%d-%b-%Y'),
        'Disbursement Amount' => @total_disbursement_amount[0].gsub(',', ''),
        'Disbursement Account Number' => Faker::Number.number(digits: 10)
      }
      ids = []
      resp = get_transaction_details(@transaction_1)
      ids << resp[:body][:id]
      resp = get_transaction_details(@transaction_2)
      ids << resp[:body][:id]
      disburse_hash = {
        utr_number: @disbursement_details['UTR Number'],
        account_number: @disbursement_details['Disbursement Account Number'],
        disbursement_date: Date.today.strftime('%Y-%m-%d'),
        amount: @disbursement_details['Disbursement Amount'],
        invoice_transaction_ids: ids
      }
      resp = disburse_multiple_transactions(disburse_hash)
      expect(resp[:code]).to eq(200)
    end

    e.run_step 'Verify payment details and proofs in the payments tab - For transaction 1' do
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @common_pages.click_transactions_tab(SETTLED)
      @common_pages.navigate_to_transaction(@transaction_1)
      @tarspect_methods.click_link('Payment')
      expect(@disbursement_page.account_number).to eq @disbursement_details['Disbursement Account Number'].to_s
      expect(@disbursement_page.disbursement_amount).to eq "₹ #{comma_seperated_value(@transaction_values_1[1].to_i)}"
      expected_values = {
        'Date of Payment' => @today_date,
        'Amount' => "₹ #{@total_disbursement_amount[1]}",
        'UTR Number' => @disbursement_details['UTR Number'],
        'Discrepancy Reason' => '-',
        'Discrepancy Receipt' => 'View Document  ',
        'Payment Receipt' => 'View Receipt'
      }
      actual_values = @disbursement_page.get_payment_details
      expect(actual_values).to eq expected_values
      expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq true
    end

    e.run_step 'Verify Due for Payment details - For transaction 1' do
      expected_values = {
        'Due Date' => @due_date,
        'Principal Paid / Outstanding' => "₹ 0  /  ₹ #{comma_seperated_value(rounded_half_down_value(@transaction_values_1[0].to_f))}",
        'Interest Paid / Outstanding' => '₹ 0  /  ₹ 0',
        'Charges Outstanding' => '₹ 0',
        'Total Outstanding' => "₹ #{comma_seperated_value(rounded_half_down_value(@transaction_values_1[0].to_f))}"
      }
      actual_values = @disbursement_page.get_due_for_payment_details
      expect(actual_values).to eq expected_values
    end

    e.run_step 'Verify payment details and proofs in the payments tab - For transaction 2' do
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @common_pages.click_transactions_tab(SHOW_ALL)
      @common_pages.navigate_to_transaction(@transaction_2)
      @tarspect_methods.click_link('Payment')
      expect(@disbursement_page.account_number).to eq @disbursement_details['Disbursement Account Number'].to_s
      expect(@disbursement_page.disbursement_amount).to eq "₹ #{comma_seperated_value(@transaction_values_2[1].to_i)}"
      expected_values = {
        'Date of Payment' => @today_date,
        'Amount' => "₹ #{@total_disbursement_amount[1]}",
        'UTR Number' => @disbursement_details['UTR Number'],
        'Discrepancy Reason' => '-',
        'Discrepancy Receipt' => 'View Document  ',
        'Payment Receipt' => 'View Receipt'
      }
      actual_values = @disbursement_page.get_payment_details
      expect(actual_values).to eq expected_values
      expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq true
    end

    e.run_step 'Verify Due for Payment details - For transaction 2' do
      expected_values = {
        'Due Date' => @due_date,
        'Principal Paid / Outstanding' => "₹ 0  /  ₹ #{comma_seperated_value(rounded_half_down_value(@transaction_values_2[0].to_f))}",
        'Interest Paid / Outstanding' => '₹ 0  /  ₹ 0',
        'Charges Outstanding' => '₹ 0',
        'Total Outstanding' => "₹ #{comma_seperated_value(rounded_half_down_value(@transaction_values_2[0].to_f))}"
      }
      actual_values = @disbursement_page.get_due_for_payment_details
      expect(actual_values).to eq expected_values
    end
  end

  it 'Disbursement: Capture Actual disbursal(Higher value)', :sanity do |e|
    e.run_step 'Create 2 complete transactions as Dealer(Draft -> Released)' do
      @testdata_1 = JSON.parse(ERB.new(@erb_file).result(binding))
      @invoice_value_1 = @testdata_1['Dealer Invoice Details']['Invoice Value'].to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
      @testdata_1['Transaction List']['Instrument Value'] = "₹#{@invoice_value_1}"
      @testdata_2 = JSON.parse(ERB.new(@erb_file).result(binding))
      @invoice_value_2 = @testdata_2['Dealer Invoice Details']['Invoice Value'].to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
      @testdata_2['Transaction List']['Instrument Value'] = "₹#{@invoice_value_2}"
      @transaction_1 = seed_transaction({
                                          actor: 'dealer',
                                          counter_party: 'anchor',
                                          invoice_details: @testdata_1['Dealer Invoice Details'],
                                          invoice_file: @invoice_file,
                                          program: 'Invoice Financing - Dealer',
                                          program_group: 'invoice'
                                        })
      expect(@transaction_1).not_to include('Error while creating transaction')
      @transaction_2 = seed_transaction({
                                          actor: 'dealer',
                                          counter_party: 'anchor',
                                          invoice_details: @testdata_2['Dealer Invoice Details'],
                                          invoice_file: @invoice_file,
                                          program: 'Invoice Financing - Dealer',
                                          program_group: 'invoice'
                                        })
      expect(@transaction_2).not_to include('Error while creating transaction')
    end

    e.run_step 'Login as Investor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['investor']['email'], $conf['users']['investor']['password'])).to eq true
    end

    e.run_step 'Verify the transaction details in list page' do
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @common_pages.click_transactions_tab(SHOW_ALL)
      @testdata_1['Transaction List']['Status'] = 'Released'
      @testdata_2['Transaction List']['Status'] = 'Released'
      @calculate_hash[:invoice_value] = @testdata_1['Dealer Invoice Details']['Invoice Value']
      @transaction_values_1 = calculate_transaction_values(@calculate_hash)
      @calculate_hash[:invoice_value] = @testdata_2['Dealer Invoice Details']['Invoice Value']
      @transaction_values_2 = calculate_transaction_values(@calculate_hash)
      @testdata_1['Transaction List']['Transaction Value'] = "₹#{comma_seperated_value(@transaction_values_1[0])}"
      @testdata_2['Transaction List']['Transaction Value'] = "₹#{comma_seperated_value(@transaction_values_2[0])}"
      @tran_resp = get_transaction_details(@transaction_1, actor: 'investor')
      expect(api_verify_transaction_in_list_page(@tran_resp[:body], @testdata_1['Transaction List'])).to eq(true)
      @tran_resp = get_transaction_details(@transaction_2, actor: 'investor')
      expect(api_verify_transaction_in_list_page(@tran_resp[:body], @testdata_2['Transaction List'])).to eq(true)
      @testdata_1['Transaction List']['Disbursement Value'] = "₹#{comma_seperated_value(@transaction_values_1[1].to_i)}"
      @testdata_2['Transaction List']['Disbursement Value'] = "₹#{comma_seperated_value(@transaction_values_2[1].to_i)}"
    end

    e.run_step 'Disburse Multiple transactions with higher disbursal value' do
      @total_invoice_amount = @disbursement_page.calculate_total_value_in_words([@testdata_1['Transaction List']['Instrument Value'], @testdata_2['Transaction List']['Instrument Value']])
      @total_disbursement_amount = @disbursement_page.calculate_total_value_in_words([@testdata_1['Transaction List']['Disbursement Value'], @testdata_2['Transaction List']['Disbursement Value']])
      @disbursement_details = {
        'UTR Number' => "UTR#{DateTime.now.to_time.to_i}#{rand(1..999)}",
        'Date of Payment' => Date.today.strftime('%d-%b-%Y'),
        'Disbursement Amount' => @total_disbursement_amount[0].gsub(',', '').to_f + 1000,
        'Disbursement Account Number' => Faker::Number.number(digits: 10)
      }
      ids = []
      resp = get_transaction_details(@transaction_1)
      ids << resp[:body][:id]
      resp = get_transaction_details(@transaction_2)
      ids << resp[:body][:id]
      disburse_hash = {
        utr_number: @disbursement_details['UTR Number'],
        account_number: @disbursement_details['Disbursement Account Number'],
        disbursement_date: Date.today.strftime('%Y-%m-%d'),
        amount: @disbursement_details['Disbursement Amount'],
        invoice_transaction_ids: ids,
        discrepancy_reason: @testdata['Discrepancy Reason'],
        discrepancy_proof: @payment_proof
      }
      resp = disburse_multiple_transactions(disburse_hash)
      expect(resp[:code]).to eq(200)
    end

    e.run_step 'Verify discrepancy details and proofs in the payments tab - For transaction 1' do
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @common_pages.click_transactions_tab(SETTLED)
      @common_pages.navigate_to_transaction(@transaction_1)
      @tarspect_methods.click_link('Payment')
      expect(@disbursement_page.validate_discrepancy_reason(@testdata['Discrepancy Reason'])).to eq true
      expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq true
    end

    e.run_step 'Verify discrepancy details and proofs in the payments tab - For transaction 2' do
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @common_pages.click_transactions_tab(SETTLED)
      @common_pages.navigate_to_transaction(@transaction_2)
      @tarspect_methods.click_link('Payment')
      expect(@disbursement_page.validate_discrepancy_reason(@testdata['Discrepancy Reason'])).to eq true
      expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq true
    end
  end
end
