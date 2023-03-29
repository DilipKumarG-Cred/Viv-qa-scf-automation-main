require './spec_helper'
describe 'Interest Calculation:', :scf, :commercials, :interest_calculation do
  before(:all) do
    @program_name = 'Invoice Financing - Vendor'
    @anchor_actor = 'interest_calc_anchor'
    @investor_actor = 'investor'
    @vendor_actor = 'interest_calc_vendor'
    @investor_id = $conf['users'][@investor_actor]['id']
    @anchor_gstn = $conf['users'][@anchor_actor]['gstn']
    @counterparty_gstn = $conf['users'][@vendor_actor]['gstn']
    @invoice_file = "#{Dir.pwd}/test-data/attachments/anchor_invoice.pdf"
    @payment_proof = "#{Dir.pwd}/test-data/attachments/payment_proof.pdf"
    @erb_file = File.read("#{Dir.pwd}/test-data/erb/testbed_data.erb")
    @update_anchor_commercial = {
      update_fields: '',
      investor_id: @investor_id,
      anchor_actor: @anchor_actor,
      program_name: 'Invoice Financing - Vendor',
      investor_actor: 'investor'
    }
    @disburse_hash = {
      transaction_id: '',
      invoice_value: '',
      type: 'frontend',
      date_of_payment: '',
      payment_proof: @payment_proof,
      program: @program_name,
      tenor: $conf['vendor_tenor'],
      yield: 12,
      strategy: 'simple_interest',
      rest: ''
    }
  end

  before(:each) do
    @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
  end

  it 'Anchor Commercials: Strategy - Simple' do |e|
    e.run_step 'Update existing anchor commercials' do
      update_fields = { interest_calculation_strategy: 'simple_interest', interest_calculation_rest: 'null' }
      @update_anchor_commercial[:update_fields] = update_fields
      resp = set_anchor_commercials(@update_anchor_commercial, action: :update)
      expect(resp[:code]).to eq(200)
    end

    e.run_step 'Create a complete transaction as Anchor(Draft -> Released)' do
      @testdata['Invoice Details']['Invoice Date'] = (Date.today - 60).strftime('%d-%b-%Y')
      @transaction_id = seed_transaction(
        {
          actor: @anchor_actor,
          counter_party: @vendor_actor,
          invoice_details: @testdata['Invoice Details'],
          invoice_file: @invoice_file,
          program: @program_name,
          program_group: 'invoice'
        }
      )
      expect(@transaction_id.to_s).not_to include('Error while creating transaction')
    end

    e.run_step 'Verify Interest Calc Strategy is calculated properly' do
      @current_due_date = Date.today.strftime('%d-%b-%Y')
      @disburse_hash.merge!(
        transaction_id: @transaction_id,
        invoice_value: @testdata['Invoice Details']['Invoice Value'],
        date_of_payment: @current_due_date,
        strategy: 'simple_interest',
        rest: ''
      )
      @details = disburse_transaction(@disburse_hash)
      expect(@details).not_to include 'Error while disbursements'
    end
  end

  it 'Anchor Commercials: Strategy - Compound Interest with Rest: Daily' do |e|
    e.run_step 'Update existing anchor commercials' do
      update_fields = {
        interest_calculation_strategy: 'compound_interest',
        interest_calculation_rest: 'daily_rest'
      }
      @update_anchor_commercial[:update_fields] = update_fields
      set_anchor_commercials(@update_anchor_commercial, action: :update)
    end

    e.run_step 'Create a complete transaction as Anchor(Draft -> Released)' do
      @testdata['Invoice Details']['Invoice Date'] = (Date.today - 60).strftime('%d-%b-%Y')
      @transaction_id = seed_transaction({
                                           actor: @anchor_actor,
                                           counter_party: @vendor_actor,
                                           invoice_details: @testdata['Invoice Details'],
                                           invoice_file: @invoice_file,
                                           program: @program_name,
                                           program_group: 'invoice'
                                         })
      expect(@transaction_id.to_s).not_to include('Error while creating transaction')
    end

    e.run_step 'Verify Interest Calc Strategy is calculated properly' do
      @current_due_date = Date.today.strftime('%d-%b-%Y')
      @disburse_hash.merge!(transaction_id: @transaction_id,
                            invoice_value: @testdata['Invoice Details']['Invoice Value'],
                            date_of_payment: @current_due_date,
                            strategy: 'compound_interest',
                            rest: 'daily')
      @details = disburse_transaction(@disburse_hash)
      expect(@details).not_to include 'Error while disbursements'
    end
  end

  it 'Anchor Commercials: Strategy - Compound Interest with Rest: Monthly' do |e|
    e.run_step 'Update existing anchor commercials' do
      update_fields = {
        interest_calculation_strategy: 'compound_interest',
        interest_calculation_rest: 'monthly_rest'
      }
      @update_anchor_commercial[:update_fields] = update_fields
      set_anchor_commercials(@update_anchor_commercial, action: :update)
    end

    e.run_step 'Create a complete transaction as Anchor(Draft -> Released)' do
      @testdata['Invoice Details']['Invoice Date'] = (Date.today - 60).strftime('%d-%b-%Y')
      @transaction_id = seed_transaction({
                                           actor: @anchor_actor,
                                           counter_party: @vendor_actor,
                                           invoice_details: @testdata['Invoice Details'],
                                           invoice_file: @invoice_file,
                                           program: @program_name,
                                           program_group: 'invoice'
                                         })
      expect(@transaction_id.to_s).not_to include('Error while creating transaction')
    end

    e.run_step 'Verify Interest Calc Strategy is calculated properly' do
      @current_due_date = Date.today.strftime('%d-%b-%Y')
      @disburse_hash.merge!(transaction_id: @transaction_id,
                            invoice_value: @testdata['Invoice Details']['Invoice Value'],
                            date_of_payment: @current_due_date,
                            strategy: 'compound_interest',
                            rest: 'monthly')
      @details = disburse_transaction(@disburse_hash)
      expect(@details).not_to include 'Error while disbursements'
    end
  end

  it 'Anchor Commercials: Strategy - Compound Interest with Rest: Quarterly' do |e|
    e.run_step 'Update existing anchor commercials' do
      update_fields = {
        interest_calculation_strategy: 'compound_interest',
        interest_calculation_rest: 'quarterly_rest'
      }
      @update_anchor_commercial[:update_fields] = update_fields
      set_anchor_commercials(@update_anchor_commercial, action: :update)
    end

    e.run_step 'Create a complete transaction as Anchor(Draft -> Released)' do
      @testdata['Invoice Details']['Invoice Date'] = (Date.today - 120).strftime('%d-%b-%Y')
      @transaction_id = seed_transaction({
                                           actor: @anchor_actor,
                                           counter_party: @vendor_actor,
                                           invoice_details: @testdata['Invoice Details'],
                                           invoice_file: @invoice_file,
                                           program: @program_name,
                                           program_group: 'invoice'
                                         })
      expect(@transaction_id.to_s).not_to include('Error while creating transaction')
    end

    e.run_step 'Verify Interest Calc Strategy is calculated properly' do
      @current_due_date = (Date.today - 120).strftime('%d-%b-%Y')
      @disburse_hash.merge!(transaction_id: @transaction_id,
                            invoice_value: @testdata['Invoice Details']['Invoice Value'],
                            date_of_payment: @current_due_date,
                            strategy: 'compound_interest',
                            rest: 'quarterly')
      @details = disburse_transaction(@disburse_hash)
      expect(@details).not_to include 'Error while disbursements'
    end
  end
end
