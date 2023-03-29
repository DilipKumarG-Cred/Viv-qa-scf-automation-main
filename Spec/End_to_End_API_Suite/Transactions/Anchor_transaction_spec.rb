require './spec_helper'
describe 'Transactions: Anchor', :scf, :transactions, :anchor_transaction do
  before(:all) do
    @anchor_actor = 'anchor'
    @vendor_actor = 'vendor'
    @investor_actor = 'investor'
    @anchor_gstn = $conf['users'][@anchor_actor]['gstn']
    @counterparty_gstn = $conf['users'][@vendor_actor]['gstn']
    @vendor_name = $conf['users'][@vendor_actor]['name']
    @anchor_name = $conf['users'][@anchor_actor]['name']
    @investor_name = $conf['users'][@investor_actor]['name']
    @investor_id = $conf['users'][@investor_actor]['id']
    @invoice_file = "#{Dir.pwd}/test-data/attachments/anchor_invoice.pdf"
    @erb_file = File.read("#{Dir.pwd}/test-data/erb/testbed_data.erb")
    @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
    @program_id = $conf['programs']['Invoice Financing - Vendor']
  end

  it 'Transaction : Anchor against vendor', :sanity, :email_notification, :mails do |e|
    e.run_step 'Verify Vendor is Approved in investor page' do
      anchor_program_id = 1
      vendor = verify_vendor_present(anchor_program_id, @investor_id, @vendor_name, actor: 'anchor')
      expect(vendor).not_to eq([])
      expect(vendor[:status]).to eq('Verified')
    end

    e.run_step 'Create a transaction initiated by anchor' do
      values = {
        actor: @anchor_actor,
        invoice_details: @testdata['Invoice Details'],
        invoice_file: @invoice_file,
        program_id: @program_id
      }
      resp = create_transaction(values[:actor], values[:invoice_details], values[:invoice_file], values[:program_id])
      expect([200, 201]).to include(resp[:code]), resp.to_s
      @transaction_id = resp[:body][:id]
    end

    e.run_step 'Verify transaction is in draft state' do
      @tran_resp = get_transaction_details(@transaction_id, actor: 'anchor')
      expect(@tran_resp[:body][:status]).to eq('new')
      expect(@tran_resp[:body][:initiator]).to eq('anchor')
      expect(@tran_resp[:body][:display_status]).to eq('Draft')
      expect(@tran_resp[:body][:invoice_value]).to eq(@testdata['Invoice Details']['Invoice Value'])
      expect(@tran_resp[:body][:anchor][:gstn]).to eq(@testdata['Invoice Details']['GSTN of Anchor'])
      expect(@tran_resp[:body][:vendor][:gstn]).to eq(@testdata['Invoice Details']['GSTN of Channel Partner'])
    end

    e.run_step 'Verify transaction is not shown for other anchors/vendors' do
      tran_resp = get_transaction_details(@transaction_id, actor: 'grn_anchor')
      expect(tran_resp[:code]).to eq(403)
      expect(tran_resp[:body][:error][:message]).to eq('User not authorized')
      tran_resp = get_transaction_details(@transaction_id, actor: 'grn_vendor')
      expect(tran_resp[:code]).to eq(403)
      expect(tran_resp[:body][:error][:message]).to eq('User not authorized')
    end

    e.run_step 'Verify intimation mail received on Transaction Initiation' do
      # Transaction initiation mail notification [1st Mail]
      flag = verify_mail_present(
        subject: 'Invoice(s)/Purchase Order(s) - Pending user action',
        body_content: @testdata['Invoice Details']['Invoice Number'],
        text: 'Gentle reminder to act'
      )
      expect(flag).to eq true
    end

    e.run_step 'Verify invoice image is uploaded to transaction' do
      expect(@tran_resp[:body][:documents].empty?).to eq(false)
      expect(@tran_resp[:body][:documents][0][:document_type]).to eq('invoice')
      expect(@tran_resp[:body][:documents][0][:file_name]).to eq('anchor_invoice.pdf')
      expect(@tran_resp[:body][:documents][0][:file_url].empty?).to eq(false)
      resp = request_url(@tran_resp[:body][:documents][0][:file_url])
      expect(resp.code).to eq(200)
      expect(resp.headers[:content_type]).to eq('application/pdf')
    end

    e.run_step 'Verify transaction available for Product user' do
      @tran_resp = get_transaction_details(@transaction_id, actor: 'product')
      expect(@tran_resp[:body][:status]).to eq('new')
      expect(@tran_resp[:body][:initiator]).to eq('anchor')
      expect(@tran_resp[:body][:display_status]).to eq('Draft')
      expect(@tran_resp[:body][:invoice_value]).to eq(@testdata['Invoice Details']['Invoice Value'])
      expect(@tran_resp[:body][:anchor][:gstn]).to eq(@testdata['Invoice Details']['GSTN of Anchor'])
      expect(@tran_resp[:body][:vendor][:gstn]).to eq(@testdata['Invoice Details']['GSTN of Channel Partner'])
    end

    e.run_step 'Verify document is available' do
      # @tarspect_methods.verify_links([@tran_resp[:body][:documents][:link]])
    end

    e.run_step "Verify transaction listed in 'Invoices to approve' as Product" do
      queries = { actor: 'product', category: 'pending_approval_invoices', program_group: 'invoice' }
      resp = api_transaction_listed?(queries, @transaction_id)
      expect(resp[0]).to eq(true)
    end

    e.run_step 'Approve transaction as Product' do
      rel_values = {
        actor: 'product',
        program_id: @program_id,
        transaction_id: @transaction_id,
        todo: 'approved',
        can_reinitiate: false,
        comment: 'Approved'
      }
      resp = approve_transcation(rel_values)
      expect(resp[:code]).to eq(200)
    end

    e.run_step 'Verify intimation mail received on Product(level 1) approval' do
      # Product Approval[1st] mail notification [2nd Mail]
      flag = verify_mail_present(
        subject: 'Invoice(s)/Purchase Order(s) - Pending user action',
        body_content: @testdata['Invoice Details']['Invoice Number'],
        text: 'Gentle reminder to act'
      )
      expect(flag).to eq true
    end

    e.run_step 'Verify status timeline after Product Approval' do
      @tran_resp = get_transaction_details(@transaction_id, actor: 'product')
      details_to_verify = { invoice_state: ['CA Approval'], change_date: Date.today }
      expect(status_present_in_timeline?(@tran_resp[:body][:state_changes], details_to_verify)).to eq(true)
    end

    e.run_step 'Verify transaction details in list page as Vendor' do
      queries = { actor: @vendor_actor, category: 'invoices', program_group: 'invoice' }
      result = api_transaction_listed?(queries, @transaction_id)
      expect(result[0]).to eq(true)
      tran = result[1][0]
      expect(tran[:invoice_value]).to eq(@testdata['Invoice Details']['Invoice Value'])
      expect(tran[:anchor][:gstn]).to eq(@testdata['Invoice Details']['GSTN of Anchor'])
      expect(tran[:vendor][:gstn]).to eq(@testdata['Invoice Details']['GSTN of Channel Partner'])
    end

    e.run_step 'Verify transaction is in draft state' do
      @tran_resp = get_transaction_details(@transaction_id, actor: @vendor_actor)
      expect(@tran_resp[:body][:display_status]).to eq('Draft')
      expect(@tran_resp[:body][:invoice_value]).to eq(@testdata['Invoice Details']['Invoice Value'])
      expect(@tran_resp[:body][:anchor][:gstn]).to eq(@testdata['Invoice Details']['GSTN of Anchor'])
      expect(@tran_resp[:body][:vendor][:gstn]).to eq(@testdata['Invoice Details']['GSTN of Channel Partner'])
    end

    e.run_step 'Verify invoice image is uploaded to transaction' do
      values = { document_type: 'invoice', file_name: 'anchor_invoice.pdf' }
      expect(verify_document_is_uploaded_and_valid(@tran_resp[:body], values)).to eq(true)
    end

    e.run_step "Verify transaction listed in 'Invoices to approve' as Vendor" do
      queries = { actor: @vendor_actor, category: 'pending_approval_invoices', program_group: 'invoice' }
      expect(api_transaction_listed?(queries, @transaction_id)[0]).to eq(true)
    end

    e.run_step 'Approve transaction as Vendor' do
      rel_values = {
        actor: @vendor_actor,
        program_id: @program_id,
        transaction_id: @transaction_id,
        todo: 'approved',
        can_reinitiate: false,
        comment: 'Approved'
      }
      resp = approve_transcation(rel_values)
      expect(resp[:code]).to eq(200)
    end

    e.run_step 'Verify intimation mail received on Vendor(level 2) approval' do
      # Vendor approval mail notification [3rd Mail]
      flag = verify_mail_present(
        subject: 'Invoice(s)/Purchase Order(s) - Pending user action',
        body_content: @testdata['Invoice Details']['Invoice Number'],
        text: 'Gentle reminder to act'
      )
      expect(flag).to eq true
    end

    e.run_step 'Verify status timeline after Product Approval' do
      @tran_resp = get_transaction_details(@transaction_id, actor: @vendor_actor)
      details_to_verify = { invoice_state: ['CA Approval', 'Vendor/Dealer Approval'], change_date: Date.today }
      expect(status_present_in_timeline?(@tran_resp[:body][:state_changes], details_to_verify)).to eq(true)
    end
  end

  it 'Invoice Validations' do |e|
    @create_values = {
      actor: @anchor_actor,
      invoice_details: '',
      invoice_file: @invoice_file,
      program_id: @program_id
    }

    e.run_step 'Mandatory Field Validation: Invoice Number' do
      @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
      @testdata['Invoice Details']['Invoice Number'] = ''
      @create_values[:invoice_details] = @testdata['Invoice Details']
      resp = create_transaction(@create_values[:actor], @create_values[:invoice_details], @create_values[:invoice_file], @create_values[:program_id])
      expect(resp[:code]).to eq(400)
      expect(resp[:body][:error][:message]).to eq('Invoice number is required')
    end

    e.run_step 'Mandatory Field Validation: Invoice Value' do
      @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
      @testdata['Invoice Details']['Invoice Value'] = ''
      @create_values[:invoice_details] = @testdata['Invoice Details']
      resp = create_transaction(@create_values[:actor], @create_values[:invoice_details], @create_values[:invoice_file], @create_values[:program_id])
      expect(resp[:code]).to eq(400)
      expect(resp[:body][:error][:message]).to eq('Invoice value is required and should be of type float')
    end

    e.run_step 'Mandatory Field Validation: Invoice Date' do
      @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
      @testdata['Invoice Details']['Invoice Date'] = ''
      @create_values[:invoice_details] = @testdata['Invoice Details']
      resp = create_transaction(@create_values[:actor], @create_values[:invoice_details], @create_values[:invoice_file], @create_values[:program_id])
      expect(resp[:code]).to eq(400)
      expect(resp[:body][:error][:message]).to eq('Invalid format/Parameter Missing. Expected format: yyyy-mm-dd')
    end

    e.run_step 'Mandatory Field Validation: Anchor GSTN' do
      @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
      @testdata['Invoice Details']['GSTN of Anchor'] = ''
      @create_values[:invoice_details] = @testdata['Invoice Details']
      resp = create_transaction(@create_values[:actor], @create_values[:invoice_details], @create_values[:invoice_file], @create_values[:program_id])
      expect(resp[:code]).to eq(400)
      expect(resp[:body][:error][:message]).to eq('Parameter anchor_gstn cannot be blank')
    end

    e.run_step 'Mandatory Field Validation: Wrong Anchor GSTN' do
      @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
      @testdata['Invoice Details']['GSTN of Anchor'] = '17CAPBH0940E1ZV'
      @create_values[:invoice_details] = @testdata['Invoice Details']
      resp = create_transaction(@create_values[:actor], @create_values[:invoice_details], @create_values[:invoice_file], @create_values[:program_id])
      expect(resp[:code]).to eq(422)
      expect(resp[:body][:error][:message]).to eq('GSTN not matching the logged in entity')
    end

    e.run_step 'Mandatory Field Validation: CounterParty GSTN' do
      @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
      @testdata['Invoice Details']['GSTN of Channel Partner'] = ''
      @create_values[:invoice_details] = @testdata['Invoice Details']
      resp = create_transaction(@create_values[:actor], @create_values[:invoice_details], @create_values[:invoice_file], @create_values[:program_id])
      expect(resp[:code]).to eq(400)
      expect(resp[:body][:error][:message]).to eq('Parameter vendor_gstn cannot be blank')
    end

    e.run_step 'Mandatory Field Validation: Wrong CounterParty GSTN' do
      @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
      @testdata['Invoice Details']['GSTN of Channel Partner'] = '83VENDO6090R8ZF'
      @create_values[:invoice_details] = @testdata['Invoice Details']
      resp = create_transaction(@create_values[:actor], @create_values[:invoice_details], @create_values[:invoice_file], @create_values[:program_id])
      expect(resp[:code]).to eq(422)
      expect(resp[:body][:error][:message]).to eq('Commercial not signed with Investor & Vendor under this Anchor Program')
    end
  end
end
