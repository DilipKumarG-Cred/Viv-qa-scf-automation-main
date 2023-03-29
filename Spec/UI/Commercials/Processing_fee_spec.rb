require './spec_helper'
describe 'Commercials: Processing Fee', :scf, :commercials, :onboarding, :processing_fee, :pf, :mails do
  before(:each) do
    @counterparty_gstn = $conf['myntra_gstn']
    @invoice_file = "#{Dir.pwd}/test-data/attachments/dealer_invoice.pdf"
    @payment_proof = "#{Dir.pwd}/test-data/attachments/payment_proof.pdf"
    @invoice_erb = File.read("#{Dir.pwd}/test-data/erb/testbed_data.erb")
    @today_date = Date.today.strftime('%d %b, %Y')
    @due_date = (Date.today + $conf['vendor_tenor']).strftime('%d %b, %Y')
    @erb_file = File.read("#{Dir.pwd}/test-data/erb/commercials_data.erb")
    @borrowing_document = "#{Dir.pwd}/test-data/attachments/borrowing_document.pdf"
    @program_name = 'Invoice Financing - Vendor Program'
    @download_path = "#{Dir.pwd}/test-data/downloaded/download_docs_verification"
    @driver = Tarspect::Browser.new($conf['browser'], @download_path).invoke
    @tarspect_methods = Common::Methods.new(@driver)
    @common_pages = Pages::CommonMethods.new(@driver)
    @commercials_page = Pages::Commercials.new(@driver)
    @transactions_page = Pages::Trasactions.new(@driver)
    @disbursement_page = Pages::Disbursement.new(@driver)
    @payments_page = Pages::Payment.new(@driver)
    navigate_to($conf['base_url'])
    @calculate_hash = {
      invoice_value: '',
      margin: $conf['margin'],
      yield: $conf['yield'],
      tenor: $conf['vendor_tenor'],
      type: 'frontend'
    }
    @created_vendor = []
  end

  after(:each) do |e| # Captures screenshot of the current page when failure happens
    snap_screenshot(e)
    flush_directory(@download_path)
    quit_browser
  end

  after(:each) do
    delete_channel_partner('Vendor', @created_vendor)
    flush_directory(@download_path)
  end

  it 'Commercials : Processing Fee', :processing_new do |e|
    @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
    @testdata['Commercials']['GSTN'] = "17#{@testdata['Commercials']['PAN']}#{Faker::Number.number(digits: 1)}Z#{Faker::Internet.user_name(specifier: 1..1).upcase}"
    @commercials_data = @testdata['Commercials']
    @company_info = @testdata['Company Info']
    @bank_details = @testdata['Bank Details']

    e.run_step "Create a vendor #{@commercials_data['Entity Name']} and complete onboarding details" do
      expect(api_create_registered_channel_partner(@testdata)).to eq true
      @created_vendor << @commercials_data['Entity Name']
      @commercials_data['Name'] = @commercials_data['Entity Name']
    end

    e.run_step 'Approve the vendor as a platform team' do
      sleep 5
      expect(api_approve_all_docs_and_vendor(@testdata, 'mandatory_docs')).to eq true
    end

    e.run_step 'Login as Product user and verify invited/onboarding date are displayed' do
      navigate_to($conf['base_url'])
      @tarspect_methods.login($conf['users']['product']['email'], $conf['users']['product']['password'])
      @common_pages.click_menu(MENU_VENDORS)
      @common_pages.search_program(@commercials_data['Name'])
      values = { name: @commercials_data['Name'], state: 'Approved', field: 'Invite Date', program: 'INVOICE FINANCING' }
      expect(@commercials_page.get_vendor_details(values)).to eq(Date.today.strftime('%d %b, %Y'))
      values.merge!(field: 'Onboarded Date')
      expect(@commercials_page.get_vendor_details(values)).to eq(Date.today.strftime('%d %b, %Y'))
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Investor and verify new vendor is present for the anchor' do
      expected_values = {
        'Status' => '-',
        'Name' => @commercials_data['Name'],
        'City' => @company_info['City'],
        'Geography' => @company_info['Geography'].downcase,
        'Sector' => @testdata['Company Info']['Sector'], # vendor type is changed to sector.
        'Relationship Age' => '-', # relationship age is removed from onboarding hence we get - here
        'Turnover' => '0',
        'Live Transaction Count' => '0'
      }
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['investor']['email'], $conf['users']['investor']['password'])).to be true
      @common_pages.click_menu(MENU_ANCHOR_LIST)
      @common_pages.navigate_to_anchor($conf['anchor_name'])
      @common_pages.select_program('Invoice Financing', 'Vendor')
      expect(@commercials_page.vendor_program_details(@commercials_data['Name'])).to eq expected_values
    end

    e.run_step 'Verify the vendor has been dropped' do
      @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
      drop_reason = @testdata['Reject Reason']
      @vendor_commercials = {
        'Processing Fee' => 2,
        'Investor GSTN' => $conf['myntra_gstn'],
        'Sanction Limit' => 10_000,
        'Tenor' => "#{$conf['vendor_tenor']} days",
        'Yield' => '15',
        'Agreement Validity' => [get_todays_date(nil, '%d-%b-%Y'), get_todays_date(300, '%d-%b-%Y')],
        'Effective Date' => Date.today.strftime('%d-%b-%Y')
      }
      @commercials_page.navigate_to_vendor(@commercials_data['Name'])
      message, actual_data = @commercials_page.check_drop('Drop', drop_reason)
      expect(message.text).to eq 'Channel Partner dropped.'
      expected_data = [drop_reason, 'Crime check failed', 'CIBIL issues']
      expect(actual_data).to eq(expected_data)
    end

    e.run_step 'Verify the vendor has been shortlisted' do
      message, shortlist, drop_button, set_limit_button = @commercials_page.check_shortlist
      expect(message.text).to eq 'Channel Partner shortlisted.'
      expect(shortlist).to eq 'Shortlisted'
      expect(drop_button).to eq true
      expect(set_limit_button).to eq true
    end

    e.run_step 'Verify the vendor should set the limit' do
      @tarspect_methods.click_button('Set Limit')
      @tarspect_methods.wait_for_loader_to_disappear(MAX_LOADER_TIME)
      @commercials_page.add_vendor_commercials(@vendor_commercials, set_limit: true)
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['VendorProgramAdded']
      drop_button = @tarspect_methods.DYNAMIC_XPATH('button', 'text()', 'Drop').is_displayed?
      expect(drop_button).to eq false
    end

    e.run_step 'Verify Vendor commercials status after adding Vendor program - Draft' do
      expected_values = {
        'Status' => 'Draft',
        'Name' => @commercials_data['Name'],
        'City' => @company_info['City'],
        'Geography' => @company_info['Geography'].downcase,
        'Sector' => @testdata['Company Info']['Sector'],
        'Relationship Age' => '-',
        'Turnover' => '0',
        'Live Transaction Count' => '0'
      }
      refresh_page
      @common_pages.click_back_button
      @commercials_page.scroll_till_program(@commercials_data['Name'])
      expect(@commercials_page.vendor_program_details(@commercials_data['Name'])).to eq expected_values
    end

    e.run_step 'Add Borrowing document' do
      @commercials_page.navigate_to_vendor(@commercials_data['Name'])
      @tarspect_methods.wait_for_loader_to_disappear(MAX_LOADER_TIME)
      @commercials_page.commercials_tab.click
      @commercials_page.upload_bd(@borrowing_document)
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['BDSigned']
    end

    e.run_step 'Submit the Commercials' do
      @tarspect_methods.click_button('Submit')
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq 'Commercial renewed successfully!'
    end

    e.run_step 'Logout as Investor' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step "Login as Vendor #{@commercials_data['Email']}" do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login(@commercials_data['Email'], $conf['users']['anchor']['password'])).to be true
      @tarspect_methods.fill_mobile_otp
      @common_pages.click_menu(MENU_ANCHOR_LIST)
      @common_pages.navigate_to_anchor($conf['anchor_name'])
      @common_pages.select_program('Invoice Financing', 'Vendor')
      investor_details = {
        'investor' => 'Kotak',
        'Sanction limit' => '10000',
        'Processing Fee' => '2.0 %',
        'Tenor' => "#{$conf['vendor_tenor']} Days",
        'Repayment Adjustment Order' => 'Interest - Principal - Charges'
      }
      expect(@common_pages.verify_interested_investors_details(investor_details)).to eq true
    end

    e.run_step 'Verify Processing fee details for the commercials(Summary and Bank account details of Investor)' do
      expected_summary = {
        'Processing fee' => '₹200',
        'CGST Fee (9%)' => '₹18',
        'IGST Fee (18%)' => '₹0',
        'SGST Fee (9%)' => '₹18',
        'Processing Fee Payable' => '₹236'
      }
      # bank_details = {
      #   'Bank Name' => @bank_details['Bank Name'],
      #   'Account Number' => @bank_details['Account Number'],
      #   'IFSC Code' => @bank_details['IFSC Code']
      # }
      # refresh_page
      @tarspect_methods.wait_for_loader_to_disappear(MAX_LOADER_TIME)
      @tarspect_methods.click_button('Record Payment')
      @tarspect_methods.click_button('Submit & Proceed To Payment')
      result = @disbursement_page.verify_summary_details(expected_summary)
      expect(result).to eq(true), "#{result} VENDOR GSTN: #{@commercials_data['GSTN']}, ANCHOR GSTN #{@vendor_commercials['Investor GSTN']}"
      # expect(@disbursement_page.verify_summary_details(bank_details)).to eq true
      @common_pages.close_modal
    end

    e.run_step 'Record Processing fee for the commercials' do
      @processing_fee = {
        'UTR Number' => "UTR#{DateTime.now.to_time.to_i}#{rand(1..999)}",
        'Date of Payment' => Date.today.strftime('%d-%b-%Y')
      }
      @commercials_page.record_processing_fee(@processing_fee)
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['ProcessingFee']
    end

    e.run_step 'Create a transaction as a Vendor(for checking the disbursement across various stages)' do
      @vendor_gstn = @commercials_data['GSTN']
      @inv_testdata = JSON.parse(ERB.new(@invoice_erb).result(binding))
      @inv_testdata['Vendor Invoice Details']['Invoice Value'] = 10_000
      @invoice_value = @inv_testdata['Vendor Invoice Details']['Invoice Value'].to_s.reverse.gsub(/(\d{3})(?=\d)/,
                                                                                                  '\\1,').reverse
      @vendor = @commercials_data['Email'].split('@')[0]
      @transaction_id = seed_transaction(
        {
          actor: @vendor,
          counter_party: 'anchor',
          invoice_details: @inv_testdata['Vendor Invoice Details'],
          invoice_file: @invoice_file,
          program: 'Invoice Financing - Vendor',
          program_group: 'invoice'
        }
      )
      expect(@transaction_id).not_to include('Error while creating transaction')
    end

    e.run_step 'Logout as Vendor' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Investor and verify processing fee' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['investor']['email'],
                                     $conf['users']['investor']['password'])).to be true
    end

    e.run_step 'Verify Investor cannot do disbursements when Vendor status is pending' do
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @common_pages.click_transactions_tab(SHOW_ALL)
      @calculate_hash[:invoice_value] = @inv_testdata['Vendor Invoice Details']['Invoice Value']
      @transaction_values = calculate_transaction_values(@calculate_hash)
      @disbursement_details = {
        'UTR Number' => "UTR#{DateTime.now.to_time.to_i}#{rand(1..999)}",
        'Date of Payment' => Date.today.strftime('%d-%b-%Y'),
        'Disbursement Amount' => @transaction_values[1],
        'Disbursement Account Number' => Faker::Number.number(digits: 10)
      }
      @common_pages.navigate_to_transaction(@transaction_id)
      @disbursement_page.click_disbursement
      @disbursement_page.disburse(@payment_proof, @disbursement_details)
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['PFPending']
      @common_pages.close_modal
    end

    e.run_step 'Verify Vendor commercials status after processing fee is done - Pending' do
      expected_values = {
        'Status' => 'Pending',
        'Name' => @commercials_data['Name'],
        'City' => @company_info['City'],
        'Geography' => @company_info['Geography'].downcase,
        'Sector' => @testdata['Company Info']['Sector'],
        'Relationship Age' => '-',
        'Turnover' => '0',
        'Live Transaction Count' => '1'
      }
      @common_pages.click_menu(MENU_ANCHOR_LIST)
      @common_pages.navigate_to_anchor($conf['anchor_name'])
      @common_pages.select_program('Invoice Financing', 'Vendor')
      # @commercials_page.scroll_till_program(@commercials_data['Name'])
      expect(@commercials_page.vendor_program_details(@commercials_data['Name'])).to eq expected_values
    end

    e.run_step 'Verify Processing fee values in the modal' do
      @commercials_page.open_processing_fee_details(@commercials_data['Name'])
      sleep 2
      expected_values = {
        'UTR Number' => @processing_fee['UTR Number'],
        'Date of Invoice' => @today_date,
        'Processing Fee' => '₹ 200',
        'CGST @ 9%' => '₹ 18',
        'SGST @ 9%' => '₹ 18',
        'Total Amount Payable' => '₹ 236'
      }
      expect(@transactions_page.verify_invoice_review_modal(expected_values)).to eq true
    end

    e.run_step 'Reject the Processing fee for the commercials' do
      @transactions_page.reject_processing_fee_invoice(@inv_testdata['Reject Reason'])
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['PFReject']
    end

    e.run_step 'Logout as Investor' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Vendor and View rejected reason for the Processing Fee' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login(@commercials_data['Email'], $conf['users']['anchor']['password'])).to be true
      @common_pages.click_menu(MENU_ANCHOR_LIST)
      expect(@commercials_page.rejected_processing_fee_present?(@inv_testdata['Reject Reason'])).to eq true
    end

    e.run_step 'Verify the rejected payments in the processing fee slider' do
      @tarspect_methods.click_button('Click to View!')
      expect(@commercials_page.rejected_reason_on_processing_fee_slider?(@inv_testdata['Reject Reason'])).to eq true
    end

    e.run_step 'Verify Rejected Processing fee payments in the popup modal' do
      expected_values = {
        'UTR Number' => @processing_fee['UTR Number'],
        'Date of Invoice' => @today_date,
        'Reason' => @inv_testdata['Reject Reason']
      }
      @tarspect_methods.click_button('Record another Payment')
      @commercials_page.open_rejected_payments
      expect(@commercials_page.verify_rejected_payments_summary(expected_values.values)).to eq true
      @commercials_page.close_reject_summary_modal
    end

    e.run_step 'Record another Processing fee for the commercials as Vendor' do
      @second_payment = {
        'UTR Number' => "UTR#{DateTime.now.to_time.to_i}#{rand(1..999)}",
        'Date of Payment' => Date.today.strftime('%d-%b-%Y')
      }
      @commercials_page.record_processing_fee(@second_payment, @payment_proof, true)
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['ProcessingFee']
    end

    e.run_step 'Verify Processing fee present in the Payment history as Vendor(Rejected and Pending payments)' do
      rejected_processing_fee = {
        'Payment Status' => 'Rejected',
        'Paid By' => @commercials_data['Name'],
        'Date of Payment' => @today_date,
        'UTR Number' => @processing_fee['UTR Number'],
        'Payment Type' => 'Processing Fee',
        'Amount' => '₹ 236'
      }
      expected_values = {
        'UTR Number' => rejected_processing_fee['UTR Number'],
        'Date of Invoice' => @today_date,
        'Processing Fee' => '₹ 200',
        'CGST @ 9%' => '₹ 18',
        'SGST @ 9%' => '₹ 18',
        'Total Amount Payable' => '₹ 236'
      }
      @common_pages.click_menu(MENU_PAYMENT_HISTORY)
      result = @payments_page.verify_transaction_in_payment_history(rejected_processing_fee.values)
      expect(result).to eq true
      @payments_page.view_detailed_breakup(expected_values['UTR Number'])
      expect(@transactions_page.verify_invoice_review_modal(expected_values)).to eq true
      @common_pages.close_modal
      pending_processing_fee = {
        'Payment Status' => 'Pending',
        'Paid By' => @commercials_data['Name'],
        'Date of Payment' => @today_date,
        'UTR Number' => @second_payment['UTR Number'],
        'Payment Type' => 'Processing Fee',
        'Amount' => '₹ 236'
      }
      expected_values = {
        'UTR Number' => pending_processing_fee['UTR Number'],
        'Date of Invoice' => @today_date,
        'Processing Fee' => '₹ 200',
        'CGST @ 9%' => '₹ 18',
        'SGST @ 9%' => '₹ 18',
        'Total Amount Payable' => '₹ 236'
      }
      result = @payments_page.verify_transaction_in_payment_history(pending_processing_fee.values)
      expect(result).to eq true
      @payments_page.view_detailed_breakup(expected_values['UTR Number'])
      expect(@transactions_page.verify_invoice_review_modal(expected_values)).to eq true
      expect(@transactions_page.invoice_preview_available?).to eq true
      @common_pages.close_modal
    end

    e.run_step 'Logout as Vendor' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Investor to verify newly recorded processing fee' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['investor']['email'],
                                     $conf['users']['investor']['password'])).to be true
    end

    e.run_step 'Verify new processing fee values in the modal' do
      @common_pages.click_menu(MENU_ANCHOR_LIST)
      @commercials_page.open_processing_fee_details(@commercials_data['Name'])
      sleep 2
      expected_values = {
        'UTR Number' => @second_payment['UTR Number'],
        'Date of Invoice' => @today_date,
        'Processing Fee' => '₹ 200',
        'CGST @ 9%' => '₹ 18',
        'SGST @ 9%' => '₹ 18',
        'Total Amount Payable' => '₹ 236'
      }
      expect(@transactions_page.verify_invoice_review_modal(expected_values)).to eq true
      expect(@transactions_page.invoice_preview_available?).to eq true
    end

    e.run_step 'Approve the new processing fee' do
      @tarspect_methods.click_button('Accept')
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['ProcessingFeeVerified']
    end

    e.run_step 'Verify Vendor commercials status after processing fee is accepted - Verified' do
      expected_values = {
        'Status' => 'Verified',
        'Name' => @commercials_data['Name'],
        'City' => @company_info['City'],
        'Geography' => @company_info['Geography'].downcase,
        'Sector' => @testdata['Company Info']['Sector'],
        'Relationship Age' => '-',
        'Turnover' => '0',
        'Live Transaction Count' => '1'
      }
      refresh_page
      @common_pages.navigate_to_anchor($conf['anchor_name'])
      @common_pages.select_program('Invoice Financing', 'Vendor')
      # @commercials_page.scroll_till_program(@commercials_data['Name'])
      expect(@commercials_page.vendor_program_details(@commercials_data['Name'])).to eq expected_values
    end

    e.run_step 'Verify Investor can do disbursements till the sanctioned limits' do
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @common_pages.click_transactions_tab(SHOW_ALL)
      @common_pages.navigate_to_transaction(@transaction_id)
      @disbursement_page.click_disbursement
      @disbursement_page.disburse(@payment_proof, @disbursement_details)
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['DisburseSuccess']
    end

    e.run_step 'Verify Investor cannot do disbursements once the sanctioned limit reached' do
      @inv_testdata2 = JSON.parse(ERB.new(@invoice_erb).result(binding))
      @inv_testdata2['Vendor Invoice Details']['Invoice Value'] = 10_000
      @invoice_value = @inv_testdata2['Vendor Invoice Details']['Invoice Value'].to_s.reverse.gsub(/(\d{3})(?=\d)/,
                                                                                                   '\\1,').reverse
      @transaction_2 = seed_transaction({
                                          actor: @vendor,
                                          counter_party: 'anchor',
                                          invoice_details: @inv_testdata2['Vendor Invoice Details'],
                                          invoice_file: @invoice_file,
                                          program: 'Invoice Financing - Vendor',
                                          program_group: 'invoice'
                                        })
      expect(@transaction_2).not_to include('Error while creating transaction')
      @calculate_hash[:invoice_value] = @inv_testdata2['Vendor Invoice Details']['Invoice Value']
      @transaction_values2 = calculate_transaction_values(@calculate_hash)
      @disbursement_details = {
        'UTR Number' => "UTR#{DateTime.now.to_time.to_i}#{rand(1..999)}",
        'Date of Payment' => Date.today.strftime('%d-%b-%Y'),
        'Disbursement Amount' => @transaction_values2[1],
        'Disbursement Account Number' => Faker::Number.number(digits: 10)
      }
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @common_pages.click_transactions_tab(SHOW_ALL)
      @common_pages.navigate_to_transaction(@transaction_2)
      @disbursement_page.click_disbursement
      @disbursement_page.disburse(@payment_proof, @disbursement_details)
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['MaxSanctionLimitReched']
      @common_pages.close_modal
    end

    e.run_step 'Verify Processing fee present in the Payment history(Rejected and Verifed payments)' do
      rejected_processing_fee = {
        'Payment Status' => 'Rejected',
        'Paid By' => @commercials_data['Name'],
        'Date of Payment' => @today_date,
        'UTR Number' => @processing_fee['UTR Number'],
        'Payment Type' => 'Processing Fee',
        'Amount' => '₹ 236'
      }
      expected_values = {
        'UTR Number' => rejected_processing_fee['UTR Number'],
        'Date of Invoice' => @today_date,
        'Processing Fee' => '₹ 200',
        'CGST @ 9%' => '₹ 18',
        'SGST @ 9%' => '₹ 18',
        'Total Amount Payable' => '₹ 236'
      }
      @common_pages.click_menu(MENU_PAYMENT_HISTORY)
      filter = {
        'Paid By' => "#{@commercials_data['Name']} - Vendor / Dealer",
        'date_range' => [
          { 'Date Range' => @today_date },
          { 'Date Range' => @today_date }
        ],
        'Type Of Payment' => 'Processing Fee'
      }
      @common_pages.apply_filter(filter)
      result = @payments_page.verify_transaction_in_payment_history(rejected_processing_fee.values)
      expect(result).to eq true
      @payments_page.view_detailed_breakup(expected_values['UTR Number'])
      expect(@transactions_page.verify_invoice_review_modal(expected_values)).to eq true
      @common_pages.close_modal
      verified_processing_fee = {
        'Payment Status' => 'Verified',
        'Paid By' => @commercials_data['Name'],
        'Date of Payment' => @today_date,
        'UTR Number' => @second_payment['UTR Number'],
        'Payment Type' => 'Processing Fee',
        'Amount' => '₹ 236'
      }
      expected_values = {
        'UTR Number' => verified_processing_fee['UTR Number'],
        'Date of Invoice' => @today_date,
        'Processing Fee' => '₹ 200',
        'CGST @ 9%' => '₹ 18',
        'SGST @ 9%' => '₹ 18',
        'Total Amount Payable' => '₹ 236'
      }
      result = @payments_page.verify_transaction_in_payment_history(verified_processing_fee.values)
      expect(result).to eq true
      @payments_page.view_detailed_breakup(expected_values['UTR Number'])
      expect(@transactions_page.verify_invoice_review_modal(expected_values)).to eq true
      expect(@transactions_page.invoice_preview_available?).to eq true
      @common_pages.close_modal
    end
  end

  it 'Commercials : Processing Fee with 0%', :processing_fee_zero do |e|
    @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
    @testdata['Commercials']['GSTN'] = "17#{@testdata['Commercials']['PAN']}#{Faker::Number.number(digits: 1)}Z#{Faker::Internet.user_name(specifier: 1..1).upcase}"
    @commercials_data = @testdata['Commercials']
    @company_info = @testdata['Company Info']

    e.run_step "Create a vendor #{@commercials_data['Entity Name']} and complete onboarding details" do
      expect(api_create_registered_channel_partner(@testdata)).to eq true
      @created_vendor << @commercials_data['Entity Name']
      @commercials_data['Name'] = @commercials_data['Entity Name']
    end

    e.run_step 'Approve the vendor as a platform team' do
      sleep 5
      expect(api_approve_all_docs_and_vendor(@testdata, 'mandatory_docs')).to eq true
    end

    e.run_step 'Login as Investor and verify new vendor is present for the anchor' do
      expected_values = {
        'Status' => '-',
        'Name' => @commercials_data['Name'],
        'City' => @company_info['City'],
        'Geography' => @company_info['Geography'].downcase,
        'Sector' => @testdata['Company Info']['Sector'],
        'Relationship Age' => '-',
        'Turnover' => '0',
        'Live Transaction Count' => '0'
      }
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['investor']['email'], $conf['users']['investor']['password'])).to be true
      @common_pages.click_menu(MENU_ANCHOR_LIST)
      @common_pages.navigate_to_anchor($conf['anchor_name'])
      @common_pages.select_program('Invoice Financing', 'Vendor')
      expect(@commercials_page.vendor_program_details(@commercials_data['Name'])).to eq expected_values
    end

    e.run_step 'verify enter amount field is disabled when PF is 0%' do
      @commercials_page.navigate_to_vendor(@commercials_data['Name'])
      @commercials_page.commercials_tab.click
      @tarspect_methods.click_button('Edit')
      @commercials_page.processing_fee_field.fill 0
      place_holder = @tarspect_methods.DYNAMIC_XPATH('input', '@placeholder', 'Enter Amount')
      expect(place_holder.get_attribute('disabled')).to eq 'true'
      @common_pages.close_modal
    end

    e.run_step 'Add vendor Commercials for New Vendor with PF 0%' do
      @vendor_commercials = {
        'Processing Fee' => 0,
        'Investor GSTN' => $conf['myntra_gstn'],
        'Sanction Limit' => 10_000,
        'Tenor' => "#{$conf['vendor_tenor']} days",
        'Yield' => '15',
        'Agreement Validity' => [get_todays_date(nil, '%d-%b-%Y'), get_todays_date(300, '%d-%b-%Y')],
        'Effective Date' => Date.today.strftime('%d-%b-%Y')
      }
      @commercials_page.add_vendor_commercials(@vendor_commercials)
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['VendorProgramAdded']
    end

    e.run_step 'Verify Vendor commercials status after adding Vendor program - Draft' do
      expected_values = {
        'Status' => 'Draft',
        'Name' => @commercials_data['Name'],
        'City' => @company_info['City'],
        'Geography' => @company_info['Geography'].downcase,
        'Sector' => @testdata['Company Info']['Sector'],
        'Relationship Age' => '-',
        'Turnover' => '0',
        'Live Transaction Count' => '0'
      }
      refresh_page
      @common_pages.click_back_button
      @commercials_page.scroll_till_program(@commercials_data['Name'])
      expect(@commercials_page.vendor_program_details(@commercials_data['Name'])).to eq expected_values
    end

    e.run_step 'Add Borrowing document' do
      @commercials_page.navigate_to_vendor(@commercials_data['Name'])
      @tarspect_methods.wait_for_loader_to_disappear(MAX_LOADER_TIME)
      @commercials_page.commercials_tab.click
      @commercials_page.upload_bd(@borrowing_document)
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['BDSigned']
    end

    e.run_step 'Submit the Commercials' do
      @tarspect_methods.click_button('Submit')
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq 'Commercial renewed successfully!'
    end

    e.run_step 'Verify Vendor commercials status post submitting the commercials with PF 0% - Verified' do
      expected_values = {
        'Status' => 'Verified',
        'Name' => @commercials_data['Name'],
        'City' => @company_info['City'],
        'Geography' => @company_info['Geography'].downcase,
        'Sector' => @testdata['Company Info']['Sector'],
        'Relationship Age' => '-',
        'Turnover' => '0',
        'Live Transaction Count' => '0'
      }
      refresh_page
      @common_pages.click_back_button
      @commercials_page.scroll_till_program(@commercials_data['Name'])
      expect(@commercials_page.vendor_program_details(@commercials_data['Name'])).to eq expected_values
    end

    e.run_step 'Logout as Investor' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step "Login as Vendor #{@commercials_data['Email']}" do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login(@commercials_data['Email'], $conf['users']['anchor']['password'])).to be true
      @tarspect_methods.fill_mobile_otp
      @common_pages.click_menu(MENU_ANCHOR_LIST)
      @common_pages.navigate_to_anchor($conf['anchor_name'])
      @common_pages.select_program('Invoice Financing', 'Vendor')
      investor_details = {
        'investor' => 'Kotak',
        'Sanction limit' => '10000',
        'Processing Fee' => '0.0 %',
        'Tenor' => "#{$conf['vendor_tenor']} Days",
        'Repayment Adjustment Order' => 'Interest - Principal - Charges'
      }
      expect(@common_pages.verify_interested_investors_details(investor_details)).to eq true
    end

    e.run_step 'Verify Submit and Proceed to Payment button is disabled since PF is 0%' do
      @common_pages.VENDOR_INVESTOR_ROW($conf['investor_name']).click
      @tarspect_methods.wait_for_loader_to_disappear(MAX_LOADER_TIME)
      expect(@tarspect_methods.DYNAMIC_LOCATOR('Submit & Proceed To Payment').get_attribute('disabled')).to eq 'true'
      @common_pages.close_modal
    end
  end

  it 'Commercials : Verify Credit Pull' do |e|
    @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
    @commercials_data = @testdata['Commercials']
    @company_info = @testdata['Company Info']
    @promoter_info = @testdata['Promoter Info']
    @commercials_data['GSTN'] = "#{Faker::Number.number(digits: 2)}#{@commercials_data['PAN']}#{Faker::Number.number(digits: 1)}Z#{Faker::Internet.user_name(specifier: 1..1).upcase}"
    e.run_step "Create a vendor #{@commercials_data['Entity Name']} and complete onboarding details" do
      expect(api_create_registered_channel_partner(@testdata)).to eq true
      @created_vendor << @commercials_data['Entity Name']
      @commercials_data['Name'] = @commercials_data['Entity Name']
    end

    e.run_step 'Approve the vendor as a platform team' do
      sleep 5
      expect(api_approve_all_docs_and_vendor(@testdata, 'mandatory_docs')).to eq true
    end

    e.run_step 'Login as Investor and verify new vendor is present for the anchor' do
      expected_values = {
        'Status' => '-',
        'Name' => @commercials_data['Name'],
        'City' => @company_info['City'],
        'Geography' => @company_info['Geography'].downcase,
        'Sector' => @testdata['Company Info']['Sector'], # vendor type is changed to sector.
        'Relationship Age' => '-', # relationship age is removed from onboarding hence we get - here
        'Turnover' => '0',
        'Live Transaction Count' => '0'
      }
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['investor']['email'], $conf['users']['investor']['password'])).to be true
      @common_pages.click_menu(MENU_ANCHOR_LIST)
      @common_pages.navigate_to_anchor($conf['anchor_name'])
      @common_pages.select_program('Invoice Financing', 'Vendor')
      expect(@commercials_page.vendor_program_details(@commercials_data['Name'])).to eq expected_values
    end

    e.run_step 'Download the file which has details for credit pull' do
      @commercials_page.navigate_to_vendor(@commercials_data['Name'], 'Details')
      @tarspect_methods.click_button('Details for Credit Pull ')
    end

    e.run_step 'Verify downloaded file data with Channel Partner Data' do
      expected_values = {
        company_name: @commercials_data['Entity Name'],
        company_pan: @commercials_data['PAN'],
        city: @company_info['City'],
        registered_address: @company_info['Registered Address'],
        promoter_name: @promoter_info['Full Name'],
        contact_number: @promoter_info['Phone Number'],
        dob: Date.parse(@promoter_info['DOB']).strftime('%d/%m/%Y'),
        gender: @promoter_info['Gender'],
        email_id: @promoter_info['Email Id'],
        address: @promoter_info['Address'],
        promoter_pan: @promoter_info['PAN']
      }
      filename = 'credit_pull'
      downloadedfile = @common_pages.check_for_file(filename, @download_path)
      credit_data = CSV.parse(File.read("#{@download_path}/#{downloadedfile}.csv"))

      actual_values = {
        company_name: credit_data[1][0],
        company_pan: credit_data[1][1],
        city: credit_data[1][2],
        registered_address: credit_data[1][3],
        promoter_name: credit_data[4][1],
        contact_number: credit_data[4][2],
        dob: credit_data[4][3],
        gender: credit_data[4][4],
        email_id: credit_data[4][5],
        address: credit_data[4][6],
        promoter_pan: credit_data[4][7]
      }
      expect(actual_values).to eq(expected_values)
    end
  end
end
