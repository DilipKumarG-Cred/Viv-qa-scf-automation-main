require './spec_helper'
describe 'Transactions: Filter Validation', :scf, :transactions, :filter, :filter_transactions, :no_run do
  before(:all) do
    @anchor_actor = 'grn_anchor'
    @anchor_id = $conf['users'][@anchor_actor]['id']
    @vendor_actor = 're_assignment_vendor'
    @vendor_id = $conf['users'][@vendor_actor]['id']
  end

  before(:each) do
    @driver = Tarspect::Browser.new($conf['browser']).invoke
    @tarspect_methods = Common::Methods.new(@driver)
    @common_pages = Pages::CommonMethods.new(@driver)
    @transactions_page = Pages::Trasactions.new(@driver)
    @payments_page = Pages::Payment.new(@driver)
  end

  after(:each) do |e|
    snap_screenshot(e)
    quit_browser
  end

  it 'Transaction : Filter Validation - Anchor' do |e|
    e.run_step 'Login as Anchor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['grn_anchor']['email'], $conf['users']['grn_anchor']['password'])).to be true
    end

    e.run_step 'Verify Filter is properly showing filtered data' do
      @common_pages.click_menu(MENU_PO_FINANCING)
      hash = {
        'Investor' => 'Kotak',
        'Vendor/Dealer' => 'Exide',
        'date_range' => [{ 'Instrument Date' => (Date.today - 7).strftime('%d %b, %Y') }, { 'Instrument Date' => (Date.today - 7).strftime('%d %b, %Y') }]
      }
      @common_pages.apply_list_filter(hash)
      @filtered_list = @transactions_page.get_transactions_in_list_page(page: :investor)
    end

    e.run_step 'Verify Investor is filtered' do
      expect(@filtered_list[:investor].uniq).to eq(['Kotak'])
    end

    e.run_step 'Verify Channel Partner is filtered' do
      expect(@filtered_list[:not_investor].uniq).to eq(['Exide'])
    end
  end

  it 'Transaction : Filter Validation - Vendor' do |e|
    e.run_step 'Login as Vendor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['re_assignment_vendor']['email'], $conf['users']['re_assignment_vendor']['password'])).to be true
    end

    e.run_step 'Verify Filter is properly showing filtered data' do
      @common_pages.click_menu(MENU_PO_FINANCING)
      hash = {
        'Investor' => 'DCB Bank',
        'Anchor' => 'TVS'
      }
      @common_pages.apply_list_filter(hash)
      @filtered_list = @transactions_page.get_transactions_in_list_page(page: :vendor)
    end

    e.run_step 'Verify Investor is filtered' do
      expect(@filtered_list[:investor].uniq).to eq(['DCB Bank'])
    end

    e.run_step 'Verify Anchor is filtered' do
      expect(@filtered_list[:not_investor].uniq).to eq(['TVS'])
    end
  end

  it 'Transaction : Filter Validation - Investor', :investor_filter do |e|
    e.run_step 'Login as Investor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['user_feedback_investor']['email'], $conf['users']['user_feedback_investor']['password'])).to be true
    end

    e.run_step 'Verify Filter is properly showing filtered data' do
      @common_pages.click_menu(MENU_PO_FINANCING)
      hash = {
        'Anchor' => 'Tvs',
        'Vendor/Dealer' => 'Ch29 Stores'
      }
      @common_pages.apply_list_filter(hash)
      @filtered_list = @transactions_page.get_transactions_in_list_page(page: :investor)
    end

    e.run_step 'Verify Investor is filtered' do
      expect(@filtered_list[:investor].uniq).to eq(['TVS'])
    end

    e.run_step 'Verify Anchor is filtered' do
      expect(@filtered_list[:not_investor].uniq).to eq(['CH29 Stores'])
    end

    e.run_step 'Verify Initiation Date is properly filtered out' do
      @common_pages.click_transactions_tab(UP_FOR_DISBURSEMENT)
      values = {
        actor: 'user_feedback_investor',
        program_group: 'po',
        anchor_id: @anchor_id,
        vendor_id: @vendor_id,
        by_group_id: true
      }
      @date_and_counts = fetch_sample_date_and_their_count(values)
      hash = {
        'Anchor' => 'Tvs', 'Vendor/Dealer' => 'Ch29 Stores',
        'date_range' => [{ 'Date Of Initiation' => Date.parse(@date_and_counts[:to_validate_created_at]).strftime('%d %b, %Y') }, { 'Date Of Initiation' => Date.parse(@date_and_counts[:to_validate_created_at]).strftime('%d %b, %Y') }]
      }
      @common_pages.apply_list_filter(hash)
      expect(@payments_page.get_total_count_of_invoices_in_due_for_payments).to eq(@date_and_counts[:count_of_created_at])
    end

    e.run_step 'Verify Instrument Date is properly filtered out' do
      hash = {
        'Anchor' => 'Tvs', 'Vendor/Dealer' => 'Ch29 Stores',
        'date_range' => [{ 'Instrument Date' => Date.parse(@date_and_counts[:to_validate_instrument_date]).strftime('%d %b, %Y') }, { 'Instrument Date' => Date.parse(@date_and_counts[:to_validate_instrument_date]).strftime('%d %b, %Y') }]
      }
      @common_pages.apply_list_filter(hash)
      expect(@payments_page.get_total_count_of_invoices_in_due_for_payments).to eq(@date_and_counts[:count_of_instrument_date])
    end

    e.run_step 'Verify Due Date is properly filtered out' do
      hash = {
        'Anchor' => 'Tvs', 'Vendor/Dealer' => 'Ch29 Stores',
        'date_range' => [{ 'Due Date' => Date.parse(@date_and_counts[:to_validate_due_date]).strftime('%d %b, %Y') }, { 'Due Date' => Date.parse(@date_and_counts[:to_validate_due_date]).strftime('%d %b, %Y') }]
      }
      @common_pages.apply_list_filter(hash)
      expect(@payments_page.get_total_count_of_invoices_in_due_for_payments).to eq(@date_and_counts[:count_of_due_date])
    end
  end

  it 'Transaction : Filter Validation - Product', :product_filter do |e|
    e.run_step 'Login as Product' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['product']['email'], $conf['users']['product']['password'])).to be true
    end

    e.run_step 'Verify Filter is properly showing filtered data' do
      @common_pages.click_menu(MENU_PO_FINANCING)
      hash = {
        'Anchor' => 'Tvs',
        'Vendor/Dealer' => 'Exide',
        'Investor' => 'Kotak'
      }
      @common_pages.apply_list_filter(hash)
      @filtered_list = @transactions_page.get_transactions_in_list_page(page: :product)
    end

    e.run_step 'Verify Investor is filtered' do
      expect(@filtered_list[:investor].uniq).to eq(['Kotak'])
    end

    e.run_step 'Verify Vendor is filtered' do
      expect(@filtered_list[:not_investor].uniq).to eq(['Exide'])
    end

    e.run_step 'Verify Anchor is filtered' do
      expect(@filtered_list[:anchor].uniq).to eq(['TVS'])
    end
  end
end
