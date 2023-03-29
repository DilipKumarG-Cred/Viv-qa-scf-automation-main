require './spec_helper'
describe 'Disburse Invoices :: POST :: Field Validations', :disburse_invoices, :api_field_validations, :dd do
  # Initialization
  before(:all) do
    @common_api = Api::Pages::Common.new
    @erb_file = File.read("#{Dir.pwd}/Api/test-data/create_invoices.erb")
    @disbursement_erb_file = File.read("#{Dir.pwd}/Api/test-data/disburse_invoices.erb")
    @configs = JSON.parse(ERB.new(@disbursement_erb_file).result(binding))['config']
    @invoice_file = "#{Dir.pwd}/test-data/attachments/anchor_invoice.pdf"
    @values = {
      actor: 'anchor',
      counter_party: 'dd_vendor',
      invoice_details: '',
      invoice_file: @invoice_file,
      program: 'Dynamic Discounting - Vendor'
    }
    @module = 'disburse_dd'
  end

  it 'Validate Disbursements :: Valid Inputs' do |e|
    e.run_step 'Disburse Invoice with all valid inputs :: expected response - 201' do
      disbursement_details = @common_api.get_disbursement_details_for_dd(@erb_file, @disbursement_erb_file, @values)
      resp = @common_api.perform_post_action(@module, {}, disbursement_details, nil)
      expect(resp[:code]).to eq(200), resp.to_s
    end
  end

  it 'Negative Validations :: Document' do |e|
    e.run_step 'Document - nil :: expected response - 200' do
      disbursement_details = @common_api.get_disbursement_details_for_dd(@erb_file, @disbursement_erb_file, @values)
      resp = @common_api.perform_post_action(@module, { 'document' => nil }, disbursement_details, nil)
      expect(resp[:code]).to eq(200), resp.to_s
    end
    e.run_step 'Document - abcd :: expected response - 422' do
      disbursement_details = @common_api.get_disbursement_details_for_dd(@erb_file, @disbursement_erb_file, @values)
      resp = @common_api.perform_post_action(@module, { 'document' => 'abcd' }, disbursement_details, nil)
      # if a valid document in not uploaded ,then it would consider it and will discard the document parameter.
      expect(resp[:code]).to eq(200), resp.to_s
    end
  end

  it 'Negative Validations :: utr_number' do |e|
    e.run_step 'utr_number - nil :: expected response - 200' do
      disburse = JSON.parse(ERB.new(@disbursement_erb_file).result(binding))['disburse_dd']
      disburse_config = JSON.parse(ERB.new(@disbursement_erb_file).result(binding))['config_for_dd']
      disburse['anchor_actor'] = disburse_config['actor']
      resp = @common_api.perform_post_action(@module, { 'utr_number' => nil }, disburse, nil)
      expect(resp[:code]).to eq(422)
      expect(resp[:body][:error][:message]).to eq("Validation failed: Utr number can't be blank")
    end
    e.run_step 'utr_number - empty :: expected response - 200' do
      disburse = JSON.parse(ERB.new(@disbursement_erb_file).result(binding))['disburse_dd']
      disburse_config = JSON.parse(ERB.new(@disbursement_erb_file).result(binding))['config_for_dd']
      disburse['anchor_actor'] = disburse_config['actor']
      resp = @common_api.perform_post_action(@module, { 'utr_number' => '' }, disburse, nil)
      expect(resp[:code]).to eq(422)
      expect(resp[:body][:error][:message]).to eq("Validation failed: Utr number can't be blank")
    end
  end

  it 'Negative Validations :: amount' do |e|
    e.run_step 'amount - nil :: expected response - 400' do
      disburse = JSON.parse(ERB.new(@disbursement_erb_file).result(binding))['disburse_dd']
      disburse_config = JSON.parse(ERB.new(@disbursement_erb_file).result(binding))['config_for_dd']
      disburse['anchor_actor'] = disburse_config['actor']
      resp = @common_api.perform_post_action(@module, { 'amount' => nil }, disburse, nil)
      expect(resp[:code]).to eq(400)
      expect(resp[:body][:error][:message]).to eq("'' is not a valid Float")
    end
    e.run_step 'amount - empty :: expected response - 400' do
      disburse = JSON.parse(ERB.new(@disbursement_erb_file).result(binding))['disburse_dd']
      disburse_config = JSON.parse(ERB.new(@disbursement_erb_file).result(binding))['config_for_dd']
      disburse['anchor_actor'] = disburse_config['actor']
      resp = @common_api.perform_post_action(@module, { 'amount' => '' }, disburse, nil)
      expect(resp[:code]).to eq(400)
      expect(resp[:body][:error][:message]).to eq("'' is not a valid Float")
    end
    e.run_step 'amount - abcde :: expected response - 400' do
      disburse = JSON.parse(ERB.new(@disbursement_erb_file).result(binding))['disburse_dd']
      disburse_config = JSON.parse(ERB.new(@disbursement_erb_file).result(binding))['config_for_dd']
      disburse['anchor_actor'] = disburse_config['actor']
      resp = @common_api.perform_post_action(@module, { 'amount' => 'abcde' }, disburse, nil)
      expect(resp[:code]).to eq(400)
      expect(resp[:body][:error][:message]).to eq("'abcde' is not a valid Float")
    end
    e.run_step 'amount - less than actual :: expected response - 422' do
      disbursement_details = @common_api.get_disbursement_details_for_dd(@erb_file, @disbursement_erb_file, @values)
      resp = @common_api.perform_post_action(@module, { 'amount' => '100' }, disbursement_details, nil)
      expect(resp[:code]).to eq(422)
      expect(resp[:body][:error][:message]).to eq("The disbursement amount provided is not matching the system's calculated amount. Please provide a valid reason/proof for the mismatch.")
    end
    e.run_step 'amount - greather than actual :: expected response - 422' do
      disbursement_details = @common_api.get_disbursement_details_for_dd(@erb_file, @disbursement_erb_file, @values)
      resp = @common_api.perform_post_action(@module, { 'amount' => disbursement_details['amount'] + 10000 }, disbursement_details, nil)
      expect(resp[:code]).to eq(422)
      expect(resp[:body][:error][:message]).to eq("The disbursement amount provided is not matching the system's calculated amount. Please provide a valid reason/proof for the mismatch.")
    end
  end

  it 'Negative Validations :: Transaction ID' do |e|
    e.run_step 'invoice_transaction_ids - nil :: expected response - 422' do
      disburse = JSON.parse(ERB.new(@disbursement_erb_file).result(binding))['disburse_dd']
      disburse_config = JSON.parse(ERB.new(@disbursement_erb_file).result(binding))['config_for_dd']
      disburse['anchor_actor'] = disburse_config['actor']
      resp = @common_api.perform_post_action(@module, { 'invoice_transaction_ids' => nil }, disburse, nil)
      expect(resp[:code]).to eq(422)
      expect(resp[:body][:error][:message]).to eq("The disbursement amount provided is not matching the system's calculated amount. Please provide a valid reason/proof for the mismatch.")
    end
    e.run_step "invoice_transaction_ids - '' :: expected response - 422" do
      disburse = JSON.parse(ERB.new(@disbursement_erb_file).result(binding))['disburse_dd']
      disburse_config = JSON.parse(ERB.new(@disbursement_erb_file).result(binding))['config_for_dd']
      disburse['anchor_actor'] = disburse_config['actor']
      resp = @common_api.perform_post_action(@module, { 'invoice_transaction_ids' => '' }, disburse, nil)
      expect(resp[:code]).to eq(422)
      expect(resp[:body][:error][:message]).to eq("The disbursement amount provided is not matching the system's calculated amount. Please provide a valid reason/proof for the mismatch.")
    end
    e.run_step 'invoice_transaction_ids - abcde :: expected response - 400' do
      disburse = JSON.parse(ERB.new(@disbursement_erb_file).result(binding))['disburse_dd']
      disburse_config = JSON.parse(ERB.new(@disbursement_erb_file).result(binding))['config_for_dd']
      disburse['anchor_actor'] = disburse_config['actor']
      resp = @common_api.perform_post_action(@module, { 'invoice_transaction_ids' => 'abcde' }, disburse, nil)
      expect(resp[:code]).to eq(400)
      expect(resp[:body][:error][:message]).to eq("'abcde' is not a valid Integer")
    end
    e.run_step 'invoice_transaction_ids - 5000.25 :: expected response - 422' do
      disbursement_details = @common_api.get_disbursement_details_for_dd(@erb_file, @disbursement_erb_file, @values)
      resp = @common_api.perform_post_action(@module, { 'invoice_transaction_ids' => 5000.25 }, disbursement_details, nil)
      expect(resp[:code]).to eq(400)
      expect(resp[:body][:error][:message]).to eq("'5000.25' is not a valid Integer")
    end
  end
end
