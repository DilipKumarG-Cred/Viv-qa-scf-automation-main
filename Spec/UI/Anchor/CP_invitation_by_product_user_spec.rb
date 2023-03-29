require './spec_helper'
describe 'Anchor: Channel Partner Invitation by Product User', :scf, :anchor, :cp_invitation_product, :mails do
  before(:all) do
    @erb_file = File.read("#{Dir.pwd}/test-data/erb/commercials_data.erb")
    @anchor_name = 'TVS'
  end

  before(:each) do
    @driver = Tarspect::Browser.new($conf['browser']).invoke
    @tarspect_methods = Common::Methods.new(@driver)
    @commercials_page = Pages::Commercials.new(@driver)
    @common_pages = Pages::CommonMethods.new(@driver)
  end

  it 'Anchor: Channel Partner Invitation by Product User' do |e|
    @testdata = JSON.parse(ERB.new(@erb_file).result(binding))['Commercials']
    @testdata['GSTN'] = "#{Faker::Number.number(digits: 2)}#{@testdata['PAN']}#{Faker::Number.number(digits: 1)}Z#{Faker::Internet.user_name(specifier: 1..1).upcase}"

    e.run_step 'Login as Product' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['product']['email'], $conf['users']['product']['password'])).to be true
    end

    e.run_step 'Add new Dealer' do
      @common_pages.click_menu(MENU_ANCHOR_LIST)
      @common_pages.navigate_to_anchor(@anchor_name)
      @common_pages.select_program('Invoice Financing', 'Dealer')
      @testdata.delete('Program')
      @testdata.delete('Select a Program')
      @commercials_page.add_commercials(@testdata)
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq('Dealer has been invited.')
    end

    e.run_step 'Verify mail received for invitation' do
      email_values = { mail_box: $conf['activation_mailbox'], subject: $notifications['Mail_Welcome_Subject'], body: @testdata['Email'] }
      activation_link = $activation_mail_helper.get_activation_link(email_values)
      expect(activation_link.empty?).to eq(false), 'Activation link is empty'
    end

    e.run_step 'Logout as Product' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Anchor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['grn_anchor']['email'], $conf['users']['grn_anchor']['password'])).to be true
    end

    e.run_step 'Verify Dealer is present in Dealer list' do
      @common_pages.click_menu(MENU_DEALERS)
      expect(@commercials_page.entity_listed?(@testdata['Entity Name'])).to eq true
    end
  end
end
