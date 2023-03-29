require './spec_helper'
describe 'Availibility Limit: Verification', :scf, :anchor, :available_limit do
  before(:all) do
    @program_type = 'Vendor Financing'
    @vendor_actor = 'anchor_summary_po_vendor'
    @vendor_id = $conf['users'][@vendor_actor]['id']
    @counterparty_gstn = $conf['users'][@vendor_actor]['gstn']
    @party_gstn = $conf['users']['anchor_summary_anchor']['gstn']
    @invoice_file = "#{Dir.pwd}/test-data/attachments/dealer_invoice.pdf"
    @payment_proof = "#{Dir.pwd}/test-data/attachments/payment_proof.pdf"
    @erb_file = File.read("#{Dir.pwd}/test-data/erb/testbed_data.erb")
    @current_due_date = (Date.today - $conf['vendor_tenor']).strftime('%d-%b-%Y')
    clear_all_overdues({ anchor: $conf['users']['anchor_summary_anchor']['name'], vendor: $conf['users'][@vendor_actor]['name'] })
  end

  before(:each) do
    @tarspect_methods = Common::Methods.new(@driver)
    @transactions_page = Pages::Trasactions.new(@driver)
    @common_pages = Pages::CommonMethods.new(@driver)
    @disbursement_page = Pages::Disbursement.new(@driver)
    @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
  end

  it 'Verification of Availibility Limit :: Anchor' do |e|
    e.run_step 'Verify Availibility limit before transaction' do
      @available_limit_values = {
        actor: 'anchor_summary_anchor',
        investor_id: 7,
        program_id: $conf['ui_programs'][@program_type],
        vendor_id: @vendor_id
      }
      resp = get_available_limits(@available_limit_values)
      expect(resp[:code]).to eq(200)
      @b_available_limit_hash = {
        sanction_limit: resp[:body][:available_limits][0][:sanction_limit],
        available_limit: resp[:body][:available_limits][0][:available_limit]
      }
    end

    e.run_step "Create a PO transaction (Draft -> Disbursed) with value #{@testdata['PO Details']['Requested Disbursement Value']}" do
      @testdata['PO Details']['PO Date'] = (Date.today - $conf['vendor_tenor']).strftime('%d-%b-%Y')
      @transaction_id = seed_transaction(
        {
          actor: 'anchor_summary_anchor',
          counter_party: @vendor_actor,
          po_details: @testdata['PO Details'],
          po_file: @invoice_file,
          program: 'PO Financing - Vendor',
          program_group: 'purchase_order'
        }
      )
      expect(@transaction_id).not_to include('Error while creating transaction')
      details = disburse_transaction(
        {
          transaction_id: @transaction_id,
          invoice_value: @testdata['PO Details']['Requested Disbursement Value'],
          tenor: $conf['vendor_tenor'],
          type: 'frontend',
          date_of_payment: @current_due_date,
          payment_proof: @payment_proof,
          program: 'PO Financing - Vendor'
        }
      )
      expect(details).not_to eq 'Error while disbursements'
      @transaction_values = details[0]
      @disbursement_values = details[1]
    end

    e.run_step 'Verify Available limit is updated' do
      sleep 10 # Wait for data reflection
      resp = get_available_limits(@available_limit_values)
      @a_available_limit_hash = {
        sanction_limit: resp[:body][:available_limits][0][:sanction_limit],
        available_limit: resp[:body][:available_limits][0][:available_limit]
      }
      @b_available_limit_hash[:available_limit] -= @transaction_values[0]
      expect(@b_available_limit_hash).to eq(@a_available_limit_hash)
    end
  end

  it 'Verification of Availibility Limit :: Channel Partner' do |e|
    e.run_step 'Verify Availibility limit before transaction' do
      @available_limit_values = {
        actor: @vendor_actor,
        investor_id: 7,
        program_id: $conf['ui_programs'][@program_type],
        anchor_id: 128
      }
      resp = get_available_limits(@available_limit_values)
      expect(resp[:code]).to eq(200)
      @b_available_limit_hash = {
        sanction_limit: resp[:body][:available_limits][0][:sanction_limit],
        available_limit: resp[:body][:available_limits][0][:available_limit]
      }
    end

    e.run_step "Create a PO transaction (Draft -> Disbursed) with value #{@testdata['PO Details']['Requested Disbursement Value']}" do
      @testdata['PO Details']['PO Date'] = (Date.today - $conf['vendor_tenor']).strftime('%d-%b-%Y')
      @transaction_id = seed_transaction(
        {
          actor: @vendor_actor,
          counter_party: 'anchor_summary_anchor',
          po_details: @testdata['PO Details'],
          po_file: @invoice_file,
          program: 'PO Financing - Vendor',
          program_group: 'purchase_order'
        }
      )
      expect(@transaction_id).not_to include('Error while creating transaction')
      details = disburse_transaction(
        {
          transaction_id: @transaction_id,
          invoice_value: @testdata['PO Details']['Requested Disbursement Value'],
          tenor: $conf['vendor_tenor'],
          type: 'frontend',
          date_of_payment: @current_due_date,
          payment_proof: @payment_proof,
          program: 'PO Financing - Vendor'
        }
      )
      expect(details).not_to eq 'Error while disbursements'
      @transaction_values = details[0]
      @disbursement_values = details[1]
    end

    e.run_step 'Verify Available limit is updated' do
      sleep 10 # Wait for data reflection
      resp = get_available_limits(@available_limit_values)
      @a_available_limit_hash = {
        sanction_limit: resp[:body][:available_limits][0][:sanction_limit],
        available_limit: resp[:body][:available_limits][0][:available_limit]
      }
      @b_available_limit_hash[:available_limit] -= @transaction_values[0]
      expect(@b_available_limit_hash).to eq(@a_available_limit_hash)
    end
  end
end
