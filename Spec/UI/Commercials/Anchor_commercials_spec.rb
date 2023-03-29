require './spec_helper'
describe 'Anchor Commercials:', :scf, :commercials, :anchor_commercials do
  before(:all) do
    @mou = "#{Dir.pwd}/test-data/attachments/borrowing_document.pdf"
    @reupload_mou = "#{Dir.pwd}/test-data/attachments/reinitiate_invoice.pdf"
    @anchor_actor = 'comm_anchor'
    @anchor_name = $conf['users'][@anchor_actor]['name']
    @anchor_id = $conf['users'][@anchor_actor]['id']
  end

  before(:each) do
    @commercials_hash = {
      'Recourse' => '100',
      'Margin' => '10',
      'Prepayment Charges' => '2',
      'Door-To-Door Tenor' => '90',
      'Pricing Min' => rand(5..8).to_s,
      'Pricing Max' => rand(12..18).to_s,
      'Maximum Tenor ' => '90 days',
      'date_range' => [{ 'Agreement Validity ' => get_todays_date(nil, '%d-%b-%Y') }, { 'Agreement Validity ' => get_todays_date(300, '%d-%b-%Y') }],
      'Penal Charges' => '5',
      'Max Sanction Limit' => '10000000000',
      'Interest Strategy' => 'Front End',
      'Liability' => 'Anchor',
      'Mandatory Invoice File Upload' => 'Yes',
      'Skip Counter Party Approval' => 'Yes',
      'Interest Calculation Strategy' => 'Simple Interest',
      'Program Code' => '9929',
      'Effective Date' => Date.today.strftime('%d-%b-%Y')
    }
    values = {
      investor_actor: 'investor',
      investor_id: 7,
      anchor_id: @anchor_id,
      program_id: $conf['programs']['Invoice Financing - Vendor']
    }
    force_delete_anchor_commercials(values)
    @driver = Tarspect::Browser.new($conf['browser']).invoke
    @tarspect_methods = Common::Methods.new(@driver)
    @common_pages = Pages::CommonMethods.new(@driver)
    @commercials_page = Pages::Commercials.new(@driver)
  end

  after(:each) do |e| # Captures screenshot of the current page when failure happens
    snap_screenshot(e)
    quit_browser
  end

  it 'Anchor Commercials: Setup Commercials', :setup_anchor_commercials do |e|
    e.run_step 'Login as Investor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['investor']['email'], $conf['users']['investor']['password'])).to be true
    end

    e.run_step 'Setup Anchor Commercials' do
      @common_pages.click_menu(MENU_ANCHOR_LIST)
      @common_pages.apply_list_filter({ 'Anchor Name' => @anchor_name })
      @common_pages.navigate_to_anchor(@anchor_name)
      @common_pages.select_program('Vendor Financing')
      @commercials_page.add_investor_anchor_commercials(@commercials_hash)
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['UpdateCommercials']
    end

    e.run_step 'Verify Anchor Commercials as Investor' do
      @expected_values = {
        'Recourse' => "#{@commercials_hash['Recourse']}%",
        'Margin' => "#{@commercials_hash['Margin']}%",
        'Pricing' => "#{@commercials_hash['Pricing Min']}-#{@commercials_hash['Pricing Max']}%",
        'Agreement Validity' => "#{get_todays_date(nil, '%d %b, %Y')} - #{get_todays_date(300, '%d %b, %Y')}",
        'Max. Tenor' => (@commercials_hash['Maximum Tenor ']).to_s,
        'Penal Charges' => "#{@commercials_hash['Penal Charges']}%",
        'Interest Strategy' => @commercials_hash['Interest Strategy'],
        'Liability' => @commercials_hash['Liability'],
        'Mandatory Invoice File' => @commercials_hash['Mandatory Invoice File Upload'],
        'Skip Counter Party Approval' => @commercials_hash['Skip Counter Party Approval'],
        'Max Sanction Limit' => '₹ 1,000 CR',
        'Door-To-Door Tenor' => '90',
        'Invoice Ageing Threshold' => '-',
        'Interest Calculation Strategy' => 'Simple Interest',
        'Interest Calculation Rest' => '-',
        'Program Code' => '9929',
        'Effective Date' => get_todays_date(nil, '%d %b, %Y'),
        'Grace Period' => '0',
        'Instruments' => 'Invoice'
      }
      values = @commercials_page.get_anchor_commercial_details
      expect(values).to eq @expected_values
    end

    e.run_step 'Investor Logs out' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Product' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['product']['email'], $conf['users']['product']['password'])).to be true
    end

    e.run_step 'Verify Product cannot see draft commercials' do
      @common_pages.click_menu(MENU_ANCHOR_LIST)
      @common_pages.apply_list_filter({ 'Anchor Name' => @anchor_name })
      @common_pages.navigate_to_anchor(@anchor_name)
      @common_pages.select_program('Vendor Financing')
      @common_pages.click_interested_investors
      url = $driver.current_url
      @common_pages.INVESTOR_LIST('Kotak').click
      url1 = $driver.current_url
      expect(url).to eq(url1) # Page should not move forward
    end

    e.run_step 'Product Logs out' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Anchor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['comm_anchor']['email'], $conf['users']['comm_anchor']['password'])).to be true
    end

    e.run_step 'Verify Anchor cannot edit commercials' do
      @common_pages.click_menu(MENU_PROGRAMS)
      @common_pages.select_program('Vendor Financing')
      @common_pages.click_interested_investors
      @common_pages.navigate_to_investor($conf['users']['investor']['name'])
      flag = @commercials_page.check_anchor_commercial_cannot_be_edited
      expect(flag).to eq(true), 'Draft Commercials are not displayed or can be edited before uploading MOU'
    end

    e.run_step 'Anchor Logs out' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Investor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['investor']['email'], $conf['users']['investor']['password'])).to be true
    end

    e.run_step 'Investor uploads MOU' do
      @common_pages.click_menu(MENU_ANCHOR_LIST)
      @common_pages.apply_list_filter({ 'Anchor Name' => @anchor_name })
      @common_pages.navigate_to_anchor(@anchor_name)
      @common_pages.select_program('Vendor Financing')
      @tarspect_methods.wait_for_loader_to_disappear
      @commercials_page.upload_mou(@mou)
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['MOUSuccess']
    end

    e.run_step 'Investor submits commercial' do
      @tarspect_methods.click_button('Submit')
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq 'Commercials renewed successfully!'
    end

    e.run_step 'Verify Edit option not available for investor after MOU upload' do
      expect(@commercials_page.edit_commercials_available?).to eq true
    end

    e.run_step 'Investor Logs out' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Product' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['product']['email'], $conf['users']['product']['password'])).to be true
    end

    e.run_step 'Verify Product cannot see draft commercials' do
      @common_pages.click_menu(MENU_ANCHOR_LIST)
      @common_pages.apply_list_filter({ 'Anchor Name' => @anchor_name })
      @common_pages.navigate_to_anchor(@anchor_name)
      @common_pages.select_program('Vendor Financing')
      @common_pages.click_interested_investors
      url = $driver.current_url
      @common_pages.INVESTOR_LIST('Kotak').click
      url1 = $driver.current_url
      expect(url).to eq(url1) # Page should not move forward
    end

    e.run_step 'Verify Updated Commercials as Product' do
      @common_pages.click_menu(MENU_ANCHOR_LIST)
      @common_pages.apply_list_filter({ 'Anchor Name' => @anchor_name })
      @common_pages.navigate_to_anchor(@anchor_name)
      @common_pages.select_program('Vendor Financing')
      @common_pages.click_live_investors
      @common_pages.INVESTOR_LIST('Kotak').click
      values = @commercials_page.get_anchor_commercial_details
      expect(values).to eq @expected_values
    end

    e.run_step 'Product Logs out' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Verify Program Code is not shown to Anchor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['comm_anchor']['email'], $conf['users']['comm_anchor']['password'])).to be true
      @common_pages.click_menu(MENU_PROGRAMS)
      @common_pages.select_program('Vendor Financing')
      @common_pages.click_live_investors
      @common_pages.navigate_to_investor($conf['users']['investor']['name'])
      @expected_values.delete('Program Code')
      values = @commercials_page.get_anchor_commercial_details
      @expected_values = @expected_values.merge('Max Exposure on PO' => '₹ 0', 'Ticket size per channel partner' => '- -')
      expect(values).to eq(@expected_values)
    end

    e.run_step 'Remove anchor commercials' do
      values = {
        investor_actor: 'investor',
        investor_id: 7,
        anchor_id: @anchor_id,
        program_id: $conf['programs']['Invoice Financing - Vendor']
      }
      force_delete_anchor_commercials(values)
    end
  end

  it 'Max Tranche Validation : Max Tranche cannot be greater than D2D', :maxtranche_validation do |e|
    e.run_step 'Login as Investor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['investor']['email'], $conf['users']['investor']['password'])).to be true
    end

    e.run_step 'Validate Max tenor cannot be greater than D2D while Setting up Anchor Commercials' do
      @common_pages.click_menu(MENU_ANCHOR_LIST)
      @common_pages.apply_list_filter({ 'Anchor Name' => @anchor_name })
      @common_pages.navigate_to_anchor(@anchor_name)
      @common_pages.select_program('Vendor Financing')
      @commercials_hash['Door-To-Door Tenor'] = 50
      @commercials_page.add_investor_anchor_commercials(@commercials_hash)
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['MaxTrancheValidation']
      @tarspect_methods.click_button('Cancel')
    end
  end
end
