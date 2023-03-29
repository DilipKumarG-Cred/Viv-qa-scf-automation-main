require './spec_helper'
describe 'Disburse Invoices :: post :: Field Validations', :disburse_invoices, :api_field_validations do
  # Initialization
  before(:all) do
    @common_api = Api::Pages::Common.new
    @invoice_erb = File.read("#{Dir.pwd}/Api/test-data/create_invoices.erb")
    @disbursement_erb_file = File.read("#{Dir.pwd}/Api/test-data/disburse_invoices.erb")
    @configs = JSON.parse(ERB.new(@disbursement_erb_file).result(binding))['config']
    @current_module = 'disburse_invoice'
    @create_txn = true
    @transactions_ids = []
    @hash = {
      configs: @configs,
      invoice_meta_data: @invoice_erb,
      vendor: 'Dozco'
    }
  end

  it 'Validate Disbursements :: Valid Inputs' do |e|
    e.run_step 'Disburse Invoice with all valid inputs :: expected response - 201' do
      @transactions_ids = @common_api.create_transactions_for_api(@hash)
      field_payload = JSON.parse(ERB.new(@disbursement_erb_file).result(binding))['disburse']
      field_payload.merge!('transaction_ids' => @transactions_ids)
      response = @common_api.perform_post_action(@current_module, {}, field_payload, @configs)
      expect(response[:code]).to eq(200), response.to_s
      @create_txn = true
    end
  end

  it 'Disburse Invoice :: UTR Number :: validations' do |e| # issue
    field = 'utr_number'
    e.run_step "#{field} :: value - null :: expected response - 400" do
      field_payload = JSON.parse(ERB.new(@disbursement_erb_file).result(binding))['disburse']
      if @create_txn == true
        @transactions_ids = @common_api.create_transactions_for_api(@hash)
        @create_txn = false
      end
      field_payload.merge!('transaction_ids' => @transactions_ids)
      response = @common_api.perform_post_action(@current_module, { field => nil }, field_payload, @configs)
      @create_txn = true if response[:code] == 200
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq 'UTR number is required'
    end
    e.run_step "#{field} :: value - empty :: expected response - 400" do
      field_payload = JSON.parse(ERB.new(@disbursement_erb_file).result(binding))['disburse']
      if @create_txn == true
        @transactions_ids = @common_api.create_transactions_for_api(@hash)
        @create_txn = false
      end
      field_payload.merge!('transaction_ids' => @transactions_ids)
      response = @common_api.perform_post_action(@current_module, { field => '' }, field_payload, @configs)
      @create_txn = true if response[:code] == 200
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq 'UTR number is required'
    end
  end

  it 'Disburse Invoice :: Payment proof :: validations' do |e|
    field = 'document'
    e.run_step "#{field} :: value - 'abcd' :: expected response - 400" do # issue
      field_payload = JSON.parse(ERB.new(@disbursement_erb_file).result(binding))['disburse']
      if @create_txn == true
        @transactions_ids = @common_api.create_transactions_for_api(@hash)
        @create_txn = false
      end
      field_payload.merge!('transaction_ids' => @transactions_ids)
      response = @common_api.perform_post_action(@current_module, { field => 'abcd' }, field_payload, @configs)
      @create_txn = true if response[:code] == 200
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq 'Upload a valid document!'
    end
  end

  it 'Disburse Invioce :: payment_date :: validations' do |e|
    field = 'payment_date'
    e.run_step "#{field} :: value - null :: expected response - 400" do
      field_payload = JSON.parse(ERB.new(@disbursement_erb_file).result(binding))['disburse']
      if @create_txn == true
        @transactions_ids = @common_api.create_transactions_for_api(@hash)
        @create_txn = false
      end
      field_payload.merge!('transaction_ids' => @transactions_ids)
      response = @common_api.perform_post_action(@current_module, { field => nil }, field_payload, @configs)
      @create_txn = true if response[:code] == 200
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq "'' is not a valid Date"
    end
    e.run_step "#{field} :: value - empty :: expected response - 400" do
      field_payload = JSON.parse(ERB.new(@disbursement_erb_file).result(binding))['disburse']
      if @create_txn == true
        @transactions_ids = @common_api.create_transactions_for_api(@hash)
        @create_txn = false
      end
      field_payload.merge!('transaction_ids' => @transactions_ids)
      response = @common_api.perform_post_action(@current_module, { field => '' }, field_payload, @configs)
      @create_txn = true if response[:code] == 200
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq "'' is not a valid Date"
    end
    e.run_step "#{field} :: String value - 'abcd' :: expected response - 400" do
      test_string = 'abcd'
      field_payload = JSON.parse(ERB.new(@disbursement_erb_file).result(binding))['disburse']
      if @create_txn == true
        @transactions_ids = @common_api.create_transactions_for_api(@hash)
        @create_txn = false
      end
      field_payload.merge!('transaction_ids' => @transactions_ids)
      response = @common_api.perform_post_action(@current_module, { field => test_string }, field_payload, @configs)
      @create_txn = true if response[:code] == 200
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq 'Invalid format/Parameter Missing. Expected format: yyyy-mm-dd'
    end
    # e.run_step "#{field} :: Integer value - 100 :: expected response - 400" do #issue
    #   test_integer = 100
    #   field_payload = JSON.parse(ERB.new(@disbursement_erb_file).result(binding))['disburse']
    #   if @create_txn == true
    #     @transactions_ids = @common_api.create_transactions_for_api(@hash)
    #     @create_txn = false
    #   end
    #   field_payload.merge!('transaction_ids' => @transactions_ids)
    #   response = @common_api.perform_post_action(@current_module, { field => test_integer }, field_payload, @configs)
    #   @create_txn = true if response[:code] == 200
    #   expect(response[:code]).to eq 400
    #   expect(response[:body][:error][:message]).to eq "Invalid format/Parameter Missing. Expected format: yyyy-mm-dd"
    # end
    e.run_step "#{field} :: Float value - 5000.25 :: expected response - 400" do
      test_float = 5000.25
      field_payload = JSON.parse(ERB.new(@disbursement_erb_file).result(binding))['disburse']
      if @create_txn == true
        @transactions_ids = @common_api.create_transactions_for_api(@hash)
        @create_txn = false
      end
      field_payload.merge!('transaction_ids' => @transactions_ids)
      response = @common_api.perform_post_action(@current_module, { field => test_float }, field_payload, @configs)
      @create_txn = true if response[:code] == 200
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq 'Invalid format/Parameter Missing. Expected format: yyyy-mm-dd'
    end
    e.run_step "#{field} :: Different date format - dd-mm-yyyy :: expected response - 400" do
      test_date = Date.today.strftime('dd-mm-yyyy')
      field_payload = JSON.parse(ERB.new(@disbursement_erb_file).result(binding))['disburse']
      if @create_txn == true
        @transactions_ids = @common_api.create_transactions_for_api(@hash)
        @create_txn = false
      end
      field_payload.merge!('transaction_ids' => @transactions_ids)
      response = @common_api.perform_post_action(@current_module, { field => test_date }, field_payload, @configs)
      @create_txn = true if response[:code] == 200
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq 'Invalid format/Parameter Missing. Expected format: yyyy-mm-dd'
    end
  end

  it 'Disburse Invoice :: Disbursement amount :: validations' do |e|
    field = 'amount'
    e.run_step "#{field} :: value - null :: expected response - 400" do
      field_payload = JSON.parse(ERB.new(@disbursement_erb_file).result(binding))['disburse']
      if @create_txn == true
        @transactions_ids = @common_api.create_transactions_for_api(@hash)
        @create_txn = false
      end
      field_payload.merge!('transaction_ids' => @transactions_ids)
      response = @common_api.perform_post_action(@current_module, { field => nil }, field_payload, @configs)
      @create_txn = true if response[:code] == 200
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq "'' is not a valid Float"
    end
    e.run_step "#{field} :: value - empty :: expected response - 400" do
      field_payload = JSON.parse(ERB.new(@disbursement_erb_file).result(binding))['disburse']
      if @create_txn == true
        @transactions_ids = @common_api.create_transactions_for_api(@hash)
        @create_txn = false
      end
      field_payload.merge!('transaction_ids' => @transactions_ids)
      response = @common_api.perform_post_action(@current_module, { field => '' }, field_payload, @configs)
      @create_txn = true if response[:code] == 200
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq "'' is not a valid Float"
    end
    e.run_step "#{field} :: String value - 'abcd' :: expected response - 400" do
      test_string = 'abcd'
      field_payload = JSON.parse(ERB.new(@disbursement_erb_file).result(binding))['disburse']
      if @create_txn == true
        @transactions_ids = @common_api.create_transactions_for_api(@hash)
        @create_txn = false
      end
      field_payload.merge!('transaction_ids' => @transactions_ids)
      response = @common_api.perform_post_action(@current_module, { field => test_string }, field_payload, @configs)
      @create_txn = true if response[:code] == 200
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq "'abcd' is not a valid Float"
    end
    e.run_step "#{field} :: Less than actual value - 100 :: expected response - 422" do
      test_integer = 100
      field_payload = JSON.parse(ERB.new(@disbursement_erb_file).result(binding))['disburse']
      if @create_txn == true
        @transactions_ids = @common_api.create_transactions_for_api(@hash)
        @create_txn = false
      end
      field_payload.merge!('transaction_ids' => @transactions_ids)
      response = @common_api.perform_post_action(@current_module, { field => test_integer }, field_payload, @configs)
      @create_txn = true if response[:code] == 200
      expect(response[:code]).to eq 422
      expect(response[:body][:error][:message]).to eq "The disbursement amount provided is not matching the system's calculated amount. Please provide a valid reason/proof for the mismatch."
    end
    e.run_step "#{field} :: Greater than than actual value - 100 :: expected response - 422" do
      field_payload = JSON.parse(ERB.new(@disbursement_erb_file).result(binding))['disburse']
      if @create_txn == true
        @transactions_ids = @common_api.create_transactions_for_api(@hash)
        @create_txn = false
      end
      field_payload.merge!('transaction_ids' => @transactions_ids)
      test_integer = field_payload['amount'] + 10000
      response = @common_api.perform_post_action(@current_module, { field => test_integer }, field_payload, @configs)
      @create_txn = true if response[:code] == 200
      expect(response[:code]).to eq 422
      expect(response[:body][:error][:message]).to eq "The disbursement amount provided is not matching the system's calculated amount. Please provide a valid reason/proof for the mismatch."
    end
  end

  it 'Disburse Invoice :: Disbursement account number :: validations' do |e| # issue
    field = 'disbursement_account_number'
    e.run_step "#{field} :: value - null :: expected response - 400" do
      field_payload = JSON.parse(ERB.new(@disbursement_erb_file).result(binding))['disburse']
      if @create_txn == true
        @transactions_ids = @common_api.create_transactions_for_api(@hash)
        @create_txn = false
      end
      field_payload.merge!('transaction_ids' => @transactions_ids)
      response = @common_api.perform_post_action(@current_module, { field => nil }, field_payload, @configs)
      @create_txn = true if response[:code] == 200
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq 'Parameter disbursement_account_number cannot be blank'
    end
    e.run_step "#{field} :: value - empty :: expected response - 400" do
      field_payload = JSON.parse(ERB.new(@disbursement_erb_file).result(binding))['disburse']
      if @create_txn == true
        @transactions_ids = @common_api.create_transactions_for_api(@hash)
        @create_txn = false
      end
      field_payload.merge!('transaction_ids' => @transactions_ids)
      response = @common_api.perform_post_action(@current_module, { field => '' }, field_payload, @configs)
      @create_txn = true if response[:code] == 200
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq 'Parameter disbursement_account_number cannot be blank'
    end
    e.run_step "#{field} :: Float value - 5000.25 :: expected response - 400" do
      test_float = 5000.25
      field_payload = JSON.parse(ERB.new(@disbursement_erb_file).result(binding))['disburse']
      if @create_txn == true
        @transactions_ids = @common_api.create_transactions_for_api(@hash)
        @create_txn = false
      end
      field_payload.merge!('transaction_ids' => @transactions_ids)
      response = @common_api.perform_post_action(@current_module, { field => test_float }, field_payload, @configs)
      @create_txn = true if response[:code] == 200
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq 'Parameter disbursement_account_number must match format (?-mix:\\A[a-zA-Z0-9]*\\z)'
    end
  end

  it 'Disburse Invoice :: invoice_transaction_ids :: validations' do |e|
    field = 'invoice_transaction_ids'
    e.run_step "#{field} :: value - null :: expected response - 400" do
      field_payload = JSON.parse(ERB.new(@disbursement_erb_file).result(binding))['disburse']
      if @create_txn == true
        @transactions_ids = @common_api.create_transactions_for_api(@hash)
        @create_txn = false
      end
      field_payload.merge!('transaction_ids' => @transactions_ids)
      field_payload.delete('anchor_id')
      field_payload.delete('vendor_id')
      field_payload.delete('program_id')
      response = @common_api.perform_post_action(@current_module, { field => nil }, field_payload, @configs)
      @create_txn = true if response[:code] == 200
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq "'' is not a valid Integer"
    end
    e.run_step "#{field} :: value - empty :: expected response - 400" do
      field_payload = JSON.parse(ERB.new(@disbursement_erb_file).result(binding))['disburse']
      if @create_txn == true
        @transactions_ids = @common_api.create_transactions_for_api(@hash)
        @create_txn = false
      end
      field_payload.merge!('transaction_ids' => @transactions_ids)
      field_payload.delete('anchor_id')
      field_payload.delete('vendor_id')
      field_payload.delete('program_id')
      response = @common_api.perform_post_action(@current_module, { field => '' }, field_payload, @configs)
      @create_txn = true if response[:code] == 200
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq "'' is not a valid Integer"
    end
    e.run_step "#{field} :: String value - 'abcd' :: expected response - 400" do
      test_string = 'abcd'
      field_payload = JSON.parse(ERB.new(@disbursement_erb_file).result(binding))['disburse']
      if @create_txn == true
        @transactions_ids = @common_api.create_transactions_for_api(@hash)
        @create_txn = false
      end
      field_payload.merge!('transaction_ids' => @transactions_ids)
      response = @common_api.perform_post_action(@current_module, { field => test_string }, field_payload, @configs)
      @create_txn = true if response[:code] == 200
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq "'abcd' is not a valid Integer"
    end
    e.run_step "#{field} :: Float value - 5000.25 :: expected response - 400" do
      test_float = 5000.25
      field_payload = JSON.parse(ERB.new(@disbursement_erb_file).result(binding))['disburse']
      if @create_txn == true
        @transactions_ids = @common_api.create_transactions_for_api(@hash)
        @create_txn = false
      end
      field_payload.merge!('transaction_ids' => @transactions_ids)
      response = @common_api.perform_post_action(@current_module, { field => test_float }, field_payload, @configs)
      @create_txn = true if response[:code] == 200
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq "'5000.25' is not a valid Integer"
    end
  end

  # anchor_id, vendor_id, program_id combinations
  it 'Disburse Invoice :: anchor_id :: validations' do |e|
    field = 'anchor_id'
    e.run_step "#{field} :: value - null :: expected response - 400" do
      field_payload = JSON.parse(ERB.new(@disbursement_erb_file).result(binding))['disburse']
      if @create_txn == true
        @transactions_ids = @common_api.create_transactions_for_api(@hash)
        @create_txn = false
      end
      field_payload.merge!('transaction_ids' => @transactions_ids)
      response = @common_api.perform_post_action(@current_module, { field => nil, 'invoice_transaction_ids' => [] }, field_payload, @configs)
      @create_txn = true if response[:code] == 200
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq "'' is not a valid Integer"
    end
    e.run_step "#{field} :: value - empty :: expected response - 400" do
      field_payload = JSON.parse(ERB.new(@disbursement_erb_file).result(binding))['disburse']
      if @create_txn == true
        @transactions_ids = @common_api.create_transactions_for_api(@hash)
        @create_txn = false
      end
      field_payload.merge!('transaction_ids' => @transactions_ids)
      response = @common_api.perform_post_action(@current_module, { field => '', 'invoice_transaction_ids' => [] }, field_payload, @configs)
      @create_txn = true if response[:code] == 200
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq "'' is not a valid Integer"
    end
    e.run_step "#{field} :: String value - 'abcd' :: expected response - 400" do
      test_string = 'abcd'
      field_payload = JSON.parse(ERB.new(@disbursement_erb_file).result(binding))['disburse']
      if @create_txn == true
        @transactions_ids = @common_api.create_transactions_for_api(@hash)
        @create_txn = false
      end
      field_payload.merge!('transaction_ids' => @transactions_ids)
      response = @common_api.perform_post_action(@current_module, { field => test_string, 'invoice_transaction_ids' => [] }, field_payload, @configs)
      @create_txn = true if response[:code] == 200
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq "'abcd' is not a valid Integer"
    end
    e.run_step "#{field} :: Float value - 5000.25 :: expected response - 400" do
      test_float = 5000.25
      field_payload = JSON.parse(ERB.new(@disbursement_erb_file).result(binding))['disburse']
      if @create_txn == true
        @transactions_ids = @common_api.create_transactions_for_api(@hash)
        @create_txn = false
      end
      field_payload.merge!('transaction_ids' => @transactions_ids)
      response = @common_api.perform_post_action(@current_module, { field => test_float, 'invoice_transaction_ids' => [] }, field_payload, @configs)
      @create_txn = true if response[:code] == 200
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq "'5000.25' is not a valid Integer"
    end
    e.run_step "#{field} :: Wrong anchor_id - 400 :: expected response - 404" do
      wrong_value = 400
      field_payload = JSON.parse(ERB.new(@disbursement_erb_file).result(binding))['disburse']
      if @create_txn == true
        @transactions_ids = @common_api.create_transactions_for_api(@hash)
        @create_txn = false
      end
      field_payload.merge!('transaction_ids' => @transactions_ids)
      response = @common_api.perform_post_action(@current_module, { field => wrong_value, 'invoice_transaction_ids' => [] }, field_payload, @configs)
      @create_txn = true if response[:code] == 200
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq 'Parameter group_id is required'
    end
  end

  it 'Disburse Invoice :: vendor_id :: validations' do |e|
    field = 'vendor_id'
    e.run_step "#{field} :: value - null :: expected response - 400" do
      field_payload = JSON.parse(ERB.new(@disbursement_erb_file).result(binding))['disburse']
      if @create_txn == true
        @transactions_ids = @common_api.create_transactions_for_api(@hash)
        @create_txn = false
      end
      field_payload.merge!('transaction_ids' => @transactions_ids)
      response = @common_api.perform_post_action(@current_module, { field => nil, 'invoice_transaction_ids' => [] }, field_payload, @configs)
      @create_txn = true if response[:code] == 200
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq "'' is not a valid Integer"
    end
    e.run_step "#{field} :: value - empty :: expected response - 400" do
      field_payload = JSON.parse(ERB.new(@disbursement_erb_file).result(binding))['disburse']
      if @create_txn == true
        @transactions_ids = @common_api.create_transactions_for_api(@hash)
        @create_txn = false
      end
      field_payload.merge!('transaction_ids' => @transactions_ids)
      response = @common_api.perform_post_action(@current_module, { field => '', 'invoice_transaction_ids' => [] }, field_payload, @configs)
      @create_txn = true if response[:code] == 200
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq "'' is not a valid Integer"
    end
    e.run_step "#{field} :: String value - 'abcd' :: expected response - 400" do
      test_string = 'abcd'
      field_payload = JSON.parse(ERB.new(@disbursement_erb_file).result(binding))['disburse']
      if @create_txn == true
        @transactions_ids = @common_api.create_transactions_for_api(@hash)
        @create_txn = false
      end
      field_payload.merge!('transaction_ids' => @transactions_ids)
      response = @common_api.perform_post_action(@current_module, { field => test_string, 'invoice_transaction_ids' => [] }, field_payload, @configs)
      @create_txn = true if response[:code] == 200
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq "'abcd' is not a valid Integer"
    end
    e.run_step "#{field} :: Float value - 5000.25 :: expected response - 400" do
      test_float = 5000.25
      field_payload = JSON.parse(ERB.new(@disbursement_erb_file).result(binding))['disburse']
      if @create_txn == true
        @transactions_ids = @common_api.create_transactions_for_api(@hash)
        @create_txn = false
      end
      field_payload.merge!('transaction_ids' => @transactions_ids)
      response = @common_api.perform_post_action(@current_module, { field => test_float, 'invoice_transaction_ids' => [] }, field_payload, @configs)
      @create_txn = true if response[:code] == 200
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq "'5000.25' is not a valid Integer"
    end
    e.run_step "#{field} :: Wrong vendor_id - 400 :: expected response - 400" do
      wrong_value = 400
      field_payload = JSON.parse(ERB.new(@disbursement_erb_file).result(binding))['disburse']
      if @create_txn == true
        @transactions_ids = @common_api.create_transactions_for_api(@hash)
        @create_txn = false
      end
      field_payload.merge!('transaction_ids' => @transactions_ids)
      response = @common_api.perform_post_action(@current_module, { field => wrong_value, 'invoice_transaction_ids' => [] }, field_payload, @configs)
      @create_txn = true if response[:code] == 200
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq 'Parameter group_id is required'
    end
  end

  it 'Disburse Invoice :: program_id :: validations' do |e|
    field = 'program_id'
    e.run_step "#{field} :: value - null :: expected response - 400" do
      field_payload = JSON.parse(ERB.new(@disbursement_erb_file).result(binding))['disburse']
      if @create_txn == true
        @transactions_ids = @common_api.create_transactions_for_api(@hash)
        @create_txn = false
      end
      field_payload.merge!('transaction_ids' => @transactions_ids)
      response = @common_api.perform_post_action(@current_module, { field => nil, 'invoice_transaction_ids' => [] }, field_payload, @configs)
      @create_txn = true if response[:code] == 200
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq "'' is not a valid Integer"
    end
    e.run_step "#{field} :: value - empty :: expected response - 400" do
      field_payload = JSON.parse(ERB.new(@disbursement_erb_file).result(binding))['disburse']
      if @create_txn == true
        @transactions_ids = @common_api.create_transactions_for_api(@hash)
        @create_txn = false
      end
      field_payload.merge!('transaction_ids' => @transactions_ids)
      response = @common_api.perform_post_action(@current_module, { field => '', 'invoice_transaction_ids' => [] }, field_payload, @configs)
      @create_txn = true if response[:code] == 200
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq "'' is not a valid Integer"
    end
    e.run_step "#{field} :: String value - 'abcd' :: expected response - 400" do
      test_string = 'abcd'
      field_payload = JSON.parse(ERB.new(@disbursement_erb_file).result(binding))['disburse']
      if @create_txn == true
        @transactions_ids = @common_api.create_transactions_for_api(@hash)
        @create_txn = false
      end
      field_payload.merge!('transaction_ids' => @transactions_ids)
      response = @common_api.perform_post_action(@current_module, { field => test_string, 'invoice_transaction_ids' => [] }, field_payload, @configs)
      @create_txn = true if response[:code] == 200
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq "'abcd' is not a valid Integer"
    end
    e.run_step "#{field} :: Float value - 5000.25 :: expected response - 400" do
      test_float = 5000.25
      field_payload = JSON.parse(ERB.new(@disbursement_erb_file).result(binding))['disburse']
      if @create_txn == true
        @transactions_ids = @common_api.create_transactions_for_api(@hash)
        @create_txn = false
      end
      field_payload.merge!('transaction_ids' => @transactions_ids)
      response = @common_api.perform_post_action(@current_module, { field => test_float, 'invoice_transaction_ids' => [] }, field_payload, @configs)
      @create_txn = true if response[:code] == 200
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq "'5000.25' is not a valid Integer"
    end
    e.run_step "#{field} :: Wrong program_id - 400 :: expected response - 404" do
      wrong_value = 400
      field_payload = JSON.parse(ERB.new(@disbursement_erb_file).result(binding))['disburse']
      if @create_txn == true
        @transactions_ids = @common_api.create_transactions_for_api(@hash)
        @create_txn = false
      end
      field_payload.merge!('transaction_ids' => @transactions_ids)
      response = @common_api.perform_post_action(@current_module, { field => wrong_value, 'invoice_transaction_ids' => [] }, field_payload, @configs)
      @create_txn = true if response[:code] == 200
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq 'Parameter group_id is required'
    end
  end
end
