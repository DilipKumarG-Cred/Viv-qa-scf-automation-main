require './spec_helper'
describe 'Dynamic Discounting: Vendor Onboarding', :scf, :commercials, :onboarding, :dd_vendor_onboarding, :dd do
  before(:all) do
    @erb_file = File.read("#{Dir.pwd}/test-data/erb/commercials_data.erb")
    @borrowing_document = "#{Dir.pwd}/test-data/attachments/borrowing_document.pdf"
    @program_name = 'Dynamic Discounting - Vendor Program'
    @created_vendors = []
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
  end

  it 'DD Commercials: Vendor with Bank details mandatory NO' do |e|
    @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
    @commercials_data = @testdata['DD Commercials']
    @commercials_data['Bank Details'] = 'false'
    @promoter_info = @testdata['Promoter Info']
    @km_person_info = @testdata['Key Managing Person Info']
    @commercials_data['GSTN'] = "#{Faker::Number.number(digits: 2)}#{@commercials_data['PAN']}#{Faker::Number.number(digits: 1)}Z#{Faker::Internet.user_name(specifier: 1..1).upcase}"
    @created_vendors << @commercials_data['Entity Name']

    e.run_step 'Login as Anchor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['anchor']['email'], $conf['users']['anchor']['password'])).to be true
    end

    e.run_step 'Invite new DD vendor with Bank details mandatory NO' do
      @common_pages.click_menu(MENU_VENDORS)
      @commercials_page.add_commercials(@commercials_data)
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['VendorInvited']
      @commercials_data['Name'] = @commercials_data['Entity Name']
      @common_pages.apply_list_filter({ 'Vendor Status ' => 'Awaiting Vendor Acceptance'.upcase })
      @common_pages.search_program(@commercials_data['Name'])
      values = { name: @commercials_data['Name'], state: 'Awaiting Vendor Acceptance', field: 'Status', program: 'DYNAMIC DISCOUNTING' }
      expect(@commercials_page.get_vendor_details(values)).to eq 'Awaiting Vendor Acceptance'
    end

    e.run_step 'Logout Anchor' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Vendor activates from the accept invite link' do
      expect(@commercials_page.activate_channel_partner(@commercials_data['Email'])).to eq true
    end

    e.run_step 'Login as Vendor' do
      sleep 10 # For Data reflection
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login(@commercials_data['Email'], $conf['users']['anchor']['password'])).to be true
    end

    e.run_step 'Verify Completion percentage for Mandatory Bank details NO(before filling any data)' do
      @commercials_page.select_onboarding_anchor_program($conf['anchor_name'])
      expect(@commercials_page.get_account_name).to eq @commercials_data['Name']
      expect(@commercials_page.get_promoter_info.include?('1 Promoter Info required')).to eq true
      expect(@commercials_page.get_key_managing_info.include?('1 Key managing person required')).to eq true
      expect(@tarspect_methods.BUTTON('Submit for Approval').get_attribute('disabled')).to eq 'true'
      expect(@commercials_page.get_progress_info).to eq '0.00% completed • 3  Steps left'
    end

    e.run_step 'Update Company info and verify profile completion percentage' do
      @company_info = {
        'City' => Faker::Address.city,
        'Geography' => ['East', 'West', 'South', 'North'].sample,
        'Sector' => ['Banks', 'Airlines'].sample
      }
      @commercials_page.update_onboarding_info('Company Info', @company_info)
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['CompanyDetailsSaved']
      expect(@tarspect_methods.BUTTON('Submit for Approval').get_attribute('disabled')).to eq 'true'
      expect(@commercials_page.get_progress_info).to eq '33.33% completed • 2  Steps left'
    end

    e.run_step 'Update Promoter info and verify profile completion percentage' do
      @commercials_page.update_onboarding_info('Promoter Information', @promoter_info)
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['PromoterAdded']
      expect(@tarspect_methods.BUTTON('Submit for Approval').get_attribute('disabled')).to eq 'true'
      expect(@commercials_page.get_progress_info).to eq '66.67% completed • 1  Steps left'
    end

    e.run_step 'Update Key managing person info and verify profile completion percentage' do
      @commercials_page.update_onboarding_info('Key Managing Person Information', @km_person_info)
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['KMPersonAdded']
      expect(@commercials_page.business_details_completed?).to eq(true), 'Business details are not completed'
    end

    e.run_step 'Verify 100% completion of mandatory onboarding details(without bank details)' do
      expect(@commercials_page.get_progress_info).to eq '100.00% completed • All steps completed'
      expect(@tarspect_methods.BUTTON('Submit for Approval').get_attribute('disabled')).to eq nil
    end

    e.run_step 'Verify Submit for approval for DD vendor onboarding' do
      @tarspect_methods.click_button('Submit for Approval')
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['SubmitForApproval']
      expect(@commercials_page.summary_text.include?($notifications['ProfileSummaryModal'])).to eq true
      @tarspect_methods.click_button('close')
    end

    e.run_step 'Verify Vendor lands on transactions list page once completed all onboarding details' do
      navigate_to($conf['base_url'])
      @tarspect_methods.wait_for_circular_to_disappear(MAX_LOADER_TIME)
      @tarspect_methods.wait_for_loader_to_disappear(MAX_LOADER_TIME)
      expect(@common_pages.menu_available?('Profile')).to eq true
      expect(@common_pages.menu_available?('Anchor List')).to eq true
    end

    e.run_step 'Navigate to profile and ensure no Bank details tab if no details provided' do
      @common_pages.click_menu('Profile')
      expect(@common_pages.menu_available?('Bank Details')).to eq true
      bank_details = @commercials_page.get_details('Bank Details')
      expect(bank_details).to eq ''
    end

    e.run_step 'Logout as Vendor' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Anchor and verify vendor status' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['anchor']['email'], $conf['users']['anchor']['password'])).to be true
      @common_pages.click_menu(MENU_VENDORS)
      @common_pages.apply_list_filter({ 'Vendor Status ' => 'Approved'.upcase })
      @common_pages.search_program(@commercials_data['Name'])
      values = { name: @commercials_data['Name'], state: 'Approved', field: 'Status', program: 'DYNAMIC DISCOUNTING' }
      expect(@commercials_page.get_vendor_details(values)).to eq 'Approved'
    end

    e.run_step 'Navigate to vendor profile and ensure no Bank details tab if no details provided' do
      @commercials_page.navigate_to_entity(@commercials_data['Name'])
      expect(@common_pages.menu_available?('Bank Details')).to eq true
      bank_details = @commercials_page.get_details('Bank Details')
      expect(bank_details).to eq ''
    end

    e.run_step 'Remove DD vendor' do
      @common_pages.click_menu(MENU_VENDORS)
      @common_pages.search_program(@commercials_data['Name'])
      @commercials_page.remove_vendor_from_more_options('Vendors', @commercials_data['Name'])
      expect(@commercials_page.vendor_removed_msg).to eq $notifications['VendorRemoved']
      expect(@commercials_page.entity_listed?(@commercials_data['Name'])).to eq false
    end

    e.run_step 'Verify Vendor removed mail sent to vendor' do
      expect(@commercials_page.vendor_removed_mail(@commercials_data['Name'])).to eq true
    end

    e.run_step 'Logout as Anchor' do
      expect(@common_pages.logout).to eq true
    end
  end

  it 'DD Commercials: Vendor with Bank details mandatory YES' do |e|
    @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
    @commercials_data = @testdata['DD Commercials']
    @commercials_data['Bank Details'] = 'true'
    @promoter_info = @testdata['Promoter Info']
    @km_person_info = @testdata['Key Managing Person Info']
    @bank_details = @testdata['Bank Details']
    @commercials_data['GSTN'] = "#{Faker::Number.number(digits: 2)}#{@commercials_data['PAN']}#{Faker::Number.number(digits: 1)}Z#{Faker::Internet.user_name(specifier: 1..1).upcase}"
    @created_vendors << @commercials_data['Entity Name']

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

    e.run_step 'Login as Vendor' do
      sleep 10 # For Data reflection
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login(@commercials_data['Email'], $conf['users']['anchor']['password'])).to be true
    end

    e.run_step 'Verify Completion percentage for Mandatory Bank details YES(before filling any data)' do
      @commercials_page.select_onboarding_anchor_program($conf['anchor_name'])
      expect(@commercials_page.get_account_name).to eq @commercials_data['Name']
      expect(@commercials_page.get_promoter_info.include?('1 Promoter Info required')).to eq true
      expect(@commercials_page.get_key_managing_info.include?('1 Key managing person required')).to eq true
      expect(@tarspect_methods.BUTTON('Submit for Approval').get_attribute('disabled')).to eq 'true'
      expect(@commercials_page.get_progress_info).to eq '0.00% completed • 4  Steps left'
    end

    e.run_step 'Update Company info and verify profile completion percentage' do
      @company_info = {
        'City' => Faker::Address.city,
        'Geography' => ['East', 'West', 'South', 'North'].sample,
        'Sector' => ['Banks', 'Airlines'].sample
      }
      @commercials_page.update_onboarding_info('Company Info', @company_info)
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['CompanyDetailsSaved']
      expect(@tarspect_methods.BUTTON('Submit for Approval').get_attribute('disabled')).to eq 'true'
      expect(@commercials_page.get_progress_info).to eq '25.00% completed • 3  Steps left'
    end

    e.run_step 'Update Promoter info and verify profile completion percentage' do
      @commercials_page.update_onboarding_info('Promoter Information', @promoter_info)
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['PromoterAdded']
      expect(@tarspect_methods.BUTTON('Submit for Approval').get_attribute('disabled')).to eq 'true'
      expect(@commercials_page.get_progress_info).to eq '50.00% completed • 2  Steps left'
    end

    e.run_step 'Update Key managing person info and verify profile completion percentage' do
      @commercials_page.update_onboarding_info('Key Managing Person Information', @km_person_info)
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['KMPersonAdded']
      expect(@tarspect_methods.BUTTON('Submit for Approval').get_attribute('disabled')).to eq 'true'
      expect(@commercials_page.get_progress_info).to eq '75.00% completed • 1  Steps left'
      expect(@commercials_page.business_details_completed?).to eq false
    end

    e.run_step 'Bank Details - IFSC code validations' do
      details = @bank_details.dup
      details['IFSC Code'] = 'WRONG0000'
      @commercials_page.update_onboarding_info('Bank Details', details)
      expect(@common_pages.ERROR_MESSAGE('IFSC Code').text).to eq $notifications['InvalidIFSC']
      details['IFSC Code'] = 'WRON1000000'
      @common_pages.close_icon.click
      @commercials_page.update_onboarding_info('Bank Details', details)
      expect(@common_pages.ERROR_MESSAGE('IFSC Code').text).to eq $notifications['InvalidIFSC']
      @common_pages.close_icon.click
    end

    e.run_step 'Update Bank Details info and verify profile completion percentage' do
      @commercials_page.update_onboarding_info('Bank Details', @bank_details)
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['BankDetailsUpdated']
      @commercials_page.make_bank_detail_primary(@bank_details['Bank Name'])
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['BankDetailsUpdated']
      expect(@commercials_page.get_progress_info).to eq '100.00% completed • All steps completed'
    end

    e.run_step 'Verify 100% completion of mandatory onboarding details(with bank details)' do
      expect(@tarspect_methods.BUTTON('Submit for Approval').get_attribute('disabled')).to eq nil
      expect(@commercials_page.business_details_completed?).to eq(true), 'Business details are not completed'
    end

    e.run_step 'Verify Submit for approval works for DD vendor onboarding' do
      @tarspect_methods.click_button('Submit for Approval')
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['SubmitForApproval']
      expect(@commercials_page.summary_text.include?($notifications['ProfileSummaryModal'])).to eq true
      @tarspect_methods.click_button('close')
    end

    e.run_step 'Verify Vendor lands on transactions list page once completed all onboarding details' do
      navigate_to($conf['base_url'])
      expect(@common_pages.menu_available?('Profile')).to eq true
      expect(@common_pages.menu_available?('Anchor List')).to eq true
    end

    e.run_step 'Navigate to profile and verify Bank details info' do
      @common_pages.click_menu('Profile')
      expect(@common_pages.menu_available?('Bank Details')).to eq true
      bank_details = @commercials_page.get_details('Bank Details')
      expect(bank_details.include?(@bank_details['Bank Name'])).to eq true
      expect(bank_details.include?(@bank_details['IFSC Code'])).to eq true
      expect(bank_details.include?(@bank_details['Account Number'])).to eq true
    end

    e.run_step 'Logout as Vendor' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Anchor and verify vendor status' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['anchor']['email'], $conf['users']['anchor']['password'])).to be true
      @common_pages.click_menu(MENU_VENDORS)
      @common_pages.apply_list_filter({ 'Vendor Status ' => 'Approved'.upcase })
      @common_pages.search_program(@commercials_data['Name'])
      values = { name: @commercials_data['Name'], state: 'Approved', field: 'Status', program: 'DYNAMIC DISCOUNTING' }
      expect(@commercials_page.get_vendor_details(values)).to eq 'Approved'
    end

    e.run_step 'Navigate to vendor profile and Verify Bank details info' do
      @commercials_page.navigate_to_entity(@commercials_data['Name'])
      expect(@common_pages.menu_available?('Bank Details')).to eq true
      bank_details = @commercials_page.get_details('Bank Details')
      expect(bank_details.include?(@bank_details['Bank Name'])).to eq true
      expect(bank_details.include?(@bank_details['IFSC Code'])).to eq true
      expect(bank_details.include?(@bank_details['Account Number'])).to eq true
    end
  end
end
