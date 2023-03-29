require './spec_helper'
describe 'Transactions associated with the Funding :: GET :: Field Validations', :transaction_history, :api_field_validations, :anchor_integration do
  before(:all) do
    @common_api = Api::Pages::Common.new
    @actor = 'grn_anchor'
    @action = 'transaction_associated'
    @disbursement_erb_file = File.read("#{Dir.pwd}/Api/test-data/disburse_invoices.erb")
    @disbursement_configs = JSON.parse(ERB.new(@disbursement_erb_file).result(binding))['config_for_ramkay']
    @resettle_invoice_erb_file = File.read("#{Dir.pwd}/Api/test-data/resettle_invoices.erb")
    @invoice_erb = File.read("#{Dir.pwd}/Api/test-data/create_invoices.erb")
    # create and disburse payment and get reciept id
    hash = {
      disbursement_configs: @disbursement_configs,
      invoice_meta_data: @invoice_erb,
      disbursement_meta_data: @disbursement_erb_file,
      vendor: 'Ramkay'
    }
    resp = @common_api.create_disbursed_transaction_for_api(hash)
    @reciept_id = resp[:body][:payment_details][:id]
  end

  after(:all) do
    clear_all_overdues({ anchor: @disbursement_configs['actor_user'], vendor: @disbursement_configs['counter_party_user'] })
  end

  it 'Valid Parameters' do |e|
    e.run_step 'With only mandatory parameter [payment_receipt_id] :: expected response - 200' do
      id = @reciept_id
      hash = { 'payment_receipt_id' => id }
      response = @common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 200
      expect(response[:body][:transactions_array][0][:payment_receipt][:id]).to eq id
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

  it 'Payment Reciept ID :: Invalid Value' do |e|
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

    e.run_step 'payment_receipt_id :: value - nil :: expected response - 500' do
      hash = { 'payment_receipt_id' => nil }
      response = @common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 500
      expect(response[:body][:error][:message]).to eq "Couldn't find PaymentReceipt"
    end
  end
end
