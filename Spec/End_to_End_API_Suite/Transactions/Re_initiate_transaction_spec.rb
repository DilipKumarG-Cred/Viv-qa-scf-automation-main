require './spec_helper'
describe 'Transactions: Re-Initiate', :scf, :transactions, :transaction_reinitiate do
  before(:all) do
    @dealer_actor = 'dealer'
    @anchor_actor = 'anchor'
    @dealer_gstn = $conf['users'][@dealer_actor]['gstn']
    @counterparty_gstn = $conf['users'][@anchor_actor]['gstn']
    @vendor_name = $conf['users'][@dealer_actor]['name']
    @anchor_name = $conf['users'][@anchor_actor]['name']
    @investor_name = $conf['users']['investor']['name']
    @invoice_file = "#{Dir.pwd}/test-data/attachments/dealer_invoice.pdf"
    @file_name = 'dealer_invoice.pdf'
    @re_initiate_file = "#{Dir.pwd}/test-data/attachments/reinitiate_invoice.pdf"
    @re_initiate_file_name = 'reinitiate_invoice.pdf'
    @erb_file = File.read("#{Dir.pwd}/test-data/erb/testbed_data.erb")
    @program_id = $conf['programs']['Invoice Financing - Dealer']
    @rel_values = {
      actor: 'product',
      program_id: @program_id,
      transaction_id: '',
      todo: 'approved',
      can_reinitiate: true,
      comment: 'Approved'
    }
  end

  before(:each) do
    @tarspect_methods = Common::Methods.new(@driver)
    @common_pages = Pages::CommonMethods.new(@driver)
    @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
  end

  it 'Transaction : Re-Initiate a transaction', :sanity do |e|
    e.run_step 'Add transaction - Dealer against Anchor' do
      values = {
        actor: @dealer_actor,
        invoice_details: @testdata['Dealer Invoice Details'],
        invoice_file: @invoice_file,
        program_id: @program_id
      }
      resp = create_transaction(values[:actor], values[:invoice_details], values[:invoice_file], values[:program_id])
      expect([200, 201]).to include(resp[:code]), resp.to_s
      @transaction_id = resp[:body][:id]
    end

    e.run_step 'Verify transaction as DEALER in list page' do
      queries = { actor: @dealer_actor, category: 'draft_invoices', program_group: 'invoice' }
      resp = api_transaction_listed?(queries, @transaction_id)
      expect(resp[0]).to eq(true)
      @tran_resp = get_transaction_details(@transaction_id, actor: @dealer_actor)
      expect(@tran_resp[:body][:status]).to eq('new')
      @testdata['Transaction List']['Instrument Value'] = @testdata['Dealer Invoice Details']['Invoice Value'].to_s
      expect(api_verify_transaction_in_list_page(@tran_resp[:body], @testdata['Transaction List'])).to eq(true)
    end

    e.run_step 'Approve Invoice as PRODUCT - 1st level of approval' do
      @rel_values.merge!(transaction_id: @transaction_id)
      resp = approve_transcation(@rel_values)
      expect(resp[:code]).to eq(200), resp.to_s
    end

    e.run_step "Reject transactsion with 'Re-Initiate transaction' as ANCHOR - 2st level of approval" do
      @rel_values.merge!(
        actor: @anchor_actor,
        todo: 'rejected',
        comment: @testdata['Reject Reason']
      )
      resp = approve_transcation(@rel_values)
      expect(resp[:code]).to eq(200)
    end

    e.run_step 'Verify status timeline after Anchor rejected as ANCHOR' do
      queries = { actor: @anchor_actor, category: 'invoices', program_group: 'invoice' }
      result = api_transaction_listed?(queries, @transaction_id)
      expect(result[0]).to eq(true)
      status = { status: 'rejected_with_reinitiation', display_status: 'Rejected', action_label: 'Reinitiate' }
      expect(fetch_status_of_transaction(result[1][0])).to eq(status)
    end

    e.run_step 'Verify transaction status in landing page' do
      resp = get_transaction_details(@transaction_id, actor: @anchor_actor)
      status = { status: 'rejected_with_reinitiation', display_status: 'Rejected', action_label: 'Reinitiate' }
      expect(fetch_status_of_transaction(resp[:body])).to eq(status)
      expected_comment = { comment_type: 'reject_reason', name: @anchor_name, comment: @testdata['Reject Reason'] }
      expect(validate_comments(resp[:body], expected_comment)).to eq(true)
    end

    e.run_step "Verify Transaction Listed in 'Rejected' as ANCHOR after Anchor rejected" do
      queries = { actor: @anchor_actor, category: 'rejected_invoices', program_group: 'invoice' }
      result = api_transaction_listed?(queries, @transaction_id)
      expect(result[0]).to eq(true)
      expect(result[1][0][:action_label]).to eq('Reinitiate')
    end

    e.run_step "Verify Transaction Listed in 'Rejected' as DEALER after Anchor rejected" do
      queries = { actor: @dealer_actor, category: 'rejected_invoices', program_group: 'invoice' }
      result = api_transaction_listed?(queries, @transaction_id)
      expect(result[0]).to eq(true)
      expect(result[1][0][:action_label]).to eq('Reinitiate')
      expected_comment = { comment_type: 'reject_reason', name: @anchor_name, comment: @testdata['Reject Reason'] }
      expect(validate_comments(result[1][0], expected_comment)).to eq(true)
    end

    e.run_step 'Verify transaction status in landing page as DEALER' do
      @tran_resp = get_transaction_details(@transaction_id, actor: @dealer_actor)
      status = { status: 'rejected_with_reinitiation', display_status: 'Rejected', action_label: 'Reinitiate' }
      expect(fetch_status_of_transaction(@tran_resp[:body])).to eq(status)
      expected_comment = { comment_type: 'reject_reason', name: @anchor_name, comment: @testdata['Reject Reason'] }
      expect(validate_comments(@tran_resp[:body], expected_comment)).to eq(true)
    end

    e.run_step 'Re-Initiate the transaction as DEALER' do
      @testdata['Dealer Invoice Details']['Invoice Value'] = @testdata['Re-Initiate Details']['Invoice Value']
      @testdata['Dealer Invoice Details']['Invoice Date'] = @testdata['Re-Initiate Details']['Invoice Date']
      values = {
        id: @tran_resp[:body][:id],
        type: 'invoice',
        invoice_value: @testdata['Dealer Invoice Details']['Invoice Value'],
        requested_disbursement_value: @tran_resp[:body][:requested_disbursement_value],
        invoice_date: @testdata['Dealer Invoice Details']['Invoice Date'],
        grn: @tran_resp[:body][:grn],
        ewb_no: @tran_resp[:body][:ewb_no],
        ewb_date: Date.parse(@tran_resp[:body][:ewb_date]).strftime('%Y-%m-%d'),
        investor_id: 7,
        actor: @dealer_actor,
        document: @re_initiate_file
      }
      resp = re_initiate_transaction(values)
      expect(resp[:code]).to eq(200), resp.to_s
    end

    e.run_step 'Verify transaction status Dealer in landing page as DEALER' do
      @tran_resp = get_transaction_details(@transaction_id, actor: @dealer_actor)
      expect(@tran_resp[:body][:status]).to eq('new')
      expect(@tran_resp[:body][:display_status]).to eq('Draft')
      details_to_verify = { invoice_state: ['Reinitiated'], change_date: Date.today }
      expect(status_present_in_timeline?(@tran_resp[:body][:state_changes], details_to_verify)).to eq(true)
    end

    e.run_step 'Verify Invoice document as DEALER in landing page' do
      document_hash = { document_type: 'invoice', file_name: 'dealer_invoice.pdf' }
      expect(verify_document_is_uploaded_and_valid(@tran_resp[:body], document_hash, search_in_array: true)).to eq(true)
    end

    e.run_step 'Verify transaction as Dealer in list page' do
      queries = { actor: @dealer_actor, category: 'invoices', program_group: 'invoice' }
      result = api_transaction_listed?(queries, @transaction_id)
      expect(result[0]).to eq(true)
      @tran = result[1][0]
      expect(@tran[:invoice_value]).to eq(@testdata['Dealer Invoice Details']['Invoice Value'])
      expect(Date.parse(@tran[:invoice_date])).to eq(Date.parse(@testdata['Dealer Invoice Details']['Invoice Date']))
    end

    e.run_step "Verify Transaction Listed in 'Invoices to approve' as Product" do
      @testdata['Transaction List']['Instrument Value'] = @testdata['Dealer Invoice Details']['Invoice Value'].to_s
      @testdata['Transaction Details']['Instrument Value'] = @testdata['Dealer Invoice Details']['Invoice Value'].to_s
      expect(api_verify_transaction_in_list_page(@tran, @testdata['Transaction List'])).to eq(true)
    end

    e.run_step 'Verify transaction as Product in landing page' do
      @tran_resp = get_transaction_details(@transaction_id, actor: @dealer_actor)
      expect(@tran_resp[:body][:display_status]).to eq('Draft')
      expect(api_verify_transaction_details_page(@tran_resp[:body], @testdata['Transaction Details'])).to eq true
    end

    e.run_step 'Verify Invoice preview is available and link is valid' do
      values = { document_type: 'invoice', file_name: 'reinitiate_invoice.pdf' }
      expect(verify_document_is_uploaded_and_valid(@tran_resp[:body], values)).to eq(true)
    end

    e.run_step 'Approve Invoice as Product - 1st level of approval' do
      @rel_values.merge!(actor: 'product', todo: 'approved')
      resp = approve_transcation(@rel_values)
      expect(resp[:code]).to eq(200)
    end

    e.run_step 'Verify status timeline after product Approval' do
      @tran_resp = get_transaction_details(@transaction_id, actor: 'product')
      details_to_verify = { invoice_state: ['CA Approval', 'Reinitiated'], change_date: Date.today }
      expect(status_present_in_timeline?(@tran_resp[:body][:state_changes], details_to_verify)).to eq(true)
      details_to_verify = { invoice_state: ['Anchor Approval'], change_date: Date.today, is_passed: false }
      expect(status_present_in_timeline?(@tran_resp[:body][:state_changes], details_to_verify)).to eq(true)
    end

    e.run_step 'Verify status timeline in the hovercard after Product Approval' do
      expected_comment = { comment_type: 'reject_reason', name: $conf['users']['product']['name'], comment: @testdata['Reject Reason'] }
      expect(validate_comments(@tran_resp[:body], expected_comment)).to eq(true)
    end

    e.run_step "Verify Transaction Listed in 'Invoices to approve' as ANCHOR" do
      queries = { actor: @anchor_actor, category: 'pending_approval_invoices', program_group: 'invoice' }
      result = api_transaction_listed?(queries, @transaction_id)
      expect(result[0]).to eq(true)
      @tran = result[1][0]
      expect(api_verify_transaction_in_list_page(@tran, @testdata['Transaction List'])).to eq(true)
    end

    e.run_step 'Verify transaction as ANCHOR in landing page' do
      @tran_resp = get_transaction_details(@transaction_id, actor: @anchor_actor)
      expect(@tran_resp[:body][:display_status]).to eq('Draft')
      expect(api_verify_transaction_details_page(@tran_resp[:body], @testdata['Transaction Details'])).to eq true
    end

    e.run_step 'Verify Invoice document as Anchor in landing page' do
      values = { document_type: 'invoice', file_name: 'reinitiate_invoice.pdf' }
      expect(verify_document_is_uploaded_and_valid(@tran_resp[:body], values)).to eq(true)
    end

    e.run_step 'Approve Invoice as Anchor - 2st level of approval' do
      @rel_values.merge!(actor: @anchor_actor)
      resp = approve_transcation(@rel_values)
      expect(resp[:code]).to eq(200)
    end

    e.run_step 'Verify status timeline after Anchor Approval' do
      @tran_resp = get_transaction_details(@transaction_id, actor: @anchor_actor)
      details_to_verify = { invoice_state: ['CA Approval', 'Reinitiated', 'Anchor Approval'], change_date: Date.today }
      expect(status_present_in_timeline?(@tran_resp[:body][:state_changes], details_to_verify)).to eq(true)
      details_to_verify = { invoice_state: ['Anchor Approval'], change_date: Date.today, is_passed: false }
      expect(status_present_in_timeline?(@tran_resp[:body][:state_changes], details_to_verify)).to eq(true)
    end

    e.run_step 'Verify status timeline in the hovercard after Anchor Approval' do
      expected_comment = { comment_type: 'reject_reason', name: @anchor_name, comment: @testdata['Reject Reason'] }
      expect(validate_comments(@tran_resp[:body], expected_comment)).to eq(true)
    end

    e.run_step 'Approve Invoice as Product(Level 2) - 3rd level of approval' do
      @rel_values.merge!(actor: 'product')
      resp = approve_transcation(@rel_values)
      expect(resp[:code]).to eq(200)
    end

    e.run_step 'Verift status changed from Draft to Released' do
      @tran_resp = get_transaction_details(@transaction_id, actor: @anchor_actor)
      expect(@tran_resp[:body][:display_status]).to eq('Released')
    end

    e.run_step 'Verify status timeline in the hovercard after Product(Level 2) Approval' do
      queries = { actor: @anchor_actor, category: 'live_invoices', program_group: 'invoice' }
      result = api_transaction_listed?(queries, @transaction_id)
      expect(result[0]).to eq(true)
      tran = result[1][0]
      expected_comment = { comment_type: 'reject_reason', name: 'Vivriti Capital Private Limited', comment: @testdata['Reject Reason'] }
      expect(validate_comments(tran, expected_comment)).to eq(true)
    end
  end
end
