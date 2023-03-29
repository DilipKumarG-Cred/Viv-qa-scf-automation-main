require './spec_helper'
describe 'Export : Due for Repayment', :scf, :payments, :export, :reports, :mails do
  before(:all) do
    @anchor_actor = 'grn_anchor'
    @vendor_actor = 'tranclub_vendor'
    @party_gstn = $conf['users'][@anchor_actor]['gstn']
    @counterparty_gstn = $conf['users'][@vendor_actor]['gstn']
    @vendor_name = $conf['users'][@vendor_actor]['name']
    @anchor_name = $conf['grn_anchor_name']
    @investor_name = $conf['user_feedback_investor']
    @invoice_file = "#{Dir.pwd}/test-data/attachments/anchor_invoice.pdf"
    @payment_proof = "#{Dir.pwd}/test-data/attachments/payment_proof.pdf"
    @erb_file = File.read("#{Dir.pwd}/test-data/erb/testbed_data.erb")
    @po_details = JSON.parse(ERB.new(@erb_file).result(binding))['PO Details']
    clear_all_overdues({ anchor: @anchor_name, vendor: @vendor_name, investor: 'user_feedback_investor' })
  end

  before(:each) do
    @driver = Tarspect::Browser.new($conf['browser']).invoke
    @tarspect_methods = Common::Methods.new(@driver)
    @common_pages = Pages::CommonMethods.new(@driver)
    @disbursement_page = Pages::Disbursement.new(@driver)
    @investor_page = Pages::Investor.new(@driver)
  end

  after(:each) do |e|
    snap_screenshot(e)
    quit_browser
  end

  it 'Export: Due for repayments', :sanity do |e|
    e.run_step 'Login as Vendor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users'][@vendor_actor]['email'], $conf['users'][@vendor_actor]['password'])).to be true
    end

    e.run_step 'Create transaction (Draft -> Disbursed)' do
      @po_details['PO Date'] = (Date.today - 60).strftime('%d-%b-%Y')
      @transaction_id = seed_transaction(
        {
          actor: @anchor_actor,
          counter_party: @vendor_actor,
          po_details: @po_details,
          po_file: @invoice_file,
          program: 'PO Financing - Vendor',
          investor_id: 9,
          program_group: 'purchase_order'
        }
      )
      expect(@transaction_id).not_to include('Error while creating transaction')
      @details = disburse_transaction(
        {
          transaction_id: @transaction_id,
          invoice_value: @po_details['Requested Disbursement Value'],
          type: 'frontend',
          date_of_payment: Date.parse(@po_details['PO Date'], '%Y-%b-%d').strftime('%d-%b-%Y'),
          payment_proof: @payment_proof,
          program: 'PO Financing - Vendor',
          tenor: 60,
          yield: 10,
          investor_actor: 'user_feedback_investor',
          margin: 10
        }
      )
      expect(@details).not_to include('Error while disbursements')
    end

    e.run_step 'Export due for repayment data' do
      @common_pages.click_menu(MENU_PO_FINANCING)
      @common_pages.click_transactions_tab(DUE_FOR_REPAYMENT)
      @common_pages.export.click
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq('please find the exported data in your mailbox!')
    end

    e.run_step 'Verify mail received with repayment data on clicking report' do
      sleep 10 # For report generation
      email_values = {
        mail_box: $conf['notification_mailbox'],
        subject: "Repayment due as on - #{Date.today.strftime('%Y-%m-%d')}",
        body: ["Dear #{@vendor_name}", 'Due for Repayment'],
        link_text: 'repayment_due'
      }
      @report_link = @common_pages.get_link_from_mail(email_values)
      expect(@report_link.empty?).to eq(false), 'File not downloaded'
    end

    e.run_step 'Fetch document' do
      resp = fetch_document(@vendor_actor, get_params_from_uri(@report_link))
      expect(resp[:code]).to eq(200)
      @document_url = resp[:body][:file_url]
    end

    e.run_step 'Verify exported data' do
      @csv_data = CSV.parse(URI.parse(@document_url).open, headers: true)
      report_hash, exp_hash = @investor_page.validate_export_repayment(@csv_data, @transaction_id)
      expect(report_hash).to eq(exp_hash)
    end

    e.run_step 'Export due for repayment data with filter' do
      @common_pages.apply_list_filter(
        {
          'Anchor' => 'Tvs',
          'Investor' => @investor_name
          # 'date_range' => [{ 'Due Date' => Date.today.strftime('%d-%m-%Y') }, { 'Due Date' => Date.today.strftime('%d-%m-%Y') }]
        }
      )
      @common_pages.export.click
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq('please find the exported data in your mailbox!')
    end

    e.run_step 'Verify mail received with repayment data on clicking report' do
      sleep 10 # For report generation
      email_values = {
        mail_box: $conf['notification_mailbox'],
        subject: "Repayment due as on - #{Date.today.strftime('%Y-%m-%d')}",
        body: ["Dear #{@vendor_name}", 'Due for Repayment'],
        link_text: 'repayment_due'
      }
      @report_link = @common_pages.get_link_from_mail(email_values)
      expect(@report_link.empty?).to eq(false), 'File not downloaded'
    end

    e.run_step 'Fetch document' do
      resp = fetch_document(@vendor_actor, get_params_from_uri(@report_link))
      expect(resp[:code]).to eq(200)
      @document_url = resp[:body][:file_url]
    end

    e.run_step 'Verify exported data' do
      @csv_data = CSV.parse(URI.parse(@document_url).open, headers: true)
      report_hash, exp_hash = @investor_page.validate_export_repayment(@csv_data, @transaction_id)
      expect(report_hash).to eq(exp_hash)
      fields = [['Investor Name', 'Channel partner name'], %i[investor anchor]]
      expect(@investor_page.validate_export_contains_only_filtered_data(@csv_data, @transaction_id, fields)).to eq(true), 'Report contains unfiltered data'
    end
  end
end
