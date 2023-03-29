require './spec_helper'
require 'erb'
describe 'Invoice Re-Initiation', :scf, :transactions, :multi_lendor, :invoice_re_initiation do
  before(:all) do
    @party_gstn = $conf['users']['grn_anchor']['gstn']
    @counterparty_gstn = $conf['users']['re_assignment_vendor']['gstn']
    @anchor_name = $conf['grn_anchor_name']
    @vendor_name = $conf['users']['re_assignment_vendor']['name']
    @investor_actor = 'investor'
    @first_investor_name = $conf['investor_name']
    @second_investor_name = $conf['users']['user_feedback_investor']['name']
    @vendor_actor = 're_assignment_vendor'
    @vendor_id = '5461' # CH29 Stores
    @borrowing_document = "#{Dir.pwd}/test-data/attachments/borrowing_document.pdf"
    @payment_proof = "#{Dir.pwd}/test-data/attachments/payment_proof.pdf"
    @erb_file = File.read("#{Dir.pwd}/test-data/erb/commercials_data.erb")
    @invoice_erb = File.read("#{Dir.pwd}/test-data/erb/testbed_data.erb")
    @invoice_data = JSON.parse(ERB.new(@invoice_erb).result(binding))['PO Details']
    @invoice_file = "#{Dir.pwd}/test-data/attachments/anchor_invoice.pdf"
  end

  before(:each) do
    @driver = Tarspect::Browser.new($conf['browser']).invoke
    @tarspect_methods = Common::Methods.new(@driver)
    @common_pages = Pages::CommonMethods.new(@driver)
    @transactions_page = Pages::Trasactions.new(@driver)
    @disbursement_page = Pages::Disbursement.new(@driver)
    @commercials_page = Pages::Commercials.new(@driver)
    @testdata = JSON.parse(ERB.new(@erb_file).result(binding))['Vendor Commercials']
    @testdata['Program'] = 'PO Financing'
    @testdata['Type'] = 'Vendor'
    @testdata['Vendor Name'] = @vendor_name
    # delete_vendor_commercials(@testdata)
    clear_all_overdues({ anchor: $conf['grn_anchor_name'], vendor: @vendor_name, investor: 'user_feedback_investor' })
    clear_all_overdues({ anchor: $conf['grn_anchor_name'], vendor: @vendor_name, investor: 'investor' })
  end

  after(:each) do |e|
    snap_screenshot(e)
  end

  after(:all) do
    quit_browser
  end

  it 'Invoice Re-Initiation : Investor Rejection', :sanity, :invoice_reinitiation do |e|
    e.run_step 'Capture Vendor Commercial for Kotak' do
      hash = {
        'Anchor ID' => 5,
        'Investor ID' => 7,
        'Program' => 'Invoice Financing',
        'Type' => 'Vendor',
        'Vendor Name' => @vendor_name,
        'actor' => @investor_actor
      }
      resp = get_vendor_commercial(hash)
      expect(resp[:code]).to eq 200
      @commercial_kotak = {
        'Yield' => resp[:body][:program_limits][:yield],
        'Sanction Limit' => resp[:body][:program_limits][:sanction_limit],
        'Tenor' => resp[:body][:program_limits][:tenor],
        'Invoice Days' => resp[:body][:program_limits][:days_to_raise_invoice]
      }
    end

    # e.run_step 'Vendor Commercial setup and approval' do
    #   @testdata['Payment Date'] = Date.today.strftime('%d %b, %Y')
    #   @testdata['Valid Till'] = (Date.today + 300).strftime('%Y-%m-%d')
    #   @testdata['Yield'] = @commercial_kotak['Yield'] - 2
    #   @testdata['Sanction Limit'] = @commercial_kotak['Sanction Limit']
    #   @testdata['Tenor'] = @commercial_kotak['Tenor']
    #   @testdata['Invoice Days'] = @commercial_kotak['Invoice Days']
    #   resp = set_and_approve_commercials(@testdata)
    #   expect(resp[0]).to eq(201), "Error in Commercial setup and approval #{resp}"
    # end

    e.run_step 'Initiate invoice Transaction' do
      @invoice_data['PO Date'] = (Date.today - 60).strftime('%d-%b-%Y')
      resp = create_po_transaction({
                                     po_details: @invoice_data,
                                     program_id: 4,
                                     actor: @vendor_actor,
                                     po_file: @invoice_file
                                   })
      @transaction_id = resp[:body][:id]
      @invoice_data_1 = JSON.parse(ERB.new(@invoice_erb).result(binding))['PO Details']
      @invoice_data_1['PO Date'] = (Date.today - 60).strftime('%d-%b-%Y')
      resp_1 = create_po_transaction({
                                       po_details: @invoice_data_1,
                                       program_id: 4,
                                       actor: @vendor_actor,
                                       po_file: @invoice_file
                                     })
      expect(resp[:code]).to eq(201), resp.to_s
      expect(resp[:body][:status]).to eq('pending_investor_assignment')
      expect(resp_1[:code]).to eq(201), 'Error in Transaction Initiation'
      expect(resp_1[:body][:status]).to eq('pending_investor_assignment')
      @transaction_id_1 = resp_1[:body][:id]
      resp = assign_investor({
                               anchor_id: @testdata['Anchor ID'],
                               ids: [@transaction_id, @transaction_id_1],
                               program_id: 1,
                               actor: @vendor_actor,
                               type: 'po',
                               investor_id: 9
                             })
      expect(resp[:code]).to eq(200)
      [@transaction_id, @transaction_id_1].each do |id|
        values = {
          counter_party: 'grn_anchor',
          transaction_id: id,
          program_id: 4
        }
        resp = release_transaction(values)
      end
      expect(resp).to eq true
    end

    e.run_step 'Login as Platform' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['product']['email'], $conf['users']['product']['password'])).to be true
    end

    e.run_step 'Verify Assigned Investor name in Platform login' do
      @common_pages.click_menu(MENU_PO_FINANCING)
      @common_pages.click_transactions_tab(SHOW_ALL)
      expect(@common_pages.transaction_listed?(@transaction_id)).to eq(true), "Transaction #{@transaction_id} is not listed"
      @common_pages.navigate_to_transaction(@transaction_id)
      expect(@common_pages.get_investor_in_details).to eq(@second_investor_name)
    end

    e.run_step 'Platform Logs out' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Anchor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['grn_anchor']['email'], $conf['users']['grn_anchor']['password'])).to be true
    end

    e.run_step 'Verify Assigned Investor name in Anchor login' do
      @common_pages.click_menu(MENU_PO_FINANCING)
      @common_pages.click_transactions_tab(SHOW_ALL)
      expect(@common_pages.transaction_listed?(@transaction_id)).to eq(true), "Transaction #{@transaction_id} is not listed"
      @common_pages.navigate_to_transaction(@transaction_id)
      expect(@common_pages.get_investor_in_details).to eq(@second_investor_name)
    end

    e.run_step 'Anchor Logs out' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Investor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['user_feedback_investor']['email'], $conf['users']['user_feedback_investor']['password'])).to be true
    end

    e.run_step 'Verify Assigned Investor name is not shown in Investor login' do
      @common_pages.click_menu(MENU_PO_FINANCING)
      @common_pages.click_transactions_tab(SHOW_ALL)
      expect(@common_pages.transaction_listed?(@transaction_id)).to eq(true), "Transaction #{@transaction_id} is not listed"
      @common_pages.navigate_to_transaction(@transaction_id)
      expect(@common_pages.get_investor_in_details).to eq(false)
    end

    e.run_step 'Reject transaction' do
      ids = []
      resp = get_po_details(@transaction_id)
      ids << resp[:body][:id]
      resp = get_po_details(@transaction_id_1)
      ids << resp[:body][:id]
      decline_hash = {
        comment: 'Testing Invoice Re-initiation',
        invoice_transaction_ids: ids,
        actor: 'user_feedback_investor'
      }
      ids << @transaction_id
      ids << @transaction_id_1
      resp = decline_multiple_transactions(decline_hash)
      expect(resp[:code]).to eq(200), resp.to_s
    end

    e.run_step 'Logout as Investor' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Vendor : CH29 Stores' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['re_assignment_vendor']['email'], $conf['users']['re_assignment_vendor']['password'])).to be true
    end

    e.run_step 'Verify status of transaction as Vendor' do
      @common_pages.click_menu(MENU_PO_FINANCING)
      @common_pages.click_transactions_tab(SHOW_ALL)
      @common_pages.navigate_to_transaction(@transaction_id)
      expect(@transactions_page.verify_transaction_status('Rejected')).to eq true
    end

    e.run_step 'Verify rejection comments as Vendor' do
      expect(@transactions_page.rejected_status('Re-Initiate Transaction', 'DCB Bank', 'Testing Invoice Re-initiation')).to eq true
    end

    e.run_step "Verify Transaction Listed in 'Rejected' as Vendor" do
      @common_pages.click_menu(MENU_PO_FINANCING)
      @common_pages.click_transactions_tab(REJECTED)
      expect(@common_pages.transaction_listed?(@transaction_id)).to eq(true), "Transaction #{@transaction_id} is not listed"
    end

    e.run_step 'Verify transaction status in landing page' do
      @common_pages.navigate_to_transaction(@transaction_id)
      expect(@transactions_page.verify_transaction_status('Rejected')).to eq true
    end

    e.run_step 'Reassign transaction to other investor' do
      @tarspect_methods.click_button('Reassign')
      @common_pages.reassign_investor('Kotak', true)
      @transactions_page.re_initiate_transaction(false, false, true)
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['ReInitiateSucess']
    end

    e.run_step 'Verify Transaction 1 does not need approval' do
      expect(@transactions_page.verify_transaction_status('Released')).to eq true
    end

    e.run_step 'Reassign another transaction to other investor with changing details' do
      @common_pages.click_menu(MENU_PO_FINANCING)
      @common_pages.click_transactions_tab(REJECTED)
      expect(@common_pages.transaction_listed?(@transaction_id_1)).to eq true
      @common_pages.navigate_to_transaction(@transaction_id_1)
      @transactions_page.change_po_value(@invoice_data_1['Requested Disbursement Value'] - 100)
      @tarspect_methods.click_button('Reassign')
      expect(@common_pages.reassign_investor('Kotak', true)).to eq(true)
      @transactions_page.re_initiate_transaction(false, false, true)
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['ReInitiateSucess']
    end

    e.run_step 'Verify Transaction 2 need approval' do
      expect(@transactions_page.verify_transaction_status('Draft')).to eq true
    end
  end

  it 'Invoice Initiation : Highlight Invoices with Overdue status' do |e|
    e.run_step 'Capture Vendor Commercial for Kotak' do
      hash = {
        'Anchor ID' => 5,
        'Investor ID' => 7,
        'Program' => 'Invoice Financing',
        'Type' => 'Vendor',
        'Vendor Name' => @vendor_name,
        'actor' => @investor_actor
      }
      resp = get_vendor_commercial(hash)
      expect(resp[:code]).to eq 200
      @commercial_kotak = {
        'Yield' => resp[:body][:program_limits][:yield],
        'Sanction Limit' => resp[:body][:program_limits][:sanction_limit],
        'Tenor' => resp[:body][:program_limits][:tenor],
        'Invoice Days' => resp[:body][:program_limits][:days_to_raise_invoice]
      }
    end

    # e.run_step 'Vendor Commercial setup and approval' do
    # @testdata['Payment Date'] = Date.today.strftime('%d %b, %Y')
    # @testdata['Valid Till'] = (Date.today + 300).strftime('%Y-%m-%d')
    # @testdata['Yield'] = @commercial_kotak['Yield'] - 2
    # @testdata['Sanction Limit'] = @commercial_kotak['Sanction Limit']
    # @testdata['Tenor'] = @commercial_kotak['Tenor']
    # @testdata['Invoice Days'] = @commercial_kotak['Invoice Days']
    # resp = set_and_approve_commercials(@testdata)
    # expect(resp[0]).to eq(201), "Error in Commercial setup and approval #{resp}"
    # end

    e.run_step 'Create an overdue transaction' do
      @invoice_data = JSON.parse(ERB.new(@invoice_erb).result(binding))['PO Details']
      @invoice_data['PO Date'] = (Date.today - 90).strftime('%Y-%m-%d')
      resp = create_po_transaction(
        {
          po_details: @invoice_data,
          program_id: 1,
          actor: @vendor_actor,
          po_file: @invoice_file
        }
      )
      @transaction_id = resp[:body][:id]
      expect(resp[:code]).to eq(201), "Error in Transaction Initiation #{resp}"
      expect(resp[:body][:status]).to eq('pending_investor_assignment')
      resp = assign_investor(
        {
          anchor_id: @testdata['Anchor ID'],
          ids: [@transaction_id],
          program_id: 1,
          actor: @vendor_actor,
          type: 'po',
          investor_id: $conf['users']['investor']['id']
        }
      )

      expect(resp[:code]).to eq(200), resp.to_s
      values = {
        counter_party: 'grn_anchor',
        transaction_id: @transaction_id,
        program_id: 4
      }
      resp = release_transaction(values)
      expect(resp).to eq(true), 'Error in Transaction Approval'
    end

    e.run_step 'Disburse the transaction' do
      @details = disburse_transaction(
        {
          transaction_id: @transaction_id,
          invoice_value: @invoice_data['Requested Disbursement Value'],
          type: 'frontend',
          date_of_payment: Date.parse(@invoice_data['PO Date'], '%Y-%b-%d').strftime('%d-%b-%Y'),
          payment_proof: @payment_proof,
          program: 'PO Financing - Vendor',
          tenor: 45,
          yield: @commercial_kotak['Yield']
        }
      )
      expect(@details).not_to include('Error while disbursements')
    end

    e.run_step 'Login as Investor - Kotak' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['investor']['email'], $conf['users']['investor']['password'])).to be true
    end

    e.run_step 'Check Overdue notification is shown in borrower list' do
      @common_pages.click_menu(MENU_BORROWER_LIST)
      hash = {
        'Anchors' => @anchor_name,
        'Channel Partners' => @vendor_name,
        'Program' => 'Vendor Financing'
      }
      @common_pages.apply_list_filter(hash)
      expect(@transactions_page.get_message_on_hover_element(@vendor_name, 'BorrowerList')).to eq 'This borrower is in overdue with you'
    end

    e.run_step 'Logout as Investor' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Investor - DCB' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['user_feedback_investor']['email'], $conf['users']['user_feedback_investor']['password'])).to be true
    end

    e.run_step 'Verify Overdue notification is shown' do
      @common_pages.click_menu(MENU_PO_FINANCING)
      @common_pages.click_transactions_tab(UP_FOR_DISBURSEMENT)
      expect(@transactions_page.get_message_on_hover_element(@vendor_name)).to eq 'This Borrower Is In Overdue With Other Investor'
    end

    e.run_step 'Logout as Investor' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Create a transaction' do
      @invoice_data = JSON.parse(ERB.new(@invoice_erb).result(binding))['PO Details']
      @invoice_data['PO Date'] = (Date.today - 60).strftime('%Y-%m-%d')
      resp = create_po_transaction({
                                     po_details: @invoice_data,
                                     program_id: 4,
                                     actor: @vendor_actor,
                                     po_file: @invoice_file
                                   })
      @transaction_id = resp[:body][:id]
      expect(resp[:code]).to eq(201), 'Error in Transaction Initiation'
      expect(resp[:body][:status]).to eq('pending_investor_assignment')
    end

    e.run_step 'Login as Vendor - CH29 Stores' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['re_assignment_vendor']['email'], $conf['users']['re_assignment_vendor']['password'])).to be true
    end

    e.run_step 'Verify notification of overdue is shown to channel partner' do
      @common_pages.click_menu(MENU_PO_FINANCING)
      @common_pages.click_transactions_tab(UNASSIGNED_INVESTOR)
      expect(@common_pages.transaction_listed?(@transaction_id)).to eq(true), "Transaction #{@transaction_id} is not listed"
      @transactions_page.deselect_checkbox_in_unassigned_investor
      @disbursement_page.select_transactions(@transaction_id)
      @tarspect_methods.click_button('Reassign')
      expect(@common_pages.verify_assignment_dialog(@first_investor_name, 'status')).to include('Overdue')
    end

    e.run_step 'Verify overdue investor can be assigned' do
      expect(@common_pages.reassign_investor(@first_investor_name)).to eq(true)
    end
  end
end
