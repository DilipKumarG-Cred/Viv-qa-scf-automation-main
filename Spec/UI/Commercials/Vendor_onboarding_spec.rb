require './spec_helper'
describe 'Commercials: Vendor Onboarding', :scf, :commercials, :onboarding, :vendor_onboarding, :mails do
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
    @disbursement_page = Pages::Disbursement.new(@driver)
    navigate_to($conf['base_url'])
    clear_cookies
  end

  after(:each) do |e| # Captures screenshot of the current page when failure happens
    snap_screenshot(e)
    quit_browser
  end

  after(:all) do
    delete_channel_partner('Vendor', @created_vendors)
  end

  it 'Commercials: Anchor invites a new vendor', :new_vendor_onboard do |e|
    @testdata = JSON.parse(ERB.new(@erb_file).result(binding))['Commercials']
    @testdata['GSTN'] = "#{Faker::Number.number(digits: 2)}#{@testdata['PAN']}#{Faker::Number.number(digits: 1)}Z#{Faker::Internet.user_name(specifier: 1..1).upcase}"
    @created_vendors << @testdata['Entity Name']
    e.run_step 'Login as Anchor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['anchor']['email'], $conf['users']['anchor']['password'])).to be true
    end

    e.run_step 'Invite new vendor' do
      @common_pages.click_menu(MENU_VENDORS)
      @commercials_page.add_commercials(@testdata)
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['VendorInvited']
    end

    e.run_step 'Logout Anchor' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Product user and verify invited/onboarding date are displayed' do
      navigate_to($conf['base_url'])
      @tarspect_methods.login($conf['users']['product']['email'], $conf['users']['product']['password'])
      @common_pages.click_menu(MENU_VENDORS)
      @common_pages.search_program(@testdata['Entity Name'])
      values = { name: @testdata['Entity Name'], state: 'Awaiting Vendor Acceptance', field: 'Invite Date', program: 'INVOICE FINANCING' }
      expect(@commercials_page.get_vendor_details(values)).to eq(Date.today.strftime('%d %b, %Y'))
      values.merge!(field: 'Onboarded Date')
      expect(@commercials_page.get_vendor_details(values)).to eq('-')
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Vendor activates from the accept invite link' do
      expect(@commercials_page.activate_channel_partner(@testdata['Email'])).to eq true
    end

    e.run_step 'Verify vendor status after Vendor accepts invitation' do
      sleep 10 # For Data reflection
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['anchor']['email'], $conf['users']['anchor']['password'])).to be true
      @common_pages.click_menu(MENU_VENDORS)
      @common_pages.apply_list_filter({ 'Vendor Status ' => 'Awaiting Vendor Acceptance'.upcase })
      values = { name: @testdata['Entity Name'], state: 'Awaiting Vendor Acceptance', field: 'Status', program: 'INVOICE FINANCING' }
      expect(@commercials_page.get_vendor_details(values)).to eq 'Awaiting Vendor Acceptance'
    end

    e.run_step 'Remove Vendor from anchor' do
      @commercials_page.remove_vendor_from_more_options('Vendors', @testdata['Entity Name'])
      expect(@commercials_page.vendor_removed_msg).to eq $notifications['VendorRemoved']
      expect(@commercials_page.entity_listed_in_current_page?(@testdata['Entity Name'])).to eq false
    end
  end

  it 'Commercials: Vendor Registration', :new_vendor_onboard do |e|
    @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
    @commercials_data = @testdata['Commercials']
    @company_info = @testdata['Company Info']
    @promoter_info = @testdata['Promoter Info']
    @km_person_info = @testdata['Key Managing Person Info']
    @bank_details = @testdata['Bank Details']
    @mandatory_documents = @testdata['Documents']['Mandatory Documents']
    @company_kyc_docs = @testdata['Documents']['Company KYC Documents']
    @mandatory_company_kyc_documents = [@company_kyc_docs[1], @company_kyc_docs[2]]
    @promoter_kyc_docs = @testdata['Documents']['Promoter KYC Documents']
    @mandatory_company_promoter_documents = ['Promoter 1 - Promoter PAN', 'Promoter 1 - Promoter Aadhaar']
    @financial_docs = @testdata['Documents']['Financials']
    @bank_statements = @testdata['Documents']['Bank Statements']
    @gst_returns = @testdata['Documents']['GST Returns']
    @msme_certificate = @testdata['Documents']['MSME Certificate']
    @commercials_data['GSTN'] = "#{Faker::Number.number(digits: 2)}#{@commercials_data['PAN']}#{Faker::Number.number(digits: 1)}Z#{Faker::Internet.user_name(specifier: 1..1).upcase}"
    @created_vendors << @commercials_data['Entity Name']
    @bank_docs = ["#{Dir.pwd}/test-data/attachments/#{@bank_statements[0]}.pdf"]
    e.run_step 'Onboard a vendor' do
      expect(@commercials_page.create_activated_channel_partner(@commercials_data)).to eq true
      @commercials_data['Name'] = @commercials_data['Entity Name']
    end

    e.run_step 'Login as Vendor' do
      sleep 10 # For Data reflection
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login(@commercials_data['Email'], $conf['users']['anchor']['password'])).to be true
    end

    e.run_step 'Verify Onboarding details required field validations' do
      @tarspect_methods.fill_mobile_otp
      sleep 5
      @common_pages.select_onboarding_anchor_program($conf['anchor_name'])
      expect(@tarspect_methods.BUTTON('Next').get_attribute('disabled')).to eq nil
    end

    e.run_step 'Update Company info' do
      @commercials_page.update_onboarding_info('Company Info', @company_info)
      expect(@tarspect_methods.assert_and_close_toaster).to eq $notifications['CompanyDetailsSaved']
      expect(@tarspect_methods.BUTTON('Next').get_attribute('disabled')).to eq nil
      @tarspect_methods.click_button('Next')
      expect(@commercials_page.business_details_completed?('Company Info')).to eq(true), 'Company Info are not completed'
    end
    e.run_step 'Update Promoter info' do
      expect(@tarspect_methods.BUTTON('Previous').get_attribute('disabled')).to eq nil
      @commercials_page.update_onboarding_info('Promoter Details', @promoter_info)
      expect(@tarspect_methods.assert_and_close_toaster).to eq $notifications['PromoterAdded']
      expect(@tarspect_methods.BUTTON('Previous').get_attribute('disabled')).to eq nil
      @tarspect_methods.click_button('Next')
      expect(@commercials_page.business_details_completed?('Promoter Details')).to eq(true), 'Promoter Details are not completed'
    end
    e.run_step 'Logout as vendor' do
      expect(@common_pages.logout).to eq true
    end
    e.run_step 'Login as vendor and verify the vendor should be landed where they left in the onboarding process' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login(@commercials_data['Email'], $conf['users']['anchor']['password'], true)).to be true
      @common_pages.select_onboarding_anchor_program($conf['anchor_name'])
      @tarspect_methods.wait_for_loader_to_disappear
      expect(@driver.current_url).to include('key-manager')
    end
    e.run_step 'Update Key managing person info' do
      @commercials_page.update_onboarding_info('Key Managing Person Information', @km_person_info)
      expect(@tarspect_methods.assert_and_close_toaster).to eq $notifications['KMPersonAdded']
      expect(@tarspect_methods.BUTTON('Previous').get_attribute('disabled')).to eq nil
      @tarspect_methods.click_button('Next')
      expect(@commercials_page.business_details_completed?('Key Managing Person Information')).to eq(true), 'Key Managing Person Information are not completed'
    end
    e.run_step 'Update Bank Details info and verify profile completion percentage' do
      @commercials_page.update_onboarding_info('Bank Details', @bank_details)
      expect(@tarspect_methods.assert_and_close_toaster).to eq $notifications['BankDetailsUpdated']
      expect(@commercials_page.business_details_completed?('Bank Details')).to eq(false), 'Bank Details should not be completed as primary is not set'
      @commercials_page.make_bank_detail_primary(@bank_details['Bank Name'])
      expect(@tarspect_methods.assert_and_close_toaster).to eq $notifications['BankDetailsUpdated']
      expect(@tarspect_methods.BUTTON('Previous').get_attribute('disabled')).to eq nil
      @tarspect_methods.click_button('Next')
      expect(@tarspect_methods.BUTTON('Next').get_attribute('disabled')).to eq nil
      expect(@commercials_page.business_details_completed?('Bank Details')).to eq(true), 'Bank Details are not completed'
    end
    e.run_step 'Verify Submit button is disabled before uploading mandatory documents' do
      @tarspect_methods.click_button('Next')
      expect(@tarspect_methods.BUTTON('Submit').get_attribute('disabled')).to eq 'true'
    end

    e.run_step 'Upload Mandatory docs' do
      @tarspect_methods.click_link('Documents')
      @tarspect_methods.wait_for_circular_to_disappear(MAX_LOADER_TIME)
      expect(@commercials_page.upload_docs(@mandatory_documents)).to eq true
    end

    e.run_step 'Uploading Bank docs by providing incorrect password' do
      expect(@commercials_page.upload_docs(@bank_docs, nil, true)).to eq true
      expect(@commercials_page.fill_password('Think123')).to eq $notifications['Incorrect Password']
    end

    e.run_step 'Uploading Bank docs by providing correct password' do
      expect(@commercials_page.fill_password('Think@123')).to eq $notifications['Correct Password']
      @tarspect_methods.click_button('Submit')
    end

    e.run_step 'Verify documents are shown mandatory' do
      expect(@commercials_page.get_status_documents_in_onboarding).to eq(['•GST Certificate*', '•Entity PAN*', '•Promoter PAN*', '•Promoter Aadhaar*'])
    end

    e.run_step 'Upload Financial docs' do
      refresh_page
      expect(@commercials_page.upload_docs(@financial_docs)).to eq true
    end

    e.run_step 'Verify Submit button cannot be clicked' do
      expect(@commercials_page.business_details_completed?('Documents')).to eq(false), 'Documents are completed!'
    end

    e.run_step 'Verify documents are shown tick mark' do
      expect(@commercials_page.map_docs(@mandatory_documents)).to eq true
      expect(@commercials_page.map_docs(@bank_docs, @bank_statements[0])).to eq true
      expect(@commercials_page.map_docs(@financial_docs)).to eq true
      sleep 5
      expect(@commercials_page.get_uploaded_document_size.size).to eq(4), 'Not all mandatory documents are properly uploaded'
      expect(@commercials_page.get_status_documents_in_onboarding).to eq(['GST Certificate*', 'Entity PAN*', 'Promoter PAN*', 'Promoter Aadhaar*'])
    end

    e.run_step 'Verify business details are completed' do
      @tarspect_methods.click_button('Next')
      expect(@tarspect_methods.BUTTON('Submit').get_attribute('disabled')).to eq nil
      expect(@commercials_page.business_details_completed?('BUSINESS INFORMATION')).to eq(true), 'Business information are not completed'
    end

    e.run_step 'Logout as vendor' do
      expect(@common_pages.logout).to eq true
    end
    e.run_step 'Login as Anchor and verify status before Submit for Approval' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['anchor']['email'], $conf['users']['anchor']['password'])).to be true
      @common_pages.click_menu(MENU_VENDORS)
      @common_pages.apply_list_filter({ 'Vendor Status ' => 'Pending Registration'.upcase })
      values = { name: @commercials_data['Name'], state: 'Pending Registration', field: 'Status', program: 'INVOICE FINANCING' }
      expect(@commercials_page.get_vendor_details(values)).to eq 'Pending Registration'
    end
    e.run_step 'Logout as Anchor' do
      expect(@common_pages.logout).to eq true
    end
    e.run_step 'Login as vendor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login(@commercials_data['Email'], $conf['users']['anchor']['password'])).to be true
    end
    e.run_step 'Vendor submits for approval' do
      @common_pages.select_onboarding_anchor_program($conf['anchor_name'])
      @common_pages.click_menu('GST VERIFICATION')
      @tarspect_methods.click_button('Submit')
      sleep 1
      @tarspect_methods.BUTTON('Submit Anyway').click
      sleep 2
      expect(@commercials_page.summary_text.include?($notifications['ProfileSummaryModal'])).to eq true
      @common_pages.close_icon.click
    end
    e.run_step 'Logout as vendor' do
      expect(@common_pages.logout).to eq true
    end
    e.run_step 'Login as vendor and verify that the vendor was landed in the profile snapshot page' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login(@commercials_data['Email'], $conf['users']['anchor']['password'], true)).to be true
      @tarspect_methods.wait_for_loader_to_disappear
      expect(@driver.current_url).to include('profile-summary')
    end
    e.run_step 'Verify client profile page after submit for approval - Company Info' do
      @tarspect_methods.wait_for_circular_to_disappear(MAX_LOADER_TIME)
      @tarspect_methods.click_link('Details')
      company_details = @commercials_page.get_details('Company Information')
      [@company_info['City'], @company_info['Geography'], @company_info['Phone Number'], @commercials_data['PAN'], @company_info['Entity Type'], @company_info['Registered Address'], @company_info['Address Type'], @company_info['State'], @company_info['Zipcode'], @company_info['Registration Type']].each do |field|
        expect(company_details.include?(field)).to eq(true), $notifications['Company_Info']
      end
    end
    e.run_step 'Verify client profile page after submit for approval - Promoter Info' do
      promoter_details = @commercials_page.get_details('Promoter Information')
      [@promoter_info['Full Name'], @promoter_info['Phone Number'], @promoter_info['Shareholding'], @promoter_info['Salutation'], @promoter_info['Gender'], @promoter_info['Marital Status'], @promoter_info['Email Id'], @promoter_info['PAN'], @promoter_info['Address Type'], @promoter_info['State'], @promoter_info['City'], @promoter_info['Zipcode'], @promoter_info['Address']].each do |field|
        expect(promoter_details.include?(field)).to eq(true), $notifications['Promoter_Info']
      end
    end
    e.run_step 'Verify client profile page after submit for approval - Key managing person Info' do
      km_person_details = @commercials_page.get_details('Key Management Information')
      expect(km_person_details.include?(@km_person_info['Full Name'])).to eq true
      expect(km_person_details.include?(@km_person_info['Phone Number'])).to eq true
      expect(km_person_details.include?(@km_person_info['Designation'])).to eq true
      expect(km_person_details.include?(@km_person_info['Email Id'])).to eq true
    end
    e.run_step 'Verify bank details can be updated in profile page' do
      @tarspect_methods.click_link('Bank Details')
      expect(@tarspect_methods.BUTTON('Edit').get_attribute('disabled')).to eq(nil)
      @tarspect_methods.click_button('Edit')
      expect(@tarspect_methods.BUTTON('Save').get_attribute('disabled')).to eq(nil)
      @updated_bd = {
        'Account Type' => 'Cash Credit',
        'Bank Name' => @bank_details['Bank Name'] + 'updated',
        'Beneficiary Account Name' => @bank_details['Beneficiary Account Name'] + 'updated',
        'IFSC Code' => 'HDFC0000001',
        'Account Number' => '1234567890'
      }
      @tarspect_methods.fill_form(@updated_bd, 1, 2)
      @tarspect_methods.click_button('Save')
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['BankDetailsUpdated']
    end

    e.run_step 'Verify Bank details after updating' do
      bank_details = @commercials_page.get_details('Bank Details')
      @updated_bd.each_key do |k|
        expect(bank_details).to include(@updated_bd[k]), "#{@updated_bd[k]} is not present in #{bank_details}"
      end
    end

    e.run_step 'Verify client documents after submit for approval - Company KYC documents' do
      @tarspect_methods.click_link('Documents')
      @tarspect_methods.click_link('Company KYC Documents')
      expect(@commercials_page.verify_uploaded_docs(@mandatory_company_kyc_documents)).to eq true
      expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq true
    end
    e.run_step 'Verify client documents after submit for approval - Promoter KYC documents' do
      @tarspect_methods.click_link('Promoter KYC Documents')
      expect(@commercials_page.verify_uploaded_docs(@mandatory_company_promoter_documents)).to eq true
      expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq true
    end

    e.run_step 'Verify documents can be uploaded from profile view' do
      @tarspect_methods.click_link('Financials')
      file = create_test_doc('Financials_doc_upload')
      @commercials_page.upload_bd(file)
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq('Documents uploaded successfully.')
    end

    e.run_step 'Logout as vendor' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Anchor and verify status after Submit for Approval' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['anchor']['email'], $conf['users']['anchor']['password'])).to be true
      @common_pages.click_menu(MENU_VENDORS)
      @common_pages.apply_list_filter({ 'Vendor Status ' => 'Awaiting Platform Verification'.upcase })
      values = { name: @commercials_data['Name'], state: 'Awaiting Platform Verification', field: 'Status', program: 'INVOICE FINANCING' }
      expect(@commercials_page.get_vendor_details(values)).to eq 'Awaiting Platform Verification'
    end

    e.run_step 'Verify adding existing vendor in different program' do
      @commercials_data['Select a Program'] = 'PO Financing - Vendor Program'
      navigate_to($conf['base_url'])
      @common_pages.click_menu(MENU_VENDORS)
      @commercials_page.add_commercials(@commercials_data)
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['VendorInvited']
      @commercials_page.navigate_to_entity(@commercials_data['Entity Name'], 'Details')
      @km_person_details = @commercials_page.get_details('Key Management Information')
    end

    e.run_step 'Logout as anchor' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as vendor and verify key manager details are prefilled' do
      navigate_to($conf['base_url'])
      @tarspect_methods.login($conf['users']['po_vendor']['email'], $conf['users']['po_vendor']['password'])
      @tarspect_methods.wait_for_loader_to_disappear
      @common_pages.select_onboarding_anchor_program($conf['anchor_name'])
      @common_pages.click_menu('Key Managing Person Information')
      [@km_person_info['Full Name'], @km_person_info['Phone Number'], @km_person_info['Designation'], @km_person_info['Email Id']].each do |field|
        expect(@km_person_details.include?(field)).to eq(true), $notifications['Key_Managing_Info']
      end
    end

    e.run_step 'Verify that vendor can add Multiple KM Person, Edit and Delete' do
      km_person_info_2 = {
        'Full Name' => "#{Faker::Name.first_name} #{Faker::Name.last_name}",
        'Phone Number' => Faker::Number.number(digits: 10),
        'Designation' => Faker::Company.profession,
        'Email Id' => "#{Faker::Internet.user_name(specifier: 5..5)}@yopmail.com"
      }
      km_person_info_2['Full Name'] = km_person_info_2['Full Name'].delete("'")
      updated_km_person_info_2 = {
        'Full Name' => "#{Faker::Name.first_name} #{Faker::Name.last_name}",
        'Phone Number' => Faker::Number.number(digits: 10),
        'Designation' => Faker::Company.profession,
        'Email Id' => "#{Faker::Internet.user_name(specifier: 5..5)}@yopmail.com"
      }
      updated_km_person_info_2['Full Name'] = updated_km_person_info_2['Full Name'].delete("'")
      @commercials_page.update_onboarding_info('Key Managing Person Information', km_person_info_2)
      @tarspect_methods.close_toaster
      @tarspect_methods.wait_for_loader_to_disappear
      @commercials_page.edit_person_info('Key Managing Person Information', km_person_info_2['Full Name'], updated_km_person_info_2)
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['KMPersonUpdated']
      @commercials_page.delete_person_info('Key Managing Person Information', updated_km_person_info_2['Full Name'])
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['KMPersonDeleted']
    end
  end
end
