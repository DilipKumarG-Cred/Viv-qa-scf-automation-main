require './spec_helper'
describe 'Switch User:', :scf, :users, :user_role do
  before(:each) do
    @driver = Tarspect::Browser.new($conf['browser']).invoke
    @tarspect_methods = Common::Methods.new(@driver)
    @common_pages = Pages::CommonMethods.new(@driver)
  end

  after(:each) do |e| # Captures screenshot of the current page when failure happens
    snap_screenshot(e)
    quit_browser
  end

  it 'Switch User:' do |e|
    e.run_step 'Login as product' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['product']['email'], $conf['users']['product']['password'])).to eq true
    end

    e.run_step 'Verify pages and menu loading properly for Product login' do
      expect(@common_pages.wait_for_transactions_to_load).to eq true
      expect(@common_pages.check_for_error_notification?).to eq false
      expect(@common_pages.menu_available?(MENU_ANCHOR_LIST)).to eq true
      expect(@common_pages.menu_available?(MENU_REFUND)).to eq true
    end

    e.run_step 'Switch user as Investor(same entity group) and verify Pages and Menu loads properly' do
      @common_pages.switch_role('CredAvenue Private Limited', 'investor')
      expect(@common_pages.wait_for_transactions_to_load).to eq true
      expect(@common_pages.check_for_error_notification?).to eq false
      expect(@common_pages.menu_available?('Dashboard')).to eq true
      expect(@common_pages.menu_available?(MENU_ANCHOR_LIST)).to eq true
      expect(@common_pages.menu_available?(MENU_REFUND)).to eq true
      expect(@common_pages.menu_available?(MENU_BORROWER_LIST)).to eq true
    end

    e.run_step 'Switch user as Vendor(different entity) and verify Pages and Menu loads properly' do
      @common_pages.switch_role('Libas Impex', 'vendor')
      navigate_to($conf['transactions_url'])
      expect(@common_pages.wait_for_transactions_to_load).to eq true
      expect(@common_pages.check_for_error_notification?).to eq false
      expect(@common_pages.menu_available?('Profile')).to eq true
      expect(@common_pages.menu_available?(MENU_ANCHOR_LIST)).to eq true
    end

    # e.run_step "Switch user as Anchor(different entity) and verify Pages and Menu loads properly" do
    #   @common_pages.switch_role('Mynthra Customer', 'Anchor')
    #   expect(@common_pages.wait_for_transactions_to_load).to eq true
    #   expect(@common_pages.check_for_error_notification?).to eq false
    #   expect(@common_pages.menu_available?('Programs')).to eq true
    #   expect(@common_pages.menu_available?('Vendors')).to eq true
    # end

    e.run_step 'Switch user as Investor(different entity) and verify Pages and Menu loads properly' do
      @common_pages.switch_role('Kotak', 'investor')
      expect(@common_pages.wait_for_transactions_to_load).to eq true
      expect(@common_pages.check_for_error_notification?).to eq false
      expect(@common_pages.menu_available?('Dashboard')).to eq true
      expect(@common_pages.menu_available?(MENU_ANCHOR_LIST)).to eq true
      expect(@common_pages.menu_available?(MENU_REFUND)).to eq true
      expect(@common_pages.menu_available?(MENU_BORROWER_LIST)).to eq true
    end
  end
end
