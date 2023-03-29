require './spec_helper'
describe 'Transactions: Reject', :scf, :transactions, :scf_reject_transaction, :hover do
  before(:all) do
    @download_path = "#{Dir.pwd}/test-data/downloaded/scf_reject_transaction"
    @anchor_gstn = $conf['myntra_gstn']
    @counterparty_gstn = $conf['libas_gstn']
    @vendor_name = $conf['vendor_name']
    @anchor_name = $conf['anchor_name']
    @investor_name = $conf['investor_name']
    @invoice_file = "#{Dir.pwd}/test-data/attachments/anchor_invoice.pdf"
    @file_name = 'anchor_invoice.pdf'
    @erb_file = File.read("#{Dir.pwd}/test-data/erb/testbed_data.erb")
    @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
    @invoice_value = @testdata['Invoice Details']['Invoice Value'].to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
    @testdata['Transaction List']['Instrument Value'] = "₹#{@invoice_value}"
  end

  before(:each) do
    @driver = Tarspect::Browser.new($conf['browser'], @download_path).invoke
    @tarspect_methods = Common::Methods.new(@driver)
    @common_pages = Pages::CommonMethods.new(@driver)
    @transactions_page = Pages::Trasactions.new(@driver)
    @commercials_page = Pages::Commercials.new(@driver)
    flush_directory(@download_path)
  end

  after(:each) do |e| # Captures screenshot of the current page when failure happens
    snap_screenshot(e)
    quit_browser
  end

  it 'Transaction : Reject a transaction', :sanity do |e|
    e.run_step 'Login as anchor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['anchor']['email'], $conf['users']['anchor']['password'])).to eq true
    end

    e.run_step 'Add transaction' do
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @common_pages.click_transactions_tab(SHOW_ALL)
      @transactions_page.add_transaction(@invoice_file, @testdata['Invoice Details'], 'Vendor Financing', 'Invoice')
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['InvoiceCreated']
    end

    e.run_step 'Verify transaction as Anchor in list page' do
      @testdata['Transaction List']['Number'] = @testdata['Invoice Details']['Invoice Number']
      expect(@transactions_page.verify_transaction_in_list_page(@testdata['Transaction List'], page: :anchor)).to eq true
      @transaction_id = @common_pages.get_transaction_id(@testdata['Transaction List'])
    end

    e.run_step 'Anchor logs out' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as product' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['product']['email'], $conf['users']['product']['password'])).to eq true
    end

    e.run_step 'Reject Invoice as Product - 1st level of approval' do
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @common_pages.click_transactions_tab(SHOW_ALL)
      @common_pages.navigate_to_transaction(@transaction_id)
      @transactions_page.reject_transaction('Discard', @testdata['Reject Reason'])
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['ProductApproved']
    end

    e.run_step 'Verify status timeline after Product rejection' do
      expect(@transactions_page.rejected_status('Discard', $conf['product_reject'], @testdata['Reject Reason'])).to eq true
    end

    e.run_step 'Verify transaction status in landing page' do
      expect(@transactions_page.verify_transaction_status('Rejected')).to eq true
    end

    e.run_step "Verify Transaction Listed in 'Rejected' as Product" do
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @common_pages.click_transactions_tab(REJECTED)
      expect(@common_pages.transaction_listed?(@transaction_id)).to eq(true), "Transaction #{@transaction_id} is not listed"
    end

    e.run_step 'Verify status timeline in the hovercard after Product rejection' do
      expect(@transactions_page.rejected_reason_on_hover(@transaction_id, $conf['product_reject'], @testdata['Reject Reason'])).to eq true
    end

    e.run_step 'Verify transaction status in landing page' do
      @common_pages.navigate_to_transaction(@transaction_id)
      expect(@transactions_page.verify_transaction_status('Rejected')).to eq true
    end

    e.run_step 'Product logs out' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Vendor - CounterParty' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['vendor']['email'], $conf['users']['vendor']['password'])).to eq true
    end

    e.run_step 'Verify status of transaction as Vendor' do
      navigate_to($conf['transactions_url'])
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @common_pages.click_transactions_tab(SHOW_ALL)
      @common_pages.navigate_to_transaction(@transaction_id)
      expect(@transactions_page.verify_transaction_status('Rejected')).to eq true
    end

    e.run_step 'Verify status timeline as Vendor after Product rejection' do
      expect(@transactions_page.rejected_status('Discard', $conf['product_reject'], @testdata['Reject Reason'])).to eq true
    end

    e.run_step "Verify Transaction Listed in 'Rejected' as Vendor" do
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @common_pages.click_transactions_tab(REJECTED)
      expect(@common_pages.transaction_listed?(@transaction_id)).to eq(true), "Transaction #{@transaction_id} is not listed"
    end

    e.run_step 'Verify status timeline in the hovercard as Vendor after Product rejection' do
      expect(@transactions_page.rejected_reason_on_hover(@transaction_id, $conf['product_reject'], @testdata['Reject Reason'])).to eq true
    end

    e.run_step 'Verify transaction status in landing page' do
      @common_pages.navigate_to_transaction(@transaction_id)
      expect(@transactions_page.verify_transaction_status('Rejected')).to eq true
    end

    e.run_step 'Vendor logs out' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Anchor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['anchor']['email'], $conf['users']['anchor']['password'])).to eq true
    end

    e.run_step 'Verify status of transaction as Anchor' do
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @common_pages.click_transactions_tab(SHOW_ALL)
      @common_pages.navigate_to_transaction(@transaction_id)
      expect(@transactions_page.verify_transaction_status('Rejected')).to eq true
    end

    e.run_step 'Verify status timeline as Anchor after Product rejection' do
      expect(@transactions_page.rejected_status('Discard', $conf['product_reject'], @testdata['Reject Reason'])).to eq true
    end

    e.run_step "Verify Transaction Listed in 'Rejected' as Anchor" do
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @common_pages.click_transactions_tab(REJECTED)
      expect(@common_pages.transaction_listed?(@transaction_id)).to eq(true), "Transaction #{@transaction_id} is not listed"
    end

    e.run_step 'Verify status timeline in the hovercard as Anchor after Product rejection' do
      expect(@transactions_page.rejected_reason_on_hover(@transaction_id, $conf['product_reject'], @testdata['Reject Reason'])).to eq true
    end

    e.run_step 'Verify transaction status in landing page' do
      @common_pages.navigate_to_transaction(@transaction_id)
      expect(@transactions_page.verify_transaction_status('Rejected')).to eq true
    end
  end

  it 'Transactions: Bulk Import', :bulk, :bulk_import_txn do |e|
    e.run_step 'Login as anchor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['anchor']['email'], $conf['users']['anchor']['password'])).to eq true
    end

    e.run_step 'Import bulk transaction and verify summary report' do
      expected_results = @transactions_page.add_bulk_transaction('anchor', 'Vendor Financing', 'Invoice')
      expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq true
      expect(@transactions_page.download_summary_report(@download_path)).to eq true
      @report_link = @transactions_page.get_summary_report_link
      actual_results = @transactions_page.verify_summary_report(@report_link)
      expect(actual_results).to eq expected_results
    end

    e.run_step 'Verify summary report modal after bulk import' do
      expect(@transactions_page.transaction_summary_present?).to eq true
      expect(@transactions_page.verify_summary('Total Transactions')).to eq '14'
      expect(@transactions_page.verify_summary('Accepted Transactions')).to eq '6'
      expect(@transactions_page.verify_summary('Rejected Transactions')).to eq '8'
      expect(@transactions_page.verify_summary('Total Value')).to eq '69000'
      @tarspect_methods.click_button('close')
    end

    e.run_step 'Verify transactions created for the valid records' do
      expect(@transactions_page.verify_valid_transactions('anchor', page: :anchor)).to eq true
    end

    e.run_step 'Verify invoices are uploaded to transactions' do
      errors = @transactions_page.validate_doc_uploaded('invoice', @report_link)
      expect(errors.size).to eq(1), "Documents are not uploaded properly #{errors}"
    end

    e.run_step 'Anchor logs out' do
      flush_directory(@download_path)
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Vendor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['vendor']['email'], $conf['users']['vendor']['password'])).to eq true
    end

    e.run_step 'Import bulk transaction and verify summary report' do
      navigate_to($conf['transactions_url'])
      expected_results = @transactions_page.add_bulk_transaction('vendor', 'Vendor Financing', 'Invoice')
      expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq true
      expect(@transactions_page.download_summary_report(@download_path)).to eq true
      report_link = @transactions_page.get_summary_report_link
      actual_results = @transactions_page.verify_summary_report(report_link)
      expect(actual_results).to eq expected_results
    end

    e.run_step 'Verify summary report modal after bulk import' do
      expect(@transactions_page.transaction_summary_present?).to eq true
      expect(@transactions_page.verify_summary('Total Transactions')).to eq '14'
      expect(@transactions_page.verify_summary('Accepted Transactions')).to eq '6'
      expect(@transactions_page.verify_summary('Rejected Transactions')).to eq '8'
      expect(@transactions_page.verify_summary('Total Value')).to eq '69000'
      @tarspect_methods.click_button('close')
    end

    e.run_step 'Verify transactions created for the valid records' do
      expect(@transactions_page.verify_valid_transactions('vendor', page: :vendor)).to eq true
    end

    e.run_step 'Vendor logs out' do
      flush_directory(@download_path)
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Dealer' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['dealer']['email'], $conf['users']['dealer']['password'])).to eq true
    end

    e.run_step 'Import bulk transaction and verify summary report' do
      navigate_to($conf['transactions_url'])
      expected_results = @transactions_page.add_bulk_transaction('dealer', 'Dealer Financing', 'Invoice')
      expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq true
      expect(@transactions_page.download_summary_report(@download_path)).to eq true
      report_link = @transactions_page.get_summary_report_link
      actual_results = @transactions_page.verify_summary_report(report_link)
      expect(actual_results).to eq expected_results
    end

    e.run_step 'Verify summary report modal after bulk import' do
      expect(@transactions_page.transaction_summary_present?).to eq true
      expect(@transactions_page.verify_summary('Total Transactions')).to eq '10'
      expect(@transactions_page.verify_summary('Accepted Transactions')).to eq '5'
      expect(@transactions_page.verify_summary('Rejected Transactions')).to eq '5'
      expect(@transactions_page.verify_summary('Total Value')).to eq '68000'
      @tarspect_methods.click_button('close')
    end

    e.run_step 'Verify transactions created for the valid records' do
      expect(@transactions_page.verify_valid_transactions('dealer', page: :vendor)).to eq true
    end
  end

  it 'Transactions: Bulk Import Validations', :bulk, :bulk_validation_txn do |e|
    e.run_step 'Login as anchor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['anchor']['email'], $conf['users']['anchor']['password'])).to eq true
    end

    e.run_step 'Bulk import different file for the program - Sheet name mismatch as anchor' do
      file = "#{Dir.pwd}/test-data/attachments/bulk_import_inv_vendor.xlsx"
      @output = @transactions_page.initiate_bulk_import_transaction(file, 'Vendor Financing', 'Invoice')
      expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq true
      expect(@transactions_page.download_summary_report(@download_path)).to eq true
      actual_results = @commercials_page.verify_vendor_import_summary_report("#{@download_path}/report.xlsx").keys
      expect(actual_results[0]).to eq 'Sheet name is invalid. Please verify with the existing template.'
    end

    e.run_step 'Verify summary report modal after Sheet mismatch as anchor' do
      expect(@transactions_page.transaction_summary_present?).to eq true
      expect(@transactions_page.verify_summary('Total Transactions')).to eq '0'
      expect(@transactions_page.verify_summary('Accepted Transactions')).to eq '0'
      expect(@transactions_page.verify_summary('Rejected Transactions')).to eq '0'
      expect(@transactions_page.verify_summary('Total Value')).to eq '0'
      @tarspect_methods.click_button('close')
    end

    e.run_step 'Bulk import file with wrong headers as anchor' do
      flush_directory(@download_path)
      file = "#{Dir.pwd}/test-data/attachments/bulk_transactions_wrong_headers.xlsx"
      @output = @transactions_page.initiate_bulk_import_transaction(file, 'Vendor Financing', 'Invoice')
      expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq true
      expect(@transactions_page.download_summary_report(@download_path)).to eq true
      actual_results = @commercials_page.verify_vendor_import_summary_report("#{@download_path}/report.xlsx").keys
      expect(actual_results[0]).to include('Invalid Columns found in the sheet - '), actual_results[0]
      expect(actual_results[0]).to include('Missing Columns found in the sheet - [')
      expect(actual_results[0]).to include('Please verify with the existing template.')
      invalid_columns = ['PO Number', 'PO Value', 'Requested Disbursement Value', 'PO Date', 'Tenor']
      missed_columns = ['Invoice Number', 'Invoice Value', 'Invoice Date', 'GRN (Optional)', 'GRN Date (Optional)', 'EWB No (Optional)', 'EWB Date (Optional)', 'Due Date (Optional)', 'Tenor (Optional)', 'Requested Disbursement Value (Optional)']
      expect(validate_wrong_headers_message(actual_results[0], invalid_columns, missed_columns)).to eq(true)
    end

    e.run_step 'Verify summary report modal with headers mismatch as anchor' do
      expect(@transactions_page.transaction_summary_present?).to eq true
      expect(@transactions_page.verify_summary('Total Transactions')).to eq '0'
      expect(@transactions_page.verify_summary('Accepted Transactions')).to eq '0'
      expect(@transactions_page.verify_summary('Rejected Transactions')).to eq '0'
      expect(@transactions_page.verify_summary('Total Value')).to eq '0'
      @tarspect_methods.click_button('close')
    end

    e.run_step 'Verify Download template Invoice Vendor Program works for anchor' do
      @tarspect_methods.click_button('Add Transaction')
      @transactions_page.select_transaction_program('Vendor Financing', 1)
      @transactions_page.select_transaction_program('Invoice', 2)
      @tarspect_methods.click_link('Download Template')
      expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq true
      expect(@tarspect_methods.file_downloaded?("#{@download_path}/invoice_vendor_transaction_bulk_upload.xlsx")).to eq true
    end

    e.run_step 'Verify Download template PO Dealer Program works for anchor' do
      refresh_page
      @transactions_page.select_transaction_program('Dealer Financing', 1)
      @transactions_page.select_transaction_program('PO', 2)
      @tarspect_methods.click_link('Download Template')
      expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq true
      expect(@tarspect_methods.file_downloaded?("#{@download_path}/po_dealer_transaction_bulk_upload.xlsx")).to eq true
    end

    e.run_step 'Anchor logs out' do
      flush_directory(@download_path)
      @common_pages.click_back_button
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Vendor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['vendor']['email'], $conf['users']['vendor']['password'])).to eq true
    end

    e.run_step 'Bulk import different file for the program - Sheet name mismatch as vendor' do
      navigate_to($conf['transactions_url'])
      file = "#{Dir.pwd}/test-data/attachments/bulk_import_inv_vendor.xlsx"
      @output = @transactions_page.initiate_bulk_import_transaction(file, 'Vendor Financing', 'Invoice')
      expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq true
      expect(@transactions_page.download_summary_report(@download_path)).to eq true
      actual_results = @commercials_page.verify_vendor_import_summary_report("#{@download_path}/report.xlsx").keys
      expect(actual_results[0]).to eq 'Sheet name is invalid. Please verify with the existing template.'
    end

    e.run_step 'Verify summary report modal after Sheet mismatch as vendor' do
      expect(@transactions_page.transaction_summary_present?).to eq true
      expect(@transactions_page.verify_summary('Total Transactions')).to eq '0'
      expect(@transactions_page.verify_summary('Accepted Transactions')).to eq '0'
      expect(@transactions_page.verify_summary('Rejected Transactions')).to eq '0'
      expect(@transactions_page.verify_summary('Total Value')).to eq '0'
      @tarspect_methods.click_button('close')
    end

    e.run_step 'Bulk import file with wrong headers as vendor' do
      flush_directory(@download_path)
      file = "#{Dir.pwd}/test-data/attachments/bulk_transactions_wrong_headers.xlsx"
      @output = @transactions_page.initiate_bulk_import_transaction(file, 'Vendor Financing', 'Invoice')
      expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq true
      expect(@transactions_page.download_summary_report(@download_path)).to eq true
      actual_results = @commercials_page.verify_vendor_import_summary_report("#{@download_path}/report.xlsx").keys
      expect(actual_results[0]).to include('Invalid Columns found in the sheet - '), actual_results[0]
      expect(actual_results[0]).to include('Missing Columns found in the sheet - [')
      expect(actual_results[0]).to include('Please verify with the existing template.')
      invalid_columns = ['PO Number', 'PO Value', 'Requested Disbursement Value', 'PO Date', 'Tenor']
      missed_columns = ['Invoice Number', 'Invoice Value', 'Invoice Date', 'GRN (Optional)', 'GRN Date (Optional)', 'EWB No (Optional)', 'EWB Date (Optional)', 'Due Date (Optional)', 'Tenor (Optional)', 'Requested Disbursement Value (Optional)']
      expect(validate_wrong_headers_message(actual_results[0], invalid_columns, missed_columns)).to eq(true)
    end

    e.run_step 'Verify summary report modal with headers mismatch as vendor' do
      expect(@transactions_page.transaction_summary_present?).to eq true
      expect(@transactions_page.verify_summary('Total Transactions')).to eq '0'
      expect(@transactions_page.verify_summary('Accepted Transactions')).to eq '0'
      expect(@transactions_page.verify_summary('Rejected Transactions')).to eq '0'
      expect(@transactions_page.verify_summary('Total Value')).to eq '0'
      @tarspect_methods.click_button('close')
    end

    e.run_step 'Verify Download template PO Vendor Program works for anchor' do
      @tarspect_methods.click_button('Add Transaction')
      @transactions_page.select_transaction_program('Vendor Financing', 1)
      @transactions_page.select_transaction_program('PO', 2)
      @tarspect_methods.click_link('Download Template')
      expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq true
      expect(@tarspect_methods.file_downloaded?("#{@download_path}/po_vendor_transaction_bulk_upload.xlsx")).to eq true
    end

    e.run_step 'Vendor logs out' do
      flush_directory(@download_path)
      @common_pages.click_back_button
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Dealer' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['dealer']['email'], $conf['users']['dealer']['password'])).to eq true
    end

    e.run_step 'Bulk import different file for the program - Sheet name mismatch as dealer' do
      navigate_to($conf['transactions_url'])
      file = "#{Dir.pwd}/test-data/attachments/bulk_import_inv_vendor.xlsx"
      @output = @transactions_page.initiate_bulk_import_transaction(file, 'Dealer Financing', 'Invoice')
      expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq true
      expect(@transactions_page.download_summary_report(@download_path)).to eq true
      actual_results = @commercials_page.verify_vendor_import_summary_report("#{@download_path}/report.xlsx").keys
      expect(actual_results[0]).to eq 'Sheet name is invalid. Please verify with the existing template.'
    end

    e.run_step 'Verify summary report modal after Sheet mismatch as dealer' do
      expect(@transactions_page.transaction_summary_present?).to eq true
      expect(@transactions_page.verify_summary('Total Transactions')).to eq '0'
      expect(@transactions_page.verify_summary('Accepted Transactions')).to eq '0'
      expect(@transactions_page.verify_summary('Rejected Transactions')).to eq '0'
      expect(@transactions_page.verify_summary('Total Value')).to eq '0'
      @tarspect_methods.click_button('close')
    end

    e.run_step 'Bulk import file with wrong headers as dealer' do
      flush_directory(@download_path)
      file = "#{Dir.pwd}/test-data/attachments/bulk_transactions_wrong_headers.xlsx"
      @output = @transactions_page.initiate_bulk_import_transaction(file, 'Dealer Financing', 'Invoice')
      expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq true
      expect(@transactions_page.download_summary_report(@download_path)).to eq true
      actual_results = @commercials_page.verify_vendor_import_summary_report("#{@download_path}/report.xlsx").keys
      expect(actual_results[0]).to include('Invalid Columns found in the sheet - '), actual_results[0]
      expect(actual_results[0]).to include('Missing Columns found in the sheet - [')
      expect(actual_results[0]).to include('Please verify with the existing template.')
      invalid_columns = ['PO Number', 'PO Value', 'Requested Disbursement Value', 'PO Date', 'Tenor']
      missed_columns = ['Invoice Number', 'Invoice Value', 'Invoice Date', 'GRN (Optional)', 'GRN Date (Optional)', 'EWB No (Optional)', 'EWB Date (Optional)', 'Due Date (Optional)', 'Tenor (Optional)', 'Requested Disbursement Value (Optional)']
      expect(validate_wrong_headers_message(actual_results[0], invalid_columns, missed_columns)).to eq(true)
    end

    e.run_step 'Verify summary report modal with headers mismatch as dealer' do
      expect(@transactions_page.transaction_summary_present?).to eq true
      expect(@transactions_page.verify_summary('Total Transactions')).to eq '0'
      expect(@transactions_page.verify_summary('Accepted Transactions')).to eq '0'
      expect(@transactions_page.verify_summary('Rejected Transactions')).to eq '0'
      expect(@transactions_page.verify_summary('Total Value')).to eq '0'
      @tarspect_methods.click_button('close')
    end

    e.run_step 'Verify Download template Invoice Dealer Program works for anchor' do
      @tarspect_methods.click_button('Add Transaction')
      @transactions_page.select_transaction_program('Dealer Financing', 1)
      @transactions_page.select_transaction_program('Invoice', 2)
      @tarspect_methods.click_link('Download Template')
      expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq true
      expect(@tarspect_methods.file_downloaded?("#{@download_path}/invoice_dealer_transaction_bulk_upload.xlsx")).to eq true
    end
  end
end
