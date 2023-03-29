require './spec_helper'
describe 'Anchor: Anchor Onboarding Verification', :scf, :anchor, :anchor_onboarding, :credit do
  before(:all) do
    @driver = Tarspect::Browser.new($conf['browser']).invoke
    @tarspect_methods = Common::Methods.new(@driver)
    @common_pages = Pages::CommonMethods.new(@driver)
    @commercials_page = Pages::Commercials.new(@driver)
  end

  after(:each) do |e|
    snap_screenshot(e)
  end

  it 'Anchor: Anchor Onboarding' do |e|
    e.run_step 'Get an EF client from list and log in' do
      @client_email = get_customer_info
      expect(@client_email).not_to eq nil
      navigate_to($conf['pool_base_url'])
      expect(@tarspect_methods.login(@client_email, $conf['generic_password'])).to be true
    end

    e.run_step "Verify anchor #{@client_email} can be logged in SCF platform" do
      @tarspect_methods.fill_mobile_otp
      @commercials_page.create_scf_login
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq(false)
    end
  end
end
