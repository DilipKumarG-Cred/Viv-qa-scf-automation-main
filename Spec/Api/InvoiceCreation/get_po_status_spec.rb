require './spec_helper'
describe 'Purchase Order Status :: GET :: Field Validations', :invoice_status, :api_field_validations, :anchor_integration do
  # Initialization
  common_api = Api::Pages::Common.new
  erb_file = File.read("#{Dir.pwd}/Api/test-data/create_invoices.erb")
  create_invoice_payload = JSON.parse(ERB.new(erb_file).result(binding))
  configs = create_invoice_payload['po']['config']
  current_module = 'create_po'

  it 'Valid Parameters' do |e|
    e.run_step 'Get transactions details with valid transaction id :: expected response - 200' do
      field_payload = create_invoice_payload['po']['create']
      create_transaction = common_api.perform_post_action(current_module, {}, field_payload, configs)
      expect(create_transaction[:code]).to eq(201), "Error in transaction creation! #{create_transaction}"
      tran_details = get_po_details(create_transaction[:body][:id])
      expect(tran_details[:code]).to eq(200), "Error in fetching details #{tran_details}"
      expect(tran_details[:body][:status]).to eq 'new'
    end
  end

  it 'Invalid Parameters' do |e|
    e.run_step 'Invalid value - nil :: expected response - 200' do
      tran_details = get_po_details(nil)
      expect(tran_details[:code]).to eq 404
    end
    e.run_step 'Invalid value - abcde :: expected response - 400' do
      tran_details = get_po_details('abcde')
      expect(tran_details[:code]).to eq 400
      expect(tran_details[:body][:error][:message]).to eq('Invalid request values [<ActionController::Parameters {"id"=>"abcde"} permitted: false>] , cannot be accepted!!')
    end
  end
end
