require './spec_helper'
describe 'PO Financing: Assign to other programs', :scf, :commercials, :onboarding, :mails do
  before(:all) do
    @erb_file = File.read("#{Dir.pwd}/test-data/erb/commercials_data.erb")
    @borrowing_document = "#{Dir.pwd}/test-data/attachments/borrowing_document.pdf"
    @created_vendors = []
    @created_dealers = []
    @po_vendors = []
    delete_channel_partner('Vendor', [['Maruthi Motors', 'PO FINANCING']], 'grn_anchor')
  end

  before(:each) do
    @driver = Tarspect::Browser.new($conf['browser']).invoke
    @tarspect_methods = Common::Methods.new(@driver)
    @common_pages = Pages::CommonMethods.new(@driver)
    @commercials_page = Pages::Commercials.new(@driver)
    @transactions_page = Pages::Trasactions.new(@driver)
    @disbursement_page = Pages::Disbursement.new(@driver)
  end

  after(:each) do |e| # Captures screenshot of the current page when failure happens
    snap_screenshot(e)
    quit_browser
  end

  after(:all) do
    delete_channel_partner('Vendor', @created_vendors)
    delete_channel_partner('Dealer', @created_dealers)
    delete_channel_partner('Vendor', @po_vendors, 'grn_anchor')
    delete_channel_partner('Vendor', [['Maruthi Motors', 'PO FINANCING']], 'grn_anchor')
  end

  it 'PO Commercials: Assign PO Vendor to Invoice Programs' do |e|
    @program_name = 'PO Financing - Vendor Program'
    @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
    @commercials_data = @testdata['Commercials']
    @company_info = @testdata['Company Info']
    @promoter_info = @testdata['Promoter Info']
    @km_person_info = @testdata['Key Managing Person Info']
    @company_kyc_docs = @testdata['Documents']['Company KYC Documents']
    @promoter_kyc_docs = @testdata['Documents']['Promoter KYC Documents']
    @financial_docs = @testdata['Documents']['Financials']
    @bank_statements = @testdata['Documents']['Bank Statements']
    @gst_returns = @testdata['Documents']['GST Returns']
    @commercials_data['GSTN'] = "#{Faker::Number.number(digits: 2)}#{@commercials_data['PAN']}#{Faker::Number.number(digits: 1)}Z#{Faker::Internet.user_name(specifier: 1..1).upcase}"
    @created_vendors << @commercials_data['Entity Name']

    e.run_step 'Login as Anchor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['anchor']['email'], $conf['users']['anchor']['password'])).to be true
    end

    e.run_step 'Add a PO vendor' do
      @common_pages.click_menu(MENU_VENDORS)
      @commercials_page.add_commercials(@commercials_data)
      @commercials_data['Name'] = @commercials_data['Entity Name']
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['VendorInvited']
    end

    e.run_step 'Verify PO vendor can be assigned Invoice vendor(Same entity type conflict)' do
      assign_details = {
        'Program' => 'Invoice Financing - Vendor Program',
        'Recommended Limit' => 40,
        'ERP Vendor Code' => Faker::Internet.user_name(specifier: 8..12).upcase
      }
      @commercials_page.assign_vendor(@commercials_data['Name'], assign_details)
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq('Successfully assigned under Invoice Financing - Vendor Program')
    end

    e.run_step 'Verify PO vendor cannot be assigned PO vendor(Same program conflict)' do
      assign_details = {
        'Program' => 'PO Financing - Vendor Program',
        'Recommended Limit' => 40,
        'ERP Vendor Code' => Faker::Internet.user_name(specifier: 8..12).upcase
      }
      @commercials_page.assign_vendor(@commercials_data['Name'], assign_details)
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq("#{@commercials_data['Name']} is already associated in PO-VENDOR program")
    end

    e.run_step 'Verify PO vendor can be assigned to PO dealer program' do
      assign_details = {
        'Program' => 'PO Financing - Dealer Program',
        'Recommended Limit' => 40,
        'ERP Vendor Code' => Faker::Internet.user_name(specifier: 8..12).upcase
      }
      @commercials_page.assign_vendor(@commercials_data['Name'], assign_details)
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['PODealerAssignSuccess']
      @created_dealers << @commercials_data['Name']
      @common_pages.click_menu(MENU_DEALERS)
      expect(@commercials_page.entity_listed?(@commercials_data['Name'])).to eq true
    end
  end

  it 'Invoice Commercials: Assign Invoice Vendor to PO Programs' do |e|
    @program_name = 'Invoice Financing - Vendor Program'
    @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
    @commercials_data = @testdata['Commercials']
    @company_info = @testdata['Company Info']
    @promoter_info = @testdata['Promoter Info']
    @km_person_info = @testdata['Key Managing Person Info']
    @company_kyc_docs = @testdata['Documents']['Company KYC Documents']
    @promoter_kyc_docs = @testdata['Documents']['Promoter KYC Documents']
    @financial_docs = @testdata['Documents']['Financials']
    @bank_statements = @testdata['Documents']['Bank Statements']
    @gst_returns = @testdata['Documents']['GST Returns']
    @commercials_data['GSTN'] = "#{Faker::Number.number(digits: 2)}#{@commercials_data['PAN']}#{Faker::Number.number(digits: 1)}Z#{Faker::Internet.user_name(specifier: 1..1).upcase}"
    @created_vendors << @commercials_data['Entity Name']

    e.run_step 'Login as Anchor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['anchor']['email'], $conf['users']['anchor']['password'])).to be true
    end

    e.run_step 'Add a Invoice vendor' do
      @common_pages.click_menu(MENU_VENDORS)
      @commercials_page.add_commercials(@commercials_data)
      @commercials_data['Name'] = @commercials_data['Entity Name']
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['VendorInvited']
    end

    e.run_step 'Verify Invoice vendor can be assigned PO vendor(Same entity type conflict)' do
      assign_details = {
        'Program' => 'PO Financing - Vendor Program',
        'Recommended Limit' => 40,
        'ERP Vendor Code' => Faker::Internet.user_name(specifier: 8..12).upcase
      }
      @commercials_page.assign_vendor(@commercials_data['Name'], assign_details)
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq('Successfully assigned under PO Financing - Vendor Program')
    end

    e.run_step 'Verify Invoice vendor cannot be assigned Invoice vendor(Same program conflict)' do
      assign_details = {
        'Program' => 'Invoice Financing - Vendor Program',
        'Recommended Limit' => 40,
        'ERP Vendor Code' => Faker::Internet.user_name(specifier: 8..12).upcase
      }
      @commercials_page.assign_vendor(@commercials_data['Name'], assign_details)
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq("#{@commercials_data['Name']} is already associated in INVOICE-VENDOR program")
    end

    e.run_step 'Verify Invoice vendor can be assigned to PO dealer program' do
      assign_details = {
        'Program' => 'PO Financing - Dealer Program',
        'Recommended Limit' => 40,
        'ERP Vendor Code' => Faker::Internet.user_name(specifier: 8..12).upcase
      }
      @commercials_page.assign_vendor(@commercials_data['Name'], assign_details)
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['PODealerAssignSuccess']
      @created_dealers << @commercials_data['Name']
      @common_pages.click_menu(MENU_DEALERS)
      expect(@commercials_page.entity_listed?(@commercials_data['Name'])).to eq true
    end
  end
end
