require './spec_helper'
describe 'Commercials: Vendor Reject', :scf, :commercials, :onboarding, :vendor_reject, :mails do
  before(:all) do
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
    navigate_to($conf['base_url'])
    delete_channel_partner('Vendor', @created_vendors)
    clear_cookies
  end

  after(:each) do |e| # Captures screenshot of the current page when failure happens
    snap_screenshot(e)
    quit_browser
  end

  after(:all) do
    delete_channel_partner('Vendor', @created_vendors)
  end

  it 'Commercials : Reject Documents, Reject Vendor by Platform', :document_reject do |e|
    @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
    @testdata['Commercials']['GSTN'] = "#{Faker::Number.number(digits: 2)}#{@testdata['Commercials']['PAN']}#{Faker::Number.number(digits: 1)}Z#{Faker::Internet.user_name(specifier: 1..1).upcase}"
    @commercials_data = @testdata['Commercials']
    @company_info = @testdata['Company Info']
    @promoter_info = @testdata['Promoter Info']
    @km_person_info = @testdata['Key Managing Person Info']
    @mandatory_docs = @testdata['Documents']['Mandatory Documents']
    @company_kyc_docs = @testdata['Documents']['Company KYC Documents']
    @mandatory_company_kyc_documents = [@company_kyc_docs[1], @company_kyc_docs[2]]
    @mandatory_company_promoter_documents = ['Promoter 1 - Promoter PAN', 'Promoter 1 - Promoter Aadhaar']
    @promoter_kyc_docs = @testdata['Documents']['Promoter KYC Documents']
    @financial_docs = @testdata['Documents']['Financials']
    @bank_statements = @testdata['Documents']['Bank Statements']
    @gst_returns = @testdata['Documents']['GST Returns']
    @created_vendors << @commercials_data['Entity Name']

    e.run_step 'Create a registered vendor' do
      expect(api_create_registered_channel_partner(@testdata)).to eq true
      @commercials_data['Name'] = @commercials_data['Entity Name']
    end

    e.run_step 'Login as Platform and navigate to vendor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['product']['email'], $conf['users']['product']['password'])).to eq true
      @common_pages.click_menu(MENU_VENDORS)
      @common_pages.apply_list_filter({ 'Vendor Status ' => 'Awaiting Platform Verification'.upcase })
      @commercials_page.navigate_to_entity(@commercials_data['Name'], 'Details')
    end

    e.run_step 'Reject Vendor documents as Plaform - Company KYC documents' do
      @tarspect_methods.click_link('Documents')
      @tarspect_methods.click_link('Company KYC Documents')
      expect(@commercials_page.reject_and_verify_mail(@commercials_data['Name'], @mandatory_docs[0], @testdata['Reject Reason'])).to eq true
      expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq true
    end

    e.run_step 'Logout as Platform' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Vendor and re-upload documents' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login(@commercials_data['Email'], $conf['users']['anchor']['password'])).to be true
    end

    e.run_step 'Re-Upload Company KYC docs' do
      @tarspect_methods.fill_mobile_otp
      @common_pages.click_menu('Documents')
      expect(@commercials_page.upload_docs(@mandatory_docs[0], "#{@mandatory_docs[0]} reupload")).to eq true
      expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq true
    end

    e.run_step 'Logout as Vendor' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Platform and approve documents' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['product']['email'], $conf['users']['product']['password'])).to be true
      @common_pages.click_menu(MENU_VENDORS)
      @common_pages.apply_list_filter({ 'Vendor Status ' => 'Processing'.upcase })
      @commercials_page.navigate_to_entity(@commercials_data['Name'], 'Details')
    end

    e.run_step 'Verify client documents after submit for approval - Company KYC documents' do
      @tarspect_methods.click_link('Documents')
      @tarspect_methods.click_link('Company KYC Documents')
      @tarspect_methods.wait_for_loader_to_disappear(MIN_LOADER_TIME)
      expect(@commercials_page.approve_doc(@mandatory_company_kyc_documents)).to eq true
      expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq true
    end
    e.run_step 'Verify client documents after submit for approval - Promoter KYC documents' do
      @tarspect_methods.click_link('Promoter KYC Documents')
      expect(@commercials_page.approve_doc(@mandatory_company_promoter_documents)).to eq true
      expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq true
    end

    e.run_step 'Reject Vendor after KYC verified' do
      @commercials_page.reject_vendor(@testdata['Reject Reason'])
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['ReviewSubmitted']
      expect(@transactions_page.verify_transaction_status('Rejected')).to eq true
    end

    e.run_step 'Logout as Platform' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Anchor and verify status' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['anchor']['email'], $conf['users']['anchor']['password'])).to be true
      @common_pages.click_menu(MENU_VENDORS)
      @common_pages.apply_list_filter({ 'Vendor Status ' => 'Rejected'.upcase })
      values = { name: @commercials_data['Name'], state: 'Rejected', field: 'Status', program: 'INVOICE FINANCING' }
      expect(@commercials_page.get_vendor_details(values)).to eq 'Rejected'
    end
  end
end
