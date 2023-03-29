require './spec_helper'
describe 'Invoice Assignment', :scf, :commercials, :invoice_assign, :no_run do
  before(:all) do
    @anchor_actor = 'grn_anchor'
    @vendor_actor = 'assignment_vendor'
    @investor_actor = 'investor'
    @second_investor_actor = 'user_feedback_investor'
    @first_investor_id = $conf['users'][@investor_actor]['id']
    @second_investor_id = $conf['users'][@second_investor_actor]['id']
    @party_gstn = $conf['users'][@anchor_actor]['gstn']
    @counterparty_gstn = $conf['users'][@vendor_actor]['gstn']
    @anchor_name = $conf['users'][@anchor_actor]['name']
    @vendor_name = $conf['users'][@vendor_actor]['name']
    @anchor_id = $conf['users'][@anchor_actor]['id']
    @vendor_id = '5083' # CH28 Stores
    @first_investor_name = $conf['investor_name']
    @second_investor_name = $conf['user_feedback_investor']
    @borrowing_document = "#{Dir.pwd}/test-data/attachments/borrowing_document.pdf"
    @payment_proof = "#{Dir.pwd}/test-data/attachments/payment_proof.pdf"
    @erb_file = File.read("#{Dir.pwd}/test-data/erb/commercials_data.erb")
    @invoice_erb = File.read("#{Dir.pwd}/test-data/erb/testbed_data.erb")
    clear_all_overdues({ anchor: $conf['grn_anchor_name'], vendor: $conf['users']['assignment_vendor']['name'] })
    @program_type = 'PO Financing - Vendor'
  end

  before(:each) do
    @invoice_data = JSON.parse(ERB.new(@invoice_erb).result(binding))['PO Details']
    @testdata = JSON.parse(ERB.new(@erb_file).result(binding))['Vendor Commercials']
    @testdata['Program'] = 'PO Financing'
    @testdata['Type'] = 'Vendor'
    @testdata['Vendor Name'] = @vendor_name
    @testdata['actor'] = @second_investor_actor
    delete_vendor_commercials(@testdata)
  end

  it 'Invoice Assignment : Verification of Assignment based on ROI', :sanity do |e|
    e.run_step 'Capture Vendor Commercial for Kotak' do
      hash = {
        'Anchor ID' => @anchor_id,
        'Investor ID' => @first_investor_id,
        'Program' => 'PO Financing',
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

    e.run_step 'Vendor Commercial setup and approval' do
      @testdata.merge!(
        'Payment Date' => get_todays_date,
        'Valid Till' => get_todays_date(300),
        'Yield' => @commercial_kotak['Yield'] - 2,
        'Sanction Limit' => @commercial_kotak['Sanction Limit'],
        'Tenor' => @commercial_kotak['Tenor'],
        'Invoice Days' => @commercial_kotak['Invoice Days'],
        'Effective Date' => get_todays_date
      )
      resp = set_and_approve_commercials(@testdata)
      expect(resp[0]).to eq(201), "Error in Commercial setup and approval #{resp}"
    end

    e.run_step 'Initiate invoice Transaction' do
      @invoice_data['PO Date'] = get_todays_date(-30)
      values = { po_details: @invoice_data, program_id: $conf['programs'][@program_type], actor: @vendor_actor }
      resp = create_po_transaction(values)
      expect(resp[:code]).to eq(201), resp.to_s
      expect(resp[:body][:status]).to eq('pending_investor_assignment')
      @transaction_id = resp[:body][:id]
    end

    e.run_step 'Verify Invoice is assigned to Investor based on ROI' do
      queries = { actor: @vendor_actor, category: 'pending_assignments', program_group: 'po' }
      resp = api_transaction_listed?(queries, @transaction_id)
      expect(resp[0]).to eq(true)
      tran = resp[1][0]
      expect(tran[:status]).to eq('pending_investor_assignment')
      expect(tran[:investor][:name]).to eq(@second_investor_name), 'Investor assgined not as expected'
      resp = get_po_details(@transaction_id, actor: @vendor_actor)
      expect(resp[:body][:investor][:name]).to eq(@second_investor_name)
    end

    e.run_step 'Verify Investor Commercials are updated correctly' do
      @assign_values = { actor: @vendor_actor, type: 'po', program_id: $conf['programs'][@program_type], anchor_id: @anchor_id, ids: @transaction_id }
      resp = fetch_assign_investors(@assign_values)
      hash = {}
      resp[:body][:commercials].each { |commercial| hash[commercial[:investor][:name]] = { yield: commercial[:yield], tenor: commercial[:tenor], available_limit: commercial[:available_limit] } }
      expected_hash = { available_limit: @commercial_kotak['Sanction Limit'], tenor: @commercial_kotak['Tenor'], yield: @commercial_kotak['Yield'] }
      expect(hash[@first_investor_name]).to eq(expected_hash)
      expected_hash = { available_limit: @testdata['Sanction Limit'], tenor: @testdata['Tenor'], yield: @testdata['Yield'] }
      expect(hash[@second_investor_name]).to eq(expected_hash)
    end

    e.run_step 'Verify Investor can be assigned' do
      @assign_values[:investor_id] = @second_investor_id
      resp = assign_investor(@assign_values)
      expect(resp[:code]).to eq(200)
    end

    e.run_step 'Verify transaction is not present in Unassigned Investor' do
      queries = { actor: @vendor_actor, category: 'pending_assignments', program_group: 'po' }
      resp = api_transaction_listed?(queries, @transaction_id)
      expect(resp[0]).to include('not present')
    end
  end
end
