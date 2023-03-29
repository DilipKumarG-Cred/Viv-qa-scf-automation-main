require './spec_helper'
describe 'MCLR RLLR: Verification', :scf, :commercials, :mclr_rllr do
  before(:all) do
    # Configs
    @investor_admin = 'mclr_investor'
    @vendor_actor = 'anchor_summary_po_dealer'
    @anchor_actor = 'anchor_summary_anchor'
    @investor_id = $conf['users'][@investor_admin]['id']
    @anchor_id = $conf['users'][@anchor_actor]['id']
    @anchor_name = $conf['users'][@anchor_actor]['name']
    @anchor_gstn = $conf['users'][@anchor_actor]['gstn']
    @party_gstn = @anchor_gstn
    @vendor_id = $conf['users'][@vendor_actor]['id']
    @counterparty_gstn = $conf['users'][@vendor_actor]['gstn']
    # Documents
    @payment_proof = "#{Dir.pwd}/test-data/attachments/payment_proof.pdf"
    @invoice_file = "#{Dir.pwd}/test-data/attachments/anchor_invoice.pdf"
    # ERB Files
    @erb_file = File.read("#{Dir.pwd}/test-data/erb/testbed_data.erb")
    # Test data
    @po_details = JSON.parse(ERB.new(@erb_file).result(binding))['PO Details']
    @program = 'PO Financing - Dealer'

    @program_terms = {
      preferences_type: 'program_terms',
      interest_calculation_rest: 'daily_rest',
      interest_calculation_strategy: 'simple_interest',
      interest_type: 'floating_interest',
      mclr: 9,
      rllr: 10,
      mclr_effective_from: '2022-01-11',
      rllr_effective_from: '2022-01-11',
      investor_actor: @investor_admin,
      investor_id: @investor_id
    }
  end

  before(:each) do
    clear_all_overdues({ anchor: @anchor_name, vendor: $conf['users']['anchor_summary_po_dealer']['name'] })
    clear_all_overdues({ anchor: @anchor_name, vendor: $conf['users']['anchor_summary_vendor']['name'] })
    delete_investor_floating_rates(@investor_admin, @investor_id)
    @driver = Tarspect::Browser.new($conf['browser']).invoke
    @commercials_page = Pages::Commercials.new(@driver)
    @tarspect_methods = Common::Methods.new(@driver)
    @transactions_page = Pages::Trasactions.new(@driver)
    @common_pages = Pages::CommonMethods.new(@driver)
    @investor_page = Pages::Investor.new(@driver)
    @disbursement_page = Pages::Disbursement.new(@driver)
  end

  after(:each) do |e|
    snap_screenshot(e)
    quit_browser
  end

  it 'MCLR :: Verification' do |e|
    @pricing = 10 # configured existing pricing
    e.run_step 'Verify floating rates can be set with new values' do
      effective_from = (Date.today - 60).strftime('%Y-%m-%d')
      @program_terms.merge!(mclr: 10, rllr: 11, mclr_effective_from: effective_from, rllr_effective_from: effective_from)
      resp = update_investor_profile(@program_terms)
      expect(resp[:code]).to eq(200)
      effective_from = (Date.today - 30).strftime('%Y-%m-%d')
      @program_terms.merge!(mclr: 11, rllr: 12, mclr_effective_from: effective_from, rllr_effective_from: effective_from)
      resp = update_investor_profile(@program_terms)
      expect(resp[:code]).to eq(200)
    end

    e.run_step 'Login as Investor ADMIN' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users'][@investor_admin]['email'], $conf['users'][@investor_admin]['password'])).to be true
    end

    e.run_step 'Verify new rates are displayed in Vendor Commercials' do
      @investor_page.go_to_program(anchor: @anchor_name, program: 'Vendor Financing')
      @transactions_page.select_vendor('West WildStone AS')
      exp_hash = {
        mclr: 'MCLR (11.0%)',
        rllr: 'RLLR (12.0%)'
      }
      hash = @investor_page.get_vendor_commercial_values
      expect(exp_hash).to eq(hash)
    end

    e.run_step 'Verify transaction disbursed with old pricing rates for existing transaction' do
      @po_details['PO Date'] = (Date.today - 60).strftime('%d-%b-%Y')
      @transaction_id = seed_transaction(
        {
          actor: @anchor_actor,
          counter_party: @vendor_actor,
          po_details: @po_details,
          po_file: @invoice_file,
          program: 'PO Financing - Dealer',
          investor_id: @investor_id,
          program_group: 'purchase_order'
        }
      )
      expect(@transaction_id).not_to include('Error while creating transaction')
      @details = disburse_transaction(
        {
          transaction_id: @transaction_id,
          invoice_value: @po_details['Requested Disbursement Value'],
          type: 'frontend',
          date_of_payment: @po_details['PO Date'],
          payment_proof: @payment_proof,
          program: 'PO Financing - Dealer',
          yield: @pricing,
          investor_actor: @investor_admin,
          strategy: 'simple_interest',
          rest: 'daily'
        }
      )
      expect(@details).not_to include('Error while disbursements')
    end

    e.run_step 'Verify repayment outstanding is calculated according to pricing' do
      tran_resp = get_po_details(@transaction_id)
      @total_outstanding = tran_resp[:body][:total_outstanding]
      @principal_outstanding = tran_resp[:body][:principal_outstanding]
      @interest_outstanding = tran_resp[:body][:interest_outstanding]
      @expected = calculate_transaction_values(
        {
          invoice_value: @po_details['Requested Disbursement Value'],
          margin: $conf['margin'],
          yield: @pricing,
          tenor: 60,
          type: 'rearend',
          strategy: 'compound_interest',
          rest: 'daily'
        }
      )
      total_outstanding = rounded_half_down_value(@total_outstanding - (@expected[0] + @expected[2]))
      expect(@principal_outstanding).to eq(@expected[0]), 'Principal outstanding is calculated wrong'
      expect(total_outstanding).to be <= (0.01), 'Total outstanding is calculated wrong'
      expect(rounded_half_down_value(@interest_outstanding - @expected[2])).to be <= (0.01), 'Interest outstanding is calculated wrong'
    end
  end

  it 'RLLR :: Verification' do |e|
    e.run_step 'Verify floating rates can be set with new values' do
      effective_from = (Date.today - 60).strftime('%Y-%m-%d')
      @program_terms.merge!(mclr: 10, rllr: 11, mclr_effective_from: effective_from, rllr_effective_from: effective_from)
      resp = update_investor_profile(@program_terms)
      expect(resp[:code]).to eq(200)
      effective_from = (Date.today - 30).strftime('%Y-%m-%d')
      @program_terms.merge!(mclr: 11, rllr: 12, mclr_effective_from: effective_from, rllr_effective_from: effective_from)
      resp = update_investor_profile(@program_terms)
      expect(resp[:code]).to eq(200)
    end

    e.run_step 'Login as Investor ADMIN' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users'][@investor_admin]['email'], $conf['users'][@investor_admin]['password'])).to be true
    end

    e.run_step 'Verify new rates are displayed in Vendor Commercials' do
      @program = 'Dealer Financing'
      @investor_page.go_to_program(anchor: @anchor_name, program: @program)
      @transactions_page.select_vendor('South Deals AS')
      exp_hash = {
        mclr: 'MCLR (11.0%)',
        rllr: 'RLLR (12.0%)'
      }
      hash = @investor_page.get_vendor_commercial_values
      expect(exp_hash).to eq(hash)
    end

    e.run_step 'Verify transaction disbursed with new and old pricing rates for existing commercials' do
      @invoice_details = JSON.parse(ERB.new(@erb_file).result(binding))['Vendor Invoice Details']
      @pricing = 13
      @vendor_actor = 'anchor_summary_vendor'
      @invoice_details['Invoice Date'] = (Date.today - 60).strftime('%d-%b-%Y')
      @invoice_details['GSTN of Channel Partner'] = $conf['users'][@vendor_actor]['gstn']
      @invoice_details['GSTN of Anchor'] = $conf['users'][@anchor_actor]['gstn']
      @transaction_id = seed_transaction(
        {
          actor: @anchor_actor,
          counter_party: @vendor_actor,
          invoice_details: @invoice_details,
          invoice_file: @invoice_file,
          program: 'Invoice Financing - Vendor',
          investor_id: @investor_id,
          program_group: 'invoice'
        }
      )
      expect(@transaction_id).not_to include('Error while creating transaction')
      @details = disburse_transaction(
        {
          transaction_id: @transaction_id,
          invoice_value: @invoice_details['Invoice Value'],
          type: 'rearend',
          date_of_payment: @invoice_details['Invoice Date'],
          payment_proof: @payment_proof,
          program: 'Invoice Financing - Vendor',
          yield: @pricing,
          investor_actor: @investor_admin,
          strategy: 'compound_interest',
          rest: 'daily'
        }
      )
      expect(@details).not_to include('Error while disbursements')
    end

    e.run_step 'Verify repayment outstanding is calculated according to pricing' do
      tran_resp = get_transaction_details(@transaction_id)
      @total_outstanding = tran_resp[:body][:total_outstanding]
      @principal_outstanding = tran_resp[:body][:principal_outstanding]
      @interest_outstanding = tran_resp[:body][:interest_outstanding]
      @first_expected = calculate_transaction_values(
        {
          invoice_value: @invoice_details['Invoice Value'],
          margin: $conf['margin'],
          yield: 12,
          tenor: 29,
          type: 'rearend',
          strategy: 'compound_interest',
          rest: 'daily'
        },
        formatted: false
      )
      @second_expected = calculate_transaction_values(
        {
          invoice_value: @invoice_details['Invoice Value'],
          margin: $conf['margin'],
          yield: 13,
          tenor: 31,
          type: 'rearend',
          strategy: 'compound_interest',
          rest: 'daily'
        },
        formatted: false
      )
      @exp_interest_outstanding = @first_expected[2] + @second_expected[2]
      total_outstanding = @total_outstanding - (@second_expected[0] + @exp_interest_outstanding)
      expect(@principal_outstanding).to eq(@second_expected[0]), 'Principal outstanding is calculated wrong'
      expect(@interest_outstanding - @exp_interest_outstanding).to be <= (0.01), "Interest outstanding is calculated wrong, #{@interest_outstanding} <> #{@exp_interest_outstanding}"
      expect(total_outstanding).to be <= (0.01), 'Total outstanding is calculated wrong'
    end
  end
end
