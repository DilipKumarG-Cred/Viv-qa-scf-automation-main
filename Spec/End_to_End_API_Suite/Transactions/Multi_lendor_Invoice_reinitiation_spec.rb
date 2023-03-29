require './spec_helper'
describe 'Invoice Re-Initiation', :scf, :transactions, :multi_lendor, :invoice_re_initiation do
  before(:all) do
    @anchor_actor = 'grn_anchor'
    @vendor_actor = 're_assignment_vendor'
    @party_gstn = $conf['users'][@anchor_actor]['gstn']
    @anchor_name = $conf['users'][@anchor_actor]['name']
    @vendor_name = $conf['users'][@vendor_actor]['name']
    @counterparty_gstn = $conf['users'][@vendor_actor]['gstn']
    @vendor_id = $conf['users'][@vendor_actor]['id']
    @first_investor_name = $conf['investor_name']
    @second_investor_name = $conf['users']['user_feedback_investor']['name']
    @borrowing_document = "#{Dir.pwd}/test-data/attachments/borrowing_document.pdf"
    @payment_proof = "#{Dir.pwd}/test-data/attachments/payment_proof.pdf"
    @erb_file = File.read("#{Dir.pwd}/test-data/erb/commercials_data.erb")
    @invoice_erb = File.read("#{Dir.pwd}/test-data/erb/testbed_data.erb")
    @invoice_data = JSON.parse(ERB.new(@invoice_erb).result(binding))['PO Details']
    @invoice_file = "#{Dir.pwd}/test-data/attachments/anchor_invoice.pdf"
  end

  before(:each) do
    @tarspect_methods = Common::Methods.new(@driver)
    @common_pages = Pages::CommonMethods.new(@driver)
    @testdata = JSON.parse(ERB.new(@erb_file).result(binding))['Vendor Commercials']
    @testdata['Program'] = 'PO Financing'
    @testdata['Type'] = 'Vendor'
    @testdata['Vendor Name'] = @vendor_name
    clear_all_overdues(anchor: $conf['grn_anchor_name'], vendor: @vendor_name, investor: 'user_feedback_investor')
  end

  it 'Invoice Re-Initiation : Investor Rejection', :sanity do |e|
    e.run_step 'Initiate invoice Transaction' do
      @invoice_data['PO Date'] = (Date.today - 60).strftime('%d-%b-%Y')
      @transaction_id = seed_transaction({
                                           actor: @vendor_actor,
                                           counter_party: @anchor_actor,
                                           po_details: @invoice_data,
                                           po_file: @invoice_file,
                                           program: 'PO Financing - Vendor',
                                           investor_id: 9,
                                           skip_counterparty_approval: true,
                                           program_group: 'purchase_order'
                                          })
      expect(@transaction_id).not_to include('Error while creating transaction')
      @invoice_data1 = JSON.parse(ERB.new(@invoice_erb).result(binding))['PO Details']
      @invoice_data1['PO Date'] = (Date.today - 60).strftime('%d-%b-%Y')
      @transaction_id1 = seed_transaction({
                                            actor: @vendor_actor,
                                            counter_party: @anchor_actor,
                                            po_details: @invoice_data1,
                                            po_file: @invoice_file,
                                            program: 'PO Financing - Vendor',
                                            investor_id: 9,
                                            skip_counterparty_approval: true,
                                            program_group: 'purchase_order'
                                          })
      expect(@transaction_id1).not_to include('Error while creating transaction')
    end

    e.run_step 'Verify Assigned Investor name in Platform login' do
      resp = get_po_details(@transaction_id, actor: 'product')
      expect(resp[:body][:investor][:name]).to eq(@second_investor_name)
    end

    e.run_step 'Verify Assigned Investor name in Anchor login' do
      resp = get_po_details(@transaction_id, actor: @anchor_actor)
      expect(resp[:body][:investor][:name]).to eq(@second_investor_name)
    end

    e.run_step 'Verify transaction can be rejected' do
      ids = []
      resp = get_po_details(@transaction_id)
      ids << resp[:body][:id]
      resp = get_po_details(@transaction_id1)
      ids << resp[:body][:id]
      decline_hash = {
        comment: 'Testing Invoice Re-initiation',
        invoice_transaction_ids: ids,
        actor: 'user_feedback_investor'
      }
      resp = decline_multiple_transactions(decline_hash)
      expect(resp[:code]).to eq(200)
    end

    e.run_step 'Verify status of transaction as Vendor' do
      @tran_resp = get_po_details(@transaction_id, actor: @vendor_actor)
      status = { status: 'rejected_with_reinitiation', display_status: 'Rejected', action_label: 'Reinitiate' }
      expect(fetch_status_of_transaction(@tran_resp[:body])).to eq(status)
    end

    e.run_step 'Verify rejection comments as Vendor' do
      expected_comment = { comment_type: 'reject_reason', name: @second_investor_name, comment: 'Testing Invoice Re-initiation' }
      expect(validate_comments(@tran_resp[:body], expected_comment)).to eq(true)
    end

    e.run_step "Verify Transaction Listed in 'Rejected' as Vendor" do
      queries = { actor: @vendor_actor, category: 'rejected_invoices', program_group: 'po' }
      resp = api_transaction_listed?(queries, @transaction_id)
      expect(resp[0]).to eq(true)
    end

    e.run_step 'Reassign transaction to other investor' do
      values = {
        id: @tran_resp[:body][:id],
        type: 'po',
        instrument_value: @tran_resp[:body][:po_value],
        required_disbursement_value: @tran_resp[:body][:po_eligible_value],
        instrument_date: Date.parse(@tran_resp[:body][:po_date]).strftime('%Y-%m-%d'),
        investor_id: 7,
        actor: @vendor_actor
      }
      resp = re_initiate_transaction(values)
      expect(resp[:code]).to eq(200)
    end

    e.run_step 'Verify Transaction 1 does not need approval' do
      resp = get_po_details(@transaction_id)
      expect(resp[:body][:display_status]).to eq('Released')
    end

    e.run_step 'Reassign another transaction to other investor with changing details' do
      @tran_resp = get_po_details(@transaction_id1)
      values = {
        id: @tran_resp[:body][:id],
        type: 'po',
        instrument_value: @tran_resp[:body][:po_value],
        required_disbursement_value: @tran_resp[:body][:po_eligible_value] - 100,
        instrument_date: Date.parse(@tran_resp[:body][:po_date]).strftime('%Y-%m-%d'),
        investor_id: 7,
        actor: @vendor_actor
      }
      resp = re_initiate_transaction(values)
      expect(resp[:code]).to eq(200)
    end

    e.run_step 'Verify Transaction 2 need approval' do
      resp = get_po_details(@transaction_id1)
      expect(resp[:body][:display_status]).to eq('Draft')
    end
  end
end
