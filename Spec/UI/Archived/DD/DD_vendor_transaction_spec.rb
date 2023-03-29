require './spec_helper'
describe 'DD Transactions: Vendor and Re-initiate', :scf, :transactions, :dd, :dd_vendor_transaction, :no_run do
  before(:all) do
    @download_path = "#{Dir.pwd}/test-data/downloaded/dd_vendor_transaction"
    @anchor_gstn = $conf['users']['anchor']['gstn']
    @vendor_gstn = $conf['users']['dd_vendor']['gstn']
    @actor = 'anchor'
    @invoice_file = "#{Dir.pwd}/test-data/attachments/anchor_invoice.pdf"
    @file_name = 'anchor_invoice.pdf'
    @re_initiate_file = "#{Dir.pwd}/test-data/attachments/reinitiate_invoice.pdf"
    @re_initiate_file_name = 'reinitiate_invoice.pdf'
    @erb_file = File.read("#{Dir.pwd}/test-data/erb/testbed_data.erb")
    @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
    @today_date = Date.today.strftime('%d %b, %Y')
  end

  before(:each) do
    @driver = Tarspect::Browser.new($conf['browser'], @download_path).invoke
    @tarspect_methods = Common::Methods.new(@driver)
    @common_pages = Pages::CommonMethods.new(@driver)
    @transactions_page = Pages::Trasactions.new(@driver)
  end

  after(:each) do |e| # Captures screenshot of the current page when failure happens
    snap_screenshot(e)
    quit_browser
  end

  it 'DD Transaction : Vendor against Anchor', :sanity do |e|
    @due_date = Date.today + 30
    @desired_date = Date.today + 10
    @discount = 10
    @tds = 8
    @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
    @invoice_value = @testdata['DD Invoice Details']['Invoice Value'] < @testdata['DD Invoice Details']['GRN'] ? @testdata['DD Invoice Details']['Invoice Value'] : @testdata['DD Invoice Details']['GRN']

    e.run_step 'Delete Auto approval rules' do
      resp = delete_rule(@actor)
      expect(resp[:code]).to eq(200)
    end

    e.run_step 'Login as Vendor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['dd_vendor']['email'], $conf['users']['dd_vendor']['password'])).to be true
    end

    e.run_step 'Add a DD transaction - Vendor against Anchor' do
      @common_pages.click_menu(MENU_PO_FINANCING)
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
        'Total Receivable' => comma_seperated_value(@total_payable)
      }
      @common_pages.apply_list_filter({ 'Instrument Number' => @testdata['DD Invoice Details']['Invoice Number'] })
      expect(@transactions_page.verify_transaction_in_list_page(@expected_values, page: :vendor, apply_filter: false)).to eq true
      @transaction_id = @common_pages.get_transaction_id(@expected_values)
    end

    e.run_step 'Verify DD transaction as Vendor in landing page' do
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
        'Total Receivable' => "₹#{comma_seperated_value(@total_payable)}"
      }
      @common_pages.navigate_to_transaction(@transaction_id)
      expect(@transactions_page.verify_transaction_status('Draft')).to eq true
      expect(@transactions_page.verify_transaction_in_detail_page(@detail_page_values)).to eq true
    end

    e.run_step 'Verify Invoice preview is available and content is visible' do
      expect(@transactions_page.invoice_preview_available?).to eq true
    end

    e.run_step 'Verify Invoice document as Vendor in landing page' do
      expect(@transactions_page.invoice_exists?(@file_name)).to eq true
      expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq true
    end

    e.run_step 'Vendor logs out' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Anchor - CounterParty' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['anchor']['email'], $conf['users']['anchor']['password'])).to eq true
    end

    e.run_step 'Verify transaction as Anchor in Show all page' do
      @common_pages.click_menu(MENU_DYNAMIC_DISCOUNTING)
      @common_pages.click_transactions_tab(SHOW_ALL)
      expect(@transactions_page.verify_transaction_in_list_page(@expected_values, page: :anchor)).to eq true
    end

    e.run_step 'Verify transaction as Anchor in Invoices to approve page' do
      @common_pages.click_transactions_tab(INVOICES_TO_APPROVE)
      expect(@transactions_page.verify_transaction_in_list_page(@expected_values, page: :anchor)).to eq true
    end

    e.run_step 'Verify transaction as Anchor in landing page' do
      @detail_page_values.delete('Total Receivable')
      @detail_page_values['Total Payable'] = "₹#{comma_seperated_value(@total_payable)}"
      @common_pages.navigate_to_transaction(@transaction_id)
      expect(@transactions_page.verify_transaction_status('Draft')).to eq true
      expect(@transactions_page.verify_transaction_in_detail_page(@detail_page_values)).to eq true
    end

    e.run_step 'Verify Invoice preview is available and content is visible as Vendo' do
      expect(@transactions_page.invoice_preview_available?).to eq true
    end

    e.run_step 'Verify Invoice document as Anchor in landing page' do
      expect(@transactions_page.invoice_exists?(@file_name)).to eq true
      expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq true
    end

    e.run_step 'Approve Invoice as Anchor' do
      @transactions_page.approve_transaction
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['VendorApproved']
    end

    e.run_step 'Verify transaction status after Anchor approval' do
      expect(@transactions_page.verify_transaction_status('Settled')).to eq true
      @tarspect_methods.click_link('Details')
      expect(@transactions_page.status_timeline_present?(@today_date, 'Counterparty approved')).to eq true
    end

    e.run_step 'Verify status timeline in the hovercard after Anchor Approval' do
      @common_pages.click_menu(MENU_DYNAMIC_DISCOUNTING)
      @common_pages.click_transactions_tab(SETTLED)
      @expected_values['Status'] = 'Settled'
      expect(@transactions_page.verify_transaction_in_list_page(@expected_values, page: :anchor)).to eq true
      expect(@transactions_page.status_timeline_on_hover(@transaction_id, @today_date, 'Counterparty approved')).to eq true
    end

    e.run_step 'Anchor logs out' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Vendor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['dd_vendor']['email'], $conf['users']['dd_vendor']['password'])).to be true
    end

    e.run_step 'Verify transaction moved to settled as Vendor' do
      @common_pages.click_menu(MENU_DYNAMIC_DISCOUNTING)
      @common_pages.click_transactions_tab(SETTLED)
      expect(@transactions_page.verify_transaction_in_list_page(@expected_values, page: :vendor)).to eq true
      expect(@transactions_page.status_timeline_on_hover(@transaction_id, @today_date, 'Counterparty approved')).to eq true
    end

    e.run_step 'Verify transaction status(Settled) in landing page' do
      @common_pages.navigate_to_transaction(@transaction_id)
      expect(@transactions_page.verify_transaction_status('Settled')).to eq true
      expect(@transactions_page.status_timeline_present?(@today_date, 'Counterparty approved')).to eq true
    end
  end

  it 'DD Transaction : Re-Initiate flow', :sanity do |e|
    @due_date = Date.today + 30
    @desired_date = Date.today + 10
    @discount = 10
    @tds = 8
    @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
    @testdata['DD Invoice Details']['GRN'] = @testdata['DD Invoice Details']['Invoice Value'] - 1000
    @invoice_value = @testdata['DD Invoice Details']['Invoice Value'] < @testdata['DD Invoice Details']['GRN'] ? @testdata['DD Invoice Details']['Invoice Value'] : @testdata['DD Invoice Details']['GRN']

    e.run_step 'Delete Auto approval rules' do
      resp = delete_rule(@actor)
      expect(resp[:code]).to eq(200)
    end

    e.run_step 'Login as Vendor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['dd_vendor']['email'], $conf['users']['dd_vendor']['password'])).to be true
    end

    e.run_step 'Add a DD transaction - Vendor against Anchor' do
      @common_pages.click_menu(MENU_PO_FINANCING)
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
        'Total Receivable' => comma_seperated_value(@total_payable)
      }
      @common_pages.apply_list_filter({ 'Instrument Number' => @testdata['DD Invoice Details']['Invoice Number'] })
      expect(@transactions_page.verify_transaction_in_list_page(@expected_values, page: :vendor, apply_filter: false)).to eq true
      @transaction_id = @common_pages.get_transaction_id(@expected_values)
    end

    e.run_step 'Verify DD transaction as Vendor in landing page' do
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
        'Total Receivable' => "₹#{comma_seperated_value(@total_payable)}"
      }
      @common_pages.navigate_to_transaction(@transaction_id)
      expect(@transactions_page.verify_transaction_status('Draft')).to eq true
      expect(@transactions_page.verify_transaction_in_detail_page(@detail_page_values)).to eq true
    end

    e.run_step 'Vendor logs out' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Anchor - CounterParty' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['anchor']['email'], $conf['users']['anchor']['password'])).to eq true
    end

    e.run_step 'Navigate to transaction and Re-initiate the transaction' do
      @common_pages.click_menu(MENU_DYNAMIC_DISCOUNTING)
      @common_pages.click_transactions_tab(SHOW_ALL)
      @common_pages.navigate_to_transaction(@transaction_id)
      @transactions_page.reject_transaction('Re-Initiate Transaction', @testdata['Reject Reason'])
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['VendorApproved']
    end

    e.run_step 'Verify transaction status after Anchor Reject' do
      expect(@transactions_page.verify_transaction_status('Rejected')).to eq true
      expect(@transactions_page.rejected_status('Re-Initiate Transaction', $conf['anchor_reject'], @testdata['Reject Reason'])).to eq true
    end

    e.run_step 'Verify transaction moved to Rejected bucket' do
      @common_pages.click_menu(MENU_DYNAMIC_DISCOUNTING)
      @common_pages.click_transactions_tab(REJECTED)
      @expected_values['Status'] = $notifications['Status']['Rejected']
      @common_pages.apply_list_filter({ 'Instrument Number' => @testdata['DD Invoice Details']['Invoice Number'] })
      expect(@transactions_page.verify_transaction_in_list_page(@expected_values, page: :anchor, apply_filter: false)).to eq true
    end

    e.run_step 'Verify status timeline value of that transaction' do
      expect(@transactions_page.rejected_reason_on_hover(@transaction_id, $conf['anchor_reject'], @testdata['Reject Reason'])).to eq true
    end

    e.run_step 'Anchor logs out' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Vendor to Re-Initiate the transaction' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['dd_vendor']['email'], $conf['users']['dd_vendor']['password'])).to be true
    end

    e.run_step 'Verify transaction moved to Rejected' do
      @common_pages.click_menu(MENU_DYNAMIC_DISCOUNTING)
      @common_pages.click_transactions_tab(REJECTED)
      expect(@common_pages.transaction_listed?(@transaction_id)).to eq(true), "Transaction #{@transaction_id} is not listed"
    end

    e.run_step 'Verify status timeline value of that transaction' do
      expect(@transactions_page.rejected_reason_on_hover(@transaction_id, $conf['anchor_reject'], @testdata['Reject Reason'])).to eq true
    end

    e.run_step 'Verify transaction status(Rejected) and status timeline(Re-Initiate) in landing page' do
      @common_pages.navigate_to_transaction(@transaction_id)
      expect(@transactions_page.verify_transaction_status('Rejected')).to eq true
      expect(@transactions_page.rejected_status('Re-Initiate Transaction', $conf['anchor_reject'], @testdata['Reject Reason'])).to eq true
    end

    e.run_step 'Re-Initiate the transation as Vendor' do
      @due_date = Date.today + 50
      @desired_date = Date.today + 40
      @discount = 12
      @tds = 11
      @re_initiate_details = {
        'Invoice Value' => Faker::Number.number(digits: 4) * 10,
        'Invoice Date' => (Date.today - 4).strftime('%d-%b-%Y'),
        'GRN Date' => (Date.today + 2).strftime('%d-%b-%Y'),
        'Due Date' => @due_date.strftime('%d-%b-%Y'),
        'Desired Date' => @desired_date.strftime('%d-%b-%Y'),
        'Discount' => @discount,
        'TDS' => @tds
      }
      @re_initiate_details['GRN (optional)'] = @re_initiate_details['Invoice Value'] + 2000
      @tarspect_methods.fill_form(@re_initiate_details, 1, 2)
      @common_pages.file_input.fill_without_clear @re_initiate_file
      @transactions_page.re_initiate_transaction(nil, nil, true)
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['ReInitiateSucess']
    end

    e.run_step 'Verify Re-Initiated transaction values as Vendor in landing page' do
      @invoice_value = @re_initiate_details['Invoice Value']
      calculated_values = @transactions_page.calculate_payable_value({
                                                                       invoice_value: @invoice_value,
                                                                       discount: @discount,
                                                                       gst: $conf['gst'],
                                                                       tds: @tds
                                                                     })
      @total_payable = calculated_values[0]
      @gst_amount = calculated_values[1]
      @detail_page_values = {
        'Instrument Value' => "₹#{comma_seperated_value(@re_initiate_details['Invoice Value'])}",
        'Instrument Date' => (Date.today - 4).strftime('%d %b, %Y'),
        'GSTN of Anchor' => @anchor_gstn,
        'GSTN of Vendor/Dealer' => @vendor_gstn,
        'Due Date' => @due_date.strftime('%d %b, %Y'),
        'Discount %' => "#{format('%.1f', @discount)} %",
        'GRN Amount' => "₹#{comma_seperated_value(@re_initiate_details['GRN (optional)'])}",
        'Days Gained' => (@due_date - @desired_date).numerator.to_s,
        'GST' => "₹#{comma_seperated_value(@gst_amount)}",
        'Total Receivable' => "₹#{comma_seperated_value(@total_payable)}"
      }
      expect(@transactions_page.verify_transaction_in_detail_page(@detail_page_values)).to eq true
    end

    e.run_step 'Verify Invoice preview is available and content is visible' do
      expect(@transactions_page.invoice_preview_available?).to eq true
    end

    e.run_step 'Verify Re-Initiate document is available' do
      expect(@transactions_page.invoice_exists?(@file_name)).to eq true
      expect(@transactions_page.invoice_exists?(@re_initiate_file_name)).to eq true
      expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq true
    end

    e.run_step 'Verify Re-Initiated transaction in the List page' do
      @common_pages.click_menu(MENU_DYNAMIC_DISCOUNTING)
      @common_pages.click_transactions_tab(DRAFT)
      @expected_values = {
        'Invoice Number' => @testdata['DD Invoice Details']['Invoice Number'],
        'Anchor Name' => $conf['users']['anchor']['name'],
        'Date of Initiation' => @today_date,
        'Desired Date' => @desired_date.strftime('%d %b, %Y'),
        'Invoice Value' => comma_seperated_value(@re_initiate_details['Invoice Value']),
        'Discount' => format('%.1f', @discount),
        'Days Gained' => (@due_date - @desired_date).numerator.to_s,
        'Status' => 'Draft',
        'Total Receivable' => comma_seperated_value(@total_payable)
      }
      @common_pages.apply_list_filter({ 'Instrument Number' => @testdata['DD Invoice Details']['Invoice Number'] })
      expect(@transactions_page.verify_transaction_in_list_page(@expected_values, page: :vendor, apply_filter: false)).to eq true
      expect(@transactions_page.rejected_reason_on_hover(@transaction_id, $conf['anchor_reject'], @testdata['Reject Reason'])).to eq true
    end

    e.run_step 'Vendor logs out' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Anchor - CounterParty' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['anchor']['email'], $conf['users']['anchor']['password'])).to eq true
    end

    e.run_step 'Approve Re-Initiated transactin as Anchor' do
      @common_pages.click_menu(MENU_DYNAMIC_DISCOUNTING)
      @common_pages.click_transactions_tab(SHOW_ALL)
      @common_pages.navigate_to_transaction(@transaction_id)
      expect(@transactions_page.verify_transaction_status('Draft')).to eq true
      @transactions_page.approve_transaction
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['VendorApproved']
    end

    e.run_step 'Verify transaction status after Anchor approval' do
      expect(@transactions_page.verify_transaction_status('Settled')).to eq true
      expect(@transactions_page.status_timeline_present?(@today_date, 'Counterparty approved')).to eq true
      expect(@transactions_page.status_timeline_present?(@today_date, 'Reinitiated')).to eq true
      expect(@transactions_page.status_timeline_present?(@today_date, 'Counterparty rejected to re-initiate')).to eq true
    end

    e.run_step 'Verify Re-Initiate document is available' do
      expect(@transactions_page.invoice_exists?(@file_name)).to eq true
      expect(@transactions_page.invoice_exists?(@re_initiate_file_name)).to eq true
      expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq true
    end

    e.run_step 'Verify status timeline in the hovercard after Anchor Approval' do
      @common_pages.click_menu(MENU_DYNAMIC_DISCOUNTING)
      @common_pages.click_transactions_tab(SETTLED)
      @expected_values['Status'] = 'Settled'
      @common_pages.apply_list_filter({ 'Instrument Number' => @testdata['DD Invoice Details']['Invoice Number'] })
      expect(@transactions_page.verify_transaction_in_list_page(@expected_values, page: :anchor, apply_filter: false)).to eq true
      expect(@transactions_page.rejected_reason_on_hover(@transaction_id, $conf['anchor_reject'], @testdata['Reject Reason'])).to eq true
    end

    e.run_step 'Anchor logs out' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Vendor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['dd_vendor']['email'], $conf['users']['dd_vendor']['password'])).to be true
    end

    e.run_step 'Verify transaction moved to settled for Re-Initiated transaction' do
      @common_pages.click_menu(MENU_DYNAMIC_DISCOUNTING)
      @common_pages.click_transactions_tab(SETTLED)
      @common_pages.apply_list_filter({ 'Instrument Number' => @testdata['DD Invoice Details']['Invoice Number'] })
      expect(@transactions_page.verify_transaction_in_list_page(@expected_values, page: :vendor, apply_filter: false)).to eq true
      expect(@transactions_page.rejected_reason_on_hover(@transaction_id, $conf['anchor_reject'], @testdata['Reject Reason'])).to eq true
    end

    e.run_step 'Verify transaction status timeline after Anchor approval' do
      @common_pages.navigate_to_transaction(@transaction_id)
      expect(@transactions_page.status_timeline_present?(@today_date, 'Counterparty approved')).to eq true
      expect(@transactions_page.status_timeline_present?(@today_date, 'Reinitiated')).to eq true
      expect(@transactions_page.status_timeline_present?(@today_date, 'Counterparty rejected to re-initiate')).to eq true
    end
  end

  it 'DD Invoice Preview and Field Validations' do |e|
    e.run_step 'Login as Anchor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['anchor']['email'], $conf['users']['anchor']['password'])).to eq true
    end

    e.run_step 'Verify Mandatory fields while uploading invoice : Invoice Number' do
      @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
      @tarspect_methods.click_button('Add Transaction')
      @testdata['DD Invoice Details'].delete('Invoice Number')
      @transactions_page.select_transaction_program('Dynamic Discounting - Vendor')
      @transactions_page.upload_invoice(@invoice_file, @testdata['DD Invoice Details'])
      @tarspect_methods.click_button('Submit')
      expect(@transactions_page.error_thrown?('Invoice Number')).to eq true
      @tarspect_methods.click_button('Remove')
      expect(@transactions_page.upload_page_available?).to eq true
    end

    e.run_step 'Verify Mandatory fields while uploading invoice : Invoice Value' do
      @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
      @testdata['DD Invoice Details'].delete('Invoice Value')
      @transactions_page.select_transaction_program('Dynamic Discounting - Vendor')
      @transactions_page.upload_invoice(@invoice_file, @testdata['DD Invoice Details'])
      @tarspect_methods.click_button('Submit')
      expect(@transactions_page.error_thrown?('Invoice Value')).to eq true
      @tarspect_methods.click_button('Remove')
    end

    e.run_step 'Verify Mandatory fields while uploading invoice : Invoice Date' do
      @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
      @testdata['DD Invoice Details'].delete('Invoice Date')
      @transactions_page.select_transaction_program('Dynamic Discounting - Vendor')
      @transactions_page.upload_invoice(@invoice_file, @testdata['DD Invoice Details'])
      @tarspect_methods.click_button('Submit')
      expect(@transactions_page.error_thrown?('Invoice Date')).to eq true
      @tarspect_methods.click_button('Remove')
    end

    e.run_step 'Verify Mandatory fields while uploading invoice : Anchor GSTN' do
      @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
      @testdata['DD Invoice Details'].delete('GSTN of Anchor')
      @transactions_page.select_transaction_program('Dynamic Discounting - Vendor')
      @transactions_page.upload_invoice(@invoice_file, @testdata['DD Invoice Details'])
      @tarspect_methods.click_button('Submit')
      expect(@transactions_page.error_thrown?('GSTN of Anchor')).to eq true
      @tarspect_methods.click_button('Remove')
      @tarspect_methods.close_toaster
    end

    e.run_step 'Verify Mandatory fields while uploading invoice : Wrong Anchor GSTN' do
      @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
      @testdata['DD Invoice Details']['GSTN of Anchor'] = $conf['libas_gstn']
      @transactions_page.select_transaction_program('Dynamic Discounting - Vendor')
      @transactions_page.upload_invoice(@invoice_file, @testdata['DD Invoice Details'])
      @tarspect_methods.click_button('Submit')
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['InvalidAnchorGSTN']
      expect(@transactions_page.alert_message).to eq $notifications['InvalidAnchorGSTNAlert']
      @tarspect_methods.click_button('Remove')
    end

    e.run_step 'Verify Mandatory fields while uploading invoice : CounterParty GSTN' do
      @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
      @testdata['DD Invoice Details'].delete('GSTN of Vendor')
      @transactions_page.select_transaction_program('Dynamic Discounting - Vendor')
      @transactions_page.upload_invoice(@invoice_file, @testdata['DD Invoice Details'])
      @tarspect_methods.click_button('Submit')
      expect(@transactions_page.error_thrown?('GSTN of Vendor')).to eq true
      @tarspect_methods.click_button('Remove')
      @tarspect_methods.close_toaster
    end

    e.run_step 'Verify Mandatory fields while uploading invoice : Wrong counter party GSTN' do
      @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
      @testdata['DD Invoice Details']['GSTN of Vendor'] = '99ABREE1288F8ZY'
      @transactions_page.select_transaction_program('Dynamic Discounting - Vendor')
      @transactions_page.upload_invoice(@invoice_file, @testdata['DD Invoice Details'])
      @tarspect_methods.click_button('Submit')
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['InvalidVendorGSTN']
      expect(@transactions_page.alert_message).to eq $notifications['InvalidVendorGSTNAlert']
      @tarspect_methods.click_button('Remove')
    end

    # e.run_step "Verify Mandatory fields while uploading invoice : Due Date" do
    #   @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
    #   @testdata['DD Invoice Details'].delete('Due Date')
    #   @transactions_page.select_transaction_program('Dynamic Discounting - Vendor')
    #   @transactions_page.upload_invoice(@invoice_file, @testdata['DD Invoice Details'])
    #   @tarspect_methods.click_button('Submit')
    #   expect(@transactions_page.error_thrown?('Due Date')).to eq true
    #   @tarspect_methods.click_button('Remove')
    # end

    # e.run_step "Verify Mandatory fields while uploading invoice : Desired Date" do
    #   @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
    #   @testdata['DD Invoice Details'].delete('Desired Date')
    #   @transactions_page.select_transaction_program('Dynamic Discounting - Vendor')
    #   @transactions_page.upload_invoice(@invoice_file, @testdata['DD Invoice Details'])
    #   @tarspect_methods.click_button('Submit')
    #   expect(@transactions_page.error_thrown?('Desired Date')).to eq true
    #   @tarspect_methods.click_button('Remove')
    # end

    e.run_step 'Verify Mandatory fields while uploading invoice : Discount' do
      @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
      @testdata['DD Invoice Details'].delete('Discount')
      @transactions_page.select_transaction_program('Dynamic Discounting - Vendor')
      @transactions_page.upload_invoice(@invoice_file, @testdata['DD Invoice Details'])
      @tarspect_methods.click_button('Submit')
      expect(@transactions_page.error_thrown?('Discount')).to eq true
      @tarspect_methods.click_button('Remove')
    end

    e.run_step 'Verify Mandatory fields while uploading invoice : TDS' do
      @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
      @testdata['DD Invoice Details'].delete('TDS')
      @transactions_page.select_transaction_program('Dynamic Discounting - Vendor')
      @transactions_page.upload_invoice(@invoice_file, @testdata['DD Invoice Details'])
      @tarspect_methods.click_button('Submit')
      expect(@transactions_page.error_thrown?('TDS')).to eq true
      @tarspect_methods.click_button('Remove')
    end
  end

  it 'DD Transactions: Bulk Import', :bulk do |e|
    e.run_step 'Login as anchor' do
      flush_directory(@download_path)
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['anchor']['email'], $conf['users']['anchor']['password'])).to eq true
    end

    e.run_step 'Import bulk DD transaction and verify summary report' do
      expected_results = @transactions_page.add_dd_bulk_transaction
      expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq true
      expect(@transactions_page.download_summary_report(@download_path)).to eq true
      report_link = @transactions_page.get_summary_report_link
      actual_results = @transactions_page.verify_summary_report(report_link)
      expect(actual_results).to eq expected_results
    end

    e.run_step 'Verify summary report modal after bulk import' do
      expect(@transactions_page.transaction_summary_present?).to eq true
      expect(@transactions_page.verify_summary('Total Transactions')).to eq '14'
      expect(@transactions_page.verify_summary('Accepted Transactions')).to eq '2'
      expect(@transactions_page.verify_summary('Rejected Transactions')).to eq '12'
      expect(@transactions_page.verify_summary('Total Value')).to eq '15000'
      @tarspect_methods.click_button('close')
    end

    e.run_step 'Verify transactions created for the valid records' do
      expect(@transactions_page.verify_valid_dd_transactions(page: :anchor)).to eq true
    end

    e.run_step 'Anchor logs out' do
      flush_directory(@download_path)
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Vendor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['dd_vendor']['email'], $conf['users']['dd_vendor']['password'])).to eq true
    end

    e.run_step 'Import bulk DD transaction and verify summary report' do
      @common_pages.click_menu(MENU_PO_FINANCING)
      expected_results = @transactions_page.add_dd_bulk_transaction
      expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq true
      expect(@transactions_page.download_summary_report(@download_path)).to eq true
      report_link = @transactions_page.get_summary_report_link
      actual_results = @transactions_page.verify_summary_report(report_link)
      expect(actual_results).to eq expected_results
    end

    e.run_step 'Verify summary report modal after bulk import' do
      expect(@transactions_page.transaction_summary_present?).to eq true
      expect(@transactions_page.verify_summary('Total Transactions')).to eq '14'
      expect(@transactions_page.verify_summary('Accepted Transactions')).to eq '2'
      expect(@transactions_page.verify_summary('Rejected Transactions')).to eq '12'
      expect(@transactions_page.verify_summary('Total Value')).to eq '15000'
      @tarspect_methods.click_button('close')
    end

    e.run_step 'Verify transactions created for the valid records' do
      expect(@transactions_page.verify_valid_dd_transactions(page: :vendor)).to eq true
      flush_directory(@download_path)
    end
  end
end
