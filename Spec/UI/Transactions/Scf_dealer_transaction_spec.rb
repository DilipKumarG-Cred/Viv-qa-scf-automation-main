require './spec_helper'
require 'erb'
describe 'Transactions: Dealer', :scf, :transactions, :dealer_transaction, :scf_dealer_transaction, :hover do
  before(:all) do
    @dealer_gstn = $conf['trends_gstn']
    @vendor_gstn = $conf['libas_gstn']
    @counterparty_gstn = $conf['myntra_gstn']
    @vendor_name = $conf['dealer_name']
    @anchor_name = $conf['anchor_name']
    @investor_name = $conf['investor_name']
    @invoice_file = "#{Dir.pwd}/test-data/attachments/dealer_invoice.pdf"
    @file_name = 'dealer_invoice.pdf'
    @erb_file = File.read("#{Dir.pwd}/test-data/erb/testbed_data.erb")
    @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
    @invoice_value = @testdata['Dealer Invoice Details']['Invoice Value'].to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
    @testdata['Transaction List']['Instrument Value'] = "₹#{@invoice_value}"
    @testdata['Transaction Details']['Instrument Value'] = "₹#{@invoice_value}"
    # @testdata['Transaction Details']['Name of the Vendor/Dealer'] = @testdata['Transaction Details']['Name of the Vendor']
    # @testdata['Transaction Details'].delete('Name of the Vendor/Dealer')
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

  it 'Transaction : Dealer against Anchor', :sanity, :dealer_anchor_txn do |e|
    e.run_step 'Login as Dealer' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['dealer']['email'], $conf['users']['dealer']['password'])).to eq true
    end

    e.run_step 'Verifying Anchor present for the dealer' do
      @tarspect_methods.wait_for_circular_to_disappear(MAX_LOADER_TIME)
      @common_pages.click_menu(MENU_ANCHOR_LIST)
      expect(@common_pages.anchor_available?(@anchor_name)).to eq true
    end

    e.run_step 'Verifying Investor commercials for Anchor via Dealer login' do
      @common_pages.navigate_to_anchor(@anchor_name)
      @common_pages.select_program('Dealer Financing')
      @investor_details = {
        'investor' => 'Kotak',
        'Sanction limit' => '10000000000',
        'Processing Fee' => '2.0 %',
        'Tenor' => '90 Days',
        # "Agreement Validity"=>"04 Nov, 2020 - 08 Sep, 2021", Need to update
        'Repayment Adjustment Order' => 'Charges - Interest - Principal'
      }

      expect(@common_pages.verify_interested_investors_details(@investor_details)).to eq true
    end

    e.run_step 'Add transaction - Dealer against Anchor' do
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @common_pages.click_transactions_tab(SHOW_ALL)
      @transactions_page.add_transaction(@invoice_file, @testdata['Dealer Invoice Details'], 'Dealer Financing', 'Invoice')
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['InvoiceCreated']
    end

    e.run_step 'Verify transaction as Dealer in list page' do
      @testdata['Transaction List']['Number'] = @testdata['Dealer Invoice Details']['Invoice Number']
      expect(@transactions_page.verify_transaction_in_list_page(@testdata['Transaction List'], page: :vendor)).to eq true
      @transaction_id = @common_pages.get_transaction_id(@testdata['Transaction List'])
    end

    e.run_step 'Verify transaction as Dealer in landing page' do
      @common_pages.navigate_to_transaction(@transaction_id)
      expect(@transactions_page.verify_transaction_status('Draft')).to eq true
      expect(@transactions_page.verify_transaction_in_detail_page(@testdata['Transaction Details'])).to eq true
    end

    e.run_step 'Verify Invoice preview is available and content is visible' do
      expect(@transactions_page.invoice_preview_available?).to eq true
    end

    e.run_step 'Verify Invoice document as Dealer in landing page' do
      expect(@transactions_page.invoice_exists?(@file_name)).to eq true
      expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq true
    end

    e.run_step 'Dealer logs out' do
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

    e.run_step 'Verify Invoice preview is available and content is visible' do
      expect(@transactions_page.invoice_preview_available?).to eq true
    end

    e.run_step 'Verify Invoice document as Product in landing page' do
      expect(@transactions_page.invoice_exists?(@file_name)).to eq true
      expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq true
    end

    e.run_step "Verify Transaction Listed in 'Invoices to approve' as Product" do
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @common_pages.click_transactions_tab(INVOICES_TO_APPROVE)
      expect(@transactions_page.verify_transaction_in_list_page(@testdata['Transaction List'], page: :product)).to eq true
    end

    e.run_step 'Approve Invoice as Product - 1st level of approval' do
      @common_pages.navigate_to_transaction(@transaction_id)
      @transactions_page.approve_transaction
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['ProductApproved']
    end

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

    e.run_step 'Login as Anchor - CounterParty' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['anchor']['email'], $conf['users']['anchor']['password'])).to eq true
    end

    e.run_step 'Verify transaction as Anchor in list page' do
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @common_pages.click_transactions_tab(SHOW_ALL)
      expect(@transactions_page.verify_transaction_in_list_page(@testdata['Transaction List'], page: :anchor)).to eq true
    end

    e.run_step 'Verify transaction as Anchor in landing page' do
      @common_pages.navigate_to_transaction(@transaction_id)
      expect(@transactions_page.verify_transaction_status('Draft')).to eq true
      expect(@transactions_page.verify_transaction_in_detail_page(@testdata['Transaction Details'])).to eq true
    end

    e.run_step 'Verify Invoice document as Anchor in landing page' do
      expect(@transactions_page.invoice_exists?(@file_name)).to eq true
      expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq true
    end

    e.run_step "Verify Transaction Listed in 'Invoices to approve' as Anchor" do
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @common_pages.click_transactions_tab(INVOICES_TO_APPROVE)
      expect(@transactions_page.verify_transaction_in_list_page(@testdata['Transaction List'], page: :anchor)).to eq true
    end

    e.run_step 'Approve Invoice as Anchor - 2st level of approval' do
      @common_pages.navigate_to_transaction(@transaction_id)
      @transactions_page.approve_transaction
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['VendorApproved']
    end

    e.run_step 'Verify status timeline after Anchor Approval' do
      expect(@transactions_page.status_timeline_present?(@today_date, 'CA Approval')).to eq true
      expect(@transactions_page.status_timeline_present?(@today_date, 'Anchor Approval')).to eq true
    end

    e.run_step 'Verify status timeline in the hovercard after Anchor Approval' do
      @common_pages.click_menu(MENU_INOICE_FINANCING)
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
      @common_pages.navigate_to_transaction(@transaction_id)
      expect(@transactions_page.verify_transaction_status('Draft')).to eq true
      @transactions_page.approve_transaction
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['ProductApproved']
    end

    e.run_step 'Verift status changed from Draft to Released' do
      expect(@transactions_page.verify_transaction_status('Released')).to eq true
    end

    e.run_step 'Verify status timeline in the hovercard after Product(Level 2) Approval' do
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @common_pages.click_transactions_tab(LIVE)
      expect(@transactions_page.status_timeline_on_hover(@transaction_id, @today_date, 'CA Approval')).to eq true
      expect(@transactions_page.status_timeline_on_hover(@transaction_id, @today_date, 'Anchor Approval')).to eq true
      expect(@transactions_page.status_timeline_on_hover(@transaction_id, @today_date, 'CA Approval (Level 2)')).to eq true
    end
  end

  it 'Transaction : Vendor against Anchor', :sanity do |e|
    e.run_step 'Login as Vendor' do
      @testdata['Vendor Invoice Details']['Invoice Value'] = @testdata['Dealer Invoice Details']['Invoice Value']
      @testdata['Transaction List']['Vendor Name'] = $conf['vendor_name']
      @testdata['Transaction Details']['Name of the Vendor/Dealer'] = $conf['vendor_name']
      # @testdata['Transaction Details'].delete('Name of the Vendor/Dealer')
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['vendor']['email'], $conf['users']['vendor']['password'])).to eq true
    end

    e.run_step 'Add transaction - Vendor against Anchor' do
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @common_pages.click_transactions_tab(SHOW_ALL)
      @transactions_page.add_transaction(@invoice_file, @testdata['Vendor Invoice Details'], 'Vendor Financing', 'Invoice')
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['InvoiceCreated']
    end

    e.run_step 'Verify transaction as Vendor in list page' do
      @testdata['Transaction List']['Number'] = @testdata['Vendor Invoice Details']['Invoice Number']
      expect(@transactions_page.verify_transaction_in_list_page(@testdata['Transaction List'], page: :vendor)).to eq true
      @transaction_id = @common_pages.get_transaction_id(@testdata['Transaction List'])
    end

    e.run_step 'Verify transaction as Vendor in landing page' do
      @common_pages.navigate_to_transaction(@transaction_id)
      expect(@transactions_page.verify_transaction_status('Draft')).to eq true
      expect(@transactions_page.verify_transaction_in_detail_page(@testdata['Transaction Details'])).to eq true
    end

    e.run_step 'Verify Invoice preview is available and content is visible' do
      expect(@transactions_page.invoice_preview_available?).to eq true
    end

    e.run_step 'Verify Invoice document as Vendor in landing page' do
      expect(@transactions_page.invoice_exists?(@file_name)).to eq true
      expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq true
    end
  end
end
