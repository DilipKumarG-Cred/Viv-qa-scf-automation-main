require './spec_helper'
describe 'Multi lendor to Channel partners:', :scf, :commercials, :multi_lendor, :ml_commercials do
  before(:all) do
    @mou = "#{Dir.pwd}/test-data/attachments/borrowing_document.pdf"
    @reupload_mou = "#{Dir.pwd}/test-data/attachments/reinitiate_invoice.pdf"
    @borrowing_document = "#{Dir.pwd}/test-data/attachments/borrowing_document.pdf"
    @anchor_name = $conf['anchor_name']
    @vendor_name = $conf['users']['ml_vendor']['name']
    @second_vendor = 'Carroll Spencer'
    @third_vendor = 'Unique STG'
    @fourth_vendor = 'Priya TVS'
    @anchor_program_id = $conf['programs']['Invoice Financing - Vendor']
    @expected_values = {
      'Status' => '-',
      'Name' => 'Just Buy Cycles',
      'City' => 'Bodinayakanur',
      'Geography' => 'south',
      'Vendor Type' => '-',
      'Relationship Age' => '',
      'Turnover' => '0',
      'Live Transaction Count' => '0'
    }
    @vendor_commercials = {
      'Processing Fee' => 2,
      'Investor GSTN' => $conf['dcb_gstn'],
      'Sanction Limit' => 100_000,
      'Tenor' => '60 days',
      'Yield' => '8',
      'Unique Identifier' => @uniq_id,
      'Agreement Validity' => [get_todays_date(-5, '%d-%b-%Y'), get_todays_date(300, '%d-%b-%Y')],
      'Invocie Upload (Days) ' => '45',
      'Effective Date' => Date.today.strftime('%d-%b-%Y')
    }
  end

  before(:each) do
    @driver = Tarspect::Browser.new($conf['browser']).invoke
    @tarspect_methods = Common::Methods.new(@driver)
    @common_pages = Pages::CommonMethods.new(@driver)
    @commercials_page = Pages::Commercials.new(@driver)
    @transactions_page = Pages::Trasactions.new(@driver)
    @disbursement_page = Pages::Disbursement.new(@driver)
    @uniq_id = 'UNIQUEID'
    @values = {
      'Program' => 'Invoice Financing',
      'Type' => 'Vendor',
      'Anchor ID' => '4',
      'Investor ID' => '9',
      'Vendor Name' => @vendor_name,
      'actor' => 'user_feedback_investor'
    }
    delete_vendor_commercials(@values)
  end

  after(:each) do |e|
    snap_screenshot(e)
  end

  after(:all) do
    quit_browser
  end

  it 'Vendor Commercials: Setup and Approval', :CP_commercial_setup, :mails, :no_run do |e|
    e.run_step 'Verify Vendor is Approved for investor Kotak' do
      resp = verify_vendor_present(@anchor_program_id, 7, @vendor_name, actor: 'investor')
      expect(resp[:status]).to eq('Verified')
      expect(resp[:name]).to eq(@vendor_name)
    end

    e.run_step 'Login as Investor: DCB' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['user_feedback_investor']['email'], $conf['users']['user_feedback_investor']['password'])).to be true
    end

    e.run_step 'Verify vendor is available to other investor' do
      @common_pages.click_menu(MENU_ANCHOR_LIST)
      @common_pages.navigate_to_anchor(@anchor_name)
      @common_pages.select_program('Invoice Financing', 'Vendor')
      # Relationship Age is calculated based on vendor created date.
      diff_in_days = (Date.today - Date.parse('01-Jan-2022')).numerator
      @age = @common_pages.calculate_relationship_age(diff_in_days)
      @expected_values['Relationship Age'] = @age
      ex_values = @expected_values.dup
      ex_values.delete('Status')
      actual_values = @commercials_page.vendor_program_details(@vendor_name)
      actual_values.delete('Status')
      expect(actual_values).to eq ex_values
    end

    e.run_step 'Verify Vendor Commercials can be set by other investors as well' do
      Tarspect::Locator.new(:xpath, "//*[text()='#{@vendor_name}']//ancestor::li").click
      @commercials_page.add_vendor_commercials(@vendor_commercials)
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['VendorProgramAdded']
    end

    e.run_step 'Logout as Investor: DCB' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Verify mail recieved on commercial setup' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['ml_vendor']['email'], $conf['users']['ml_vendor']['password'])).to be true
      email_values = {
        mail_box: $conf['notification_mailbox'],
        subject: 'New action from DCB Bank on your Yubi Flow program',
        body: 'Invoice Financing - Vendor',
        link_text: 'live-investors'
      }
      @common_pages.get_link_from_mail(email_values, new_tab: false)
    end

    e.run_step 'Approve Commercials and add Borrowing Document' do
      investor_details = {
        'investor' => 'DCB',
        'Sanction limit' => '100000',
        'Processing Fee' => '2.0 %',
        'Tenor' => '60 Days',
        'Repayment Adjustment Order' => 'Interest - Principal - Charges'
      }
      expect(@common_pages.verify_interested_investors_details(investor_details)).to eq true
      @common_pages.VENDOR_INVESTOR_ROW($conf['users']['user_feedback_investor']['name']).click
      @commercials_page.check_field_in_vendor_commercial(['Unique Identifier'])
      @commercials_page.upload_bd(@borrowing_document)
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['BDSigned']
      @common_pages.close_modal
    end

    e.run_step 'Verify Processing fee details for the commercials' do
      expected_summary = {
        'Processing fee' => '₹2,000',
        'CGST Fee (9%)' => '₹0',
        'IGST Fee (18%)' => '₹360',
        'SGST Fee (9%)' => '₹0',
        'Processing Fee Payable' => '₹2,360'
      }
      refresh_page
      @tarspect_methods.click_button('Record Payment')
      @tarspect_methods.click_button('Submit & Proceed To Payment')
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

    e.run_step 'Login as Product and verify if Unique Identifier is shown' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['product']['email'], $conf['users']['product']['password'])).to be true
      @common_pages.click_menu(MENU_ANCHOR_LIST)
      @common_pages.navigate_to_anchor(@anchor_name)
      @common_pages.select_program('Invoice Financing', 'Vendor')
      @common_pages.click_live_investors
      @common_pages.navigate_to_investor($conf['users']['user_feedback_investor']['name'])
      @commercials_page.scroll_till_program(@vendor_name)
      @transactions_page.select_vendor(@vendor_name)
      @commercials_page.check_field_in_vendor_commercial(['Unique Identifier'])
      @common_pages.close_modal
    end

    e.run_step 'Logout as Product' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Investor: DCB' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['user_feedback_investor']['email'], $conf['users']['user_feedback_investor']['password'])).to be true
    end

    e.run_step 'Verify Vendor status - Pending' do
      @expected_values['Status'] = 'Pending'
      @common_pages.click_menu(MENU_ANCHOR_LIST)
      @common_pages.navigate_to_anchor($conf['anchor_name'])
      @common_pages.select_program('Invoice Financing', 'Vendor')
      expect(@commercials_page.vendor_program_details(@vendor_name)).to eq @expected_values
    end

    e.run_step 'Verify Processing fee for the commercials' do
      @commercials_page.verify_processing_fee(@vendor_name)
      @tarspect_methods.click_button('Accept')
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['ProcessingFeeVerified']
    end

    e.run_step 'Verify Vendor status - Approved' do
      refresh_page
      @tarspect_methods.wait_for_loader_to_disappear
      @tarspect_methods.wait_for_circular_to_disappear
      resp = verify_vendor_present(@anchor_program_id, 9, @vendor_name, actor: 'user_feedback_investor')
      expect(resp[:status]).to eq('Verified')
      expect(resp[:name]).to eq(@vendor_name)
    end

    e.run_step 'Verify Same Unique Identifier cannot be added for another vendor in Same program' do
      @common_pages.search_program(@second_vendor)
      @transactions_page.select_vendor(@second_vendor)
      @commercials_page.add_vendor_commercials(@vendor_commercials)
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['UniqueIdentifierError']
      @common_pages.close_modal
    end

    e.run_step 'Verify Same Unique Identifier can be added for another vendor in different program' do
      @common_pages.click_back_button
      @common_pages.click_back_button
      @common_pages.select_program('PO Financing', 'Vendor')
      @common_pages.search_program(@third_vendor)
      @transactions_page.select_vendor(@third_vendor)
      @commercials_page.add_vendor_commercials(@vendor_commercials, edit: true)
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['VendorProgramAdded']
    end

    e.run_step 'Verify Same Unique Identifier can be added for another vendor with anchor program' do
      @common_pages.click_menu(MENU_ANCHOR_LIST)
      @common_pages.navigate_to_anchor($conf['grn_anchor_name'])
      @common_pages.select_program('Invoice Financing', 'Dealer')
      @common_pages.search_program(@fourth_vendor)
      @transactions_page.select_vendor(@fourth_vendor)
      @commercials_page.add_vendor_commercials(@vendor_commercials, edit: true)
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['VendorProgramAdded']
    end

    e.run_step 'Delete commercials' do
      resp = delete_vendor_commercials(@values)
      expect(resp[:code]).to eq(200), resp.to_s
    end
  end
end
