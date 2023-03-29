require './spec_helper'
describe 'Utilization Report: Verification', :scf, :anchor, :utilization_report, :reports, :mails do
  before(:each) do
    @download_path = "#{Dir.pwd}/test-data/downloaded/utilization_report"
    @driver = Tarspect::Browser.new($conf['browser'], @download_path).invoke
    @tarspect_methods = Common::Methods.new(@driver)
    @transactions_page = Pages::Trasactions.new(@driver)
    @common_pages = Pages::CommonMethods.new(@driver)
    flush_directory(@download_path)
    @program_type = 'Vendor Financing'
  end

  after(:each) do |e|
    snap_screenshot(e)
    quit_browser
  end

  it 'Utilization Report :: Single Program Verification', :utilization_single_program do |e|
    e.run_step 'Login as Anchor : Snapdeal' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['anchor_summary_anchor']['email'], $conf['users']['anchor_summary_anchor']['password'])).to be true
    end

    case @program_type
    when 'Vendor Financing'
      @channel_partner = 'Campus Sutra'
      @user = 'utilization_vendor'
      @investor = 'investor'
    end

    e.run_step "Verify report can be generated for '#{$conf['users'][@user]['name']}', '#{$conf['users'][@investor]['name']}'" do
      values = {
        investor_id: $conf['users'][@investor]['id'],
        program_id: $conf['ui_programs'][@program_type],
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
        'Report Name' => 'Utilization Report',
        'Program Type' => @program_type,
        'Vendor/Dealer' => @channel_partner,
        'Investor' => $conf['users'][@investor]['name']
      }
      expect(@common_pages.generate_report(hash, $conf['users']['anchor_summary_anchor']['email'], 'Utilization Report')).to eq true
    end

    e.run_step 'Verify mail recieved on report generation and verify the file' do
      email_values = {
        mail_box: $conf['notification_mailbox'],
        subject: 'Your report is ready',
        body: ['Dear Snapdeal', 'request for a Utilization Report'],
        link_text: 'utilization_report'
      }
      @report_link = @common_pages.get_link_from_mail(email_values)
      expect(@report_link.empty?).to eq(false), 'File not downloaded'
    end

    e.run_step 'Fetch document' do
      resp = fetch_document('anchor_summary_anchor', get_params_from_uri(@report_link))
      expect(resp[:code]).to eq(200)
      @document_url = resp[:body][:file_url]
    end

    e.run_step 'Verify report with limits' do
      @csv_data = CSV.parse(URI.parse(@document_url).open, headers: true)
      values = { csv_data: @csv_data, program_type: @program_type, channel_partner: @channel_partner, investor: $conf['users'][@investor]['name'] }
      actual_values = validate_utilization_report(values)
      expect(actual_values).not_to eq([]), "Report with #{@program_type}, #{@channel_partner} not found"
      actual_hash = {
        sanction_limit: actual_values[0].to_f.round(2).to_s,
        available_limit: actual_values[1].to_f.round(2).to_s
      }
      expect(@exp_hash).to eq(actual_hash)
    end
  end

  it 'Utilization Report :: Multiple Program Verification' do |e|
    e.run_step 'Login as Anchor : Snapdeal' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['anchor_summary_anchor']['email'], $conf['users']['anchor_summary_anchor']['password'])).to be true
    end

    e.run_step 'Verify report can be generated' do
      @common_pages.click_menu(MENU_REPORTS)
      hash = {
        'Report Name' => 'Utilization Report',
        'Program Type' => @program_type
      }
      expect(@common_pages.generate_report(hash, $conf['users']['anchor_summary_anchor']['email'], 'Utilization Report')).to eq true
    end

    e.run_step 'Verify mail recieved on report generation and verify the file' do
      email_values = {
        mail_box: $conf['notification_mailbox'],
        subject: 'Your report is ready',
        body: ['Dear Snapdeal', 'request for a Utilization Report'],
        link_text: 'utilization_report'
      }
      @report_link = @common_pages.get_link_from_mail(email_values)
      expect(@report_link.empty?).to eq(false), 'File not downloaded'
    end

    e.run_step 'Fetch document' do
      resp = fetch_document('anchor_summary_anchor', get_params_from_uri(@report_link))
      expect(resp[:code]).to eq(200)
      @document_url = resp[:body][:file_url]
    end

    e.run_step 'Verify report with limits' do
      @csv_data = CSV.parse(URI.parse(@document_url).open, headers: true)
      values = { csv_data: @csv_data, program_type: 'Invoice Financing - Vendor', channel_partner: 'West Store As', investor: 'PNB' }
      result = validate_utilization_report(values)
      expect(result).not_to eq([]), "Report with 'West Store As' not found #{result}"
      values = { csv_data: @csv_data, program_type: 'Invoice Financing - Dealer', channel_partner: 'South Deals As', investor: 'PNB' }
      result = validate_utilization_report(values)
      expect(result).not_to eq([]), "Report with 'Campus Sutra' not found #{result}"
    end
  end

  it 'Reports :: Utilization Report :: Access to Product User Verification' do |e|
    e.run_step 'Login as Product' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['product']['email'], $conf['users']['product']['password'])).to be true
    end

    case @program_type
    when 'Vendor Financing'
      @channel_partner = 'Campus Sutra'
      @user = 'utilization_vendor'
      @investor = 'investor'
      @program = 'Invoice Financing'
    end

    e.run_step "Verify report can be generated for '#{$conf['users'][@user]['name']}', '#{$conf['users'][@investor]['name']}'" do
      values = {
        investor_id: $conf['users'][@investor]['id'],
        program_id: $conf['ui_programs'][@program_type],
        vendor_id: $conf['users'][@user]['id'],
        actor: 'anchor_summary_anchor'
      }
      resp = get_available_limits(values)
      expect(resp[:code]).to eq(200)
      @exp_hash = {
        sanction_limit: resp[:body][:available_limits][0][:sanction_limit].to_f,
        available_limit: resp[:body][:available_limits][0][:available_limit].to_f
      }
      @common_pages.click_menu(MENU_REPORTS)
      hash = { 'User Type' => 'Anchor' }
      @tarspect_methods.fill_form(hash, 1, 2)
      @common_pages.select_report_menu('Anchor', 'Snapdeal')
      hash = { 'Report Name' => 'Utilization Report', 'Program Type' => @program_type }
      expect(@common_pages.generate_report(hash, $conf['users']['product']['email'], 'Utilization Report')).to eq true
    end

    e.run_step 'Verify mail recieved on report generation and verify the file' do
      email_values = {
        mail_box: $conf['notification_mailbox'],
        subject: 'Your report is ready',
        body: ['Dear Snapdeal', 'request for a Utilization Report', 'ready for you to download'],
        link_text: 'utilization_report'
      }
      sleep 20
      @report_link = @common_pages.get_link_from_mail(email_values)
      expect(@report_link.empty?).to eq(false), 'File not downloaded'
    end

    e.run_step 'Fetch document' do
      resp = fetch_document('product', get_params_from_uri(@report_link))
      expect(resp[:code]).to eq(200)
      @document_url = resp[:body][:file_url]
    end

    e.run_step 'Verify report with limits' do
      @csv_data = CSV.parse(URI.parse(@document_url).open, headers: true)
      values = { csv_data: @csv_data, program_type: @program, channel_partner: @channel_partner, investor: $conf['users'][@investor]['name'] }
      actual_values = validate_utilization_report(values)
      expect(actual_values).not_to eq([]), "Report with #{@program_type}, #{@channel_partner} not found"
      actual_hash = { sanction_limit: actual_values[0].to_f, available_limit: actual_values[1].to_f }
      expect(actual_hash).to eq(@exp_hash)
    end
  end
end
