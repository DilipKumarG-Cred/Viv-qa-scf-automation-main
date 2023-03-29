require './spec_helper'
describe 'PO Transactions: Reject and Re-Initiate', :scf, :transactions, :po, :po_transaction_reject, :hover do
  before(:all) do
    @party_gstn = $conf['tvs_gstn']
    @counterparty_gstn = $conf['users']['po_vendor']['gstn']
    @vendor_name = $conf['users']['po_vendor']['name']
    @anchor_name = $conf['users']['grn_anchor']['name']
    @investor_name = $conf['investor_name']
    @po_file = "#{Dir.pwd}/test-data/attachments/anchor_invoice.pdf"
    @file_name = 'anchor_invoice.pdf'
    @re_initiate_file = "#{Dir.pwd}/test-data/attachments/reinitiate_invoice.pdf"
    @re_initiate_file_name = 'reinitiate_invoice.pdf'
    @erb_file = File.read("#{Dir.pwd}/test-data/erb/testbed_data.erb")
    @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
    @total_po_value = @testdata['PO Details']['PO Value'].to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
    @eligile_po_value = @testdata['PO Details']['Requested Disbursement Value'].to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
    @testdata['Transaction List']['Instrument Value'] = "₹#{@eligile_po_value}"
    @testdata['PO Detail View']['Requested Disbursement Value'] = "₹#{@eligile_po_value}"
    @testdata['PO Detail View']['Instrument Value'] = "₹#{@total_po_value}"
    @today_date = Date.today.strftime('%d %b, %Y')
  end

  before(:each) do
    @driver = Tarspect::Browser.new($conf['browser']).invoke
    @tarspect_methods = Common::Methods.new(@driver)
    @common_pages = Pages::CommonMethods.new(@driver)
    @transactions_page = Pages::Trasactions.new(@driver)
  end

  after(:each) do |e| # Captures screenshot of the current page when failure happens
    snap_screenshot(e)
    quit_browser
  end

  after(:all) do
    # quit_browser #Tear down
  end

  it 'PO Transaction : Reject flow', :sanity do |e|
    e.run_step 'Login as Anchor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['grn_anchor']['email'], $conf['users']['grn_anchor']['password'])).to be true
    end

    e.run_step 'Add PO transaction' do
      @common_pages.click_menu(MENU_PO_FINANCING)
      @common_pages.click_transactions_tab(SHOW_ALL)
      @transactions_page.add_transaction(@po_file, @testdata['PO Details'], 'Vendor Financing', 'PO')
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['POCreated']
    end

    e.run_step 'Verify PO as Anchor in list page' do
      @common_pages.click_menu(MENU_PO_FINANCING)
      @testdata['Transaction List']['Number'] = @testdata['PO Details']['PO Number']
      @testdata['Transaction List']['Instrument Value'] = round_the_amount_to_lakhs(@testdata['PO Details']['PO Value'])
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

    e.run_step 'Reject PO as Product - 1st level of approval' do
      @common_pages.click_menu(MENU_PO_FINANCING)
      @common_pages.navigate_to_transaction(@transaction_id)
      @tarspect_methods.wait_for_loader_to_disappear(MIN_LOADER_TIME)
      @transactions_page.reject_transaction('Discard', @testdata['Reject Reason'])
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['ProductApproved']
    end

    e.run_step 'Verify status timeline after Product reject' do
      expect(@transactions_page.rejected_status('Discard', $conf['product_reject'], @testdata['Reject Reason'])).to eq true
    end

    e.run_step 'Verify transaction status in landing page' do
      expect(@transactions_page.verify_transaction_status('Rejected')).to eq true
    end

    e.run_step "Verify PO Transaction Listed in 'Rejected' as Product" do
      @common_pages.click_menu(MENU_PO_FINANCING)
      @common_pages.click_transactions_tab(REJECTED)
      expect(@common_pages.transaction_listed?(@transaction_id)).to eq(true), "Transaction #{@transaction_id} is not listed"
    end

    e.run_step 'Verify status timeline in the hovercard after Product rejection' do
      expect(@transactions_page.rejected_reason_on_hover(@transaction_id, $conf['product_reject'], @testdata['Reject Reason'])).to eq true
    end

    e.run_step 'Product logs out' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Vendor - CounterParty' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['po_vendor']['email'], $conf['users']['po_vendor']['password'])).to eq true
    end

    e.run_step "Verify PO Transaction Listed in 'Rejected' as Vendor" do
      navigate_to($conf['transactions_url'])
      @common_pages.click_menu(MENU_PO_FINANCING)
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

    e.run_step 'Verify status timeline after Product reject' do
      expect(@transactions_page.rejected_status('Discard', $conf['product_reject'], @testdata['Reject Reason'])).to eq true
    end

    e.run_step 'Vendor logs out' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Anchor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['grn_anchor']['email'], $conf['users']['grn_anchor']['password'])).to eq true
    end

    e.run_step "Verify PO Transaction Listed in 'Rejected' as Anchor" do
      @common_pages.click_menu(MENU_PO_FINANCING)
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

    e.run_step 'Verify status timeline after Product reject' do
      expect(@transactions_page.rejected_status('Discard', $conf['product_reject'], @testdata['Reject Reason'])).to eq true
    end

    e.run_step 'Anchor logs out' do
      expect(@common_pages.logout).to eq true
    end
  end

  it 'PO Transaction : Re-initiate', :sanity, :po_reinitiate do |e|
    @party_gstn = $conf['users']['po_dealer']['gstn']
    @counterparty_gstn = $conf['users']['grn_anchor']['gstn']
    @vendor_name = $conf['users']['po_dealer']['name']
    @anchor_name = $conf['users']['grn_anchor']['name']
    @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
    @total_po_value = @testdata['PO Details']['PO Value'].to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
    @eligile_po_value = @testdata['PO Details']['Requested Disbursement Value'].to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
    @testdata['Transaction List']['Instrument Value'] = "₹#{@eligile_po_value}"
    @testdata['PO Details'].merge!(
      'GSTN of Anchor' => @counterparty_gstn,
      'GSTN of Channel Partner' => @party_gstn
    )
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

    e.run_step 'Add PO transaction' do
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
      @testdata['Transaction List']['Number'] = @testdata['PO Details']['PO Number']
      @testdata['Transaction List']['Instrument Value'] = round_the_amount_to_lakhs(@testdata['PO Details']['PO Value'])
      @common_pages.click_transactions_tab(SHOW_ALL)
      expect(@transactions_page.verify_transaction_in_list_page(@testdata['Transaction List'], page: :vendor)).to eq true
      @transaction_id = @common_pages.get_transaction_id(@testdata['Transaction List'])
    end

    e.run_step 'Dealer logs out' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as product' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['product']['email'], $conf['users']['product']['password'])).to eq true
    end

    e.run_step 'Approve Invoice as Product - 1st level of approval' do
      @common_pages.click_menu(MENU_PO_FINANCING)
      @common_pages.navigate_to_transaction(@transaction_id)
      @transactions_page.approve_transaction
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['ProductApproved']
    end

    e.run_step 'Product logs out' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Anchor - CounterParty' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['grn_anchor']['email'], $conf['users']['grn_anchor']['password'])).to eq true
    end

    e.run_step 'Reject PO with Re-Inititate as Anchor - 2st level of approval' do
      @common_pages.click_menu(MENU_PO_FINANCING)
      @common_pages.navigate_to_transaction(@transaction_id)
      @transactions_page.reject_transaction('Re-Initiate Transaction', @testdata['Reject Reason'])
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['VendorApproved']
    end

    e.run_step 'Verify status timeline after Anchor rejected' do
      expect(@transactions_page.rejected_status('Re-Initiate Transaction', @anchor_name, @testdata['Reject Reason'])).to eq true
    end

    e.run_step 'Verify transaction status in landing page' do
      expect(@transactions_page.verify_transaction_status('Rejected')).to eq true
    end

    e.run_step "Verify Transaction Listed in 'Rejected' after Anchor rejects with Re-Initiate" do
      @common_pages.click_menu(MENU_PO_FINANCING)
      @common_pages.click_transactions_tab(REJECTED)
      expect(@common_pages.transaction_listed?(@transaction_id)).to eq(true), "Transaction #{@transaction_id} is not listed"
    end

    e.run_step 'Verify status timeline in the hovercard after Anchor  rejects with Re-Initiate' do
      expect(@transactions_page.rejected_reason_on_hover(@transaction_id, @anchor_name, @testdata['Reject Reason'])).to eq true
    end

    e.run_step 'Anchor logs out' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Dealer to Re-Initiate the transaction' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['po_dealer']['email'], $conf['users']['po_dealer']['password'])).to eq true
    end

    e.run_step "Verify Transaction Listed in 'Rejected' after Anchor rejected" do
      @common_pages.click_menu(MENU_PO_FINANCING)
      @common_pages.click_transactions_tab(REJECTED)
      expect(@common_pages.transaction_listed?(@transaction_id)).to eq(true), "Transaction #{@transaction_id} is not listed"
    end

    e.run_step 'Verify status timeline in the hovercard after Anchor rejected' do
      expect(@transactions_page.rejected_reason_on_hover(@transaction_id, @anchor_name, @testdata['Reject Reason'])).to eq true
    end

    e.run_step 'Verify transaction status in landing page' do
      @common_pages.navigate_to_transaction(@transaction_id)
      expect(@transactions_page.verify_transaction_status('Rejected')).to eq true
    end

    e.run_step 'Re-Initiate the transaction as dealer' do
      @transactions_page.re_initiate_transaction(@re_initiate_file, @testdata['Re-Initiate PO Details'])
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['ReInitiateSucess']
      # Replace old invoice details values with re-initiated invoice values
      @total_po_value = comma_seperated_value(@testdata['Re-Initiate PO Details']['PO Value'])
      @eligile_po_value = comma_seperated_value(@testdata['Re-Initiate PO Details']['Requested Disbursement Value'])
      @testdata['Transaction List']['Instrument Value'] = "₹#{@eligile_po_value}"
      @testdata['PO Detail View'].merge!(
        'Requested Disbursement Value' => "₹#{@eligile_po_value}",
        'Instrument Value' => "₹#{@total_po_value}",
        'Instrument Date' => (Date.today - 1).strftime('%d %b, %Y')
      )
    end

    e.run_step 'Verify transaction status Dealer in landing page' do
      expect(@transactions_page.verify_transaction_status('Draft')).to eq true
      @testdata['PO Detail View'].delete('GSTN of Channel Partner')
      expect(@transactions_page.verify_transaction_in_detail_page(@testdata['PO Detail View'])).to eq true
    end

    e.run_step 'Verify Invoice preview is available and content is visible' do
      expect(@transactions_page.invoice_preview_available?).to eq true
    end

    e.run_step 'Verify Invoice document as Dealer in landing page' do
      expect(@transactions_page.invoice_exists?(@file_name, 'Purchase Order')).to eq true
      expect(@transactions_page.invoice_exists?(@re_initiate_file_name, 'Purchase Order')).to eq true
      expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq true
    end

    e.run_step 'Verify transaction as Dealer in list page' do
      @common_pages.click_menu(MENU_PO_FINANCING)
      @common_pages.click_transactions_tab(DRAFT)
      expect(@transactions_page.verify_transaction_in_list_page(@testdata['Transaction List'], page: :vendor)).to eq true
    end

    e.run_step 'Dealer logs out' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as product' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['product']['email'], $conf['users']['product']['password'])).to eq true
    end

    e.run_step 'Verify transaction as Product in landing page' do
      @common_pages.click_menu(MENU_PO_FINANCING)
      @common_pages.click_transactions_tab(INVOICES_TO_APPROVE)
      @common_pages.navigate_to_transaction(@transaction_id)
      expect(@transactions_page.verify_transaction_status('Draft')).to eq true
    end

    e.run_step 'Verify Invoice preview is available and content is visible' do
      expect(@transactions_page.invoice_preview_available?).to eq true
    end

    e.run_step 'Verify Invoice document as Product in landing page' do
      expect(@transactions_page.invoice_exists?(@file_name, 'Purchase Order')).to eq true
      expect(@transactions_page.invoice_exists?(@re_initiate_file_name, 'Purchase Order')).to eq true
      expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq true
    end

    e.run_step 'Approve Invoice as Product after Re-Initiate - 1st level of approval' do
      @transactions_page.approve_transaction
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['ProductApproved']
    end

    e.run_step 'Verify status timeline after product Approval' do
      @tarspect_methods.click_link('Details')
      expect(@transactions_page.status_timeline_present?(@today_date, 'CA Approval')).to eq true
      expect(@transactions_page.status_timeline_present?(@today_date, 'Anchor Approval')).to eq true
      expect(@transactions_page.status_timeline_present?(@today_date, 'Reinitiated')).to eq true
    end

    e.run_step 'Verify status timeline in the hovercard after Product Approval' do
      @common_pages.click_menu(MENU_PO_FINANCING)
      @common_pages.click_transactions_tab(DRAFT)
      expect(@transactions_page.rejected_reason_on_hover(@transaction_id, @anchor_name, @testdata['Reject Reason'])).to eq true
    end

    e.run_step 'Product logs out' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Anchor - CounterParty' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['grn_anchor']['email'], $conf['users']['grn_anchor']['password'])).to eq true
    end

    e.run_step 'Verify transaction as Anchor in landing page' do
      @common_pages.click_menu(MENU_PO_FINANCING)
      @common_pages.click_transactions_tab(INVOICES_TO_APPROVE)
      @common_pages.navigate_to_transaction(@transaction_id)
      expect(@transactions_page.verify_transaction_status('Draft')).to eq true
    end

    e.run_step 'Verify Invoice document as Anchor in landing page' do
      expect(@transactions_page.invoice_exists?(@file_name, 'Purchase Order')).to eq true
      expect(@transactions_page.invoice_exists?(@re_initiate_file_name, 'Purchase Order')).to eq true
      expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq true
    end

    e.run_step 'Approve Invoice as Anchor after Re-Initiate - 2nd level of approval' do
      @transactions_page.approve_transaction
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['VendorApproved']
    end

    e.run_step 'Verify status timeline after product Approval' do
      @tarspect_methods.click_link('Details')
      expect(@transactions_page.status_timeline_present?(@today_date, 'CA Approval')).to eq true
      expect(@transactions_page.status_timeline_present?(@today_date, 'Anchor Approval')).to eq true
      expect(@transactions_page.status_timeline_present?(@today_date, 'Reinitiated')).to eq true
      expect(@transactions_page.status_timeline_present?(@today_date, 'Anchor Approval')).to eq true
    end

    e.run_step 'Verify status timeline in the hovercard after Product Approval' do
      @common_pages.click_menu(MENU_PO_FINANCING)
      @common_pages.click_transactions_tab(DRAFT)
      expect(@transactions_page.rejected_reason_on_hover(@transaction_id, @anchor_name, @testdata['Reject Reason'])).to eq true
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
      @transactions_page.approve_transaction
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['ProductApproved']
    end

    e.run_step 'Verift status changed from Draft to Released' do
      expect(@transactions_page.verify_transaction_status('Released')).to eq true
    end

    e.run_step 'Verify status timeline in the hovercard after Product(Level 2) Approval' do
      @common_pages.click_menu(MENU_PO_FINANCING)
      @common_pages.click_transactions_tab(LIVE)
      @common_pages.apply_list_filter({ 'Instrument Number' => @testdata['PO Details']['PO Number'], 'With Documents?' => true })
      expect(@transactions_page.rejected_reason_on_hover(@transaction_id, @anchor_name, @testdata['Reject Reason'])).to eq true
    end
  end
end
