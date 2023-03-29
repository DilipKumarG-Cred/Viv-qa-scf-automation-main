require './spec_helper'
describe 'Transactions: Channel Partner against Anchor', :scf, :transactions, :channel_partner_transaction do
  before(:all) do
    @anchor_actor = 'anchor'
    @vendor_actor = 'vendor'
    @dealer_actor = 'dealer'
    @investor_actor = 'investor'
    @vendor_gstn = $conf['users'][@vendor_actor]['gstn']
    @anchor_gstn = $conf['users'][@anchor_actor]['gstn']
    @dealer_gstn = $conf['users'][@dealer_actor]['gstn']
    @counterparty_gstn = $conf['users'][@anchor_actor]['gstn']
    @vendor_name = $conf['users'][@vendor_actor]['name']
    @anchor_name = $conf['users'][@anchor_actor]['name']
    @investor_name = $conf['users'][@investor_actor]['name']
    @investor_id = $conf['users'][@investor_actor]['id']
    @invoice_file = "#{Dir.pwd}/test-data/attachments/dealer_invoice.pdf"
    @erb_file = File.read("#{Dir.pwd}/test-data/erb/testbed_data.erb")
    @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
    @program_id = $conf['programs']['Invoice Financing - Vendor']
  end

  before(:each) do
    @tarspect_methods = Common::Methods.new(@driver)
    @common_pages = Pages::CommonMethods.new(@driver)
    @transactions_page = Pages::Trasactions.new(@driver)
  end

  it 'Transaction : Vendor against Anchor', :sanity do |e|
    e.run_step 'Create a transaction initiated by vendor' do
      values = {
        actor: @vendor_actor,
        invoice_details: @testdata['Vendor Invoice Details'],
        invoice_file: @invoice_file,
        program_id: @program_id
      }
      resp = create_transaction(values[:actor], values[:invoice_details], values[:invoice_file], values[:program_id])
      expect([200, 201]).to include(resp[:code]), resp.to_s
      @transaction_id = resp[:body][:id]
    end

    e.run_step 'Verify transaction is in draft state' do
      @tran_resp = get_transaction_details(@transaction_id, actor: 'vendor')
      expect(@tran_resp[:body][:status]).to eq('new')
      expect(@tran_resp[:body][:initiator]).to eq('vendor')
      expect(@tran_resp[:body][:display_status]).to eq('Draft')
      expect(@tran_resp[:body][:invoice_value]).to eq(@testdata['Vendor Invoice Details']['Invoice Value'])
      expect(@tran_resp[:body][:anchor][:gstn]).to eq(@testdata['Vendor Invoice Details']['GSTN of Anchor'])
      expect(@tran_resp[:body][:vendor][:gstn]).to eq(@testdata['Vendor Invoice Details']['GSTN of Channel Partner'])
    end

    e.run_step 'Verify invoice image is uploaded to transaction' do
      expect(@tran_resp[:body][:documents].empty?).to eq(false)
      expect(@tran_resp[:body][:documents][0][:document_type]).to eq('invoice')
      expect(@tran_resp[:body][:documents][0][:file_name]).to eq('dealer_invoice.pdf')
      expect(@tran_resp[:body][:documents][0][:file_url].empty?).to eq(false)
      resp = request_url(@tran_resp[:body][:documents][0][:file_url])
      expect(resp.code).to eq(200)
      expect(resp.headers[:content_type]).to eq('application/pdf')
    end

    e.run_step 'Verify transaction available for Product user' do
      @tran_resp = get_transaction_details(@transaction_id, actor: 'product')
      expect(@tran_resp[:body][:status]).to eq('new')
      expect(@tran_resp[:body][:initiator]).to eq('vendor')
      expect(@tran_resp[:body][:display_status]).to eq('Draft')
      expect(@tran_resp[:body][:invoice_value]).to eq(@testdata['Vendor Invoice Details']['Invoice Value'])
      expect(@tran_resp[:body][:anchor][:gstn]).to eq(@testdata['Vendor Invoice Details']['GSTN of Anchor'])
      expect(@tran_resp[:body][:vendor][:gstn]).to eq(@testdata['Vendor Invoice Details']['GSTN of Channel Partner'])
    end

    e.run_step 'Verify document is available' do
      # @tarspect_methods.verify_links([@tran_resp[:body][:documents][:link]])
    end

    e.run_step "Verify transaction listed in 'Invoices to approve' as Product" do
      queries = { actor: 'product', category: 'pending_approval_invoices', program_group: 'invoice' }
      resp = api_transaction_listed?(queries, @transaction_id)
      expect(resp[0]).to eq(true)
    end
  end

  it 'Transaction : Dealer against Anchor', :sanity do |e|
    e.run_step 'Create a transaction initiated by vendor' do
      @program_id = $conf['programs']['Invoice Financing - Dealer']
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

    e.run_step 'Verify transaction is in draft state' do
      @tran_resp = get_transaction_details(@transaction_id, actor: 'dealer')
      expect(@tran_resp[:body][:status]).to eq('new')
      expect(@tran_resp[:body][:initiator]).to eq('vendor')
      expect(@tran_resp[:body][:display_status]).to eq('Draft')
      expect(@tran_resp[:body][:invoice_value]).to eq(@testdata['Dealer Invoice Details']['Invoice Value'])
      expect(@tran_resp[:body][:anchor][:gstn]).to eq(@testdata['Dealer Invoice Details']['GSTN of Anchor'])
      expect(@tran_resp[:body][:vendor][:gstn]).to eq(@testdata['Dealer Invoice Details']['GSTN of Dealer'])
    end

    e.run_step 'Verify invoice image is uploaded to transaction' do
      expect(@tran_resp[:body][:documents].empty?).to eq(false)
      expect(@tran_resp[:body][:documents][0][:document_type]).to eq('invoice')
      expect(@tran_resp[:body][:documents][0][:file_name]).to eq('dealer_invoice.pdf')
      expect(@tran_resp[:body][:documents][0][:file_url].empty?).to eq(false)
      resp = request_url(@tran_resp[:body][:documents][0][:file_url])
      expect(resp.code).to eq(200)
      expect(resp.headers[:content_type]).to eq('application/pdf')
    end

    e.run_step 'Verify transaction available for Product user' do
      @tran_resp = get_transaction_details(@transaction_id, actor: 'product')
      expect(@tran_resp[:body][:status]).to eq('new')
      expect(@tran_resp[:body][:initiator]).to eq('vendor')
      expect(@tran_resp[:body][:display_status]).to eq('Draft')
      expect(@tran_resp[:body][:invoice_value]).to eq(@testdata['Dealer Invoice Details']['Invoice Value'])
      expect(@tran_resp[:body][:anchor][:gstn]).to eq(@testdata['Dealer Invoice Details']['GSTN of Anchor'])
      expect(@tran_resp[:body][:vendor][:gstn]).to eq(@testdata['Dealer Invoice Details']['GSTN of Dealer'])
    end

    e.run_step 'Verify document is available' do
      # @tarspect_methods.verify_links([@tran_resp[:body][:documents][:link]])
    end

    e.run_step "Verify transaction listed in 'Invoices to approve' as Product" do
      queries = { actor: 'product', category: 'pending_approval_invoices', program_group: 'invoice' }
      resp = api_transaction_listed?(queries, @transaction_id)
      expect(resp[0]).to eq(true)
    end
  end
end
