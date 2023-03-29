require './spec_helper'
describe 'Transactions: Invoice expiry verification', :scf, :transactions, :invoice_date_expiry do
  before(:all) do
    @anchor_actor = 'anchor'
    @vendor_actor = 'vendor'
    @dealer_actor = 'dealer'
    @investor_actor = 'investor'
    @counterparty_gstn = $conf['users'][@vendor_actor]['gstn']
    @anchor_gstn = $conf['users'][@anchor_actor]['gstn']
    @vendor_name = $conf['users'][@vendor_actor]['name']
    @anchor_name = $conf['users'][@anchor_actor]['name']
    @investor_name = $conf['users'][@investor_actor]['name']
    @investor_id = $conf['users'][@investor_actor]['id']
    @invoice_file = "#{Dir.pwd}/test-data/attachments/anchor_invoice.pdf"
    @erb_file = File.read("#{Dir.pwd}/test-data/erb/testbed_data.erb")
  end

  before(:each) do
    @tarspect_methods = Common::Methods.new(@driver)
    @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
  end

  it 'Transaction : Invoice Date expiry Verification with tooltip', :sanity do |e|
    e.run_step 'Create a complete transaction as Anchor(Draft -> Released)' do
      @testdata['Invoice Details']['Invoice Date'] = (Date.today - 90).strftime('%d-%b-%Y')
      @transaction_id = seed_transaction(
        {
          actor: @anchor_actor,
          counter_party: @vendor_actor,
          invoice_details: @testdata['Invoice Details'],
          invoice_file: @invoice_file,
          program: 'Invoice Financing - Vendor',
          program_group: 'invoice'
        }
      )
      expect(@transaction_id).not_to include('Error while creating transaction')
    end

    e.run_step 'Verify tool tip is present for expired invoices' do
      @tran_resp = get_transaction_details(@transaction_id, actor: @investor_actor)
      expect(@tran_resp[:body][:status]).to eq('investor_approved')
      expect(@tran_resp[:body][:is_stale_invoice]).to eq(true)
    end
  end
end
