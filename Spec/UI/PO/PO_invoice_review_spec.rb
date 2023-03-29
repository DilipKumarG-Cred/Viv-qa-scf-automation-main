require './spec_helper'
describe 'PO Invoice Review:', :scf, :po, :transactions, :po_invoice_review, :no_run do
  before(:all) do
    @party_gstn = $conf['users']['grn_anchor']['gstn']
    @anchor_gstn = $conf['users']['grn_anchor']['gstn']
    @counterparty_gstn = $conf['users']['po_vendor']['gstn']
    @vendor_name = $conf['users']['po_vendor']['name']
    @anchor_name = $conf['users']['grn_anchor']['name']
    @investor_name = $conf['investor_name']
    @invoice_file = "#{Dir.pwd}/test-data/attachments/anchor_invoice.pdf"
    @po_review_file = "#{Dir.pwd}/test-data/attachments/po_review_file.pdf"
    @po_review_file_name = 'po_review_file.pdf'
    @payment_proof = "#{Dir.pwd}/test-data/attachments/payment_proof.pdf"
    @erb_file = File.read("#{Dir.pwd}/test-data/erb/testbed_data.erb")
    clear_all_overdues({ anchor: $conf['grn_anchor_name'], vendor: $conf['users']['po_dealer']['name'] })
  end

  before(:each) do
    clear_all_overdues({ anchor: @anchor_name, vendor: @vendor_name, liability: 'po_vendor' })
    @driver = Tarspect::Browser.new($conf['browser']).invoke
    @tarspect_methods = Common::Methods.new(@driver)
    @common_pages = Pages::CommonMethods.new(@driver)
    @transactions_page = Pages::Trasactions.new(@driver)
    @disbursement_page = Pages::Disbursement.new(@driver)
    @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
    @today_date = Date.today.strftime('%d %b, %Y')
    @invoice_discrepancy_date = (Date.today - 30).strftime('%d %b, %Y')
    @current_due_date = (Date.today - $conf['vendor_tenor']).strftime('%d-%b-%Y')
    @eligile_po_value = comma_seperated_value(@testdata['PO Details']['Requested Disbursement Value'])
    @testdata['Transaction List'].merge!(
      'Status' => 'Settled',
      'Instrument Value' => "₹#{@eligile_po_value}",
      'Actions' => 'Invoice Due'
    )
  end

  after(:each) do |e| # Captures screenshot of the current page when failure happens
    snap_screenshot(e)
    quit_browser
  end

  after(:all) do
    clear_all_overdues({ anchor: @anchor_name, vendor: @vendor_name })
  end

  it 'Invoice Review : Upload Invoice against PO and review as Investor', :sanity, :review_po_invoice do |e|
    e.run_step 'Create and disburse a PO(with Invoice overdue in x days)' do
      @transaction_id = seed_transaction({
                                           actor: 'grn_anchor',
                                           counter_party: 'po_vendor',
                                           po_details: @testdata['PO Details'],
                                           po_file: @invoice_file,
                                           program: 'PO Financing - Vendor',
                                           program_group: 'purchase_order'
                                         })
      expect(@transaction_id).not_to include('Error while creating transaction')
      details = disburse_transaction({
                                       transaction_id: @transaction_id,
                                       invoice_value: @testdata['PO Details']['Requested Disbursement Value'],
                                       type: 'frontend',
                                       date_of_payment: @current_due_date,
                                       payment_proof: @payment_proof,
                                       program: 'PO Financing - Vendor'
                                     })
      expect(details).not_to eq 'Error while disbursements'
    end

    e.run_step 'Login as Vendor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['po_vendor']['email'], $conf['users']['po_vendor']['password'])).to eq true
    end

    e.run_step 'Verify Invoice Due status present in list page' do
      @common_pages.click_menu(MENU_PO_FINANCING)
      @common_pages.apply_filter({ 'Instrument Number' => @testdata['PO Details']['PO Number'] })
      @testdata['Transaction List']['Number'] = @testdata['PO Details']['PO Number']
      @testdata['Transaction List']['Instrument Value'] = round_the_amount_to_lakhs(@testdata['PO Details']['PO Value'])
      expect(@transactions_page.verify_transaction_in_list_page(@testdata['Transaction List'], page: :vendor, apply_filter: false)).to eq true
    end

    e.run_step 'Verify Invoice Due days displayed correctly upon hovering(Overdue by x days)' do
      @transactions_page.hover_actions_for_transactions(@transaction_id)
      expect(@transactions_page.overdue_tooltip(@transaction_id)).to eq 'Invoice overdue by 15 days!'
    end

    e.run_step 'Navigate to transactions and upload Invoice to PO' do
      @testdata['Invoice Details'].merge!(
        'Invoice Value' => @testdata['PO Details']['PO Value'] + 1000,
        'GSTN of ' => @testdata['Invoice Details']['GSTN of Channel Partner']
      )
      @common_pages.navigate_to_transaction(@transaction_id)
      expect(@transactions_page.verify_transaction_status('Invoice Due')).to eq true
      @tarspect_methods.click_link('Invoices & Documents')
      @tarspect_methods.click_link('Invoices')
      @transactions_page.upload_invoice_to_po(@testdata['PO Details'], @po_review_file)
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['InvoiceCreated']
    end

    e.run_step 'Verify attached invoice is available for the PO' do
      @common_pages.click_menu(MENU_PO_FINANCING)
      @common_pages.navigate_to_transaction(@transaction_id)
      @tarspect_methods.click_link('Invoices & Documents')
      @tarspect_methods.click_link('Invoices')
      expect(@transactions_page.invoice_exists?(@po_review_file_name)).to eq true
      expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq true
    end

    e.run_step 'Verify PO is in Invoice Due before submit for review' do
      expect(@transactions_page.verify_transaction_status('Invoice Due')).to eq true
    end

    e.run_step 'Verify PO is not in Invoice Due after submitted for review' do
      @transactions_page.submit_invoice_for_review
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['POReviewSubmitted']
      expect(@transactions_page.verify_transaction_status('Invoice Due')).to eq false
    end

    e.run_step 'Verify Invoice Due Action not present in list page' do
      @common_pages.click_menu(MENU_PO_FINANCING)
      @common_pages.click_transactions_tab(SHOW_ALL)
      expect(@transactions_page.actions_present?(@transaction_id)).to eq false
    end

    e.run_step 'Logout as Vendor' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Investor for Review Approval' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['investor']['email'], $conf['users']['investor']['password'])).to eq true
    end

    e.run_step 'Verify transaction present under PO Invoices to approve tab' do
      @common_pages.click_menu(MENU_PO_FINANCING)
      @common_pages.click_transactions_tab(PO_INVOICES_TO_APPROVE)
      @common_pages.apply_list_filter({ 'Instrument Number' => @testdata['PO Details']['PO Number'] })
      expect(@common_pages.transaction_listed?(@transaction_id)).to eq(true), "Transaction #{@transaction_id} is not listed"
    end

    e.run_step 'Verify the Invoice file present for the PO' do
      @common_pages.navigate_to_transaction(@transaction_id)
      expect(@transactions_page.approve_invoice_message_available?).to eq true
      @tarspect_methods.click_link('Invoices & Documents')
      @tarspect_methods.click_link('Invoices')
      expect(@transactions_page.invoice_exists?(@po_review_file_name)).to eq true
      expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq true
    end

    e.run_step 'Validate the Invoice details and approve the Invoice' do
      @transactions_page.open_invoice_document
      expected_values = {
        'Invoice Value' => "₹ #{comma_seperated_value(@testdata['Invoice Details']['Invoice Value'])}",
        'Name of the Vendor' => @vendor_name,
        'Name of the Anchor' => @anchor_name,
        'Date of Invoice' => @today_date
      }
      expect(@transactions_page.verify_invoice_review_modal(expected_values)).to eq true
      @transactions_page.approve_transaction
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['ReviewApproved']
      expect(@transactions_page.approve_invoice_message_available?).to eq false
    end
  end

  it 'Invoice Review : Reject Uploaded Invoice', :sanity do |e|
    @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
    @eligile_po_value = comma_seperated_value(@testdata['PO Details']['Requested Disbursement Value'])
    @po_upcoming_due = (Date.today - $conf['vendor_tenor'] + 30).strftime('%d-%b-%Y')
    @testdata['Transaction List'].merge!(
      'Status' => 'Settled',
      'Instrument Value' => "₹#{@eligile_po_value}",
      'Actions' => 'Invoice Due'
    )
    e.run_step 'Create and disburse a PO(with Invoice due in upcoming days)' do
      @transaction_id = seed_transaction({
                                           actor: 'grn_anchor',
                                           counter_party: 'po_vendor',
                                           po_details: @testdata['PO Details'],
                                           po_file: @invoice_file,
                                           program: 'PO Financing - Vendor',
                                           program_group: 'purchase_order'
                                         })
      expect(@transaction_id).not_to include('Error while creating transaction')
      details = disburse_transaction({
                                       transaction_id: @transaction_id,
                                       invoice_value: @testdata['PO Details']['Requested Disbursement Value'],
                                       type: 'frontend',
                                       date_of_payment: @po_upcoming_due,
                                       payment_proof: @payment_proof,
                                       program: 'PO Financing - Vendor'
                                     })
      expect(details).not_to eq 'Error while disbursements'
    end

    e.run_step 'Login as Vendor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['po_vendor']['email'], $conf['users']['po_vendor']['password'])).to eq true
    end

    e.run_step 'Verify Invoice Due status present in list page' do
      @common_pages.click_menu(MENU_PO_FINANCING)
      @common_pages.apply_filter({ 'Instrument Number' => @testdata['PO Details']['PO Number'] })
      @testdata['Transaction List']['Number'] = @testdata['PO Details']['PO Number']
      @testdata['Transaction List']['Instrument Value'] = round_the_amount_to_lakhs(@testdata['PO Details']['PO Value'])
      expect(@transactions_page.verify_transaction_in_list_page(@testdata['Transaction List'], page: :vendor, apply_filter: false)).to eq true
    end

    e.run_step 'Verify Invoice Due days displayed correctly upon hovering(Upcoming Due in x days)' do
      @transactions_page.hover_actions_for_transactions(@transaction_id)
      expect(@transactions_page.overdue_tooltip(@transaction_id)).to eq 'Invoice due in 15 days!'
    end

    e.run_step 'Navigate to transactions and upload Invoice to PO(Invoice date and Invoice value less than PO)' do
      @testdata['Invoice Details'].merge!(
        'Invoice Value' => @testdata['PO Details']['Requested Disbursement Value'] - 1000,
        'GSTN of ' => @testdata['Invoice Details']['GSTN of Channel Partner'],
        'Invoice Date' => (Date.today - 30).strftime('%d-%b-%Y')
      )
      @common_pages.navigate_to_transaction(@transaction_id)
      @tarspect_methods.click_link('Invoices & Documents')
      @tarspect_methods.click_link('Invoices')
      @transactions_page.upload_invoice_to_po(@testdata['Invoice Details'], @po_review_file)
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['InvoiceCreated']
    end

    e.run_step 'Verify Discrepancies warning and Submit the Invoice for Review' do
      @common_pages.click_menu(MENU_PO_FINANCING)
      @common_pages.navigate_to_transaction(@transaction_id)
      @tarspect_methods.click_link('Invoices & Documents')
      @tarspect_methods.click_link('Invoices')
      expect(@transactions_page.invoice_discrepancies_present?).to eq true
      @transactions_page.submit_invoice_for_review
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['POReviewSubmitted']
    end

    e.run_step 'Logout as Vendor' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Investor for Review reject' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['investor']['email'], $conf['users']['investor']['password'])).to eq true
    end

    e.run_step 'Navigate to the PO and Verify the discrepancies' do
      @common_pages.click_menu(MENU_PO_FINANCING)
      @common_pages.click_transactions_tab(PO_INVOICES_TO_APPROVE)
      @common_pages.apply_list_filter({ 'Instrument Number' => @testdata['PO Details']['PO Number'] })
      @common_pages.navigate_to_transaction(@transaction_id)
      @tarspect_methods.click_link('Invoices & Documents')
      @tarspect_methods.click_link('Invoices')
      expect(@transactions_page.invoice_discrepancies_present?).to eq true
      @transactions_page.open_invoice_document
      expect(@transactions_page.verify_discrepancies_in_review_modal("Invoice date(#{@invoice_discrepancy_date}) is earlier than Purchase Order date (#{@today_date})")).to eq true
      expect(@transactions_page.verify_discrepancies_in_review_modal("Invoice value(#{@testdata['Invoice Details']['Invoice Value']}) is lesser than Purchase Order Value(#{@testdata['PO Details']['PO Value']})")).to eq true
      @common_pages.close_modal
    end

    e.run_step 'Navigate to the PO and reject the invoice with reason' do
      @transactions_page.reject_invoice_for_po(@testdata['Reject Reason'])
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['ReviewRejected']
    end

    e.run_step 'Validate the Rejected reason for the Invoice' do
      expect(@transactions_page.reject_reason_present?(@testdata['Reject Reason'])).to eq true
      expect(@transactions_page.invoice_discrepancies_present?).to eq true
    end

    e.run_step 'Logout as Investor' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Vendor and verify rejected reason present' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['po_vendor']['email'], $conf['users']['po_vendor']['password'])).to eq true
    end

    e.run_step 'Navigate to the PO and Verify the rejected reason for the uploaded invoice' do
      @common_pages.click_menu(MENU_PO_FINANCING)
      @common_pages.navigate_to_transaction(@transaction_id)
      @tarspect_methods.click_link('Invoices & Documents')
      @tarspect_methods.click_link('Invoices')
      expect(@transactions_page.reject_reason_present?(@testdata['Reject Reason'])).to eq true
      expect(@transactions_page.invoice_discrepancies_present?).to eq true
    end
  end
end
