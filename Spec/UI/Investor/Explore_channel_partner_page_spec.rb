require './spec_helper'
describe 'Explore Channel Partner', :scf, :explore_channel_partner do
  before(:all) do
    @investor_actor = 'investor'
    @erb_file = File.read("#{Dir.pwd}/test-data/erb/commercials_data.erb")
  end

  before(:each) do
    @driver = Tarspect::Browser.new($conf['browser']).invoke
    @tarspect_methods = Common::Methods.new(@driver)
    @common_pages = Pages::CommonMethods.new(@driver)
    @commercials_page = Pages::Commercials.new(@driver)
    @created_vendor = []
  end

  after(:each) do |e| # Captures screenshot of the current page when failure happens
    snap_screenshot(e)
    quit_browser
  end

  it 'Explore Channel Partner - Investor' do |e|
    e.run_step 'Onboard a vendor' do
      @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
      @testdata['Commercials']['Select a Program'] = 'Invoice Financing - Vendor Program'
      @testdata['Commercials']['Program'] = 'Invoice Financing - Vendor Program'
      @commercials_data = @testdata['Commercials']
      @company_info = @testdata['Company Info']
      @promoter_info = @testdata['Promoter Info']
      @commercials_data['GSTN'] = "#{Faker::Number.number(digits: 2)}#{@commercials_data['PAN']}#{Faker::Number.number(digits: 1)}Z#{Faker::Internet.user_name(specifier: 1..1).upcase}"
      expect(api_create_registered_channel_partner(@testdata)).to eq true
      @created_vendor << @commercials_data['Entity Name']
      @commercials_data['Name'] = @commercials_data['Entity Name']
      expect(api_approve_all_docs_and_vendor(@testdata, 'mandatory_docs')).to eq true
    end

    e.run_step 'Login as Investor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users'][@investor_actor]['email'], $conf['users'][@investor_actor]['password'])).to eq true
    end

    e.run_step 'Verify whether the investor can landed in the Shortlisted page while navigating to the Explore channel partner menu' do
      @common_pages.click_menu(MENU_EXPLORE_CHANNEL_PARTNERS)
      expect(@driver.current_url).to include('shortlisted')
    end

    e.run_step 'Verify whether the shortlist, dropped and new section available in the explore CP page' do
      expect(@tarspect_methods.BUTTON('Shortlisted').is_displayed?).to eq true
      expect(@tarspect_methods.BUTTON('Dropped').is_displayed?).to eq true
      expect(@tarspect_methods.BUTTON('New').is_displayed?).to eq true
    end

    e.run_step 'verify whether the newly onboarded Channel partner is present in the New action section' do
      @tarspect_methods.click_button('New')
      @common_pages.search_program(@commercials_data['Name'])
      expect(@common_pages.vendor_present(@commercials_data['Name'])).to eq true
      refresh_page
    end

    e.run_step 'Search whether the channel partner is present in the New section page' do
      @tarspect_methods.click_button('New')
      @common_pages.search_program(@commercials_data['Name'])
      @common_pages.vendor_details.click
      @common_pages.click_back_button
    end

    [['asc', 'Entity Name', 2], ['desc', 'Entity Name', 2], ['asc', 'Anchor Name', 3], ['desc', 'Anchor Name', 3], [:asc, 'Onboarded Date', 11], [:desc, 'Onboarded Date', 11]].each do |value|
      e.run_step "Verify the #{value[1]} column in New section should be in #{value[0]} order" do
        @common_pages.SIMPLE_XPATH(value[1]).click
        page_datas = @common_pages.get_all_page_datas(value[2]).uniq
        if value[1].eql?('Onboarded Date')
          expect(compare_dates(page_datas, sort: value[0])).to eq(true)
        else
          expect(compare_values(page_datas, value[0])).to eq(true)
        end
      end
    end

    e.run_step 'Shortlist the newly onboarded channel partner' do
      @common_pages.search_program(@commercials_data['Name'])
      @common_pages.vendor_details.click
      @tarspect_methods.click_button('Shortlist')
      expect(@commercials_page.shortlist.text).to eq 'Shortlisted'
      @common_pages.click_back_button
    end

    e.run_step 'Search for the newly Shortlisted channel partner' do
      @tarspect_methods.click_button('Shortlisted')
      @common_pages.search_program(@commercials_data['Name'])
      @common_pages.vendor_details.click
      expect(@commercials_page.shortlist.text).to eq 'Shortlisted'
    end

    e.run_step 'Verify the shortlisted channel partner should be there in shortlisted section' do
      @common_pages.click_menu(MENU_EXPLORE_CHANNEL_PARTNERS)
      expect(@common_pages.shortlisted_by.is_displayed?).to eq true
      expect(@common_pages.yubi_team.is_displayed?).to eq true
      expect(@common_pages.investor.is_displayed?).to eq true
      @common_pages.search_program(@commercials_data['Name'])
      expect(@common_pages.vendor_present(@commercials_data['Name'])).to eq true
      expect(@common_pages.get_each_page_datas(4)[0].gsub("\n", ' ')).to include("By #{$conf['users'][@investor_actor]['name'].downcase}")
      @common_pages.vendor_details.click
      expect(@common_pages.company_information.is_displayed?).to eq true
    end

    e.run_step 'Verify whether the channel partner who linked with other investor will not be there in New section' do
      @common_pages.click_menu(MENU_EXPLORE_CHANNEL_PARTNERS)
      @tarspect_methods.click_button('New')
      refresh_page
      @common_pages.search_program(@commercials_data['Name'])
      expect(@common_pages.vendor_present(@commercials_data['Name'])).to eq false
    end

    e.run_step 'verify the column names present in the shortlisted section' do
      @tarspect_methods.click_button('Shortlisted')
      expected_data = ['Entity Name',
                       'Anchor Name',
                       'Program',
                       'Shortlisted Date',
                       'Total Revenue (₹)',
                       'Vintage with Anchors',
                       'Dependency on Anchor (%)',
                       'Business with Anchor (₹)',
                       'EBITDA (%)',
                       'Entity Type', 'GST Verification Status',
                       'State(s)']
      expect(@common_pages.explore_container_col_names.text.split("\n")).to eq(expected_data)
    end

    [['asc', 'Entity Name', 1], ['desc', 'Entity Name', 1], ['asc', 'Anchor Name', 2], ['desc', 'Anchor Name', 2], [:asc, 'Shortlisted Date', 4], [:desc, 'Shortlisted Date', 4]].each do |value|
      e.run_step "Verify the #{value[1]} column in Shortlisted section should be in #{value[0]} order" do
        @common_pages.SIMPLE_XPATH(value[1]).click
        page_datas = @common_pages.get_all_page_datas(value[2]).uniq
        if value[1].eql?('Shortlisted Date')
          expect(compare_dates(page_datas, sort: value[0])).to eq(true)
        else
          expect(compare_values(page_datas, value[0])).to eq(true)
        end
      end
    end
  end

  it 'Internal Team view funnel recommondation and drop the channel partners' do |e|
    e.run_step 'Onboard a channel partner' do
      @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
      @testdata['Commercials']['Select a Program'] = 'Invoice Financing - Vendor Program'
      @testdata['Commercials']['Program'] = 'Invoice Financing - Vendor Program'
      @commercials_data = @testdata['Commercials']
      @company_info = @testdata['Company Info']
      @promoter_info = @testdata['Promoter Info']
      @commercials_data['GSTN'] = "#{Faker::Number.number(digits: 2)}#{@commercials_data['PAN']}#{Faker::Number.number(digits: 1)}Z#{Faker::Internet.user_name(specifier: 1..1).upcase}"
      expect(api_create_registered_channel_partner(@testdata)).to eq true
      @created_vendor << @commercials_data['Entity Name']
      @commercials_data['Name'] = @commercials_data['Entity Name']
      expect(api_approve_all_docs_and_vendor(@testdata, 'mandatory_docs')).to eq true
    end

    e.run_step 'Login as Product' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['product']['email'], $conf['users']['product']['password'])).to be true
    end

    e.run_step 'Verify whether the shortlisted and dropped options are available in the Investor funnel view' do
      @common_pages.click_menu(MENU_EXPLORE_CHANNEL_PARTNERS)
      @common_pages.click_menu(MENU_INVESTOR_FUNNEL)
      expect(@tarspect_methods.BUTTON('Shortlisted').is_displayed?).to eq true
      expect(@tarspect_methods.BUTTON('Dropped').is_displayed?).to eq true
    end

    e.run_step 'Verify that the user can able to select the investor whose funnel they want to view' do
      @common_pages.investor_drp_down.click
      @common_pages.investor.click
      expect(@common_pages.verify_actor_present_in_all_pages($conf['users'][@investor_actor]['name'], 3)).to eq true
    end

    e.run_step 'Logout as Product' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Investor' do
      expect(@tarspect_methods.login($conf['users'][@investor_actor]['email'], $conf['users'][@investor_actor]['password'])).to eq true
    end

    e.run_step 'Drop the newly onboarded channel partner from the investor login and verify the dropped reason is present' do
      @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
      @drop_reason = @testdata['Reject Reason']
      @common_pages.click_menu(MENU_EXPLORE_CHANNEL_PARTNERS)
      @tarspect_methods.click_button('New')
      @common_pages.search_program(@commercials_data['Name'])
      @common_pages.vendor_details.click
      message, actual_data = @commercials_page.check_drop('Drop', @drop_reason)
      expect(message.text).to eq 'Channel Partner dropped.'
      expected_data = [@drop_reason, 'Crime check failed', 'CIBIL issues']
      expect(actual_data).to eq(expected_data)
    end

    e.run_step 'Verify the dropped channel partner is present in the dropped section' do
      @common_pages.click_menu(MENU_EXPLORE_CHANNEL_PARTNERS)
      @tarspect_methods.click_button('Dropped')
      @common_pages.search_program(@commercials_data['Name'])
      expect(@common_pages.vendor_present(@commercials_data['Name'])).to eq true
      @common_pages.vendor_details.click
      expect(@common_pages.company_information.is_displayed?).to eq true
      @common_pages.click_back_button
    end

    e.run_step 'Search for the dropped channel partner in dropped section' do
      @tarspect_methods.click_button('Dropped')
      @common_pages.search_program(@commercials_data['Name'])
      expect(@common_pages.vendor_present(@commercials_data['Name'])).to eq true
    end

    e.run_step 'verify whether the dropped date is present in the dropped section' do
      @common_pages.click_menu(MENU_EXPLORE_CHANNEL_PARTNERS)
      @tarspect_methods.click_button('Dropped')
      @common_pages.search_program(@commercials_data['Name'])
      expect(@common_pages.explore_container_col_names.text.gsub("\n", ' ')).to include('Dropped Date')
      expect(@common_pages.get_each_page_datas(8)[0].gsub("\n", ' ')).to include("By #{$conf['users'][@investor_actor]['name'].downcase}")
    end

    e.run_step 'verify the column names present in the Dropped section' do
      expected_data = ['Entity Name',
                       'Anchor Name',
                       'Program',
                       'Total Revenue (₹)',
                       'Vintage with Anchors',
                       'Dependency on Anchor (%)',
                       'Dropped Date',
                       'Dropped Reason',
                       'Business with Anchor (₹)',
                       'EBITDA (%)',
                       'Entity Type',
                       'GST Verification Status',
                       'State(s)']
      expect(@common_pages.explore_container_col_names.text.split("\n")).to eq(expected_data)
      refresh_page
    end

    [['asc', 'Entity Name', 2], ['desc', 'Entity Name', 2], ['asc', 'Anchor Name', 3], ['desc', 'Anchor Name', 3], [:asc, 'Dropped Date', 8], [:desc, 'Dropped Date', 8]].each do |value|
      e.run_step "Verify the #{value[1]} column in Dropped section should be in #{value[0]} order" do
        @common_pages.SIMPLE_XPATH(value[1]).click
        page_datas = @common_pages.get_all_page_datas(value[2]).uniq
        if value[1].eql?('Dropped Date')
          expect(compare_dates(page_datas, sort: value[0])).to eq(true)
        else
          expect(compare_values(page_datas, value[0])).to eq(true)
        end
      end
    end

    e.run_step 'Logout as Investor' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Product' do
      expect(@tarspect_methods.login($conf['users']['product']['email'], $conf['users']['product']['password'])).to be true
    end

    e.run_step 'Verify the newly onboarded channel partner is present in the New section of internal team view' do
      @common_pages.click_menu(MENU_EXPLORE_CHANNEL_PARTNERS)

      @common_pages.search_program(@commercials_data['Name'])
      expect(@common_pages.vendor_present(@commercials_data['Name'])).to eq true
    end

    e.run_step 'Verify the dropped channel partner by investor is present in the dropped section of the internal team investor funnel section' do
      @common_pages.click_menu(MENU_INVESTOR_FUNNEL)
      @tarspect_methods.click_button('Dropped')
      refresh_page
      @common_pages.search_program(@commercials_data['Name'])
      expect(@common_pages.vendor_present(@commercials_data['Name'])).to eq true
    end

    e.run_step 'Verify the dropped channel parter should be recommonded to the investor' do
      @common_pages.vendor_details.click
      expect(@tarspect_methods.BUTTON('Recommend').is_displayed?).to eq true
      @tarspect_methods.click_button('Recommend')
      @tarspect_methods.wait_for_loader_to_disappear(MAX_LOADER_TIME)
      @common_pages.select_investor.click
      @common_pages.investor.click
      @common_pages.select_investor.click
      @tarspect_methods.click_button('Submit')
      expect(@common_pages.recommonded_message.text).to eq $notifications['RecommondedMessage']
    end

    e.run_step 'Verify recommonded channel partner should be there in shortlisted section' do
      @common_pages.click_menu(MENU_INVESTOR_FUNNEL)
      @common_pages.search_program(@commercials_data['Name'])
      expect(@common_pages.vendor_present(@commercials_data['Name'])).to eq true
    end

    e.run_step 'Logout as Product' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Investor' do
      expect(@tarspect_methods.login($conf['users'][@investor_actor]['email'], $conf['users'][@investor_actor]['password'])).to eq true
    end

    e.run_step 'Verify the recommonded channel partner should be there in shortlisted section in the explore channel partner page and drop the channel partner' do
      @common_pages.click_menu(MENU_EXPLORE_CHANNEL_PARTNERS)
      @common_pages.search_program(@commercials_data['Name'])
      expect(@common_pages.vendor_present(@commercials_data['Name'])).to eq true
      @common_pages.vendor_details.click
      message, actual_data = @commercials_page.check_drop('Drop', @drop_reason)
    end

    e.run_step 'Verify channel partner can be shortlisted from the dropped section' do
      @common_pages.click_menu(MENU_EXPLORE_CHANNEL_PARTNERS)
      @tarspect_methods.click_button('Dropped')
      @common_pages.search_program(@commercials_data['Name'])
      @common_pages.vendor_details.click
      message, shortlist, drop_button, set_limit_button = @commercials_page.check_shortlist
      expect(message.text).to eq 'Channel Partner shortlisted.'
      expect(shortlist).to eq 'Shortlisted'
      expect(drop_button).to eq true
      expect(set_limit_button).to eq true
    end
  end
end
