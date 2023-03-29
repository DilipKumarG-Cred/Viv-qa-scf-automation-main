require './spec_helper'
describe 'Export : Borrowers list', :scf, :export, :export_borrowers_lists, :reports, :mails do
  before(:all) do
    @anchor_actor = 'grn_anchor'
    @vendor_actor = 'tranclub_vendor'
    @vendor_name = $conf['users'][@vendor_actor]['name']
    @anchor_name = $conf['grn_anchor_name']
    @investor_name = $conf['user_feedback_investor']
  end

  before(:each) do
    @driver = Tarspect::Browser.new($conf['browser']).invoke
    @tarspect_methods = Common::Methods.new(@driver)
    @common_pages = Pages::CommonMethods.new(@driver)
  end

  after(:each) do |e|
    snap_screenshot(e)
    quit_browser
  end

  it 'Export: Borrowers List', :sanity, :export_borrowewrs_list do |e|
    e.run_step 'Login as Investor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['user_feedback_investor']['email'], $conf['users']['user_feedback_investor']['password'])).to be true
    end

    e.run_step 'Export Borrowers list data' do
      @common_pages.click_menu(MENU_BORROWER_LIST)
      @common_pages.apply_list_filter({ 'Anchors' => @anchor_name, 'Borrowers' => @vendor_name, 'Channel Partners' => @vendor_name })
      @tarspect_methods.click_button('Export')
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq('please find the exported data in your mailbox!')
    end

    e.run_step 'Verify mail recieved on report generation and verify the file' do
      email_values = {
      mail_box: $conf['notification_mailbox'],
      subject: "Borrower list as on - #{Date.today.strftime('%d-%m-%Y')}",
      body: ['Dear DCB Bank', "borrowers list report as on #{Date.today.strftime('%Y-%m-%d')}"],
      link_text: 'borrower_list'
      }
      @report_link = @common_pages.get_link_from_mail(email_values)
      expect(@report_link.empty?).to eq(false), 'File not downloaded'
    end

    e.run_step 'Fetch document' do
      resp = fetch_document('user_feedback_investor', get_params_from_uri(@report_link))
      expect(resp[:code]).to eq(200)
      @document_url = resp[:body][:file_url]
    end

    e.run_step 'Verify report with limits' do
      @csv_data = CSV.parse(URI.parse(@document_url).open, headers: true)
      values = { csv_data: @csv_data, channel_partner: @vendor_name, investor: @investor_name }
      actual_values, expected_values = validate_borrower_list(values)
      expect(actual_values).to eq(expected_values)
    end
  end
end
