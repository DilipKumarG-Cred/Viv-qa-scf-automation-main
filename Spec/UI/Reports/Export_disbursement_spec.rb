require './spec_helper'
describe 'Export : Up for Disbursement', :scf, :export, :export_disbursements, :reports, :mails do
  before(:all) do
    @anchor_actor = 'grn_anchor'
    @vendor_actor = 'tranclub_vendor'
    @party_gstn = $conf['users'][@anchor_actor]['gstn']
    @counterparty_gstn = $conf['users'][@vendor_actor]['gstn']
    @vendor_name = $conf['users'][@vendor_actor]['name']
    @anchor_name = $conf['grn_anchor_name']
    @investor_name = $conf['user_feedback_investor']
    @invoice_file = "#{Dir.pwd}/test-data/attachments/anchor_invoice.pdf"
    @erb_file = File.read("#{Dir.pwd}/test-data/erb/testbed_data.erb")
    @po_details = JSON.parse(ERB.new(@erb_file).result(binding))['PO Details']
  end

  before(:each) do
    @driver = Tarspect::Browser.new($conf['browser']).invoke
    @tarspect_methods = Common::Methods.new(@driver)
    @common_pages = Pages::CommonMethods.new(@driver)
    @investor_page = Pages::Investor.new(@driver)
  end

  after(:each) do |e|
    snap_screenshot(e)
    quit_browser
  end

  it 'Export: Up for Disbursement', :sanity, :export_disbursement, :no_run do |e|
    e.run_step 'Login as Investor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['user_feedback_investor']['email'], $conf['users']['user_feedback_investor']['password'])).to be true
    end

    e.run_step 'Create transaction (Draft -> Released)' do
      @transaction_id = seed_transaction(
        {
          actor: @anchor_actor,
          counter_party: @vendor_actor,
          po_details: @po_details,
          po_file: @invoice_file,
          program: 'PO Financing - Vendor',
          investor_id: 9,
          skip_counterparty_approval: true,
          program_group: 'purchase_order'
        }
      )
      expect(@transaction_id).not_to include('Error while creating transaction')
    end

    e.run_step 'Export Disbursement data' do
      @common_pages.click_menu(MENU_PO_FINANCING)
      @common_pages.click_transactions_tab(UP_FOR_DISBURSEMENT)
      @common_pages.export.click
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq('please find the exported data in your mailbox!')
    end

    e.run_step 'Verify mail received with disbursement data on clicking report' do
      sleep 10 # For report generation
      email_values = {
        mail_box: $conf['notification_mailbox'],
        subject: "Up for disbursement report as on - #{Date.today.strftime('%d-%m-%Y')}",
        body: ["Dear #{@investor_name}", 'up for disbursement report'],
        link_text: 'up_for_disbursement_instrument_report'
      }
      @report_link = @common_pages.get_link_from_mail(email_values)
      expect(@report_link.empty?).to eq(false), 'File not present'
    end

    e.run_step 'Fetch document' do
      resp = fetch_document('user_feedback_investor', get_params_from_uri(@report_link))
      expect(resp[:code]).to eq(200)
      @document_url = resp[:body][:file_url]
    end

    e.run_step 'Verify exported data' do
      @csv_data = CSV.parse(URI.parse(@document_url).open, headers: true)
      report_hash, exp_hash = @investor_page.validate_export_disbursement(@csv_data, @transaction_id)
      expect(report_hash).to eq(exp_hash)
    end

    e.run_step 'Export Disbursement data with filter' do
      @common_pages.apply_list_filter(
        {
          'Vendor/Dealer' => 'Stg Tranclub',
          'Anchor' => 'Tvs',
          'date_range' => [{ 'Date Of Initiation' => @po_details['PO Date'] }, { 'Date Of Initiation' => @po_details['PO Date'] }]
        }
      )
      @common_pages.export.click
      expect(@common_pages.check_for_error_notification?).to eq false
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq('please find the exported data in your mailbox!')
    end

    e.run_step 'Verify mail received with disbursement data on clicking report' do
      sleep 10 # For report generation
      email_values = {
        mail_box: $conf['notification_mailbox'],
        subject: "Up for disbursement report as on - #{Date.today.strftime('%d-%m-%Y')}",
        body: ["Dear #{@investor_name}", 'up for disbursement report'],
        link_text: 'up_for_disbursement_instrument_report'
      }
      @report_link = @common_pages.get_link_from_mail(email_values)
      expect(@report_link.empty?).to eq(false), 'File not present'
    end

    e.run_step 'Fetch document' do
      resp = fetch_document('user_feedback_investor', get_params_from_uri(@report_link))
      expect(resp[:code]).to eq(200)
      @document_url = resp[:body][:file_url]
    end

    e.run_step 'Verify exported data' do
      @csv_data = CSV.parse(URI.parse(@document_url).open, headers: true)
      report_hash, exp_hash = @investor_page.validate_export_disbursement(@csv_data, @transaction_id)
      expect(report_hash).to eq(exp_hash)
      fields = [['Anchor name', 'Channel partner name'], %i[anchor vendor]]
      expect(@investor_page.validate_export_contains_only_filtered_data(@csv_data, @transaction_id, fields)).to eq(true), 'Report contains unfiltered data'
    end
  end
end
