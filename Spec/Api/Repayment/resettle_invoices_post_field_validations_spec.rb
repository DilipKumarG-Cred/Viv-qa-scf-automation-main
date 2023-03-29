require './spec_helper'
describe 'Resettle Invoices :: post :: Field Validations', :resettle_invoices, :api_field_validations do
  # Initialization
  before(:all) do
    @common_api = Api::Pages::Common.new
    @invoice_erb = File.read("#{Dir.pwd}/Api/test-data/create_invoices.erb")
    @disbursement_erb_file = File.read("#{Dir.pwd}/Api/test-data/disburse_invoices.erb")
    @disbursement_configs = JSON.parse(ERB.new(@disbursement_erb_file).result(binding))['config']
    @resettle_invoice_erb_file = File.read("#{Dir.pwd}/Api/test-data/resettle_invoices.erb")
    @resettle_configs = JSON.parse(ERB.new(@resettle_invoice_erb_file).result(binding))['config']
    @current_module = 'resettle_invoice'
    @create_seed = true
    @hash = {
      disbursement_configs: @disbursement_configs,
      invoice_meta_data: @invoice_erb,
      disbursement_meta_data: @disbursement_erb_file,
      vendor: 'Dozco'
    }
  end

  after(:all) do
    clear_all_overdues({ anchor: @disbursement_configs['actor_user'], vendor: @disbursement_configs['counter_party_user'] })
  end

  it 'Validate Repayments :: Valid Inputs' do |e|
    e.run_step 'Resettle Invoice with all valid inputs :: expected response - 201' do
      @common_api.create_disbursed_transaction_for_api(@hash) if @create_seed
      field_payload = JSON.parse(ERB.new(@resettle_invoice_erb_file).result(binding))['resettle_invoice']
      response = @common_api.perform_post_action(@current_module, {}, field_payload, @resettle_configs)
      expect(response[:code]).to eq 200
      @create_seed = true
    end
  end

  it 'Resettle Invoice :: UTR Number :: validations' do |e| # issue
    field = 'utr_number'
    e.run_step "#{field} :: value - null :: expected response - 400" do
      @common_api.create_disbursed_transaction_for_api(@hash) if @create_seed
      field_payload = JSON.parse(ERB.new(@resettle_invoice_erb_file).result(binding))['resettle_invoice']
      response = @common_api.perform_post_action(@current_module, { field => nil }, field_payload, @resettle_configs)
      @create_seed = response[:code] == 200
      expect(response[:code]).to eq(400), response.to_s
      expect(response[:body][:error][:message]).to eq 'UTR number is required'
    end
    e.run_step "#{field} :: value - empty :: expected response - 400" do
      @common_api.create_disbursed_transaction_for_api(@hash) if @create_seed
      field_payload = JSON.parse(ERB.new(@resettle_invoice_erb_file).result(binding))['resettle_invoice']
      response = @common_api.perform_post_action(@current_module, { field => '' }, field_payload, @resettle_configs)
      @create_seed = response[:code] == 200
      expect(response[:code]).to eq(400), response.to_s
      expect(response[:body][:error][:message]).to eq 'UTR number is required'
    end
  end

  it 'Resetttle invoice :: Payment proof :: validations' do |e| # issue
    field = 'document'
    e.run_step "#{field} :: value - 'abcd' :: expected response - 400" do
      @common_api.create_disbursed_transaction_for_api(@hash) if @create_seed
      field_payload = JSON.parse(ERB.new(@resettle_invoice_erb_file).result(binding))['resettle_invoice']
      response = @common_api.perform_post_action(@current_module, { field => 'abcd' }, field_payload, @resettle_configs)
      @create_seed = response[:code] == 200
      expect(response[:code]).to eq(400), response.to_s
      expect(response[:body][:error][:message]).to eq 'Upload a valid document!'
    end
    e.run_step "#{field} :: value - 100 :: expected response - 400" do # issue
      @common_api.create_disbursed_transaction_for_api(@hash) if @create_seed
      field_payload = JSON.parse(ERB.new(@resettle_invoice_erb_file).result(binding))['resettle_invoice']
      response = @common_api.perform_post_action(@current_module, { field => 100 }, field_payload, @resettle_configs)
      @create_seed = response[:code] == 200
      expect(response[:code]).to eq(400), response.to_s
      expect(response[:body][:error][:message]).to eq 'Upload a valid document!'
    end
  end

  it 'Resetttle invoice :: payment_date :: validations' do |e|
    field = 'payment_date'
    e.run_step "#{field} :: value - null :: expected response - 400" do
      @common_api.create_disbursed_transaction_for_api(@hash) if @create_seed
      field_payload = JSON.parse(ERB.new(@resettle_invoice_erb_file).result(binding))['resettle_invoice']
      response = @common_api.perform_post_action(@current_module, { field => nil }, field_payload, @resettle_configs)
      @create_seed = response[:code] == 200
      expect(response[:code]).to eq(400), response.to_s
      expect(response[:body][:error][:message]).to eq "'' is not a valid Date"
    end
    e.run_step "#{field} :: value - empty :: expected response - 400" do
      @common_api.create_disbursed_transaction_for_api(@hash) if @create_seed
      field_payload = JSON.parse(ERB.new(@resettle_invoice_erb_file).result(binding))['resettle_invoice']
      response = @common_api.perform_post_action(@current_module, { field => '' }, field_payload, @resettle_configs)
      @create_seed = response[:code] == 200
      expect(response[:code]).to eq(400), response.to_s
      expect(response[:body][:error][:message]).to eq "'' is not a valid Date"
    end
    e.run_step "#{field} :: String value - 'abcd' :: expected response - 400" do
      test_string = 'abcd'
      @common_api.create_disbursed_transaction_for_api(@hash) if @create_seed
      field_payload = JSON.parse(ERB.new(@resettle_invoice_erb_file).result(binding))['resettle_invoice']
      response = @common_api.perform_post_action(@current_module, { field => test_string }, field_payload, @resettle_configs)
      @create_seed = response[:code] == 200
      expect(response[:code]).to eq(400), response.to_s
      expect(response[:body][:error][:message]).to eq "'abcd' is not a valid Date"
    end
    e.run_step "#{field} :: Integer value - 100 :: expected response - 400" do # issue
      test_integer = 100
      @common_api.create_disbursed_transaction_for_api(@hash) if @create_seed
      field_payload = JSON.parse(ERB.new(@resettle_invoice_erb_file).result(binding))['resettle_invoice']
      response = @common_api.perform_post_action(@current_module, { field => test_integer }, field_payload, @resettle_configs)
      @create_seed = response[:code] == 200
      expect(response[:code]).to eq(422), response.to_s
      expect(response[:body][:error][:message]).to include 'Payment date greater than '
    end
    e.run_step "#{field} :: Float value - 5000.25 :: expected response - 400" do
      test_float = 5000.25
      @common_api.create_disbursed_transaction_for_api(@hash) if @create_seed
      field_payload = JSON.parse(ERB.new(@resettle_invoice_erb_file).result(binding))['resettle_invoice']
      response = @common_api.perform_post_action(@current_module, { field => test_float }, field_payload, @resettle_configs)
      @create_seed = response[:code] == 200
      expect(response[:code]).to eq(400), response.to_s
      expect(response[:body][:error][:message]).to eq "'5000.25' is not a valid Date"
    end
    e.run_step "#{field} :: Different date format - dd-mm-yyyy :: expected response - 400" do
      test_date = Date.today.strftime('dd-mm-yyyy')
      @common_api.create_disbursed_transaction_for_api(@hash) if @create_seed
      field_payload = JSON.parse(ERB.new(@resettle_invoice_erb_file).result(binding))['resettle_invoice']
      response = @common_api.perform_post_action(@current_module, { field => test_date }, field_payload, @resettle_configs)
      @create_seed = response[:code] == 200
      expect(response[:code]).to eq(400), response.to_s
      expect(response[:body][:error][:message]).to eq "'dd-mm-yyyy' is not a valid Date"
    end
  end

  it 'Resetttle invoice :: Amount :: validations' do |e|
    field = 'amount'
    e.run_step "#{field} :: value - null :: expected response - 400" do
      @common_api.create_disbursed_transaction_for_api(@hash) if @create_seed
      field_payload = JSON.parse(ERB.new(@resettle_invoice_erb_file).result(binding))['resettle_invoice']
      response = @common_api.perform_post_action(@current_module, { field => nil }, field_payload, @resettle_configs)
      @create_seed = response[:code] == 200
      expect(response[:code]).to eq(400), response.to_s
      expect(response[:body][:error][:message]).to eq "'' is not a valid Float"
    end
    e.run_step "#{field} :: value - empty :: expected response - 400" do
      @common_api.create_disbursed_transaction_for_api(@hash) if @create_seed
      field_payload = JSON.parse(ERB.new(@resettle_invoice_erb_file).result(binding))['resettle_invoice']
      response = @common_api.perform_post_action(@current_module, { field => '' }, field_payload, @resettle_configs)
      @create_seed = response[:code] == 200
      expect(response[:code]).to eq(400), response.to_s
      expect(response[:body][:error][:message]).to eq "'' is not a valid Float"
    end
    e.run_step "#{field} :: String value - 'abcd' :: expected response - 400" do
      test_string = 'abcd'
      @common_api.create_disbursed_transaction_for_api(@hash) if @create_seed
      field_payload = JSON.parse(ERB.new(@resettle_invoice_erb_file).result(binding))['resettle_invoice']
      response = @common_api.perform_post_action(@current_module, { field => test_string }, field_payload, @resettle_configs)
      @create_seed = response[:code] == 200
      expect(response[:code]).to eq(400), response.to_s
      expect(response[:body][:error][:message]).to eq "'abcd' is not a valid Float"
    end
  end

  it 'Resettle Invioce :: investor_id :: validations' do |e|
    field = 'investor_id'
    e.run_step "#{field} :: value - null :: expected response - 400" do
      @common_api.create_disbursed_transaction_for_api(@hash) if @create_seed
      field_payload = JSON.parse(ERB.new(@resettle_invoice_erb_file).result(binding))['resettle_invoice']
      response = @common_api.perform_post_action(@current_module, { field => nil }, field_payload, @resettle_configs)
      @create_seed = response[:code] == 200
      expect(response[:code]).to eq(400), response.to_s
      expect(response[:body][:error][:message]).to eq "'' is not a valid Integer"
    end
    e.run_step "#{field} :: value - empty :: expected response - 400" do
      @common_api.create_disbursed_transaction_for_api(@hash) if @create_seed
      field_payload = JSON.parse(ERB.new(@resettle_invoice_erb_file).result(binding))['resettle_invoice']
      response = @common_api.perform_post_action(@current_module, { field => '' }, field_payload, @resettle_configs)
      @create_seed = response[:code] == 200
      expect(response[:code]).to eq(400), response.to_s
      expect(response[:body][:error][:message]).to eq "'' is not a valid Integer"
    end
    e.run_step "#{field} :: String value - 'abcd' :: expected response - 400" do
      test_string = 'abcd'
      @common_api.create_disbursed_transaction_for_api(@hash) if @create_seed
      field_payload = JSON.parse(ERB.new(@resettle_invoice_erb_file).result(binding))['resettle_invoice']
      response = @common_api.perform_post_action(@current_module, { field => test_string }, field_payload, @resettle_configs)
      @create_seed = response[:code] == 200
      expect(response[:code]).to eq(400), response.to_s
      expect(response[:body][:error][:message]).to eq "'abcd' is not a valid Integer"
    end
    e.run_step "#{field} :: Float value - 5000.25 :: expected response - 400" do
      test_float = 5000.25
      @common_api.create_disbursed_transaction_for_api(@hash) if @create_seed
      field_payload = JSON.parse(ERB.new(@resettle_invoice_erb_file).result(binding))['resettle_invoice']
      response = @common_api.perform_post_action(@current_module, { field => test_float }, field_payload, @resettle_configs)
      @create_seed = response[:code] == 200
      expect(response[:code]).to eq(400), response.to_s
      expect(response[:body][:error][:message]).to eq "'5000.25' is not a valid Integer"
    end
    e.run_step "#{field} :: Wrong Investor ID - 100 :: expected response - 500" do
      wrong_investor = 100
      @common_api.create_disbursed_transaction_for_api(@hash) if @create_seed
      field_payload = JSON.parse(ERB.new(@resettle_invoice_erb_file).result(binding))['resettle_invoice']
      response = @common_api.perform_post_action(@current_module, { field => wrong_investor }, field_payload, @resettle_configs)
      @create_seed = response[:code] == 200
      expect(response[:code]).to eq 500
      expect(response[:body][:error][:message]).to eq "Couldn't find Investor with 'id'=100"
    end
  end

  it 'Resettle Invioce :: anchor_id :: validations' do |e|
    field = 'anchor_id'
    e.run_step "#{field} :: value - null :: expected response - 400" do
      @common_api.create_disbursed_transaction_for_api(@hash) if @create_seed
      field_payload = JSON.parse(ERB.new(@resettle_invoice_erb_file).result(binding))['resettle_invoice']
      response = @common_api.perform_post_action(@current_module, { field => nil }, field_payload, @resettle_configs)
      @create_seed = response[:code] == 200
      expect(response[:code]).to eq(400), response.to_s
      expect(response[:body][:error][:message]).to eq "'' is not a valid Integer"
    end
    e.run_step "#{field} :: value - empty :: expected response - 400" do
      @common_api.create_disbursed_transaction_for_api(@hash) if @create_seed
      field_payload = JSON.parse(ERB.new(@resettle_invoice_erb_file).result(binding))['resettle_invoice']
      response = @common_api.perform_post_action(@current_module, { field => '' }, field_payload, @resettle_configs)
      @create_seed = response[:code] == 200
      expect(response[:code]).to eq(400), response.to_s
      expect(response[:body][:error][:message]).to eq "'' is not a valid Integer"
    end
    e.run_step "#{field} :: String value - 'abcd' :: expected response - 400" do
      test_string = 'abcd'
      @common_api.create_disbursed_transaction_for_api(@hash) if @create_seed
      field_payload = JSON.parse(ERB.new(@resettle_invoice_erb_file).result(binding))['resettle_invoice']
      response = @common_api.perform_post_action(@current_module, { field => test_string }, field_payload, @resettle_configs)
      @create_seed = response[:code] == 200
      expect(response[:code]).to eq(400), response.to_s
      expect(response[:body][:error][:message]).to eq "'abcd' is not a valid Integer"
    end
    e.run_step "#{field} :: Float value - 5000.25 :: expected response - 400" do
      test_float = 5000.25
      @common_api.create_disbursed_transaction_for_api(@hash) if @create_seed
      field_payload = JSON.parse(ERB.new(@resettle_invoice_erb_file).result(binding))['resettle_invoice']
      response = @common_api.perform_post_action(@current_module, { field => test_float }, field_payload, @resettle_configs)
      @create_seed = response[:code] == 200
      expect(response[:code]).to eq(400), response.to_s
      expect(response[:body][:error][:message]).to eq "'5000.25' is not a valid Integer"
    end
    e.run_step "#{field} :: Wrong Anchor ID - 100 :: expected response - 422" do
      wrong_anchor = 100
      @common_api.create_disbursed_transaction_for_api(@hash) if @create_seed
      field_payload = JSON.parse(ERB.new(@resettle_invoice_erb_file).result(binding))['resettle_invoice']
      response = @common_api.perform_post_action(@current_module, { field => wrong_anchor }, field_payload, @resettle_configs)
      @create_seed = response[:code] == 200
      expect(response[:code]).to eq(422), response.to_s
      expect(response[:body][:error][:message]).to eq 'Repayment Transactions are not present in the system'
    end
  end
end
