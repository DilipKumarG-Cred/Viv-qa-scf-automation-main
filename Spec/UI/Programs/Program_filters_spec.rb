require './spec_helper'
describe 'Program Filters: Verification', :scf, :commercials, :program_filters, :no_run do
  before(:all) do
    @anchor_name = $conf['users']['commercials_anchor']['name']
  end

  before(:each) do
    @driver = Tarspect::Browser.new($conf['browser']).invoke
    @tarspect_methods = Common::Methods.new(@driver)
    @common_pages = Pages::CommonMethods.new(@driver)
    @commercials_page = Pages::Commercials.new(@driver)
    @programs_page = Pages::Programs.new(@driver)
    @transactions_page = Pages::Trasactions.new(@driver)
    @choose_program_values = {
      header: 'Explore Programs',
      where: 'investor_explore',
      anchor: @anchor_name,
      validate_only: true,
      type: ''
    }
  end

  after(:each) do |e|
    snap_screenshot(e)
    quit_browser
  end

  it 'Program Filters: Verification' do |e|
    e.run_step 'Login as Investor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['mclr_investor']['email'], $conf['users']['mclr_investor']['password'])).to eq true
    end

    e.run_step 'Verify only listed anchor ratings are shown in drop down' do
      @common_pages.click_menu(MENU_EXPLORE_PROGRAMS)
      expected_ratings = ['A', 'A-', 'A+', 'AA', 'AA-', 'AA+', 'AAA', 'B', 'B-', 'B+', 'BB', 'BB-', 'BB+', 'BBB', 'BBB-', 'BBB+', 'C', 'C-', 'C+', 'Unrated']
      expect(@programs_page.verify_multiple_values_can_be_chosen).to eq(expected_ratings)
    end

    e.run_step 'Verify anchor with ratings are shown properly' do
      @program_type = 'Purchase Order Financing - Dealer'
      hash = { 'Anchor Rating' => 'B+' }
      @common_pages.apply_filter(hash)
      @choose_program_values[:type] = @program_type
      @choose_program_values[:anchor] = 'Boat Mics'
      expect(@programs_page.investor_choose_program(@choose_program_values)).to eq(true)
    end

    e.run_step 'Verify Anchors with Industry filter shown properly' do
      hash = { 'Industry' => 'Automobiles' }
      @common_pages.apply_filter(hash)
      @choose_program_values[:type] = @program_type
      @choose_program_values[:anchor] = 'Arvind Mills'
      expect(@programs_page.investor_choose_program(@choose_program_values)).to eq(true)
    end

    e.run_step 'Verify Anchors with multiple Industry filter shown properly' do
      @common_pages.clear_filter.click
      @tarspect_methods.wait_for_loader_to_disappear
      @common_pages.filter.click
      hash = { 'Industry' => 'Automobiles' }
      @tarspect_methods.fill_form(hash, 1, 2)
      hash = { 'Industry' => 'Oil, Gas & Consumable Fuels' }
      @tarspect_methods.fill_form(hash, 1, 2)
      @tarspect_methods.click_button('Apply')
      @choose_program_values[:type] = @program_type
      @choose_program_values[:anchor] = 'Arvind Mills'
      expect(@programs_page.investor_choose_program(@choose_program_values)).to eq(true)
      @choose_program_values[:anchor] = 'GMR Infra'
      expect(@programs_page.investor_choose_program(@choose_program_values)).to eq(true)
    end

    e.run_step 'Verify Programs with Program Type filter' do
      @program_type = 'Invoice Financing - Vendor'
      hash = { 'Program Type' => 'Invoice Financing - Vendor Program' }
      @common_pages.apply_filter(hash)
      @choose_program_values[:type] = @program_type
      @choose_program_values[:anchor] = 'Arvind Mills'
      expect(@programs_page.investor_choose_program(@choose_program_values)).to eq(true)
    end

    e.run_step 'Verify Programs with multiple Program Type filter' do
      @common_pages.clear_filter.click
      @tarspect_methods.wait_for_loader_to_disappear
      @common_pages.filter.click
      program_type = ['Invoice Financing - Vendor Program', 'Invoice Financing - Dealer Program']
      hash = { 'Program Type' => program_type[0] }
      @tarspect_methods.fill_form(hash, 1, 2)
      hash = { 'Program Type' => program_type[1] }
      @tarspect_methods.fill_form(hash, 1, 2)
      @tarspect_methods.click_button('Apply')
      expect(@programs_page.get_all_program_lists).to eq(['Invoice Financing - Vendor', 'Invoice Financing - Dealer'])
    end

    e.run_step 'Verify Programs are listed on Program size filter' do
      values = { 'Program Size' => [1000, 8000] }
      @programs_page.apply_slider_filter_in_programs(values)
      @choose_program_values[:type] = 'Invoice Financing - Vendor'
      @choose_program_values[:anchor] = 'GMR Infra'
      expect(@programs_page.investor_choose_program(@choose_program_values)).to eq(true)
      @choose_program_values[:type] = 'Invoice Financing - Dealer'
      @choose_program_values[:anchor] = 'Myntra'
      expect(@programs_page.investor_choose_program(@choose_program_values)).to eq(false)
    end

    e.run_step 'Verify Programs are listed on Expected Pricing filter' do
      values = { 'Expected Pricing' => [11, 15] }
      @programs_page.apply_slider_filter_in_programs(values)
      @choose_program_values[:type] = 'Purchase Order Financing - Vendor'
      @choose_program_values[:anchor] = 'Myntra'
      expect(@programs_page.investor_choose_program(@choose_program_values)).to eq(false)
      @choose_program_values[:type] = 'Invoice Financing - Vendor'
      @choose_program_values[:anchor] = 'Arvind Mills'
      expect(@programs_page.investor_choose_program(@choose_program_values)).to eq(true)
    end

    e.run_step 'Verify Programs are listed based on Tenure' do
      values = { 'Tenure' => [70, 79] }
      @programs_page.apply_slider_filter_in_programs(values)
      @choose_program_values[:type] = 'Invoice Financing - Dealer'
      @choose_program_values[:anchor] = 'Myntra'
      expect(@programs_page.investor_choose_program(@choose_program_values)).to eq(true)
      @choose_program_values[:type] = 'Purchase Order Financing - Dealer'
      @choose_program_values[:anchor] = 'Boat Mics'
      expect(@programs_page.investor_choose_program(@choose_program_values)).to eq(false)
    end

    e.run_step 'Verify Programs are listed based on EBITDA' do
      values = { 'EBITDA' => [-4, 100] }
      @programs_page.apply_slider_filter_in_programs(values)
      @choose_program_values[:type] = 'Purchase Order Financing - Dealer'
      @choose_program_values[:anchor] = 'Myntra'
      expect(@programs_page.investor_choose_program(@choose_program_values)).to eq(true)
      @choose_program_values[:type] = 'Invoice Financing - Dealer'
      @choose_program_values[:anchor] = 'BBOEHM-163465367134'
      expect(@programs_page.investor_choose_program(@choose_program_values)).to eq(false)
    end
  end
end
