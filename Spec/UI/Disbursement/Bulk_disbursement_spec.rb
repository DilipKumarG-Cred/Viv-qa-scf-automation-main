require './spec_helper'
describe 'Disbursement: Bulk Upload', :scf, :disbursements, :bulk, :bulk_disburse do
  before(:all) do
    @anchor_actor = 'grn_anchor'
    @vendor_actor = 'po_vendor'
    @party_gstn = $conf['users'][@anchor_actor]['gstn']
    @counterparty_gstn = $conf['users'][@vendor_actor]['gstn']
    @vendor_name = $conf['users'][@vendor_actor]['name']
    @anchor_name = $conf['users'][@anchor_actor]['name']
    @investor_name = $conf['investor_name']
    @invoice_file = "#{Dir.pwd}/test-data/attachments/anchor_invoice.pdf"
    @upload_file = "#{Dir.pwd}/test-data/attachments/disbursement_bulk_upload.xlsx"
    @erb_file = File.read("#{Dir.pwd}/test-data/erb/testbed_data.erb")
    @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
    clear_all_overdues({ anchor: @anchor_name, vendor: @vendor_name, liability: @anchor_actor })
    @download_path = "#{Dir.pwd}/test-data/downloaded/disbursement_bulk_import"
    flush_directory(@download_path)
  end

  before(:each) do
    @driver = Tarspect::Browser.new($conf['browser'], @download_path).invoke
    @tarspect_methods = Common::Methods.new(@driver)
    @common_pages = Pages::CommonMethods.new(@driver)
    @disbursement_page = Pages::Disbursement.new(@driver)
  end

  after(:each) do |e|
    snap_screenshot(e)
    quit_browser
  end

  it 'Disbursement: Bulk Upload', :sanity do |e|
    e.run_step 'Create multiple transactions (Draft -> Released)' do
      @transactions = []
      17.times do
        @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
        @testdata['PO Details']['PO Date'] = (Date.today - $conf['vendor_tenor']).strftime('%d-%b-%Y')
        transaction_id = seed_transaction(
          {
            actor: @anchor_actor,
            counter_party: @vendor_actor,
            po_details: @testdata['PO Details'],
            po_file: @invoice_file,
            program: 'PO Financing - Vendor',
            program_group: 'purchase_order'
          }
        )
        expect(transaction_id).not_to include('Error while creating transaction')
        @transactions << transaction_id
      end
    end

    e.run_step 'Create a transaction with different anchor, vendor combination' do
      @dealer_gstn = $conf['trends_gstn']
      @counterparty_gstn = $conf['myntra_gstn']
      @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
      @testdata['Dealer Invoice Details']['Invoice Date'] = (Date.today - $conf['dealer_tenor']).strftime('%d-%b-%Y')
      transaction_id = seed_transaction(
        {
          actor: 'dealer',
          counter_party: 'anchor',
          invoice_details: @testdata['Dealer Invoice Details'],
          invoice_file: @invoice_file,
          program: 'Invoice Financing - Dealer',
          program_group: 'invoice'
        }
      )
      expect(transaction_id).not_to include('Error while creating transaction')
      @invoice_transactions = [transaction_id]
    end

    e.run_step 'Login as Investor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['investor']['email'], $conf['users']['investor']['password'])).to be true
    end

    e.run_step 'Verify bulk disbursal data is uploaded and summary' do
      @common_pages.click_menu('PO Financing')
      @tarspect_methods.click_button('Add Settlement details')
      @total_test_data, @disbursement_amount = @disbursement_page.create_test_data_for_bulk_disbursement(@transactions, @invoice_transactions)
      @disbursement_page.generate_bulk_disbursement(@total_test_data, @upload_file)
      @actual_summary, @report_link = @disbursement_page.upload_bulk_disbursement(@upload_file)
      expect(@report_link.empty?).to eq(false), 'Report link is empty'
    end

    e.run_step 'Verify report of bulk disbursement' do
      expected_report = @disbursement_page.create_expected_data_for_bulk_disburse(@total_test_data)
      actual_report = @disbursement_page.verify_bulk_disbursment_summary_report(@report_link)
      expect(actual_report).to eq(expected_report)
    end

    e.run_step 'Verify Summary report' do
      disb_formatted = "₹ #{rounded_half_down_value(format('%g', @disbursement_amount / 100000)).to_f} LAC"
      expected_summary = {
        'Total Disbursement Value' => disb_formatted,
        'Invoices disbursed' => '24',
        'Payment accepted' => '9',
        'Payment rejected' => '15'
      }
      expect(@actual_summary).to eq(expected_summary)
    end
  end
end
