require './spec_helper'
describe 'Transactions: Bulk Approve / Reject', :scf, :transactions, :anchor_transaction do
  before(:all) do
    @anchor_actor = 'anchor'
    @vendor_actor = 'vendor'
    @anchor_gstn = $conf['users'][@anchor_actor]['gstn']
    @counterparty_gstn = $conf['users'][@vendor_actor]['gstn']
    @vendor_name = $conf['users'][@vendor_actor]['name']
    @anchor_name = $conf['users'][@anchor_actor]['name']
    @invoice_file = "#{Dir.pwd}/test-data/attachments/anchor_invoice.pdf"
    @erb_file = File.read("#{Dir.pwd}/test-data/erb/testbed_data.erb")
  end

  before(:each) do
    @tarspect_methods = Common::Methods.new(@driver)
    @common_pages = Pages::CommonMethods.new(@driver)
    @transactions_page = Pages::Trasactions.new(@driver)
    @disbursement_page = Pages::Disbursement.new(@driver)
  end

  it 'Bulk approve and Reject spec: Invoices', :sanity do |e|
    e.run_step 'Create 2 draft transaction as Anchor' do
      @testdata1 = JSON.parse(ERB.new(@erb_file).result(binding))
      @testdata2 = JSON.parse(ERB.new(@erb_file).result(binding))
      tran_resp = create_transaction(@anchor_actor, @testdata1['Invoice Details'], @invoice_file, 1)
      expect(tran_resp[:code]).to eq(200), tran_resp.to_s
      @transaction1 = tran_resp[:body][:id].to_s
      expect(@transaction1.empty?).to eq false
      tran_resp = create_transaction(@anchor_actor, @testdata2['Invoice Details'], @invoice_file, 1)
      expect(tran_resp[:code]).to eq(200), tran_resp.to_s
      @transaction2 = tran_resp[:body][:id].to_s
      expect(@transaction2.empty?).to eq false
    end

    e.run_step 'Approve transactions as Product user' do
      rel_values = {
        actor: 'product',
        program_id: $conf['programs']['Invoice Financing - Vendor'],
        transaction_id: [@transaction1, @transaction2],
        todo: 'approved',
        can_reinitiate: false,
        comment: @testdata2['Reject Reason'],
        program_group: 'invoice'
      }
      resp = approve_transcation(rel_values)
      expect(resp[:code]).to eq(200)
    end

    e.run_step "Verify transaction listed in 'Invoices to approve' as Product" do
      queries = { actor: 'product', category: 'draft_invoices', program_group: 'invoice' }
      resp = api_transaction_listed?(queries, [@transaction1, @transaction2])
      expect(resp[0]).to eq(true)
    end

    e.run_step 'Verify status timeline for both transactions after Product Approval' do
      @tran_resp = get_transaction_details(@transaction1, actor: 'product')
      details_to_verify = { invoice_state: ['CA Approval'], change_date: Date.today }
      expect(status_present_in_timeline?(@tran_resp[:body][:state_changes], details_to_verify)).to eq(true)
      @tran_resp = get_transaction_details(@transaction2, actor: 'product')
      details_to_verify = { invoice_state: ['CA Approval'], change_date: Date.today }
      expect(status_present_in_timeline?(@tran_resp[:body][:state_changes], details_to_verify)).to eq(true)
    end

    e.run_step 'Bulk reject the transactions as Counter Party user' do
      rel_values = {
        actor: @vendor_actor,
        program_id: $conf['programs']['Invoice Financing - Vendor'],
        transaction_id: [@transaction1, @transaction2],
        todo: 'rejected',
        can_reinitiate: false,
        comment: @testdata1['Reject Reason'],
        program_group: 'invoice'
      }
      resp = approve_transcation(rel_values)
      expect(resp[:code]).to eq(200)
    end

    e.run_step "Verify Transaction Listed in 'Rejected' as Channel Partner after Anchor rejected" do
      queries = { actor: @vendor_actor, category: 'rejected_invoices', program_group: 'invoice' }
      @result = api_transaction_listed?(queries, [@transaction1, @transaction2])
      expect(@result[0]).to eq(true)
    end

    e.run_step 'Verify status timeline for both transactions after Vendor Rejection' do
      expected_comment = { comment_type: 'reject_reason', name: @vendor_name, comment: @testdata1['Reject Reason'] }
      expect(validate_comments(@result[1][0], expected_comment)).to eq(true)
      expect(validate_comments(@result[1][1], expected_comment)).to eq(true)
    end
  end
end
