require './spec_helper'
describe 'Transactions: Sort Transactions', :scf, :transactions, :sort, :no_run do
  before(:all) do
    @anchor_gstn = $conf['myntra_gstn']
    @counterparty_gstn = $conf['zudio_gstn']
    @vendor_name = $conf['mip_vendor_name']
    @anchor_name = $conf['anchor_name']
    @investor_name = $conf['investor_name']
  end

  before(:each) do
    @driver = Tarspect::Browser.new($conf['browser']).invoke
    @tarspect_methods = Common::Methods.new(@driver)
    @common_pages = Pages::CommonMethods.new(@driver)
    @transactions_page = Pages::Trasactions.new(@driver)
  end

  after(:each) do |e|
    snap_screenshot(e)
    quit_browser
  end

  it 'Transaction : Sort Validation - Vendor' do |e|
    e.run_step 'Login as Vendor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['zudio_vendor']['email'], $conf['users']['zudio_vendor']['password'])).to be true
    end

    e.run_step 'Sort Transactions basis Initiation Date ' do
      @common_pages.click_menu(MENU_PO_FINANCING)
      @common_pages.SIMPLE_XPATH('Initiation Date').click
      expected_asc_values = ['17 Jan, 2022', '18 Jan, 2022', '19 Jan, 2022', '20 Jan, 2022', '21 Jan, 2022', '23 Jan, 2022', '24 Jan, 2022', '25 Jan, 2022', '27 Jan, 2022']
      ascending_list_items = @transactions_page.get_transactions_in_list_page(page: :vendor)
      asc_date_values = ascending_list_items[:initiation_date].uniq
      expect(asc_date_values).to eq(expected_asc_values)
      @common_pages.SIMPLE_XPATH('Initiation Date').click
      descending_list_items = @transactions_page.get_transactions_in_list_page(page: :vendor)
      desc_date_values = descending_list_items[:initiation_date].uniq
      expect(compare_dates(desc_date_values, sort: :desc)).to eq(true)
      @common_pages.SIMPLE_XPATH('Initiation Date').click
    end

    e.run_step 'Sort Transaction basis Instrument Date' do
      @common_pages.SIMPLE_XPATH('Instrument Date').click
      @asc_txn_date = @transactions_page.get_transactions_in_list_page(page: :vendor)
      asc_txn_date_values = @asc_txn_date[:instrument_date].uniq
      expect(compare_dates(asc_txn_date_values, sort: :asc)).to eq(true)
      @common_pages.SIMPLE_XPATH('Instrument Date').click
      @desc_txn_date = @transactions_page.get_transactions_in_list_page(page: :vendor)
      desc_txn_date_values = @desc_txn_date[:instrument_date].uniq
      expect(compare_dates(desc_txn_date_values, sort: :desc)).to eq(true)
      @common_pages.SIMPLE_XPATH('Instrument Date').click
    end

    e.run_step 'Sort Transaction basis Due Date' do
      @common_pages.SIMPLE_XPATH('Due Date').click
      @asc_due_date = @transactions_page.get_transactions_in_list_page(page: :vendor)
      asc_due_date_values = @asc_due_date[:due_date].uniq
      expect(compare_dates(asc_due_date_values, sort: :asc)).to eq(true)
      @common_pages.SIMPLE_XPATH('Due Date').click
      @desc_due_date = @transactions_page.get_transactions_in_list_page(page: :vendor)
      desc_due_date_values = @desc_due_date[:due_date].uniq
      expect(compare_dates(desc_due_date_values, sort: :desc)).to eq(true)
      @common_pages.SIMPLE_XPATH('Due Date').click
    end
  end
end
