require './spec_helper'
describe 'DD Transactions: Anchor and Reject', :scf, :transactions, :dd, :dd_anchor_transaction, :hover, :no_run do
  before(:all) do
    @download_path = "#{Dir.pwd}/test-data/downloaded/dd_anchor_transaction"
    @anchor_gstn = $conf['users']['anchor']['gstn']
    @vendor_gstn = $conf['users']['dd_vendor']['gstn']
    @investor_name = $conf['investor_name']
    @invoice_file = "#{Dir.pwd}/test-data/attachments/anchor_invoice.pdf"
    @file_name = 'anchor_invoice.pdf'
    @erb_file = File.read("#{Dir.pwd}/test-data/erb/testbed_data.erb")
    @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
    @today_date = Date.today.strftime('%d %b, %Y')
  end

  before(:each) do
    @driver = Tarspect::Browser.new($conf['browser'], @download_path).invoke
    @tarspect_methods = Common::Methods.new(@driver)
    @common_pages = Pages::CommonMethods.new(@driver)
    @transactions_page = Pages::Trasactions.new(@driver)
    @commercials_page = Pages::Commercials.new(@driver)
  end

  after(:each) do |e| # Captures screenshot of the current page when failure happens
    snap_screenshot(e)
    quit_browser
  end

  it 'DD Transaction : Anchor against vendor', :sanity do |e|
    @due_date = Date.today + 30
    @desired_date = Date.today + 10
    @discount = 10
    @tds = 8
    @invoice_value = @testdata['DD Invoice Details']['Invoice Value'] < @testdata['DD Invoice Details']['GRN'] ? @testdata['DD Invoice Details']['Invoice Value'] : @testdata['DD Invoice Details']['GRN']
    e.run_step 'Login as Anchor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['anchor']['email'], $conf['users']['anchor']['password'])).to be true
    end

    e.run_step 'Add a DD transaction - Anchor against vendor' do
      @transactions_page.add_transaction(@invoice_file, @testdata['DD Invoice Details'], 'Dynamic Discounting - Vendor')
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['InvoiceCreated']
    end

    e.run_step 'Verify DD transaction in the List page' do
      calculated_values = @transactions_page.calculate_payable_value({
                                                                       invoice_value: @invoice_value,
                                                                       discount: @testdata['DD Invoice Details']['Discount'],
                                                                       gst: $conf['gst'],
                                                                       tds: @testdata['DD Invoice Details']['TDS']
                                                                     })
      @total_payable = calculated_values[0]
      @gst_amount = calculated_values[1]
      @expected_values = {
        'Invoice Number' => @testdata['DD Invoice Details']['Invoice Number'],
        'Anchor Name' => $conf['users']['anchor']['name'],
        'Date of Initiation' => @today_date,
        'Desired Date' => @desired_date.strftime('%d %b, %Y'),
        'Invoice Value' => comma_seperated_value(@testdata['DD Invoice Details']['Invoice Value']),
        'Discount' => format('%.1f', @discount),
        'Days Gained' => (@due_date - @desired_date).numerator.to_s,
        'Status' => 'Draft',
        'Total Payable' => comma_seperated_value(@total_payable)
      }
      @common_pages.apply_list_filter({ 'Instrument Number' => @testdata['DD Invoice Details']['Invoice Number'] })
      expect(@transactions_page.verify_transaction_in_list_page(@expected_values, page: :anchor, apply_filter: false)).to eq true
      @transaction_id = @common_pages.get_transaction_id(@expected_values)
    end

    e.run_step 'Verify DD transaction as Anchor in landing page' do
      @detail_page_values = {
        'Instrument Value' => "₹#{comma_seperated_value(@testdata['DD Invoice Details']['Invoice Value'])}",
        'Instrument Date' => @today_date,
        'GSTN of Anchor' => @anchor_gstn,
        'GSTN of Vendor/Dealer' => @vendor_gstn,
        'Due Date' => @due_date.strftime('%d %b, %Y'),
        'Discount %' => "#{format('%.1f', @discount)} %",
        'GRN Amount' => "₹#{comma_seperated_value(@testdata['DD Invoice Details']['GRN'])}",
        'Days Gained' => (@due_date - @desired_date).numerator.to_s,
        'GST' => "₹#{comma_seperated_value(@gst_amount)}",
        'Total Payable' => "₹#{comma_seperated_value(@total_payable)}"
      }
      @common_pages.navigate_to_transaction(@transaction_id)
      expect(@transactions_page.verify_transaction_status('Draft')).to eq true
      expect(@transactions_page.verify_transaction_in_detail_page(@detail_page_values)).to eq true
    end

    e.run_step 'Verify Invoice preview is available and content is visible' do
      expect(@transactions_page.invoice_preview_available?).to eq true
    end

    e.run_step 'Verify Invoice document as Anchor in landing page' do
      expect(@transactions_page.invoice_exists?(@file_name)).to eq true
      expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq(true), 'Broken links present'
    end

    e.run_step 'Anchor logs out' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Vendor - CounterParty' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['dd_vendor']['email'], $conf['users']['dd_vendor']['password'])).to eq true
    end

    e.run_step 'Verify transaction as Vendor in Show all page' do
      @common_pages.click_menu(MENU_DYNAMIC_DISCOUNTING)
      @common_pages.click_transactions_tab(SHOW_ALL)
      @common_pages.apply_list_filter({ 'Instrument Number' => @testdata['DD Invoice Details']['Invoice Number'] })
      expect(@transactions_page.verify_transaction_in_list_page(@expected_values, page: :vendor, apply_filter: false)).to eq true
    end

    e.run_step 'Verify transaction as Vendor in Invoices to approve page' do
      @common_pages.click_transactions_tab(INVOICES_TO_APPROVE)
      @common_pages.apply_list_filter({ 'Instrument Number' => @testdata['DD Invoice Details']['Invoice Number'] })
      expect(@transactions_page.verify_transaction_in_list_page(@expected_values, page: :vendor, apply_filter: false)).to eq true
    end

    e.run_step 'Verify transaction as Vendor in landing page' do
      @detail_page_values.delete('Total Payable')
      @detail_page_values['Total Receivable'] = "₹#{comma_seperated_value(@total_payable)}"
      @common_pages.navigate_to_transaction(@transaction_id)
      expect(@transactions_page.verify_transaction_status('Draft')).to eq true
      expect(@transactions_page.verify_transaction_in_detail_page(@detail_page_values)).to eq true
    end

    e.run_step 'Verify Invoice preview is available and content is visible as Vendo' do
      expect(@transactions_page.invoice_preview_available?).to eq true
    end

    e.run_step 'Verify Invoice document as Vendor in landing page' do
      expect(@transactions_page.invoice_exists?(@file_name)).to eq true
      expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq(true), 'Broken links present'
    end

    e.run_step 'Approve Invoice as Vendor' do
      @transactions_page.approve_transaction
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['VendorApproved']
    end

    e.run_step 'Verify transaction status after vendor approval' do
      expect(@transactions_page.verify_transaction_status('Settled')).to eq true
      @tarspect_methods.click_link('Details')
      expect(@transactions_page.status_timeline_present?(@today_date, 'Counterparty approved')).to eq true
    end

    e.run_step 'Verify status timeline in the hovercard after Vendor Approval' do
      @common_pages.click_menu(MENU_DYNAMIC_DISCOUNTING)
      @common_pages.click_transactions_tab(SETTLED)
      @expected_values['Status'] = 'Settled'
      @common_pages.apply_list_filter({ 'Instrument Number' => @testdata['DD Invoice Details']['Invoice Number'] })
      expect(@transactions_page.verify_transaction_in_list_page(@expected_values, page: :vendor, apply_filter: false)).to eq true
      expect(@transactions_page.status_timeline_on_hover(@transaction_id, @today_date, 'Counterparty approved')).to eq true
    end

    e.run_step 'Vendor logs out' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Anchor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['anchor']['email'], $conf['users']['anchor']['password'])).to be true
    end

    e.run_step 'Verify transaction moved to settled as Anchor' do
      @common_pages.click_menu(MENU_DYNAMIC_DISCOUNTING)
      @common_pages.click_transactions_tab(SETTLED)
      @common_pages.apply_list_filter({ 'Instrument Number' => @testdata['DD Invoice Details']['Invoice Number'] })
      expect(@transactions_page.verify_transaction_in_list_page(@expected_values, page: :anchor, apply_filter: false)).to eq true
      expect(@transactions_page.status_timeline_on_hover(@transaction_id, @today_date, 'Counterparty approved')).to eq true
    end

    e.run_step 'Verify transaction status(Settled) in landing page' do
      @common_pages.navigate_to_transaction(@transaction_id)
      expect(@transactions_page.verify_transaction_status('Settled')).to eq true
      expect(@transactions_page.status_timeline_present?(@today_date, 'Counterparty approved')).to eq true
    end

    e.run_step 'Anchor logs out' do
      expect(@common_pages.logout).to eq true
    end
  end

  it 'DD Transaction : Reject flow', :sanity do |e|
    @due_date = Date.today + 30
    @desired_date = Date.today + 10
    @discount = 10
    @tds = 8
    @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
    @invoice_value = @testdata['DD Invoice Details']['Invoice Value'] < @testdata['DD Invoice Details']['GRN'] ? @testdata['DD Invoice Details']['Invoice Value'] : @testdata['DD Invoice Details']['GRN']

    e.run_step 'Login as Anchor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['anchor']['email'], $conf['users']['anchor']['password'])).to be true
    end

    e.run_step 'Add a DD transaction - Anchor against vendor' do
      @transactions_page.add_transaction(@invoice_file, @testdata['DD Invoice Details'], 'Dynamic Discounting - Vendor')
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['InvoiceCreated']
    end

    e.run_step 'Verify DD transaction in the List page' do
      calculated_values = @transactions_page.calculate_payable_value({
                                                                       invoice_value: @invoice_value,
                                                                       discount: @discount,
                                                                       gst: $conf['gst'],
                                                                       tds: @tds
                                                                     })
      @total_payable = calculated_values[0]
      @gst_amount = calculated_values[1]
      @expected_values = {
        'Invoice Number' => @testdata['DD Invoice Details']['Invoice Number'],
        'Anchor Name' => $conf['users']['anchor']['name'],
        'Date of Initiation' => @today_date,
        'Desired Date' => @desired_date.strftime('%d %b, %Y'),
        'Invoice Value' => comma_seperated_value(@testdata['DD Invoice Details']['Invoice Value']),
        'Discount' => format('%.1f', @discount),
        'Days Gained' => (@due_date - @desired_date).numerator.to_s,
        'Status' => 'Draft',
        'Total Payable' => comma_seperated_value(@total_payable)
      }
      @common_pages.apply_list_filter({ 'Instrument Number' => @testdata['DD Invoice Details']['Invoice Number'] })
      expect(@transactions_page.verify_transaction_in_list_page(@expected_values, page: :anchor, apply_filter: false)).to eq true
      @transaction_id = @common_pages.get_transaction_id(@expected_values)
    end

    e.run_step 'Verify DD transaction as Anchor in landing page' do
      @detail_page_values = {
        'Instrument Value' => "₹#{comma_seperated_value(@testdata['DD Invoice Details']['Invoice Value'])}",
        'Instrument Date' => @today_date,
        'GSTN of Anchor' => @anchor_gstn,
        'GSTN of Vendor/Dealer' => @vendor_gstn,
        'Due Date' => @due_date.strftime('%d %b, %Y'),
        'Discount %' => "#{format('%.1f', @discount)} %",
        'GRN Amount' => "₹#{comma_seperated_value(@testdata['DD Invoice Details']['GRN'])}",
        'Days Gained' => (@due_date - @desired_date).numerator.to_s,
        'GST' => "₹#{comma_seperated_value(@gst_amount)}",
        'Total Payable' => "₹#{comma_seperated_value(@total_payable)}"
      }
      @common_pages.navigate_to_transaction(@transaction_id)
      expect(@transactions_page.verify_transaction_status('Draft')).to eq true
      expect(@transactions_page.verify_transaction_in_detail_page(@detail_page_values)).to eq true
    end

    e.run_step 'Anchor logs out' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Vendor - CounterParty' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['dd_vendor']['email'], $conf['users']['dd_vendor']['password'])).to eq true
    end

    e.run_step 'Navigate to transaction and reject the transaction' do
      @common_pages.click_menu(MENU_DYNAMIC_DISCOUNTING)
      @common_pages.click_transactions_tab(SHOW_ALL)
      @common_pages.navigate_to_transaction(@transaction_id)
      @transactions_page.reject_transaction('Discard', @testdata['Reject Reason'])
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['VendorApproved']
    end

    e.run_step 'Verify transaction status after Vendor Reject' do
      expect(@transactions_page.verify_transaction_status('Rejected')).to eq true
      expect(@transactions_page.rejected_status('Discard', $conf['users']['dd_vendor']['name'], @testdata['Reject Reason'])).to eq true
    end

    e.run_step 'Verify transaction moved to Rejected bucket' do
      @common_pages.click_menu(MENU_DYNAMIC_DISCOUNTING)
      @common_pages.click_transactions_tab(REJECTED)
      @expected_values['Status'] = $notifications['Status']['Rejected']
      @common_pages.apply_list_filter({ 'Instrument Number' => @testdata['DD Invoice Details']['Invoice Number'] })
      expect(@transactions_page.verify_transaction_in_list_page(@expected_values, page: :vendor, apply_filter: false)).to eq true
      expect(@transactions_page.rejected_reason_on_hover(@transaction_id, $conf['users']['dd_vendor']['name'], @testdata['Reject Reason'])).to eq true
    end

    e.run_step 'Vendor logs out' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Anchor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['anchor']['email'], $conf['users']['anchor']['password'])).to be true
    end

    e.run_step 'Verify transaction moved to Rejected as Anchor' do
      @common_pages.click_menu(MENU_DYNAMIC_DISCOUNTING)
      @common_pages.click_transactions_tab(REJECTED)
      @common_pages.apply_list_filter({ 'Instrument Number' => @testdata['DD Invoice Details']['Invoice Number'] })
      expect(@transactions_page.verify_transaction_in_list_page(@expected_values, page: :anchor, apply_filter: false)).to eq true
      expect(@transactions_page.rejected_reason_on_hover(@transaction_id, $conf['users']['dd_vendor']['name'], @testdata['Reject Reason'])).to eq true
    end

    e.run_step 'Verify transaction status(Rejected) in landing page' do
      @common_pages.navigate_to_transaction(@transaction_id)
      expect(@transactions_page.verify_transaction_status('Rejected')).to eq true
      expect(@transactions_page.rejected_status('Discard', $conf['users']['dd_vendor']['name'], @testdata['Reject Reason'])).to eq true
    end

    e.run_step 'Anchor logs out' do
      expect(@common_pages.logout).to eq true
    end
  end

  it 'User Permissions : Investor and Anchor', :sanity do |e|
    e.run_step 'Login as Product' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['product']['email'], $conf['users']['product']['password'])).to be true
    end

    e.run_step 'Verify Dynamic Discounting is not available for product' do
      expect(@common_pages.menu_available?('Dynamic Discounting')).to eq false
    end

    e.run_step 'Product logs out' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Investor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['investor']['email'], $conf['users']['investor']['password'])).to eq true
    end

    e.run_step 'Verify Dynamic Discounting is not available for Investor' do
      expect(@common_pages.menu_available?('Dynamic Discounting')).to eq false
    end

    e.run_step 'Verify Dynamic Discounting program is not listed in the anchor programs' do
      @common_pages.click_menu(MENU_ANCHOR_LIST)
      @common_pages.navigate_to_anchor($conf['anchor_name'])
      expect(@common_pages.anchor_available?('Dynamic Discounting')).to eq false
    end

    e.run_step 'Investor logs out' do
      expect(@common_pages.logout).to eq true
    end
  end

  it 'DD Transactions: Bulk Import Validations', :bulk do |e|
    e.run_step 'Login as anchor' do
      flush_directory(@download_path)
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['anchor']['email'], $conf['users']['anchor']['password'])).to eq true
    end

    e.run_step 'Bulk import different file for the program - Sheet name mismatch as anchor' do
      file = "#{Dir.pwd}/test-data/attachments/bulk_import_inv_vendor.xlsx"
      @output = @transactions_page.initiate_bulk_import_transaction(file, 'Dynamic Discounting - Vendor')
      expect(@tarspect_methods.check_for_broken_links('billdiscounting', 'Summary')).to eq(true), 'Broken links present'
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
      @output = @transactions_page.initiate_bulk_import_transaction(file, 'Dynamic Discounting - Vendor')
      expect(@tarspect_methods.check_for_broken_links('billdiscounting', 'Summary')).to eq(true), 'Broken links present'
      expect(@transactions_page.download_summary_report(@download_path)).to eq true
      actual_results = @commercials_page.verify_vendor_import_summary_report("#{@download_path}/report.xlsx").keys
      expect(actual_results[0]).to include 'Invalid Columns found in the sheet - ["GSTN of Vendor", "EWB No (Optional)", "EWB Date (Optional)", "Tenor"]'
      expect(actual_results[0]).to include 'Missing Columns found in the sheet - ["GSTN of vendor", "Due date", "Desired date", "Discount %", "TDS %"]'
      expect(actual_results[0]).to include 'Please verify with the existing template.'
    end

    e.run_step 'Verify summary report modal with headers mismatch as anchor' do
      expect(@transactions_page.transaction_summary_present?).to eq true
      expect(@transactions_page.verify_summary('Total Transactions')).to eq '0'
      expect(@transactions_page.verify_summary('Accepted Transactions')).to eq '0'
      expect(@transactions_page.verify_summary('Rejected Transactions')).to eq '0'
      expect(@transactions_page.verify_summary('Total Value')).to eq '0'
      @tarspect_methods.click_button('close')
    end

    e.run_step 'Verify Download template works for anchor' do
      @tarspect_methods.click_button('Add Transaction')
      @transactions_page.select_transaction_program('Dynamic Discounting - Vendor')
      @tarspect_methods.LINK('Download Template').wait_for_element
      expect(@tarspect_methods.check_for_broken_links('billdiscounting', 'Download Template')).to eq(true), 'Broken links present'
      @tarspect_methods.click_link('Download Template')
      expect(@tarspect_methods.file_downloaded?("#{@download_path}/dd_vendor_transaction_bulk_upload.xlsx")).to eq true
    end

    e.run_step 'Anchor logs out' do
      flush_directory(@download_path)
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Vendor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['dd_vendor']['email'], $conf['users']['dd_vendor']['password'])).to eq true
    end

    e.run_step 'Bulk import different file for the program - Sheet name mismatch as vendor' do
      file = "#{Dir.pwd}/test-data/attachments/bulk_import_inv_vendor.xlsx"
      @output = @transactions_page.initiate_bulk_import_transaction(file, 'Dynamic Discounting - Vendor')
      expect(@tarspect_methods.check_for_broken_links('billdiscounting', 'Summary')).to eq(true), 'Broken links present'
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
      @output = @transactions_page.initiate_bulk_import_transaction(file, 'Dynamic Discounting - Vendor')
      expect(@tarspect_methods.check_for_broken_links('billdiscounting', 'Summary')).to eq(true), 'Broken links present'
      expect(@transactions_page.download_summary_report(@download_path)).to eq true
      actual_results = @commercials_page.verify_vendor_import_summary_report("#{@download_path}/report.xlsx").keys
      expect(actual_results[0]).to include 'Invalid Columns found in the sheet - ["GSTN of Vendor", "EWB No (Optional)", "EWB Date (Optional)", "Tenor"]'
      expect(actual_results[0]).to include 'Missing Columns found in the sheet - ["GSTN of vendor", "Due date", "Desired date", "Discount %", "TDS %"]'
      expect(actual_results[0]).to include 'Please verify with the existing template.'
    end

    e.run_step 'Verify summary report modal with headers mismatch as vendor' do
      expect(@transactions_page.transaction_summary_present?).to eq true
      expect(@transactions_page.verify_summary('Total Transactions')).to eq '0'
      expect(@transactions_page.verify_summary('Accepted Transactions')).to eq '0'
      expect(@transactions_page.verify_summary('Rejected Transactions')).to eq '0'
      expect(@transactions_page.verify_summary('Total Value')).to eq '0'
      @tarspect_methods.click_button('close')
    end

    e.run_step 'Verify Download template works for vendor' do
      @tarspect_methods.click_button('Add Transaction')
      @transactions_page.select_transaction_program('Dynamic Discounting - Vendor')
      @tarspect_methods.click_link('Download Template')
      expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq(true), 'Broken links present'
      expect(@tarspect_methods.file_downloaded?("#{@download_path}/dd_vendor_transaction_bulk_upload.xlsx")).to eq true
      flush_directory(@download_path)
    end
  end
end
