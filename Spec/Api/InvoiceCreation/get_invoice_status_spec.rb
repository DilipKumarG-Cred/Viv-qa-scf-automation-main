require './spec_helper'
describe 'Invoice Status :: GET :: Field Validations', :invoice_status, :api_field_validations, :anchor_integration do
  # Initialization
  common_api = Api::Pages::Common.new
  erb_file = File.read("#{Dir.pwd}/Api/test-data/create_invoices.erb")
  create_invoice_payload = JSON.parse(ERB.new(erb_file).result(binding))
  configs = create_invoice_payload['invoice']['config']
  current_module = 'create_invoice'

  before(:all) do
    @actor = 'grn_anchor'
    @action = 'funding_history'
  end

  it 'Valid Parameters' do |e|
    e.run_step 'Get transactions details with valid transaction id :: expected response - 200' do
      field_payload = create_invoice_payload['invoice']['create']
      create_transaction = common_api.perform_post_action(current_module, {}, field_payload, configs)
      expect(create_transaction[:code]).to eq(200), "Error in transaction creation! #{create_transaction}"
      tran_details = get_transaction_details(create_transaction[:body][:id])
      expect(tran_details[:code]).to eq(200), "Error in fetching details #{tran_details}"
      expect(tran_details[:body][:status]).to eq 'new'
    end
  end

  it 'Invalid Parameters' do |e|
    e.run_step 'Invalid value - nil :: expected response - 200' do
      tran_details = get_transaction_details(nil)
      expect(tran_details[:code]).to eq(200)
      expect(tran_details[:body][:invoices]).to eq([])
    end
    e.run_step 'Invalid value - abcde :: expected response - 400' do
      tran_details = get_transaction_details('abcde')
      expect(tran_details[:code]).to eq(400)
      expect(tran_details[:body][:error][:message]).to eq('Invalid request values [<ActionController::Parameters {"id"=>"abcde"} permitted: false>] , cannot be accepted!!')
    end
  end
end
