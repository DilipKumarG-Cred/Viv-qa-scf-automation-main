require './spec_helper'
describe 'PO Transactions: Bulk actions', :scf, :transactions, :po, :bulk_approve, :bulk do
  before(:all) do
    @anchor_actor = 'grn_anchor'
    @party_gstn = $conf['users'][@anchor_actor]['gstn']
    @counterparty_gstn = $conf['users']['po_dealer']['gstn']
    @vendor_name = $conf['users']['po_dealer']['name']
    @vendor_actor = 'po_dealer'
    @po_file = "#{Dir.pwd}/test-data/attachments/anchor_invoice.pdf"
    @erb_file = File.read("#{Dir.pwd}/test-data/erb/testbed_data.erb")
    @today_date = Date.today.strftime('%d %b, %Y')
  end

  before(:each) do
    @driver = Tarspect::Browser.new($conf['browser']).invoke
    @tarspect_methods = Common::Methods.new(@driver)
    @common_pages = Pages::CommonMethods.new(@driver)
    @transactions_page = Pages::Trasactions.new(@driver)
    @disbursement_page = Pages::Disbursement.new(@driver)
  end

  after(:each) do |e| # Captures screenshot of the current page when failure happens
    snap_screenshot(e)
    quit_browser
  end

  it 'Bulk approve and Reject spec: PO', :sanity, :bulk_approve_reject do |e|
    e.run_step 'Create 2 draft transaction as Anchor' do
      @testdata_1 = JSON.parse(ERB.new(@erb_file).result(binding))
      @testdata_2 = JSON.parse(ERB.new(@erb_file).result(binding))
      values = {
        actor: 'po_dealer',
        po_details: @testdata_1['PO Details'],
        po_file: @po_file,
        program_id: 3 # 3 => po dealer program id in staging
      }
      values[:program_id] = 4 unless $conf['env'] == 'staging' # 4 => po dealer program in for qa and demo env
      resp = create_po_transaction(values)
      expect(resp[:code]).to eq(201), resp.to_s
      @transaction_1 = resp[:body][:id].to_s
      values = {
        actor: 'po_dealer',
        po_details: @testdata_2['PO Details'],
        po_file: @po_file,
        program_id: 3 # 3 => po dealer program id in staging
      }
      values[:program_id] = 4 unless $conf['env'] == 'staging' # 4 => po dealer program id in qa and demo env
      resp = create_po_transaction(values)
      expect(resp[:code]).to eq(201), resp.to_s
      @transaction_2 = resp[:body][:id].to_s
      resp = assign_investor({
                               anchor_id: $conf['users'][@anchor_actor]['id'],
                               ids: [@transaction_1, @transaction_2],
                               program_id: 2,
                               actor: @vendor_actor,
                               type: 'po',
                               investor_id: 7
                             })
    end

    e.run_step 'Login as product and bulk approve transactions' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['product']['email'], $conf['users']['product']['password'])).to eq true
    end

    e.run_step 'Bulk select the transactions and approve the transactions as Product' do
      @common_pages.click_menu(MENU_PO_FINANCING)
      @common_pages.click_transactions_tab(INVOICES_TO_APPROVE)
      @disbursement_page.select_transactions([@transaction_1, @transaction_2])
      @transactions_page.approve_transaction
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['ProductApproved']
    end

    e.run_step 'Verify transaction listed in the Draft after approving as Product' do
      @common_pages.click_menu(MENU_PO_FINANCING)
      @common_pages.click_transactions_tab(DRAFT)
      expect(@common_pages.transaction_listed?(@transaction_1)).to eq true
      expect(@common_pages.transaction_listed?(@transaction_2)).to eq true
    end

    e.run_step 'Verify approval details for transaction 1' do
      @common_pages.navigate_to_transaction(@transaction_1)
      expect(@transactions_page.status_timeline_present?(@today_date, 'CA Approval')).to eq true
    end

    e.run_step 'Verify approval details for transaction 2' do
      @common_pages.click_menu(MENU_PO_FINANCING)
      @common_pages.click_transactions_tab(DRAFT)
      @common_pages.navigate_to_transaction(@transaction_2)
      expect(@transactions_page.status_timeline_present?(@today_date, 'CA Approval')).to eq true
    end

    e.run_step 'Product logs out' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Anchor(counterparty) and approve the transactions' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users'][@anchor_actor]['email'], $conf['users'][@anchor_actor]['password'])).to eq true
    end

    e.run_step 'Bulk select the transactions and approve the transactions as Anchor' do
      @common_pages.click_menu(MENU_PO_FINANCING)
      @common_pages.click_transactions_tab(INVOICES_TO_APPROVE)
      @disbursement_page.select_transactions([@transaction_1, @transaction_2])
      @transactions_page.approve_transaction
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['VendorApproved']
    end

    e.run_step 'Verify transaction listed in the Draft after anchor Approval' do
      @common_pages.click_menu(MENU_PO_FINANCING)
      @common_pages.click_transactions_tab(DRAFT)
      expect(@common_pages.transaction_listed?(@transaction_1)).to eq true
      expect(@common_pages.transaction_listed?(@transaction_2)).to eq true
    end

    e.run_step 'Verify approval details for transaction 1' do
      @common_pages.navigate_to_transaction(@transaction_1)
      expect(@transactions_page.status_timeline_present?(@today_date, 'CA Approval')).to eq true
      expect(@transactions_page.status_timeline_present?(@today_date, 'Anchor Approval')).to eq true
    end

    e.run_step 'Verify approval details for transaction 2' do
      @common_pages.click_menu(MENU_PO_FINANCING)
      @common_pages.click_transactions_tab(DRAFT)
      @common_pages.navigate_to_transaction(@transaction_2)
      expect(@transactions_page.status_timeline_present?(@today_date, 'CA Approval')).to eq true
      expect(@transactions_page.status_timeline_present?(@today_date, 'Anchor Approval')).to eq true
    end

    e.run_step 'Anchor logs out' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as product and bulk reject the transactions(Re-Initiate)(3rd level)' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['product']['email'], $conf['users']['product']['password'])).to eq true
    end

    e.run_step 'Bulk select the transactions and reject the transactions as product(Re-Initiate)' do
      @common_pages.click_menu(MENU_PO_FINANCING)
      @common_pages.click_transactions_tab(INVOICES_TO_APPROVE)
      @disbursement_page.select_transactions([@transaction_1, @transaction_2])
      @transactions_page.reject_transaction('Re-Initiate Transaction', @testdata_1['Reject Reason'])
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['ProductApproved']
    end

    e.run_step 'Verify Reinitiate action is available for the transcations' do
      @common_pages.click_menu(MENU_PO_FINANCING)
      @common_pages.click_transactions_tab(REJECTED)
      expect(@common_pages.transaction_listed?(@transaction_1)).to eq true
      expect(@transactions_page.actions_needed(@transaction_1)).to eq 'Reinitiate'
      expect(@common_pages.transaction_listed?(@transaction_2)).to eq true
      expect(@transactions_page.actions_needed(@transaction_2)).to eq 'Reinitiate'
    end

    e.run_step 'Verify transaction status in landing page - Transaction 1' do
      @common_pages.navigate_to_transaction(@transaction_1)
      expect(@transactions_page.verify_transaction_status('Rejected')).to eq true
      expect(@transactions_page.rejected_status('Re-Initiate Transaction', $conf['product_reject'], @testdata_1['Reject Reason'])).to eq true
    end

    e.run_step 'Verify transaction status in landing page - Transaction 2' do
      @common_pages.click_menu(MENU_PO_FINANCING)
      @common_pages.click_transactions_tab(REJECTED)
      @common_pages.navigate_to_transaction(@transaction_2)
      expect(@transactions_page.verify_transaction_status('Rejected')).to eq true
      expect(@transactions_page.rejected_status('Re-Initiate Transaction', $conf['product_reject'], @testdata_1['Reject Reason'])).to eq true
    end
  end
end
