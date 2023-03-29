require './spec_helper'
require 'erb'
# Known issues
# URLs are publicly accessible
# https://vivriticapital.visualstudio.com/Vivriti%20Marketplace/_workitems/edit/13352
###
describe 'Transactions: Anchor', :scf, :transactions, :scf_anchor_transaction, :hover do
  before(:all) do
    @anchor_gstn = $conf['myntra_gstn']
    @counterparty_gstn = $conf['libas_gstn']
    @vendor_name = $conf['vendor_name']
    @anchor_name = $conf['anchor_name']
    @investor_name = $conf['investor_name']
    @invoice_file = "#{Dir.pwd}/test-data/attachments/anchor_invoice.pdf"
    @file_name = 'anchor_invoice.pdf'
    @erb_file = File.read("#{Dir.pwd}/test-data/erb/testbed_data.erb")
  end

  before(:each) do
    @driver = Tarspect::Browser.new($conf['browser']).invoke
    @tarspect_methods = Common::Methods.new(@driver)
    @common_pages = Pages::CommonMethods.new(@driver)
    @transactions_page = Pages::Trasactions.new(@driver)
    @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
    @invoice_value = comma_seperated_value(@testdata['Invoice Details']['Invoice Value'])
    @testdata['Transaction List']['Instrument Value'] = "₹#{@invoice_value}"
    @testdata['Transaction Details']['Instrument Value'] = "₹#{@invoice_value}"
    @today_date = Date.today.strftime('%d %b, %Y')
  end

  after(:each) do |e| # Captures screenshot of the current page when failure happens
    snap_screenshot(e)
    quit_browser
  end

  after(:all) do
    # quit_browser #Tear down
  end

  it 'Transaction : Anchor against vendor', :sanity, :email_notification, :txn_anchor_vendor, :mails, :no_run do |e|
    e.run_step 'Login as Anchor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['anchor']['email'], $conf['users']['anchor']['password'])).to be true
    end
    e.run_step 'Verify Vendor is Approved in investor page' do
      vendor_details = verify_vendor_present(1, 7, @vendor_name, actor: 'anchor')
      expect(vendor_details[:status]).to eq('Verified')
    end

    e.run_step 'Add transaction - Anchor against vendor' do
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @testdata['Invoice Details'].merge!('Tenor' => 60)
      @transactions_page.add_transaction(@invoice_file, @testdata['Invoice Details'], 'Vendor Financing', 'Invoice')
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['InvoiceCreated']
    end

    # e.run_step 'Verify intimation mail received on Transaction Initiation' do
    #   # Transaction initiation mail notification [1st Mail]
    #   flag = verify_mail_present(
    #     subject: 'Invoice(s)/Purchase Order(s) - Pending user action',
    #     body_content: @testdata['Invoice Details']['Invoice Number'],
    #     text: 'Gentle reminder to act'
    #   )
    #   expect(flag).to eq true
    # end

    e.run_step 'Verify transaction as Anchor in list page' do
      @testdata['Transaction List']['Number'] = @testdata['Invoice Details']['Invoice Number']
      expect(@transactions_page.verify_transaction_in_list_page(@testdata['Transaction List'], page: :anchor)).to eq true
      @transaction_id = @common_pages.get_transaction_id(@testdata['Transaction List'])
    end

    e.run_step 'Verify transaction as Anchor in landing page' do
      @common_pages.navigate_to_transaction(@transaction_id)
      expect(@transactions_page.verify_transaction_status('Draft')).to eq true
      expect(@transactions_page.verify_transaction_in_detail_page(@testdata['Transaction Details'])).to eq true
    end

    e.run_step 'Verify Invoice preview is available and content is visible' do
      expect(@transactions_page.invoice_preview_available?).to eq true
    end

    e.run_step 'Verify Invoice document as Anchor in landing page' do
      expect(@transactions_page.invoice_exists?(@file_name)).to eq true
      expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq true
    end

    e.run_step 'Anchor logs out' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as product' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['product']['email'], $conf['users']['product']['password'])).to eq true
    end

    e.run_step 'Verify transaction as product in list page' do
      expect(@transactions_page.verify_transaction_in_list_page(@testdata['Transaction List'], page: :product)).to eq true
    end

    e.run_step 'Verify transaction as Product in landing page' do
      @common_pages.navigate_to_transaction(@transaction_id)
      expect(@transactions_page.verify_transaction_status('Draft')).to eq true
      expect(@transactions_page.verify_transaction_in_detail_page(@testdata['Transaction Details'])).to eq true
    end

    e.run_step 'Verify Invoice document as Product in landing page' do
      expect(@transactions_page.invoice_exists?(@file_name)).to eq true
      expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq true
    end

    e.run_step "Verify transaction listed in 'Invoices to approve' as Product" do
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @common_pages.click_transactions_tab(INVOICES_TO_APPROVE)
      expect(@transactions_page.verify_transaction_in_list_page(@testdata['Transaction List'], page: :product)).to eq true
    end

    e.run_step 'Approve Invoice as Product - 1st level of approval' do
      @common_pages.navigate_to_transaction(@transaction_id)
      @transactions_page.approve_transaction
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['ProductApproved']
    end

    # e.run_step 'Verify intimation mail received on Product(level 1) approval' do
    #   # Product Approval[1st] mail notification [2nd Mail]
    #   flag = verify_mail_present(
    #     subject: 'Invoice(s)/Purchase Order(s) - Pending user action',
    #     body_content: @testdata['Invoice Details']['Invoice Number'],
    #     text: 'Gentle reminder to act'
    #   )
    #   expect(flag).to eq true
    # end

    e.run_step 'Verify status timeline after Product Approval' do
      expect(@transactions_page.status_timeline_present?(@today_date, 'CA Approval')).to eq true
    end

    e.run_step 'Verify status timeline in the hovercard after Product Approval' do
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @common_pages.click_transactions_tab(DRAFT)
      expect(@transactions_page.status_timeline_on_hover(@transaction_id, @today_date, 'CA Approval')).to eq true
    end

    e.run_step 'Product logs out' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Vendor - CounterParty' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['vendor']['email'], $conf['users']['vendor']['password'])).to eq true
    end

    e.run_step 'Verify transaction as Vendor in list page' do
      navigate_to($conf['transactions_url'])
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @common_pages.click_transactions_tab(SHOW_ALL)
      expect(@transactions_page.verify_transaction_in_list_page(@testdata['Transaction List'], page: :vendor)).to eq true
    end

    e.run_step 'Verify transaction as Vendor in landing page' do
      @common_pages.navigate_to_transaction(@transaction_id)
      expect(@transactions_page.verify_transaction_status('Draft')).to eq true
      expect(@transactions_page.verify_transaction_in_detail_page(@testdata['Transaction Details'])).to eq true
    end

    e.run_step 'Verify Invoice document as Vendor in landing page' do
      expect(@transactions_page.invoice_exists?(@file_name)).to eq true
      expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq true
    end

    e.run_step "Verify transaction listed in 'Invoices to approve' as Vendor" do
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @common_pages.click_transactions_tab(INVOICES_TO_APPROVE)
      expect(@transactions_page.verify_transaction_in_list_page(@testdata['Transaction List'], page: :vendor)).to eq true
    end

    e.run_step 'Approve Invoice as Vendor - 2nd level of approval' do
      @common_pages.navigate_to_transaction(@transaction_id)
      @transactions_page.approve_transaction
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['VendorApproved']
    end

    # e.run_step 'Verify intimation mail received on Vendor(level 2) approval' do
    #   # Vendor approval mail notification [3rd Mail]
    #   flag = verify_mail_present(
    #     subject: 'Invoice(s)/Purchase Order(s) - Pending user action',
    #     body_content: @testdata['Invoice Details']['Invoice Number'],
    #     text: 'Gentle reminder to act'
    #   )
    #   expect(flag).to eq true
    # end

    e.run_step 'Verify status timeline after Vendor Approval' do
      expect(@transactions_page.status_timeline_present?(@today_date, 'CA Approval')).to eq true
      expect(@transactions_page.status_timeline_present?(@today_date, 'Vendor/Dealer Approval')).to eq true
      expect(@transactions_page.status_timeline_present?(@today_date, "By\nscf")).to eq true
    end

    e.run_step 'Verify status timeline in the hovercard after Vendor Approval' do
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @common_pages.click_transactions_tab(DRAFT)
      expect(@transactions_page.status_timeline_on_hover(@transaction_id, @today_date, 'CA Approval')).to eq true
      expect(@transactions_page.status_timeline_on_hover(@transaction_id, @today_date, 'Vendor/Dealer Approval')).to eq true
      expect(@transactions_page.status_timeline_on_hover(@transaction_id, @today_date, "By\nscf")).to eq true
    end

    e.run_step 'Vendor logs out' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Product(Level 2) - 3rd party verification' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['product']['email'], $conf['users']['product']['password'])).to eq true
    end

    e.run_step 'Approve Invoice as Product(Level 2) - 3rd level of approval' do
      @common_pages.navigate_to_transaction(@transaction_id)
      expect(@transactions_page.verify_transaction_status('Draft')).to eq true
      @transactions_page.approve_transaction
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['ProductApproved']
    end

    # e.run_step 'Verify intimation mail received on Product(level 3) approval' do
    #   # Product approval [2nd] mail notification [4th Mail]
    #   flag = verify_mail_present(
    #     subject: 'Invoice(s)/Purchase Order(s) - Ready for disbursal',
    #     body_content: @testdata['Invoice Details']['Invoice Number'],
    #     text: 'Gentle reminder to act'
    #   )
    #   expect(flag).to eq true
    # end

    e.run_step 'Verift status changed from Draft to Released' do
      expect(@transactions_page.verify_transaction_status('Released')).to eq true
    end

    e.run_step 'Verify status timeline in the hovercard after Product(Level 2) Approval' do
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @common_pages.click_transactions_tab(LIVE)
      expect(@transactions_page.status_timeline_on_hover(@transaction_id, @today_date, 'CA Approval')).to eq true
      expect(@transactions_page.status_timeline_on_hover(@transaction_id, @today_date, 'Vendor/Dealer Approval')).to eq true
      expect(@transactions_page.status_timeline_on_hover(@transaction_id, @today_date, "By\nscf")).to eq true
      expect(@transactions_page.status_timeline_on_hover(@transaction_id, @today_date, 'CA Approval (Level 2)')).to eq true
    end
  end

  it 'Invoice Preview and Invoice Validations' do |e|
    e.run_step 'Login as Anchor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['anchor']['email'], $conf['users']['anchor']['password'])).to eq true
    end

    e.run_step 'Verify Mandatory fields while uploading invoice : Invoice Number' do
      @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
      @tarspect_methods.click_button('Add Transaction')
      @testdata['Invoice Details'].delete('Invoice Number')
      @transactions_page.select_transaction_program('Vendor Financing', 1)
      @transactions_page.select_transaction_program('Invoice', 2)
      @transactions_page.upload_invoice(@invoice_file, @testdata['Invoice Details'])
      @tarspect_methods.click_button('Submit')
      expect(@transactions_page.error_thrown?('Invoice Number')).to eq true
      @tarspect_methods.click_button('Remove')
      expect(@transactions_page.upload_page_available?).to eq true
    end

    e.run_step 'Verify Mandatory fields while uploading invoice : Invoice Value' do
      @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
      @testdata['Invoice Details'].delete('Invoice Value')
      @transactions_page.select_transaction_program('Vendor Financing', 1)
      @transactions_page.select_transaction_program('Invoice', 2)
      @transactions_page.upload_invoice(@invoice_file, @testdata['Invoice Details'])
      @tarspect_methods.click_button('Submit')
      expect(@transactions_page.error_thrown?('Invoice Value')).to eq true
      @tarspect_methods.click_button('Remove')
    end

    e.run_step 'Verify Mandatory fields while uploading invoice : Invoice Date' do
      @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
      @testdata['Invoice Details'].delete('Invoice Date')
      @transactions_page.select_transaction_program('Vendor Financing', 1)
      @transactions_page.select_transaction_program('Invoice', 2)
      @transactions_page.upload_invoice(@invoice_file, @testdata['Invoice Details'])
      @tarspect_methods.click_button('Submit')
      expect(@transactions_page.error_thrown?('Invoice Date')).to eq true
      @tarspect_methods.click_button('Remove')
    end

    e.run_step 'Verify Mandatory fields while uploading invoice : Anchor GSTN' do
      @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
      @testdata['Invoice Details'].delete('GSTN of Anchor')
      @transactions_page.select_transaction_program('Vendor Financing', 1)
      @transactions_page.select_transaction_program('Invoice', 2)
      @transactions_page.upload_invoice(@invoice_file, @testdata['Invoice Details'])
      @tarspect_methods.click_button('Submit')
      expect(@transactions_page.error_thrown?('GSTN of Anchor')).to eq true
      @tarspect_methods.click_button('Remove')
      @tarspect_methods.close_toaster
    end

    e.run_step 'Verify Mandatory fields while uploading invoice : Wrong Anchor GSTN' do
      @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
      @testdata['Invoice Details']['GSTN of Anchor'] = $conf['libas_gstn']
      @transactions_page.select_transaction_program('Vendor Financing', 1)
      @transactions_page.select_transaction_program('Invoice', 2)
      @transactions_page.upload_invoice(@invoice_file, @testdata['Invoice Details'])
      @tarspect_methods.click_button('Submit')
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['InvalidAnchorGSTN']
      expect(@transactions_page.alert_message).to include($notifications['InvalidAnchorGSTNAlert'])
      @tarspect_methods.click_button('Remove')
    end

    e.run_step 'Verify Mandatory fields while uploading invoice : CounterParty GSTN' do
      @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
      @testdata['Invoice Details'].delete('GSTN of Channel Partner')
      @transactions_page.select_transaction_program('Vendor Financing', 1)
      @transactions_page.select_transaction_program('Invoice', 2)
      @transactions_page.upload_invoice(@invoice_file, @testdata['Invoice Details'])
      @tarspect_methods.click_button('Submit')
      expect(@transactions_page.error_thrown?('GSTN of Channel Partner')).to eq true
      @tarspect_methods.click_button('Remove')
      @tarspect_methods.close_toaster
    end

    e.run_step 'Verify Mandatory fields while uploading invoice : Wrong counter party GSTN' do
      @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
      @testdata['Invoice Details']['GSTN of Channel Partner'] = '99ABREE1288F8ZY'
      @transactions_page.select_transaction_program('Vendor Financing', 1)
      @transactions_page.select_transaction_program('Invoice', 2)
      @transactions_page.upload_invoice(@invoice_file, @testdata['Invoice Details'])
      @tarspect_methods.click_button('Submit')
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['InvalidVendorGSTN']
      expect(@transactions_page.alert_message).to eq $notifications['InvalidVendorGSTNAlert']
      @tarspect_methods.click_button('Remove')
    end

    e.run_step 'Verify Requested disbursement Value greater than Invoice Value' do
      @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
      @testdata['Invoice Details'].merge!('Requested Disbursement Value' => @testdata['Invoice Details']['Invoice Value'] + 1000)
      @transactions_page.select_transaction_program('Vendor Financing', 1)
      @transactions_page.select_transaction_program('Invoice', 2)
      @transactions_page.upload_invoice(@invoice_file, @testdata['Invoice Details'])
      @tarspect_methods.click_button('Submit')
      expect(@common_pages.ERROR_MESSAGE('Requested Disbursement Value').text).to eq('Requested Disbursement Value cannot be greater than the entered Invoice value')
      @tarspect_methods.click_button('Remove')
    end

    e.run_step 'Verify GRN cannot be greater than Invoice Value' do
      @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
      @testdata['Invoice Details'].merge!('GRN' => @testdata['Invoice Details']['Invoice Value'] + 100)
      @transactions_page.select_transaction_program('Vendor Financing', 1)
      @transactions_page.select_transaction_program('Invoice', 2)
      @transactions_page.upload_invoice(@invoice_file, @testdata['Invoice Details'])
      @tarspect_methods.click_button('Submit')
      expect(@common_pages.ERROR_MESSAGE('GRN').text).to eq('GRN cannot be greater than the entered Invoice value')
      @tarspect_methods.click_button('Remove')
    end

    e.run_step 'Verify Requested disbursement value cannot be greater than GRN value ' do
      @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
      @testdata['Invoice Details'].merge!('GRN' => @testdata['Invoice Details']['Invoice Value'] - 100)
      @testdata['Invoice Details'].merge!('Requested Disbursement Value' => @testdata['Invoice Details']['Invoice Value'])
      @transactions_page.select_transaction_program('Vendor Financing', 1)
      @transactions_page.select_transaction_program('Invoice', 2)
      @transactions_page.upload_invoice(@invoice_file, @testdata['Invoice Details'])
      @tarspect_methods.click_button('Submit')
      expect(@common_pages.ERROR_MESSAGE('Requested Disbursement Value').text).to eq('Requested Disbursement Value cannot be greater than the GRN value')
    end
  end

  it 'Transaction : Only show transaction to valid actors', :sanity do |e|
    e.run_step 'Login as Anchor 1 - Myntra' do
      @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
      @invoice_value = comma_seperated_value(@testdata['Invoice Details']['Invoice Value'])
      @testdata['Transaction List']['Instrument Value'] = "₹#{@invoice_value}"
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['anchor']['email'], $conf['users']['anchor']['password'])).to be true
    end

    e.run_step 'Add transaction - Anchor 1 against vendor 1' do
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

    e.run_step 'Anchor 1 logs out' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Anchor 2 - TVS' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['grn_anchor']['email'], $conf['users']['grn_anchor']['password'])).to eq true
    end

    e.run_step 'Verify transaction is not present in list page' do
      expect(@transactions_page.verify_transaction_in_list_page(@testdata['Transaction List'], page: :anchor)).not_to eq true
    end

    e.run_step 'Anchor 2 logs out' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Vendor 2 - Dozco' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['grn_vendor']['email'], $conf['users']['grn_vendor']['password'])).to eq true
    end

    e.run_step 'Verify transaction is not present in list page' do
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      expect(@transactions_page.verify_transaction_in_list_page(@testdata['Transaction List'], page: :vendor)).not_to eq true
    end
  end
end
