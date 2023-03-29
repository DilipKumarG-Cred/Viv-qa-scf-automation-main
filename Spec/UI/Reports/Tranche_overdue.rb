require './spec_helper'
describe 'Tranche Overdue: Verification', :scf, :anchor, :tranche_overdue_report, :reports, :mails do
  before(:each) do
    @download_path = "#{Dir.pwd}/test-data/downloaded/tranche_overdue_report"
    @driver = Tarspect::Browser.new($conf['browser'], @download_path).invoke
    @tarspect_methods = Common::Methods.new(@driver)
    @common_pages = Pages::CommonMethods.new(@driver)
    @program_type = 'Vendor Financing'
    @channel_partner = 'West Store As'
    @user = 'anchor_summary_vendor'
    @investor = 'mclr_investor'
  end

  after(:each) do |e|
    snap_screenshot(e)
    quit_browser
  end

  it 'Tranche Overdue Report :: Single Program Verification', :tranche_overdue_single_program do |e|
    e.run_step 'Login as Anchor : Snapdeal' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['anchor_summary_anchor']['email'], $conf['users']['anchor_summary_anchor']['password'])).to be true
    end

    e.run_step "Verify report can be generated for '#{$conf['users'][@user]['name']}', '#{$conf['users'][@investor]['name']}'" do
      values = {
        investor_id: $conf['users'][@investor]['id'],
        program_id: $conf['programs'][@program_type],
        vendor_id: $conf['users'][@user]['id'],
        actor: 'anchor_summary_anchor'
      }
      resp = get_available_limits(values)
      expect(resp[:code]).to eq(200)
      @exp_hash = {
        sanction_limit: resp[:body][:available_limits][0][:sanction_limit].to_s,
        available_limit: resp[:body][:available_limits][0][:available_limit].to_s
      }
      @common_pages.click_menu(MENU_REPORTS)
      hash = {
        'Report Name' => 'Tranche Overdue',
        'Program Type' => @program_type,
        'Instrument Type' => 'Invoice',
        'Vendor/Dealer' => @channel_partner,
        'Investor' => $conf['users'][@investor]['name']
      }
      expect(@common_pages.generate_report(hash, $conf['users']['anchor_summary_anchor']['email'], 'Tranche Overdue')).to eq true
    end

    e.run_step 'Verify mail recieved on report generation and verify the file' do
      email_values = {
        mail_box: $conf['notification_mailbox'],
        subject: "Tranche overdue as on - #{Date.today.strftime('%Y-%m-%d')}",
        body: ['Dear Snapdeal', "due report as on #{Date.today.strftime('%Y-%m-%d')}"],
        link_text: 'tranche_overdue'
      }
      @report_link = @common_pages.get_link_from_mail(email_values)
      expect(@report_link.empty?).to eq(false), 'File not downloaded'
      navigate_to($conf['base_url'])
    end

    e.run_step 'Fetch document' do
      resp = fetch_document('anchor_summary_anchor', get_params_from_uri(@report_link))
      expect(resp[:code]).to eq(200)
      @document_url = resp[:body][:file_url]
    end

    e.run_step 'Verify report with limits' do
      @csv_data = CSV.parse(URI.parse(@document_url).open, headers: true)
      values = { csv_data: @csv_data, program_type: @program_type, channel_partner: @channel_partner, investor: $conf['users'][@investor]['name'] }
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @common_pages.click_transactions_tab(DUE_FOR_REPAYMENT)
      @common_pages.apply_list_filter({ 'Vendor/Dealer' => values[:channel_partner].capitalize, 'Investor' => values[:investor].capitalize })
      @tarspect_methods.click_button('View Detail')
      @tarspect_methods.wait_for_loader_to_disappear(MAX_LOADER_TIME)
      actual_values, expected_value = validate_tranche_overdue(values)
      expect(actual_values).not_to eq([]), "Could not find any dues as on #{Date.today.strftime('%Y-%m-%d')}"
      expect(actual_values).to eq(expected_value)
    end
  end
end
