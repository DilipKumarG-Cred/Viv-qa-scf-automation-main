require './spec_helper'
describe 'Commercials: DD vendor assign', :scf, :onboarding, :dd_vendor_assign, :dd do
  before(:all) do
    @erb_file = File.read("#{Dir.pwd}/test-data/erb/commercials_data.erb")
    @borrowing_document = "#{Dir.pwd}/test-data/attachments/borrowing_document.pdf"
    @created_inv_vendors = []
    @created_dd_vendors = []
    @created_inv_dealers = []
  end

  before(:each) do
    @driver = Tarspect::Browser.new($conf['browser']).invoke
    @tarspect_methods = Common::Methods.new(@driver)
    @common_pages = Pages::CommonMethods.new(@driver)
    @commercials_page = Pages::Commercials.new(@driver)
    navigate_to($conf['base_url'])
  end

  after(:each) do |e| # Captures screenshot of the current page when failure happens
    snap_screenshot(e)
    quit_browser
  end

  after(:all) do
    delete_channel_partner('Vendor', @created_inv_vendors)
    delete_channel_partner('Vendor', @created_dd_vendors)
    delete_channel_partner('Dealer', @created_inv_dealers)
  end

  it 'Assign Invoice vendor(approved) to DD Vendor' do |e|
    @program_name = 'Invoice Financing - Vendor Program'
    @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
    @testdata['Commercials']['GSTN'] = "#{Faker::Number.number(digits: 2)}#{@testdata['Commercials']['PAN']}#{Faker::Number.number(digits: 1)}Z#{Faker::Internet.user_name(specifier: 1..1).upcase}"
    @commercials_data = @testdata['Commercials']
    @company_info = @testdata['Company Info']
    @promoter_info = @testdata['Promoter Info']
    @bank_details  = @testdata['Bank Details']
    @km_person_info = @testdata['Key Managing Person Info']
    @company_kyc_docs = @testdata['Documents']['Company KYC Documents']
    @promoter_kyc_docs = @testdata['Documents']['Promoter KYC Documents']
    @financial_docs = @testdata['Documents']['Financials']
    @bank_statements = @testdata['Documents']['Bank Statements']
    @gst_returns = @testdata['Documents']['GST Returns']
    @created_inv_vendors << @commercials_data['Entity Name']

    e.run_step 'Create a Invoice Vendor and complete onboarding details' do
      expect(api_create_registered_channel_partner(@testdata)).to eq true
      @commercials_data['Name'] = @commercials_data['Entity Name']
    end

    e.run_step 'Approve the Invoice Vendor as a platform team' do
      expect(api_approve_all_docs_and_vendor(@testdata)).to eq true
    end

    e.run_step 'Login as Anchor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['anchor']['email'], $conf['users']['anchor']['password'])).to be true
    end

    e.run_step 'Assign Invoice Vendor to DD with Bank details(YES)' do
      @assign_details = {
        'Program' => 'Dynamic Discounting - Vendor Program',
        'GST' => 40
      }
      @common_pages.click_menu(MENU_VENDORS)
      @common_pages.apply_list_filter({ 'Vendor Status ' => 'Approved'.upcase })
      @common_pages.search_program(@commercials_data['Name'])
      @commercials_page.assign_vendor(@commercials_data['Name'], @assign_details)
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['DDVendorAssignSucess']
      @created_dd_vendors << @commercials_data['Name']
    end

    e.run_step 'Verify DD vendor listed in vendor list as Anchor as Pending Registration' do
      @common_pages.apply_list_filter({ 'Vendor Status ' => 'Pending Registration'.upcase })
      @common_pages.search_program(@commercials_data['Name'])
      values = { name: @commercials_data['Name'], state: 'Pending Registration', field: 'Status', program: 'DYNAMIC DISCOUNTING' }
      expect(@commercials_page.get_vendor_details(values)).to eq 'Pending Registration'
    end

    e.run_step 'Verify Invoice vendor listed in vendor list as Anchor as Approved' do
      @common_pages.apply_list_filter({ 'Vendor Status ' => 'Approved'.upcase })
      @common_pages.search_program(@commercials_data['Name'])
      values = { name: @commercials_data['Name'], state: 'Approved', field: 'Status', program: 'INVOICE FINANCING' }
      expect(@commercials_page.get_vendor_details(values)).to eq 'Approved'
    end

    e.run_step 'Logout as Anchor' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as DD Vendor and verify whether it lands in transactions page(INV VENODR IS approved)' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login(@commercials_data['Email'], $conf['users']['anchor']['password'])).to be true
      expect(@common_pages.menu_available?('Profile')).to eq true
      expect(@common_pages.menu_available?('Anchor List')).to eq true
    end

    e.run_step 'Navigate to DD Onboarding details and verify completion progress' do
      @common_pages.click_menu('Profile')
      @commercials_page.select_onboarding_anchor_program($conf['anchor_name'])
      expect(@commercials_page.business_details_completed?).to eq(true), 'Business details are not completed'
      expect(@commercials_page.documents_completed?).to eq(true), 'Documents are not completed'
      expect(@commercials_page.get_progress_info).to eq '100.00% completed • All steps completed'
      expect(@tarspect_methods.BUTTON('Submit for Approval').get_attribute('disabled')).to eq nil
    end

    e.run_step 'Navigate to profile and verify Bank details info' do
      navigate_to($conf['base_url'])
      @common_pages.click_menu('Profile')
      @commercials_page.choose_program('Myntra', 'Vendor')
      expect(@common_pages.menu_available?('Bank Details')).to eq true
      bank_details = @commercials_page.get_details('Bank Details')
      expect(bank_details.include?(@bank_details['Bank Name'])).to eq true
      expect(bank_details.include?(@bank_details['IFSC Code'])).to eq true
      expect(bank_details.include?(@bank_details['Account Number'])).to eq true
    end

    e.run_step 'Verify company details populated from Invoice vendor program except Vendor Code' do
      company_details = @commercials_page.get_details('Company Information')
      expect(company_details.include?(@company_info['City'])).to eq true
      expect(company_details.include?(@company_info['Geography'])).to eq true
      expect(company_details.include?(@company_info['Phone Number'])).to eq true
      expect(company_details.include?(@commercials_data['PAN'])).to eq true
      expect(company_details.include?(@company_info['Entity Type'])).to eq true
    end
  end

  it 'Assign DD vendor(approved) to PO Dealer' do |e|
    @program_name = 'Dynamic Discounting - Vendor Program'
    @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
    @commercials_data = @testdata['DD Commercials']
    @commercials_data['Bank Details'] = 'true'
    @company_info = @testdata['Company Info']
    @promoter_info = @testdata['Promoter Info']
    @bank_details  = @testdata['Bank Details']
    @km_person_info = @testdata['Key Managing Person Info']
    @company_kyc_docs = @testdata['Documents']['Company KYC Documents']
    @promoter_kyc_docs = @testdata['Documents']['Promoter KYC Documents']
    @financial_docs = @testdata['Documents']['Financials']
    @bank_statements = @testdata['Documents']['Bank Statements']
    @gst_returns = @testdata['Documents']['GST Returns']
    @commercials_data['GSTN'] = "#{Faker::Number.number(digits: 2)}#{@commercials_data['PAN']}#{Faker::Number.number(digits: 1)}Z#{Faker::Internet.user_name(specifier: 1..1).upcase}"
    @created_dd_vendors << @commercials_data['Entity Name']

    e.run_step 'Login as Anchor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['anchor']['email'], $conf['users']['anchor']['password'])).to be true
    end

    e.run_step 'Invite new DD vendor with Bank details mandatory YES' do
      @common_pages.click_menu(MENU_VENDORS)
      @commercials_page.add_commercials(@commercials_data)
      @commercials_data['Name'] = @commercials_data['Entity Name']
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['VendorInvited']
    end

    e.run_step 'Logout Anchor' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Vendor activates from the accept invite link' do
      expect(@commercials_page.activate_channel_partner(@commercials_data['Email'])).to eq true
    end

    e.run_step 'Complete Onboarding details for DD Vendor' do
      sleep 10 # For Data reflection
      @vendor = @commercials_data['Email'].split('@')[0]
      set_cookies_api(@vendor, @commercials_data['Email'], $conf['users']['anchor']['password'])
      @company_info = {
        'City' => Faker::Address.city,
        'Geography' => ['East', 'West', 'South', 'North'].sample,
        'Sector' => ['Banks', 'Airlines'].sample,
        'UAM' => "D#{Faker::Number.number(digits: 11)}",
        'MSME/Non-MSME' => ['MSME', 'Non-MSME'].sample,
        'Entity Type' => ['Individual', 'Sole Proprietorship', 'Partnership', 'Private Limited', 'Llp', 'Limited Compay'].sample
      }
      resp = add_company_info(@vendor, @company_info)
      expect(resp[:code]).to eq(200), resp.to_s
      resp = add_promoter_info(@vendor, @promoter_info)
      expect(resp[:code]).to eq(200), resp.to_s
      resp = add_key_manager_info({
                                    anchor_actor: 'anchor',
                                    actor: @vendor,
                                    program: @commercials_data['Program'],
                                    km_person_info: @km_person_info
                                  })
      expect(resp[:code]).to eq(200), resp.to_s
      resp = add_bank_details({
                                anchor_actor: 'anchor',
                                actor: @vendor,
                                program: @commercials_data['Program'],
                                bank_details: @bank_details,
                                is_primary: true
                              })
      expect(resp[:code]).to eq(200), resp.to_s
      resp = submit_for_review(@vendor)
      expect(resp[:code]).to eq(200), resp.to_s
    end

    e.run_step 'Login as Anchor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['anchor']['email'], $conf['users']['anchor']['password'])).to be true
    end

    e.run_step 'Assign Invoice Vendor to DD with Bank details(YES)' do
      @assign_details = {
        'Program' => 'PO Financing - Dealer Program'
      }
      @common_pages.click_menu(MENU_VENDORS)
      @common_pages.search_program(@commercials_data['Name'])
      @commercials_page.assign_vendor(@commercials_data['Name'], @assign_details)
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['PODealerAssignSuccess']
      @created_inv_dealers << @commercials_data['Name']
    end

    e.run_step 'Verify DD vendor listed in vendor list as Anchor as Approved' do
      @common_pages.search_program(@commercials_data['Name'].downcase)
      values = { name: @commercials_data['Name'], state: 'Approved', field: 'Status', program: 'DYNAMIC DISCOUNTING' }
      expect(@commercials_page.get_vendor_details(values)).to eq 'Approved'
    end

    e.run_step 'Verify PO Dealer listed in Dealer list as Anchor as Pending Registration' do
      @common_pages.click_menu(MENU_DEALERS)
      @common_pages.search_program(@commercials_data['Name'].downcase)
      values = { name: @commercials_data['Name'], state: 'Pending Registration', field: 'Status', program: 'PO FINANCING' }
      expect(@commercials_page.get_vendor_details(values)).to eq 'Pending Registration'
    end

    e.run_step 'Logout as Anchor' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as PO Dealer and verify whether it lands in invite page(as documents are yet to be completed)' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login(@commercials_data['Email'], $conf['users']['anchor']['password'])).to be true
      expect(@common_pages.menu_available?('Profile')).to eq false
    end

    e.run_step 'Navigate to PO dealer onboarding details' do
      @commercials_page.select_onboarding_anchor_program($conf['anchor_name'], 'Pending Registration')
      sleep 5
      expect(@commercials_page.get_account_name).to eq @commercials_data['Name']
    end

    e.run_step 'Verify completion progress for the PO Dealer' do
      expect(@commercials_page.business_details_completed?).to eq false
      expect(@commercials_page.documents_completed?).to eq false
      expect(@commercials_page.get_progress_info).to eq '33.33% completed • 6  Steps left'
      expect(@tarspect_methods.BUTTON('Submit for Approval').get_attribute('disabled')).to eq 'true'
    end

    e.run_step 'Complete Onboarding details for the PO Dealer and submit for review' do
      @company_info = @testdata['Company Info']
      resp = add_company_info(@vendor, @company_info)
      expect(resp[:code]).to eq(200), resp.to_s
      resp = upload_onbaording_documents({
                                           actor: @vendor,
                                           type: 'mandatory_docs'
                                         })
      expect(resp).to eq(true), resp.to_s
      resp = submit_for_review(@vendor)
      expect(resp[:code]).to eq(200), resp.to_s
    end

    e.run_step 'Navigate to profile and verify Company details for PO Dealer program' do
      navigate_to($conf['base_url'])
      @common_pages.click_menu('Profile')
      @commercials_page.choose_program('Myntra', 'Dealer')
      company_details = @commercials_page.get_details('Company Information')
      expect(company_details.include?(@company_info['Entity Type'])).to eq true
      expect(@common_pages.menu_available?('Bank Details')).to eq true
    end

    e.run_step 'Navigate to profile and verify Company details are updated for DD Vendor program' do
      @commercials_page.choose_program('Myntra', 'Vendor', true)
      company_details = @commercials_page.get_details('Company Information')
      expect(company_details.include?(@company_info['Entity Type'])).to eq true
      expect(@common_pages.menu_available?('Bank Details')).to eq true
    end

    e.run_step 'Logout as Dealer' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Product and verify Vendor status - Awaiting platform verification for the dealer' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['product']['email'], $conf['users']['product']['password'])).to eq true
      @common_pages.click_menu(MENU_DEALERS)
      @common_pages.search_program(@commercials_data['Name'])
      values = { name: @commercials_data['Name'], state: 'Awaiting Platform Verification', field: 'Status', program: 'DYNAMIC DISCOUNTING' }
      expect(@commercials_page.get_vendor_details(values)).to eq 'Awaiting Platform Verification'
    end

    e.run_step 'Verify DD vendor listed in vendor list as Product as Approved' do
      @common_pages.click_menu(MENU_VENDORS)
      @common_pages.search_program(@commercials_data['Name'])
      values = { name: @commercials_data['Name'], state: 'Approved', field: 'Status', program: 'DYNAMIC DISCOUNTING' }
      expect(@commercials_page.get_vendor_details(values)).to eq 'Approved'
    end
  end
end
