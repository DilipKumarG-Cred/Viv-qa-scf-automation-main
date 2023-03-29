require './spec_helper'
describe 'Commercials: User Feedbacks', :scf, :commercials, :skip_counter_party do
  before(:all) do
    @anchor_actor = 'user_feedback_anchor'
    @vendor_actor = 'user_feedback_vendor'
    @investor_actor = 'user_feedback_investor'
    @anchor_gstn = $conf['users'][@anchor_actor]['gstn']
    @counterparty_gstn = $conf['users'][@vendor_actor]['gstn']
    @vendor_name = $conf['users'][@vendor_actor]['name']
    @anchor_name = $conf['users'][@anchor_actor]['name']
    @investor_name = $conf['users'][@investor_actor]['name']
    @invoice_file = "#{Dir.pwd}/test-data/attachments/anchor_invoice.pdf"
    @file_name = 'anchor_invoice.pdf'
    @erb_file = File.read("#{Dir.pwd}/test-data/erb/testbed_data.erb")
    @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
    @testdata['Transaction List']['Instrument Value'] = @testdata['Invoice Details']['Invoice Value'].to_s
    @today_date = Date.today.strftime('%d %b, %Y')
    @program_id = $conf['programs']['Invoice Financing - Vendor']
  end

  before(:each) do
    update_fields = { skip_counter_party_approval: false, is_invoice_file_mandatory: true }
    @update_anchor_commercial = {
      update_fields: update_fields,
      investor_id: 9,
      anchor_actor: @anchor_actor,
      program_name: 'Invoice Financing - Vendor',
      investor_actor: @investor_actor
    }
    resp = set_anchor_commercials(@update_anchor_commercial, action: :update)
    expect(resp[:code]).to eq(200)
  end

  it 'Commercials : Skip Counterparty approval(Anchor)', :sanity do |e|
    e.run_step 'Set Skip Counterparty Approval - Yes as product' do
      update_fields = { skip_counter_party_approval: true }
      @update_anchor_commercial[:update_fields] = update_fields
      resp = set_anchor_commercials(@update_anchor_commercial, action: :update)
      expect(resp[:code]).to eq(200)
    end

    e.run_step 'Add a transaction as anchor' do
      tran_resp = create_transaction(@anchor_actor, @testdata['Invoice Details'], @invoice_file, @program_id)
      expect(tran_resp[:code]).to eq(200)
      @transaction_id = tran_resp[:body][:id]
    end

    e.run_step 'Verify transaction as Anchor in list page' do
      @tran_resp = get_transaction_details(@transaction_id, actor: @anchor_actor)
      expect(api_verify_transaction_in_list_page(@tran_resp[:body], @testdata['Transaction List'])).to eq(true)
    end

    e.run_step 'Verify VCPL and counterparty approval happens immediately once the transaction created - Status timeline in homepage' do
      queries = { actor: @anchor_actor, category: 'invoices', program_group: 'invoice' }
      result = api_transaction_listed?(queries, @transaction_id)
      expect(result[0]).to eq(true)
      details_to_verify = { invoice_state: ['CA Approval', 'Vendor/Dealer Approval'], change_date: Date.today }
      expect(status_present_in_timeline?(result[1][0][:state_changes], details_to_verify)).to eq(true)
    end

    e.run_step 'Verify VCPL and counterparty approval happens immediately once the transaction created - Status timeline in transaction details page' do
      details_to_verify = { invoice_state: ['CA Approval', 'Vendor/Dealer Approval'], change_date: Date.today }
      expect(status_present_in_timeline?(@tran_resp[:body][:state_changes], details_to_verify)).to eq(true)
    end
  end

  it 'Commercials : Skip Counterparty approval(Vendor)', :sanity do |e|
    @vendor_gstn = $conf['users'][@vendor_actor]['gstn']
    @counterparty_gstn = $conf['users'][@anchor_actor]['gstn']
    @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
    @testdata['Transaction List']['Instrument Value'] = @testdata['Dealer Invoice Details']['Invoice Value'].to_s
    @testdata['Vendor Invoice Details']['Invoice Value'] = @testdata['Dealer Invoice Details']['Invoice Value']

    e.run_step 'Set Skip Counterparty Approval - Yes as product' do
      update_fields = { skip_counter_party_approval: true }
      @update_anchor_commercial[:update_fields] = update_fields
      resp = set_anchor_commercials(@update_anchor_commercial, action: :update)
      expect(resp[:code]).to eq(200)
    end

    e.run_step 'Add a transaction as vendor' do
      tran_resp = create_transaction(@vendor_actor, @testdata['Vendor Invoice Details'], @invoice_file, @program_id)
      expect(tran_resp[:code]).to eq(200), tran_resp.to_s
      @transaction_id = tran_resp[:body][:id]
    end

    e.run_step 'Verify transaction as Vendor in list page' do
      @tran_resp = get_transaction_details(@transaction_id, actor: @vendor_actor)
      expect(api_verify_transaction_in_list_page(@tran_resp[:body], @testdata['Transaction List'])).to eq(true)
    end

    e.run_step 'Verify VCPL and counterparty approval happens immediately once the transaction created - Status timeline in homepage' do
      queries = { actor: @vendor_actor, category: 'invoices', program_group: 'invoice' }
      result = api_transaction_listed?(queries, @transaction_id)
      expect(result[0]).to eq(true)
      details_to_verify = { invoice_state: ['CA Approval', 'Vendor/Dealer Approval'], change_date: Date.today }
      expect(status_present_in_timeline?(result[1][0][:state_changes], details_to_verify)).to eq(true)
    end

    e.run_step 'Verify VCPL and counterparty approval happens immediately once the transaction created - Status timeline in transaction details page' do
      details_to_verify = { invoice_state: ['CA Approval', 'Vendor/Dealer Approval'], change_date: Date.today }
      expect(status_present_in_timeline?(@tran_resp[:body][:state_changes], details_to_verify)).to eq(true)
    end
  end

  it 'Commercials: Skip Invoice Upload' do |e|
    @vendor_gstn = $conf['users'][@vendor_actor]['gstn']
    @counterparty_gstn = $conf['users'][@anchor_actor]['gstn']
    @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
    @testdata['Transaction List']['Instrument Value'] = @testdata['Dealer Invoice Details']['Invoice Value'].to_s
    @testdata['Vendor Invoice Details']['Invoice Value'] = @testdata['Dealer Invoice Details']['Invoice Value']

    e.run_step 'Verifying adding a transaction as vendor with no invoice with Mandatory Invoice - YES' do
      @tran_resp = create_transaction(@vendor_actor, @testdata['Vendor Invoice Details'], nil, @program_id)
      expect(@tran_resp[:code]).to eq(422)
    end

    e.run_step 'Verify alert is thrown when no invoice is attached' do
      expect(@tran_resp[:body][:error][:message]).to eq('Invoice file attachment is mandatory')
    end

    e.run_step 'Set Mandatory Invoice Upload - No as product' do
      update_fields = { is_invoice_file_mandatory: false }
      @update_anchor_commercial[:update_fields] = update_fields
      resp = set_anchor_commercials(@update_anchor_commercial, action: :update)
      expect(resp[:code]).to eq(200), resp.to_s
    end

    e.run_step 'Add a transaction as vendor with no invoice with Mandatory Invoice - NO' do
      @tran_resp = create_transaction(@vendor_actor, @testdata['Vendor Invoice Details'], nil, @program_id)
      expect(@tran_resp[:code]).to eq(200), @tran_resp.to_s
      @transaction_id = @tran_resp[:body][:id]
    end

    e.run_step 'Verify transaction as Vendor in list page' do
      queries = { actor: @vendor_actor, category: 'invoices', program_group: 'invoice' }
      result = api_transaction_listed?(queries, @transaction_id)
      expect(result[0]).to eq(true)
    end

    e.run_step 'Verify no invoice document is present' do
      expect(@tran_resp[:body][:documents]).to match_array([])
    end
  end
end
