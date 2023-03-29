require './spec_helper'
describe 'Transactions associated with the Payment :: GET :: Field Validations', :transaction_history, :api_field_validations, :anchor_integration do
  before(:all) do
    @common_api = Api::Pages::Common.new
    @actor = 'grn_anchor'
    @action = 'transaction_history'
    # create and disburse payment and get reciept id
    @disbursement_erb_file = File.read("#{Dir.pwd}/Api/test-data/disburse_invoices.erb")
    @disbursement_configs = JSON.parse(ERB.new(@disbursement_erb_file).result(binding))['config_for_ramkay']
    @resettle_invoice_erb_file = File.read("#{Dir.pwd}/Api/test-data/resettle_invoices.erb")
    @invoice_erb = File.read("#{Dir.pwd}/Api/test-data/create_invoices.erb")
    resettle_payload = JSON.parse(ERB.new(@resettle_invoice_erb_file).result(binding))['resettle_invoice_with_anchor']
    resettle_payload.merge!('liability' => 'investor')
    hash = {
      disbursement_configs: @disbursement_configs,
      invoice_meta_data: @invoice_erb,
      disbursement_meta_data: @disbursement_erb_file,
      resettle_payload: resettle_payload,
      vendor: 'Ramkay'
    }
    @reciept_id = @common_api.get_reciept_for_new_resettled_transaction(hash)
  end

  it 'Valid Parameters' do |e|
    e.run_step 'With only mandatory parameter [payment_receipt_id] :: expected response - 200' do
      hash = { 'payment_receipt_id' => @reciept_id }
      response = @common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 200
      expect(response[:body][:transactions_array][0][:payment_receipt][:id]).to eq @reciept_id
    end

    e.run_step 'Including Optional parameters :: expected response - 200' do
      hash = {
        'payment_receipt_id' => @reciept_id,
        'vendor_id' => 1,
        'investor_id' => 2,
        'payment_type' => 'current'
      }
      response = @common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 200
    end
  end

  it 'No Parameters' do |e|
    e.run_step 'Empty parameter :: Expected response - 500' do
      hash = {}
      response = @common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 500
      expect(response[:body][:error][:message]).to eq "Couldn't find PaymentReceipt"
    end
  end

  it 'payment_receipt_id :: Invalid Value' do |e|
    e.run_step 'payment_receipt_id :: Incorrect value - 0 :: expected response - 500' do
      id = 0
      hash = { 'payment_receipt_id' => id }
      response = @common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 500
      expect(response[:body][:error][:message]).to eq "Couldn't find PaymentReceipt"
    end

    e.run_step 'payment_receipt_id :: String value - abcd :: expected response - 400' do
      id = 'abcd'
      hash = { 'payment_receipt_id' => id }
      response = @common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq("'abcd' is not a valid Integer")
    end

    e.run_step 'payment_receipt_id :: Float value - 0.01 :: expected response - 400' do
      id = 0.01
      hash = { 'payment_receipt_id' => id }
      response = @common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq("'0.01' is not a valid Integer")
    end

    e.run_step "payment_receipt_id :: Special char - @\#@ :: expected response - 400" do
      hash = { 'payment_receipt_id' => '@#@' }
      response = @common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq("'@\#@' is not a valid Integer")
    end

    e.run_step 'payment_receipt_id :: Empty value :: expected response - 400' do
      hash = { 'payment_receipt_id' => '' }
      response = @common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq("'' is not a valid Integer")
    end

    e.run_step 'payment_receipt_id :: value - nil :: expected response - 400' do
      hash = { 'payment_receipt_id' => nil }
      response = @common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 500
      expect(response[:body][:error][:message]).to eq "Couldn't find PaymentReceipt"
    end
  end

  it 'payment_type :: Invalid Value' do |e|
    e.run_step 'Incorrect Value - RefundInvalid :: expected response - 400' do
      hash = { 'payment_type' => 'RefundInvalid', 'payment_receipt_id' => @reciept_id }
      response = @common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq('Parameter payment_type must be within ["current", "prepayment", "overdue"]')
    end

    e.run_step 'Float Value - 0.01 :: expected response - 400' do
      hash = { 'payment_type' => '0.01', 'payment_receipt_id' => @reciept_id }
      response = @common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq('Parameter payment_type must be within ["current", "prepayment", "overdue"]')
    end

    e.run_step "Special Char Value - @\#@ :: expected response - 400" do
      hash = { 'payment_type' => '@#@', 'payment_receipt_id' => @reciept_id }
      response = @common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq('Parameter payment_type must be within ["current", "prepayment", "overdue"]')
    end

    e.run_step 'Value - Empty :: expected response - 400' do
      hash = {
        'payment_type' => '',
        'payment_receipt_id' => @reciept_id
      }
      response = @common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq('Parameter payment_type must be within ["current", "prepayment", "overdue"]')
    end

    e.run_step 'Value - nil :: expected response - 200' do
      hash = {
        'payment_type' => nil,
        'payment_receipt_id' => @reciept_id
      }
      response = @common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 200
    end
  end
end
