require './spec_helper'
describe 'Switch Anchor to Credit Platform:', :scf, :anchor, :anchor_switch do
  before(:each) do
    @driver = Tarspect::Browser.new($conf['browser']).invoke
    @tarspect_methods = Common::Methods.new(@driver)
    @common_pages = Pages::CommonMethods.new(@driver)
  end

  after(:each) do |e|
    snap_screenshot(e)
    quit_browser
  end

  it 'Switch :: Anchor to Credit Platform' do |e|
    e.run_step 'Login as Anchor : Myntra' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['anchor']['email'], $conf['users']['anchor']['password'])).to be true
    end
    e.run_step 'Verify Anchor can land in Credit platfrom' do
      expect(@common_pages.switch_to_credit_platform).to include('credit-stg.go-yubi.in')
    end
  end
end
