require './spec_helper'
describe 'PO Transactions', :scf, :transactions, :po, :po_transaction, :hover do
  before(:all) do
    @party_gstn = $conf['tvs_gstn']
    @counterparty_gstn = $conf['users']['po_vendor']['gstn']
    @vendor_name = $conf['users']['po_vendor']['name']
    @anchor_name = $conf['users']['grn_anchor']['name']
    @investor_name = $conf['investor_name']
    @po_file = "#{Dir.pwd}/test-data/attachments/anchor_invoice.pdf"
    @file_name = 'anchor_invoice.pdf'
    @erb_file = File.read("#{Dir.pwd}/test-data/erb/testbed_data.erb")
  end

  before(:each) do
    @driver = Tarspect::Browser.new($conf['browser']).invoke
    @tarspect_methods = Common::Methods.new(@driver)
    @common_pages = Pages::CommonMethods.new(@driver)
    @transactions_page = Pages::Trasactions.new(@driver)
    @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
    @total_po_value = comma_seperated_value(@testdata['PO Details']['PO Value'])
    @eligile_po_value = comma_seperated_value(@testdata['PO Details']['Requested Disbursement Value'])
    @testdata['Transaction List']['Instrument Value'] = "₹#{@eligile_po_value}"
    @testdata['PO Detail View']['Requested Disbursement Value'] = "₹#{@eligile_po_value}"
    @testdata['PO Detail View']['Instrument Value'] = "₹#{@total_po_value}"
    @today_date = Date.today.strftime('%d %b, %Y')
    @testdata['Transaction List'].delete('Invoice Value')
  end

  after(:each) do |e|
    snap_screenshot(e)
    quit_browser
  end

  it 'PO Transaction : Anchor against vendor', :sanity, :anchor_against_vendor do |e|
    e.run_step 'Login as Anchor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['grn_anchor']['email'], $conf['users']['grn_anchor']['password'])).to be true
    end

    e.run_step 'Verify Vendor is Approved in investor page' do
      @common_pages.click_menu(MENU_PROGRAMS)
      @common_pages.select_program('Vendor Financing')
      @common_pages.click_live_investors
      @common_pages.navigate_to_investor(@testdata['Investor Commercials']['investor'])
      expect(@transactions_page.verify_vendor_approved?(@vendor_name)).to eq true
    end

    e.run_step 'Add PO transaction - Anchor against vendor' do
      @common_pages.click_menu(MENU_PO_FINANCING)
      @common_pages.click_transactions_tab(SHOW_ALL)
      @transactions_page.add_transaction(@po_file, @testdata['PO Details'], 'Vendor Financing', 'PO')
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['POCreated']
    end

    e.run_step 'Verify PO as Anchor in list page' do
      @common_pages.click_menu(MENU_PO_FINANCING)
      @common_pages.apply_filter({ 'Instrument Number' => @testdata['PO Details']['PO Number'], 'With Documents?' => true })
      @testdata['Transaction List']['Number'] = @testdata['PO Details']['PO Number']
      @testdata['Transaction List']['Instrument Value'] = round_the_amount_to_lakhs(@testdata['PO Details']['PO Value'])
      expect(@transactions_page.verify_transaction_in_list_page(@testdata['Transaction List'], page: :anchor, apply_filter: false)).to eq true
      @transaction_id = @common_pages.get_transaction_id(@testdata['Transaction List'])
    end

    e.run_step 'Verify PO as Anchor in landing page' do
      @common_pages.navigate_to_transaction(@transaction_id)
      expect(@transactions_page.verify_transaction_status('Draft')).to eq true
      expect(@transactions_page.verify_transaction_in_detail_page(@testdata['PO Detail View'])).to eq true
    end

    e.run_step 'Verify PO document preview is available and content is visible' do
      expect(@transactions_page.invoice_preview_available?).to eq true
    end

    e.run_step 'Verify PO document as Anchor in landing page' do
      expect(@transactions_page.invoice_exists?(@file_name, 'Purchase Order')).to eq true
      # expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq true
    end

    e.run_step 'Verify No Invoice document as Anchor in landing page' do
      expect(@transactions_page.invoice_exists?(@file_name)).to eq false
    end

    e.run_step 'Anchor logs out' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as product' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['product']['email'], $conf['users']['product']['password'])).to eq true
    end

    e.run_step 'Verify transaction as product in list page listing under Invoices to approve' do
      @common_pages.click_menu(MENU_PO_FINANCING)
      @common_pages.click_transactions_tab(INVOICES_TO_APPROVE)
      queries = { actor: 'product', category: 'pending_approval_invoices', program_group: 'po' }
      result = api_transaction_listed?(queries, @transaction_id)
      expect(result[0]).to eq(true), 'Transaction not listed in pending_approval_invoices'
      @tran_resp = get_po_details(@transaction_id, actor: 'product')
      expect(api_verify_transaction_in_list_page(@tran_resp[:body], @testdata['Transaction List'])).to eq(true)
    end

    e.run_step 'Verify transaction as Product in landing page' do
      @common_pages.apply_filter({ 'Instrument Number' => @testdata['PO Details']['PO Number'], 'With Documents?' => true })
      @common_pages.navigate_to_transaction(@transaction_id)
      expect(@transactions_page.verify_transaction_status('Draft')).to eq true
      expect(@transactions_page.verify_transaction_in_detail_page(@testdata['PO Detail View'])).to eq true
    end

    e.run_step 'Verify PO document preview is available and content is visible' do
      expect(@transactions_page.invoice_preview_available?).to eq true
    end

    e.run_step 'Verify PO document as Anchor in landing page' do
      expect(@transactions_page.invoice_exists?(@file_name, 'Purchase Order')).to eq true
      # expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq true
    end

    e.run_step 'Verify No Invoice document as Anchor in landing page' do
      expect(@transactions_page.invoice_exists?(@file_name)).to eq false
    end

    e.run_step 'Approve Invoice as Product - 1st level of approval' do
      @transactions_page.approve_transaction
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['ProductApproved']
    end

    e.run_step 'Verify status timeline after Product Approval' do
      @tarspect_methods.click_link('Details')
      expect(@transactions_page.status_timeline_present?(@today_date, 'CA Approval')).to eq true
    end

    e.run_step 'Verify status timeline in the hovercard after Product Approval' do
      @common_pages.click_menu(MENU_PO_FINANCING)
      @common_pages.click_transactions_tab(DRAFT)
      @common_pages.apply_filter({ 'Instrument Number' => @testdata['PO Details']['PO Number'], 'With Documents?' => true })
      expect(@transactions_page.status_timeline_on_hover(@transaction_id, @today_date, 'CA Approval')).to eq true
    end

    e.run_step 'Product logs out' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Vendor - CounterParty' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['po_vendor']['email'], $conf['users']['po_vendor']['password'])).to eq true
    end

    e.run_step 'Verify transaction as Vendor in list page listing under invoices to Approve' do
      @tran_resp = get_po_details(@transaction_id, actor: 'po_vendor')
      expect(api_verify_transaction_in_list_page(@tran_resp[:body], @testdata['Transaction List'])).to eq(true)
    end

    e.run_step 'Verify transaction as Vendor in landing page' do
      navigate_to($conf['transactions_url'])
      @common_pages.click_menu(MENU_PO_FINANCING)
      @common_pages.click_transactions_tab(INVOICES_TO_APPROVE)
      @common_pages.apply_filter({ 'Instrument Number' => @testdata['PO Details']['PO Number'], 'With Documents?' => true })
      @common_pages.navigate_to_transaction(@transaction_id)
      expect(@transactions_page.verify_transaction_status('Draft')).to eq true
      expect(@transactions_page.verify_transaction_in_detail_page(@testdata['PO Detail View'])).to eq true
    end

    e.run_step 'Verify PO document as Vendor in landing page' do
      expect(@transactions_page.invoice_exists?(@file_name, 'Purchase Order')).to eq true
      # expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq true
    end

    e.run_step 'Verify No Invoice document as Vendor in landing page' do
      expect(@transactions_page.invoice_exists?(@file_name)).to eq false
    end

    e.run_step 'Approve Invoice as Vendor - 2st level of approval' do
      @transactions_page.approve_transaction
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['VendorApproved']
    end

    e.run_step 'Verify status timeline after Vendor Approval' do
      @tarspect_methods.click_link('Details')
      expect(@transactions_page.status_timeline_present?(@today_date, 'CA Approval')).to eq true
      expect(@transactions_page.status_timeline_present?(@today_date, 'Vendor/Dealer Approval')).to eq true
    end

    e.run_step 'Verify status timeline in the hovercard after Vendor Approval' do
      @common_pages.click_menu(MENU_PO_FINANCING)
      @common_pages.click_transactions_tab(DRAFT)
      @common_pages.apply_filter({ 'Instrument Number' => @testdata['PO Details']['PO Number'], 'With Documents?' => true })
      expect(@transactions_page.status_timeline_on_hover(@transaction_id, @today_date, 'CA Approval')).to eq true
      expect(@transactions_page.status_timeline_on_hover(@transaction_id, @today_date, 'Vendor/Dealer Approval')).to eq true
    end

    e.run_step 'Vendor logs out' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Product(Level 2) - 3rd party verification' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['product']['email'], $conf['users']['product']['password'])).to eq true
    end

    e.run_step 'Approve Invoice as Product(Level 2) - 3rd level of approval' do
      @common_pages.click_menu(MENU_PO_FINANCING)
      @common_pages.navigate_to_transaction(@transaction_id)
      expect(@transactions_page.verify_transaction_status('Draft')).to eq true
      @transactions_page.approve_transaction
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['ProductApproved']
    end

    e.run_step 'Verift status changed from Draft to Released' do
      expect(@transactions_page.verify_transaction_status('Released')).to eq true
    end

    e.run_step 'Verify status timeline in the hovercard after Product(Level 2) Approval' do
      @common_pages.click_menu(MENU_PO_FINANCING)
      @common_pages.click_transactions_tab(LIVE)
      @common_pages.apply_filter({ 'Instrument Number' => @testdata['PO Details']['PO Number'], 'With Documents?' => true })
      expect(@transactions_page.status_timeline_on_hover(@transaction_id, @today_date, 'CA Approval')).to eq true
      expect(@transactions_page.status_timeline_on_hover(@transaction_id, @today_date, 'Vendor/Dealer Approval')).to eq true
      expect(@transactions_page.status_timeline_on_hover(@transaction_id, @today_date, 'CA Approval (Level 2)')).to eq true
    end
  end

  it 'PO Transaction : Dealer against Anchor', :sanity, :po_txn_dealer_anchor do |e|
    @party_gstn = $conf['users']['po_dealer']['gstn']
    @counterparty_gstn = $conf['users']['grn_anchor']['gstn']
    @vendor_name = $conf['users']['po_dealer']['name']
    @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
    @total_po_value = comma_seperated_value(@testdata['PO Details']['PO Value'])
    @eligile_po_value = comma_seperated_value(@testdata['PO Details']['Requested Disbursement Value'])
    @testdata['Transaction List']['Instrument Value'] = "₹#{@eligile_po_value}"
    @testdata['PO Details'].merge!(
      'GSTN of Anchor' => @counterparty_gstn,
      'GSTN of Channel Partner' => @party_gstn
    )
    @testdata['Transaction List'].delete('Invoice Value')
    @testdata['PO Detail View'].merge!(
      'Requested Disbursement Value' => "₹#{@eligile_po_value}",
      'Instrument Value' => "₹#{@total_po_value}",
      'GSTN of Vendor/Dealer' => @party_gstn,
      'GSTN of Anchor' => @counterparty_gstn,
      'Name of the Vendor/Dealer' => @vendor_name
    )

    e.run_step 'Login as Dealer' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['po_dealer']['email'], $conf['users']['po_dealer']['password'])).to be true
    end

    e.run_step 'Verifying Anchor present for the dealer' do
      navigate_to($conf['transactions_url'])
      @common_pages.click_menu(MENU_ANCHOR_LIST)
      expect(@common_pages.anchor_available?(@anchor_name)).to eq true
    end

    e.run_step 'Verifying Investor commercials for Anchor via Dealer login' do
      @common_pages.navigate_to_anchor(@anchor_name)
      @common_pages.select_program('Dealer Financing')
      investor_details = {
        'investor' => 'Kotak',
        'Sanction limit' => '10000000000',
        'Processing Fee' => '10.0 %',
        'Tenor' => '90 Days',
        # "Agreement Validity"=>"19 Apr, 2021 - 15 Oct, 2021",
        'Repayment Adjustment Order' => 'Charges - Interest - Principal'
      }
      expect(@common_pages.verify_interested_investors_details(investor_details)).to eq true
    end

    e.run_step 'Add PO transaction - Dealer against Anchor' do
      @common_pages.click_menu(MENU_PO_FINANCING)
      @common_pages.click_transactions_tab(SHOW_ALL)
      @transactions_page.add_transaction(@po_file, @testdata['PO Details'], 'Dealer Financing', 'PO')
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['POCreated']
      @common_pages.click_menu(MENU_PO_FINANCING)
      @common_pages.click_transactions_tab(UNASSIGNED_INVESTOR)
      @tarspect_methods.click_button('Reassign')
      @common_pages.reassign_investor(@investor_name)
    end

    e.run_step 'Verify PO as Dealer in list page' do
      @common_pages.apply_filter({ 'Instrument Number' => @testdata['PO Details']['PO Number'] })
      @testdata['Transaction List']['Number'] = @testdata['PO Details']['PO Number']
      @testdata['Transaction List']['Instrument Value'] = round_the_amount_to_lakhs(@testdata['PO Details']['PO Value'])
      @common_pages.click_transactions_tab(SHOW_ALL)
      expect(@transactions_page.verify_transaction_in_list_page(@testdata['Transaction List'], page: :vendor, apply_filter: false)).to eq true
      @transaction_id = @common_pages.get_transaction_id(@testdata['Transaction List'])
    end

    e.run_step 'Verify PO as Dealer in landing page' do
      @common_pages.navigate_to_transaction(@transaction_id)
      expect(@transactions_page.verify_transaction_status('Draft')).to eq true
      expect(@transactions_page.verify_transaction_in_detail_page(@testdata['PO Detail View'])).to eq true
    end

    e.run_step 'Verify PO document preview is available and content is visible' do
      expect(@transactions_page.invoice_preview_available?).to eq true
    end

    e.run_step 'Verify PO document as Dealer in landing page' do
      expect(@transactions_page.invoice_exists?(@file_name, 'Purchase Order')).to eq true
      # expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq true
    end

    e.run_step 'Verify No Invoice document as Anchor in landing page' do
      expect(@transactions_page.invoice_exists?(@file_name)).to eq false
    end

    e.run_step 'Dealer logs out' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as product' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['product']['email'], $conf['users']['product']['password'])).to eq true
    end

    e.run_step 'Verify transaction as product in list page listing under Invoices to approve' do
      @common_pages.click_menu(MENU_PO_FINANCING)
      @common_pages.click_transactions_tab(INVOICES_TO_APPROVE)
      @common_pages.apply_filter({ 'Instrument Number' => @testdata['PO Details']['PO Number'], 'With Documents?' => true })
      expect(@transactions_page.verify_transaction_in_list_page(@testdata['Transaction List'], page: :product, apply_filter: false)).to eq true
    end

    e.run_step 'Verify transaction as Product in landing page' do
      @common_pages.navigate_to_transaction(@transaction_id)
      expect(@transactions_page.verify_transaction_status('Draft')).to eq true
      expect(@transactions_page.verify_transaction_in_detail_page(@testdata['PO Detail View'])).to eq true
    end

    e.run_step 'Verify PO document preview is available and content is visible' do
      expect(@transactions_page.invoice_preview_available?).to eq true
    end

    e.run_step 'Verify PO document as Anchor in landing page' do
      expect(@transactions_page.invoice_exists?(@file_name, 'Purchase Order')).to eq true
      # expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq true
    end

    e.run_step 'Verify No Invoice document as Anchor in landing page' do
      expect(@transactions_page.invoice_exists?(@file_name)).to eq false
    end

    e.run_step 'Approve Invoice as Product - 1st level of approval' do
      @transactions_page.approve_transaction
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['ProductApproved']
    end

    e.run_step 'Verify status timeline after Product Approval' do
      @tarspect_methods.click_link('Details')
      expect(@transactions_page.status_timeline_present?(@today_date, 'CA Approval')).to eq true
    end

    e.run_step 'Verify status timeline in the hovercard after Product Approval' do
      @common_pages.click_menu(MENU_PO_FINANCING)
      @common_pages.click_transactions_tab(DRAFT)
      expect(@transactions_page.status_timeline_on_hover(@transaction_id, @today_date, 'CA Approval')).to eq true
    end

    e.run_step 'Product logs out' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Anchor - CounterParty' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['grn_anchor']['email'], $conf['users']['grn_anchor']['password'])).to eq true
    end

    e.run_step 'Verify transaction as Anchor in list page listing under invoices to Approve' do
      @common_pages.click_menu(MENU_PO_FINANCING)
      @common_pages.click_transactions_tab(INVOICES_TO_APPROVE)
      @common_pages.apply_filter({ 'Instrument Number' => @testdata['PO Details']['PO Number'], 'With Documents?' => true })
      expect(@transactions_page.verify_transaction_in_list_page(@testdata['Transaction List'], page: :anchor, apply_filter: false)).to eq true
    end

    e.run_step 'Verify transaction as Anchor in landing page' do
      @common_pages.navigate_to_transaction(@transaction_id)
      expect(@transactions_page.verify_transaction_status('Draft')).to eq true
      expect(@transactions_page.verify_transaction_in_detail_page(@testdata['PO Detail View'])).to eq true
    end

    e.run_step 'Verify PO document as Anchor in landing page' do
      expect(@transactions_page.invoice_exists?(@file_name, 'Purchase Order')).to eq true
      # expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq true
    end

    e.run_step 'Verify No Invoice document as Anchor in landing page' do
      expect(@transactions_page.invoice_exists?(@file_name)).to eq false
    end

    e.run_step 'Approve Invoice as Anchor - 2st level of approval' do
      @transactions_page.approve_transaction
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['VendorApproved']
    end

    e.run_step 'Verify status timeline after Vendor Approval' do
      @tarspect_methods.click_link('Details')
      expect(@transactions_page.status_timeline_present?(@today_date, 'CA Approval')).to eq true
      expect(@transactions_page.status_timeline_present?(@today_date, 'Anchor Approval')).to eq true
    end

    e.run_step 'Verify status timeline in the hovercard after Anchor Approval' do
      @common_pages.click_menu(MENU_PO_FINANCING)
      @common_pages.click_transactions_tab(DRAFT)
      expect(@transactions_page.status_timeline_on_hover(@transaction_id, @today_date, 'CA Approval')).to eq true
      expect(@transactions_page.status_timeline_on_hover(@transaction_id, @today_date, 'Anchor Approval')).to eq true
    end

    e.run_step 'Anchor logs out' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Product(Level 2) - 3rd party verification' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['product']['email'], $conf['users']['product']['password'])).to eq true
    end

    e.run_step 'Approve Invoice as Product(Level 2) - 3rd level of approval' do
      @common_pages.click_menu(MENU_PO_FINANCING)
      @common_pages.navigate_to_transaction(@transaction_id)
      expect(@transactions_page.verify_transaction_status('Draft')).to eq true
      @transactions_page.approve_transaction
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['ProductApproved']
    end

    e.run_step 'Verift status changed from Draft to Released' do
      expect(@transactions_page.verify_transaction_status('Released')).to eq true
    end

    e.run_step 'Verify status timeline in the hovercard after Product(Level 2) Approval' do
      @common_pages.click_menu(MENU_PO_FINANCING)
      @common_pages.click_transactions_tab(LIVE)
      expect(@transactions_page.status_timeline_on_hover(@transaction_id, @today_date, 'CA Approval')).to eq true
      expect(@transactions_page.status_timeline_on_hover(@transaction_id, @today_date, 'Anchor Approval')).to eq true
      expect(@transactions_page.status_timeline_on_hover(@transaction_id, @today_date, 'CA Approval (Level 2)')).to eq true
    end
  end

  it 'PO Preview and PO Validations' do |e|
    e.run_step 'Login as Anchor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['anchor']['email'], $conf['users']['anchor']['password'])).to eq true
    end

    e.run_step 'Verify Mandatory fields while uploading PO : PO Number' do
      @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
      @tarspect_methods.click_button('Add Transaction')
      @testdata['PO Details'].delete('PO Number')
      @transactions_page.select_transaction_program('Vendor Financing', 1)
      @transactions_page.select_transaction_program('PO', 2)
      @transactions_page.upload_invoice(@po_file, @testdata['PO Details'])
      @tarspect_methods.click_button('Submit')
      expect(@transactions_page.error_thrown?('PO Number')).to eq true
      @tarspect_methods.click_button('Remove')
      expect(@transactions_page.upload_page_available?).to eq true
    end

    e.run_step 'Verify Mandatory fields while uploading PO : PO Value' do
      @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
      @testdata['PO Details'].delete('PO Value')
      @transactions_page.select_transaction_program('Vendor Financing', 1)
      @transactions_page.select_transaction_program('PO', 2)
      @transactions_page.upload_invoice(@po_file, @testdata['PO Details'])
      @tarspect_methods.click_button('Submit')
      expect(@transactions_page.error_thrown?('PO Value')).to eq true
      @tarspect_methods.click_button('Remove')
    end

    e.run_step 'Verify Mandatory fields while uploading PO : Requested Disbursement Value' do
      @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
      @testdata['PO Details'].delete('Requested Disbursement Value')
      @transactions_page.select_transaction_program('Vendor Financing', 1)
      @transactions_page.select_transaction_program('PO', 2)
      @transactions_page.upload_invoice(@po_file, @testdata['PO Details'])
      @tarspect_methods.click_button('Submit')
      expect(@transactions_page.error_thrown?('Requested Disbursement Value')).to eq true
      @tarspect_methods.click_button('Remove')
    end

    e.run_step 'Verify Mandatory fields while uploading PO : PO Date' do
      @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
      @testdata['PO Details'].delete('PO Date')
      @transactions_page.select_transaction_program('Vendor Financing', 1)
      @transactions_page.select_transaction_program('PO', 2)
      @transactions_page.upload_invoice(@po_file, @testdata['PO Details'])
      @tarspect_methods.click_button('Submit')
      expect(@transactions_page.error_thrown?('PO Date')).to eq true
      @tarspect_methods.click_button('Remove')
    end

    e.run_step 'Verify Mandatory fields while uploading PO : Anchor GSTN' do
      @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
      @testdata['PO Details'].delete('GSTN of Anchor')
      @transactions_page.select_transaction_program('Vendor Financing', 1)
      @transactions_page.select_transaction_program('PO', 2)
      @transactions_page.upload_invoice(@po_file, @testdata['PO Details'])
      @tarspect_methods.click_button('Submit')
      expect(@transactions_page.error_thrown?('GSTN of Anchor')).to eq true
      @tarspect_methods.click_button('Remove')
      @tarspect_methods.close_toaster
    end

    e.run_step 'Verify Mandatory fields while uploading PO : Wrong Anchor GSTN' do
      @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
      @testdata['PO Details']['GSTN of Anchor'] = $conf['libas_gstn']
      @transactions_page.select_transaction_program('Vendor Financing', 1)
      @transactions_page.select_transaction_program('PO', 2)
      @transactions_page.upload_invoice(@po_file, @testdata['PO Details'])
      @tarspect_methods.click_button('Submit')
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['InvalidAnchorGSTN']
      expect(@transactions_page.alert_message).to eq $notifications['InvalidAnchorGSTNAlert']
      @tarspect_methods.click_button('Remove')
    end

    e.run_step 'Verify Mandatory fields while uploading PO : CounterParty GSTN' do
      @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
      @testdata['PO Details'].delete('GSTN of Channel Partner')
      @transactions_page.select_transaction_program('Vendor Financing', 1)
      @transactions_page.select_transaction_program('PO', 2)
      @transactions_page.upload_invoice(@po_file, @testdata['PO Details'])
      @tarspect_methods.click_button('Submit')
      expect(@transactions_page.error_thrown?('GSTN of Channel Partner')).to eq true
      @tarspect_methods.click_button('Remove')
      @tarspect_methods.close_toaster
    end

    e.run_step 'Verify Mandatory fields while uploading PO : Wrong counter party GSTN' do
      @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
      @testdata['PO Details']['GSTN of Channel Partner'] = '99ABREE1288F8ZY'
      @transactions_page.select_transaction_program('Vendor Financing', 1)
      @transactions_page.select_transaction_program('PO', 2)
      @transactions_page.upload_invoice(@po_file, @testdata['PO Details'])
      @tarspect_methods.click_button('Submit')
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['InvalidVendorGSTN']
      expect(@transactions_page.alert_message).to eq $notifications['InvalidVendorGSTNAlert']
      @tarspect_methods.click_button('Remove')
    end

    e.run_step 'Verify Requested Disbursement Value cannot be greater than PO Value' do
      @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
      @testdata['PO Details']['Requested Disbursement Value'] = @testdata['PO Details']['PO Value'] + 100
      @transactions_page.select_transaction_program('Vendor Financing', 1)
      @transactions_page.select_transaction_program('PO', 2)
      @transactions_page.upload_invoice(@po_file, @testdata['PO Details'])
      @tarspect_methods.click_button('Submit')
      expect(@common_pages.ERROR_MESSAGE('Requested Disbursement Value').text).to eq $notifications['RequestedValueAlert']
      @tarspect_methods.click_button('Remove')
    end
  end
end
