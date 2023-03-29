require './spec_helper'
describe 'Commercials: Platform Verification', :scf, :commercials, :onboarding, :platform_verification, :mails do
  before(:all) do
    @anchor_actor = 'anchor'
    @investor_actor = 'investor'
    @investor_id = $conf['users'][@investor_actor]['id']
    @anchor_name = $conf['users'][@anchor_actor]['name']
    @anchor_id = $conf['users'][@anchor_actor]['id']
    @erb_file = File.read("#{Dir.pwd}/test-data/erb/commercials_data.erb")
    @borrowing_document = "#{Dir.pwd}/test-data/attachments/borrowing_document.pdf"
    @program_name = 'Invoice Financing - Vendor Program'
    @created_vendors = []
  end

  before(:each) do
    @driver = Tarspect::Browser.new($conf['browser']).invoke
    @tarspect_methods = Common::Methods.new(@driver)
    @common_pages = Pages::CommonMethods.new(@driver)
    @commercials_page = Pages::Commercials.new(@driver)
    @transactions_page = Pages::Trasactions.new(@driver)
    @disbursement_page = Pages::Disbursement.new(@driver)
    navigate_to($conf['base_url'])
    clear_cookies
  end

  after(:each) do |e|
    snap_screenshot(e)
    quit_browser
  end

  after(:all) do
    delete_channel_partner('Vendor', @created_vendors)
  end

  it 'Commercials : Platform Verification' do |e|
    @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
    @testdata['Commercials']['GSTN'] = "#{Faker::Number.number(digits: 2)}#{@testdata['Commercials']['PAN']}#{Faker::Number.number(digits: 1)}Z#{Faker::Internet.user_name(specifier: 1..1).upcase}"
    @commercials_data = @testdata['Commercials']
    @company_info = @testdata['Company Info']
    @promoter_info = @testdata['Promoter Info']
    @km_person_info = @testdata['Key Managing Person Info']
    @company_kyc_docs = @testdata['Documents']['Company KYC Documents']
    @promoter_kyc_docs = @testdata['Documents']['Promoter KYC Documents']
    @financial_docs = @testdata['Documents']['Financials']
    @bank_statements = @testdata['Documents']['Bank Statements']
    @gst_returns = @testdata['Documents']['GST Returns']
    @created_vendors << @commercials_data['Entity Name']

    @anchor_program_id = get_anchor_program_id('Invoice Financing', 'Vendor', @anchor_id)

    e.run_step 'Create a registered vendor' do
      expect(@commercials_page.create_registered_channel_partner(@testdata)).to eq true
      @commercials_data['Name'] = @commercials_data['Entity Name']
    end

    e.run_step 'Login as Platform and verify the status' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['product']['email'], $conf['users']['product']['password'])).to eq true
      @common_pages.click_menu(MENU_VENDORS)
      @common_pages.apply_list_filter({ 'Vendor Status ' => 'Awaiting Platform Verification'.upcase })
      values = { name: @commercials_data['Name'], state: 'Awaiting Platform Verification', field: 'Status', program: 'INVOICE FINANCING' }
      expect(@commercials_page.get_vendor_details(values)).to eq 'Awaiting Platform Verification'
    end

    e.run_step 'Verify Vendor details as Plaform - Company details' do
      @commercials_page.navigate_to_entity(@commercials_data['Name'], 'Details')
      expect(@transactions_page.verify_transaction_status('Awaiting Platform Verification')).to eq true
      company_details = @commercials_page.get_details('Company Information')
      expect(company_details.include?(@company_info['City'])).to eq true
      expect(company_details.include?(@company_info['Geography'])).to eq true
      expect(company_details.include?(@company_info['Phone Number'])).to eq true
      expect(company_details.include?(@commercials_data['PAN'])).to eq true
      expect(company_details.include?(@company_info['Entity Type'])).to eq true
    end

    e.run_step 'Verify Vendor details as Plaform - Promoter Info' do
      promoter_details = @commercials_page.get_details('Promoter Information')
      expect(promoter_details.include?(@promoter_info['Full Name'])).to eq true
      expect(promoter_details.include?(@promoter_info['Phone Number'])).to eq true
      expect(promoter_details.include?(@promoter_info['Shareholding'])).to eq true
    end

    e.run_step 'Verify Vendor details as Plaform - Key managing person Info' do
      km_person_details = @commercials_page.get_details('Key Management Information')
      expect(km_person_details.include?(@km_person_info['Full Name'])).to eq true
      expect(km_person_details.include?(@km_person_info['Phone Number'])).to eq true
      expect(km_person_details.include?(@km_person_info['Designation'])).to eq true
      expect(km_person_details.include?(@km_person_info['Email Id'])).to eq true
    end

    e.run_step 'Verify Vendor documents as Plaform - Company KYC documents' do
      @tarspect_methods.click_link('Documents')
      @tarspect_methods.click_link('Company KYC Documents')
      expect(@commercials_page.verify_uploaded_docs(@company_kyc_docs)).to eq true
      expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq true
    end

    e.run_step 'Verify Vendor documents as Plaform - Promoter KYC documents' do
      @tarspect_methods.click_link('Promoter KYC Documents')
      expect(@commercials_page.verify_uploaded_docs(@promoter_kyc_docs)).to eq true
      expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq true
    end

    e.run_step 'Verify Vendor documents as Plaform - Financials' do
      @tarspect_methods.click_link('Financials')
      expect(@commercials_page.verify_uploaded_docs(@financial_docs)).to eq true
      expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq true
    end

    e.run_step 'Verify Vendor documents as Plaform - Bank Statements' do
      @tarspect_methods.click_link('Bank Statements')
      expect(@commercials_page.verify_uploaded_docs(@bank_statements)).to eq true
      expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq true
    end

    e.run_step 'Verify Vendor documents as Plaform - GST Returns' do
      @tarspect_methods.click_link('GST Returns')
      expect(@commercials_page.verify_uploaded_docs(@gst_returns)).to eq true
      expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq true
    end

    e.run_step 'Approve Vendor documents as Plaform - Company KYC documents' do
      @tarspect_methods.click_link('Company KYC Documents')
      expect(@commercials_page.approve_doc(@company_kyc_docs)).to eq true
      expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq true
    end

    e.run_step 'Approve Vendor documents as Plaform - Promoter KYC documents' do
      @tarspect_methods.click_link('Promoter KYC Documents')
      expect(@commercials_page.approve_doc(@promoter_kyc_docs)).to eq true
      expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq true
    end

    e.run_step 'Approve Vendor documents as Plaform - Financials' do
      @tarspect_methods.click_link('Financials')
      expect(@commercials_page.approve_doc(@financial_docs)).to eq true
      expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq true
    end

    e.run_step 'Approve Vendor documents as Plaform - Bank Statements' do
      @tarspect_methods.click_link('Bank Statements')
      expect(@commercials_page.approve_doc(@bank_statements)).to eq true
      expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq true
    end

    e.run_step 'Approve Vendor documents as Plaform - GST Returns' do
      @tarspect_methods.click_link('GST Returns')
      expect(@commercials_page.approve_doc(@gst_returns)).to eq true
      expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq true
    end

    e.run_step 'Verify status after all document verifications as platform team' do
      expect(@transactions_page.verify_transaction_status('Kyc Verified')).to eq true
    end

    e.run_step 'Approve the Vendor as Platform' do
      @transactions_page.approve_transaction
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['ReviewSubmitted']
    end

    e.run_step 'Verify status after approval as platform team' do
      expect(@transactions_page.verify_transaction_status('Approved')).to eq true
    end

    e.run_step 'Logout as Platform' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Anchor and verify Vendor status' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users'][@anchor_actor]['email'], $conf['users'][@anchor_actor]['password'])).to be true
      @common_pages.click_menu(MENU_VENDORS)
      @common_pages.apply_list_filter({ 'Vendor Status ' => 'Approved'.upcase })
      @common_pages.search_program(@commercials_data['Name'])
      values = { name: @commercials_data['Name'], state: 'Approved', field: 'Status', program: 'INVOICE FINANCING' }
      expect(@commercials_page.get_vendor_details(values)).to eq 'Approved'
    end

    e.run_step 'Logout as Anchor' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Investor and verify Vendor status' do
      expected_values = {
        'Status' => '-',
        'Name' => @commercials_data['Name'],
        'City' => @company_info['City'],
        'Geography' => @company_info['Geography'].downcase,
        'Vendor Type' => '-',
        'Relationship Age' => '0 Days',
        'Turnover' => '0',
        'Live Transaction Count' => '0'
      }
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users'][@investor_actor]['email'], $conf['users'][@investor_actor]['password'])).to be true
      @common_pages.click_menu(MENU_ANCHOR_LIST)
      @common_pages.navigate_to_anchor($conf['anchor_name'])
      @common_pages.select_program('Invoice Financing', 'Vendor')
      sleep 1
      expect(@commercials_page.vendor_program_details(@commercials_data['Name'])).to eq expected_values
    end

    e.run_step 'Verify Vendor details as Investor - Company details' do
      @commercials_page.navigate_to_vendor(@commercials_data['Name'])
      expect(@transactions_page.verify_transaction_status('Approved')).to eq(true), "#{@commercials_data['Name']} is not in approved state"
      company_details = @commercials_page.get_details('Company Information')
      expect(company_details.include?(@company_info['City'])).to eq true
      expect(company_details.include?(@company_info['Geography'])).to eq true
      expect(company_details.include?(@company_info['Phone Number'])).to eq true
      expect(company_details.include?(@commercials_data['PAN'])).to eq true
      expect(company_details.include?(@company_info['Entity Type'])).to eq true
    end

    e.run_step 'Verify Vendor details as Investor - Promoter Info' do
      promoter_details = @commercials_page.get_details('Promoter Information')
      expect(promoter_details.include?(@promoter_info['Full Name'])).to eq true
      expect(promoter_details.include?(@promoter_info['Phone Number'])).to eq true
      expect(promoter_details.include?(@promoter_info['Shareholding'])).to eq true
    end

    e.run_step 'Verify Vendor details as Investor - Key managing person Info' do
      km_person_details = @commercials_page.get_details('Key Management Information')
      expect(km_person_details.include?(@km_person_info['Full Name'])).to eq true
      expect(km_person_details.include?(@km_person_info['Phone Number'])).to eq true
      expect(km_person_details.include?(@km_person_info['Designation'])).to eq true
      expect(km_person_details.include?(@km_person_info['Email Id'])).to eq true
    end

    e.run_step 'Verify Vendor documents as Investor - Company KYC documents' do
      @tarspect_methods.click_link('Documents')
      @tarspect_methods.click_link('Company KYC Documents')
      expect(@commercials_page.verify_uploaded_docs(@company_kyc_docs)).to eq true
      expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq true
    end

    e.run_step 'Verify Vendor documents as Investor - Promoter KYC documents' do
      @tarspect_methods.click_link('Promoter KYC Documents')
      expect(@commercials_page.verify_uploaded_docs(@promoter_kyc_docs)).to eq true
      expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq true
    end

    e.run_step 'Verify Vendor documents as Investor - Financials' do
      @tarspect_methods.click_link('Financials')
      expect(@commercials_page.verify_uploaded_docs(@financial_docs)).to eq true
      expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq true
    end

    e.run_step 'Verify Vendor documents as Investor - Bank Statements' do
      @tarspect_methods.click_link('Bank Statements')
      expect(@commercials_page.verify_uploaded_docs(@bank_statements)).to eq true
      expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq true
    end

    e.run_step 'Verify Vendor documents as Investor - GST Returns' do
      @tarspect_methods.click_link('GST Returns')
      expect(@commercials_page.verify_uploaded_docs(@gst_returns)).to eq true
      expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq true
    end

    e.run_step 'Add vendor Commercials for New vendor' do
      @vendor_commercials = {
        'Processing Fee' => 2,
        'Investor GSTN' => @commercials_data['GSTN'],
        'Sanction Limit' => 10000,
        'Tenor' => '60 days',
        'Yield' => '15',
        'Agreement Validity' => [get_todays_date(nil, '%d-%b-%Y'), get_todays_date(300, '%d-%b-%Y')],
        'Effective Date' => Date.today.strftime('%d-%b-%Y')
      }
      @commercials_page.add_vendor_commercials(@vendor_commercials)
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['VendorProgramAdded']
    end

    e.run_step 'Verify Vendor commercials status after adding vendor program - Draft' do
      resp = verify_vendor_present(@anchor_program_id, @investor_id, @commercials_data['Name'], actor: @investor_actor)
      expect(resp[:status]).to eq('Draft')
      expect(resp[:name]).to eq(@commercials_data['Name'])
      expect(resp[:live_transaction_count]).to eq(0)
      expect(resp[:vendor_status]).to eq('approved')
    end

    e.run_step 'Logout as Investor' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Vendor and approve commercials' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login(@commercials_data['Email'], $conf['users'][@anchor_actor]['password'])).to be true
      @common_pages.click_menu(MENU_ANCHOR_LIST)
      @common_pages.navigate_to_anchor($conf['anchor_name'])
      @common_pages.select_program('Invoice Financing', 'Vendor')
      investor_details = {
        'investor' => 'Kotak',
        'Sanction limit' => '10000',
        'Processing Fee' => '2.0 %',
        'Tenor' => '60 Days',
        # "Agreement Validity"=>"19 Apr, 2021 - 15 Oct, 2021",
        'Repayment Adjustment Order' => 'Interest - Principal - Charges'
      }
      expect(@common_pages.verify_interested_investors_details(investor_details)).to eq true
      @common_pages.VENDOR_INVESTOR_ROW($conf['investor_name']).click
      @commercials_page.upload_bd(@borrowing_document)
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['BDSigned']
      @common_pages.close_modal
    end

    e.run_step 'Verify Processing fee details for the commercials' do
      expected_summary = {
        'Processing fee' => '₹200',
        'CGST Fee (9%)' => '₹18',
        'IGST Fee (18%)' => '₹0',
        'SGST Fee (9%)' => '₹18',
        'Processing Fee Payable' => '₹236'
      }
      refresh_page
      @tarspect_methods.click_button('Record Payment')
      @tarspect_methods.click_button('Submit & Proceed To Payment')
      sleep 1
      expect(@disbursement_page.verify_summary_details(expected_summary)).to eq true
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

    e.run_step 'Logout as Vendor' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Investor and verify processing fee' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users'][@investor_actor]['email'], $conf['users'][@investor_actor]['password'])).to be true
    end

    e.run_step 'Verify Vendor status - Pending' do
      resp = verify_vendor_present(@anchor_program_id, @investor_id, @commercials_data['Name'], actor: @investor_actor)
      expect(resp[:status]).to eq('Pending')
      expect(resp[:name]).to eq(@commercials_data['Name'])
      expect(resp[:live_transaction_count]).to eq(0)
      expect(resp[:vendor_status]).to eq('approved')
    end

    e.run_step 'Verify Processing fee for the commercials' do
      @common_pages.click_menu(MENU_ANCHOR_LIST)
      @commercials_page.verify_processing_fee(@commercials_data['Name'])
      @tarspect_methods.click_button('Accept')
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['ProcessingFeeVerified']
    end

    e.run_step 'Verify Vendor status - Approved' do
      resp = verify_vendor_present(@anchor_program_id, @investor_id, @commercials_data['Name'], actor: @investor_actor)
      expect(resp[:status]).to eq('Verified')
      expect(resp[:name]).to eq(@commercials_data['Name'])
      expect(resp[:live_transaction_count]).to eq(0)
      expect(resp[:vendor_status]).to eq('approved')
    end
  end
end
