require './spec_helper'
describe 'Commercials: Channel Partner Validations', :scf, :commercials, :onboarding, :vendor_validations do
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

  it 'Commercials : Remove Vendor', :remove_vendor, :mails, :no_run do |e|
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

    e.run_step 'Create a registered vendor' do
      expect(@commercials_page.create_activated_channel_partner(@commercials_data)).to eq true
      @commercials_data['Name'] = @commercials_data['Entity Name']
    end

    e.run_step 'Login as Anchor and Remove vendor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['anchor']['email'], $conf['users']['anchor']['password'])).to be true
      @commercials_page.remove_commercials('Vendors', @commercials_data['Name'])
      expect(@commercials_page.vendor_removed_msg).to eq $notifications['VendorRemoved']
      expect(@commercials_page.entity_listed?(@commercials_data['Name'])).to eq false
    end

    e.run_step 'Verify Vendor removed mail sent to vendor' do
      expect(@commercials_page.vendor_removed_mail(@commercials_data['Name'])).to eq true
    end

    e.run_step 'Verify Anchor cannot remove vendor with Transactions' do
      refresh_page
      @commercials_page.vendor_disabled?('Vendors', $conf['vendor_name'])
    end

    e.run_step 'Logout as Anchor' do
      expect(@common_pages.logout).to eq true
    end
  end

  it 'Commercials : Vendor Onboarding Validations', :vendor_onboarding_validations, :mails, :no_run do |e|
    @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
    @commercials_data = @testdata['Commercials']
    @company_info = @testdata['Company Info']
    @promoter_info = @testdata['Promoter Info']
    @km_person_info = @testdata['Key Managing Person Info']
    @bank_details = @testdata['Bank Details']
    @company_kyc_docs = @testdata['Documents']['Company KYC Documents']
    @mandatory_documents = @testdata['Documents']['Mandatory Documents']
    @promoter_kyc_docs = @testdata['Documents']['Promoter KYC Documents']
    @financial_docs = @testdata['Documents']['Financials']
    @bank_statements = @testdata['Documents']['Bank Statements']
    @gst_returns = @testdata['Documents']['GST Returns']
    @commercials_data['GSTN'] = "#{Faker::Number.number(digits: 2)}#{@commercials_data['PAN']}#{Faker::Number.number(digits: 1)}Z#{Faker::Internet.user_name(specifier: 1..1).upcase}"
    actual_gstn = @commercials_data['GSTN']
    @created_vendors << @commercials_data['Entity Name']

    e.run_step 'Login as Anchor' do
      navigate_to($conf['base_url'])
      @tarspect_methods.login($conf['users']['anchor']['email'], $conf['users']['anchor']['password'])
    end

    e.run_step 'Add vendor with invalid GSTN data' do
      @commercials_data['GSTN'] = "#{Faker::Number.number(digits: 1)}#{@commercials_data['PAN']}#{Faker::Number.number(digits: 2)}Z#{Faker::Internet.user_name(specifier: 1..1).upcase}"
      @common_pages.click_menu(MENU_VENDORS)
      @commercials_page.add_commercials(@commercials_data)
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq 'Please provide a valid GSTN'
    end

    e.run_step 'Add vendor with invalid Email data' do
      @commercials_data['GSTN'] = actual_gstn
      invalid_email = 'aksdnfkajdnfandf.kndkfnaoinefa'
      @tarspect_methods.fill_form({ 'PAN' => @commercials_data['PAN'] }, 1, 2)
      @tarspect_methods.fill_form({ 'Email' => invalid_email }, 1, 2)
      @tarspect_methods.click_button('Submit')
      expect(@commercials_page.verify_required_field('Email')).to eq true
    end

    e.run_step 'Logout' do
      navigate_to($conf['base_url'])
      @tarspect_methods.wait_for_circular_to_disappear
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Create seed vendor' do
      expect(@commercials_page.create_activated_channel_partner(@commercials_data)).to eq true
    end

    e.run_step 'Login as newly created vendor' do
      sleep 10 # For data reflection
      navigate_to($conf['base_url'])
      @tarspect_methods.login(@commercials_data['Email'], $conf['users']['anchor']['password'])
    end

    e.run_step 'Verify Pre-filled company details' do
      @tarspect_methods.fill_mobile_otp
      @tarspect_methods.wait_for_loader_to_disappear
      @common_pages.select_onboarding_anchor_program($conf['anchor_name'])
      @common_pages.click_menu('Company Info')
      expected_values = {
        'Entity Name *' => @commercials_data['Entity Name'],
        'GSTN *' => @commercials_data['GSTN'],
        'PAN' => @commercials_data['PAN'],
        'Entity Type *' => '',
        'Relationship From *' => '',
        'City *' => '',
        'Phone Number *' => '',
        'Geography *' => '',
        'MSME/Non-MSME' => '',
        'Sector *' => '',
        'UAM' => ''
      }
      expect(@commercials_page.get_detailed_company_info).to eq expected_values
    end

    e.run_step "Verify 'auto-save' is working properly" do
      @commercials_page.update_onboarding_info('Company Info', { 'Phone Number' => @company_info['Phone Number'] })
      @tarspect_methods.click_button('Next')
      @tarspect_methods.click_button('Previous')
      auto_saved_value = @tarspect_methods.DYNAMIC_LOCATOR('contactNo', '@name').get_attribute('value')
      expect(auto_saved_value).to eq(@company_info['Phone Number']), 'Auto Save is not working'
    end

    e.run_step 'Verify PAN details are non editable' do
      expect(@commercials_page.input_not_editable?('PAN')).to eq true
    end

    e.run_step 'Verify required field validations - Company info' do
      expect(@commercials_page.verify_required_field('Entity Name')).to eq true
      expect(@commercials_page.verify_required_field('GSTN')).to eq true
      expect(@commercials_page.verify_required_field('Entity Type')).to eq true
    end

    e.run_step 'Verify required field validations - Promoter info' do
      @common_pages.click_menu('Promoter Details')
      @tarspect_methods.click_button(' Add Promoters')
      expect(@commercials_page.verify_required_field('Full Name')).to eq true
      expect(@commercials_page.verify_required_field('Phone Number')).to eq true
      expect(@commercials_page.verify_required_field('Shareholding')).to eq true
      @common_pages.close_icon.click
    end

    e.run_step 'Add Multiple Promoters, Edit and Delete' do
      promoter_info_2 = {
        'Full Name' => "#{Faker::Name.first_name} #{Faker::Name.last_name}",
        'Phone Number' => Faker::Number.number(digits: 10),
        'Shareholding' => '10'
      }
      promoter_info_2['Full Name'] = promoter_info_2['Full Name'].delete("'")
      updated_promoter_info_2 = {
        'Full Name' => "#{Faker::Name.first_name} #{Faker::Name.last_name}",
        'Phone Number' => Faker::Number.number(digits: 10),
        'Shareholding' => '8'
      }
      updated_promoter_info_2['Full Name'] = updated_promoter_info_2['Full Name'].delete("'")
      @commercials_page.update_onboarding_info('Promoter Details', @promoter_info)
      @tarspect_methods.close_toaster
      @commercials_page.update_onboarding_info('Promoter Details', promoter_info_2)
      @tarspect_methods.close_toaster
      [promoter_info_2['Full Name'], promoter_info_2['Phone Number'].to_s, (promoter_info_2['Shareholding'].to_s + '.0%')].each do |field|
        expect(@commercials_page.get_onboarding_page_list('Promoter Details').include?(field)).to eq true
      end

      @commercials_page.edit_person_info('Promoter Details', promoter_info_2['Full Name'], updated_promoter_info_2)
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['PromoterUpdated']

      [promoter_info_2['Full Name'], promoter_info_2['Phone Number'].to_s, (promoter_info_2['Shareholding'].to_s + '.0%')].each do |field|
        expect(@commercials_page.get_onboarding_page_list('Promoter Details').include?(field)).to eq false
      end

      [updated_promoter_info_2['Full Name'], updated_promoter_info_2['Phone Number'].to_s, (updated_promoter_info_2['Shareholding'].to_s + '.0%')].each do |field|
        expect(@commercials_page.get_onboarding_page_list('Promoter Details').include?(field)).to eq true
      end

      @commercials_page.delete_person_info('Promoter Details', updated_promoter_info_2['Full Name'])
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['PromoterDeleted']
      [updated_promoter_info_2['Full Name'], updated_promoter_info_2['Phone Number'].to_s, (updated_promoter_info_2['Shareholding'].to_s + '.0%')].each do |field|
        expect(@commercials_page.get_onboarding_page_list('Promoter Details').include?(field)).to eq false
      end
    end

    e.run_step 'Verify required field validations - Key managing person info' do
      @common_pages.click_menu('Key Managing Person Information')
      @tarspect_methods.click_button(' Add Key Managers')
      expect(@commercials_page.verify_required_field('Full Name')).to eq true
      expect(@commercials_page.verify_required_field('Phone Number')).to eq true
      @common_pages.close_icon.click
    end

    e.run_step 'Add Multiple KM Person, Edit and Delete' do
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
      @commercials_page.update_onboarding_info('Key Managing Person Information', @km_person_info)
      @tarspect_methods.close_toaster
      @commercials_page.update_onboarding_info('Key Managing Person Information', km_person_info_2)
      @tarspect_methods.close_toaster
      header = 'Key Managing Person (KMP) Details'
      [km_person_info_2['Full Name'], km_person_info_2['Phone Number'].to_s, km_person_info_2['Designation'].to_s, km_person_info_2['Email Id'].to_s].each do |field|
        expect(@commercials_page.get_onboarding_page_list(header).include?(field)).to eq true
      end
      @common_pages.click_menu('Key Managing Person Information')
      @commercials_page.edit_person_info('Key Managing Person Information', km_person_info_2['Full Name'], updated_km_person_info_2)
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['KMPersonUpdated']
      [km_person_info_2['Full Name'], km_person_info_2['Phone Number'].to_s, km_person_info_2['Designation'].to_s, km_person_info_2['Email Id'].to_s].each do |field|
        expect(@commercials_page.get_onboarding_page_list(header).include?(field)).to eq false
      end
      [updated_km_person_info_2['Full Name'], updated_km_person_info_2['Phone Number'].to_s, updated_km_person_info_2['Designation'].to_s, updated_km_person_info_2['Email Id'].to_s].each do |field|
        expect(@commercials_page.get_onboarding_page_list(header).include?(field)).to eq true
      end
      @commercials_page.delete_person_info('Key Managing Person Information', updated_km_person_info_2['Full Name'])
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['KMPersonDeleted']
      sleep 2
      [updated_km_person_info_2['Full Name'], updated_km_person_info_2['Phone Number'].to_s, updated_km_person_info_2['Designation'].to_s, updated_km_person_info_2['Email Id'].to_s].each do |field|
        expect(@commercials_page.get_onboarding_page_list(header).include?(field)).to eq false
      end
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

    e.run_step 'Bank details - Name Validations' do
      v = @bank_details.dup
      v['Bank Name'] = 'Hell,*('
      @commercials_page.update_onboarding_info('Bank Details', v)
      expect(@common_pages.ERROR_MESSAGE('Bank Name').text).to eq('Invalid Bank Name')
      @common_pages.close_modal
      v = @bank_details.dup
      v['Beneficiary Account Name'] = 'Hell,*('
      @commercials_page.update_onboarding_info('Bank Details', v)
      expect(@common_pages.ERROR_MESSAGE('Beneficiary Account Name').text).to eq('Invalid Beneficiary Name')
    end

    e.run_step 'Verify mandatory documents can be uploaded' do
      @common_pages.click_menu('Documents')
      @commercials_page.upload_and_map_docs(@mandatory_documents)
      expect(@commercials_page.verify_uploaded_docs(@mandatory_documents)).to eq true
    end

    e.run_step 'Remove uploaded documents' do
      expect(@commercials_page.remove_docs(@mandatory_documents)).to eq true
    end
  end

  it 'Commercials : Onboard Existing Vendors' do |e|
    @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
    @commercials_data = @testdata['Commercials']
    @commercials_data['Entity Name'] = 'Libas Impex'
    @commercials_data['GSTN'] = $conf['libas_gstn']
    @commercials_data['PAN'] = $conf['libas_gstn'][2..11]

    e.run_step 'Onboard a vendor' do
      navigate_to($conf['base_url'])
      @tarspect_methods.login($conf['users']['anchor']['email'], $conf['users']['anchor']['password'])
    end

    e.run_step 'Verify adding existing vendor in same anchor' do
      @common_pages.click_menu(MENU_VENDORS)
      @commercials_page.add_commercials(@commercials_data)
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['VendorExists']
    end

    e.run_step 'Verify adding existing vendor in different anchor' do
      navigate_to($conf['base_url'])
      @common_pages.click_menu(MENU_VENDORS)
      delete_channel_partner('Vendor', [['Exide', 'INVOICE FINANCING']], 'anchor')
      @commercials_data['Entity Name'] = 'Exide'
      @commercials_data['GSTN'] = $conf['users']['po_vendor']['gstn']
      @commercials_page.add_commercials(@commercials_data)
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['VendorInvited']
    end

    e.run_step 'Remove Vendor from anchor' do
      @commercials_page.remove_commercials('Vendors', 'Exide')
      expect(@commercials_page.vendor_removed_msg).to eq $notifications['VendorRemoved']
      expect(@commercials_page.entity_listed?('Exide')).to eq false
    end
  end
end
