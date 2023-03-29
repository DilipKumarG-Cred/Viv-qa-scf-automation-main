require './spec_helper'
describe 'Create PO :: post :: Field Validations', :create_po, :api_field_validations do
  # Initialization
  common_api = Api::Pages::Common.new
  erb_file = File.read("#{Dir.pwd}/Api/test-data/create_invoices.erb")
  configs = JSON.parse(ERB.new(erb_file).result(binding))['po']['config']
  current_module = 'create_po'

  it 'Create PO :: Valid Inputs' do |e|
    e.run_step 'Create PO with all valid inputs :: expected response - 201' do
      field_payload = JSON.parse(ERB.new(erb_file).result(binding))['po']['create']
      field_payload['Requested Disbursement Value'] = field_payload['PO Value'] if field_payload['Requested Disbursement Value'] > field_payload['PO Value']
      response = common_api.perform_post_action(current_module, {}, field_payload, configs)
      expect(response[:code]).to eq(201), response.to_s
    end
  end

  it 'Create PO :: PO Number :: validations' do |e|
    field = 'PO Number'
    e.run_step "#{field} :: value - null :: expected response - 400" do
      field_payload = JSON.parse(ERB.new(erb_file).result(binding))['po']['create']
      response = common_api.perform_post_action(current_module, { field => nil }, field_payload, configs)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq 'PO number is required'
    end
    e.run_step "#{field} :: value - empty :: expected response - 400" do
      field_payload = JSON.parse(ERB.new(erb_file).result(binding))['po']['create']
      response = common_api.perform_post_action(current_module, { field => '' }, field_payload, configs)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq 'PO number is required'
    end
  end

  it 'Create PO :: PO file :: validations' do |e|
    field = 'PO file'
    e.run_step "#{field} :: value - null :: expected response - 422" do
      field_payload = JSON.parse(ERB.new(erb_file).result(binding))['po']['create']
      response = common_api.perform_post_action(current_module, { field => nil }, field_payload, configs)
      expect(response[:code]).to eq 422
      expect(response[:body][:error][:message]).to eq 'Purchase Order file attachment is mandatory'
    end
    e.run_step "#{field} :: value - empty :: expected response - 422" do
      field_payload = JSON.parse(ERB.new(erb_file).result(binding))['po']['create']
      response = common_api.perform_post_action(current_module, { field => '' }, field_payload, configs)
      expect(response[:code]).to eq 422
      expect(response[:body][:error][:message]).to eq 'Purchase Order file attachment is mandatory'
    end
    e.run_step "#{field} :: value - abc :: expected response - 400" do
      field_payload = JSON.parse(ERB.new(erb_file).result(binding))['po']['create']
      response = common_api.perform_post_action(current_module, { field => 'abc' }, field_payload, configs)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq 'Upload a valid document!'
    end
  end

  it 'Create PO :: PO Value :: validations' do |e|
    field = 'PO Value'
    e.run_step "#{field} :: value - null :: expected response - 400" do
      field_payload = JSON.parse(ERB.new(erb_file).result(binding))['po']['create']
      response = common_api.perform_post_action(current_module, { field => nil }, field_payload, configs)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq 'PO value is required and should be of type float'
    end
    e.run_step "#{field} :: value - empty :: expected response - 400" do
      field_payload = JSON.parse(ERB.new(erb_file).result(binding))['po']['create']
      response = common_api.perform_post_action(current_module, { field => '' }, field_payload, configs)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq 'PO value is required and should be of type float'
    end
    e.run_step "#{field} :: String value - 'abcd' :: expected response - 400" do
      test_string = 'abcd'
      field_payload = JSON.parse(ERB.new(erb_file).result(binding))['po']['create']
      response = common_api.perform_post_action(current_module, { field => test_string }, field_payload, configs)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq 'PO value is required and should be of type float'
    end
    e.run_step "#{field} :: Float value - 5000.25 :: expected response - 201" do
      test_float = 5000.25
      field_payload = JSON.parse(ERB.new(erb_file).result(binding))['po']['create']
      field_payload['Requested Disbursement Value'] = 4000
      response = common_api.perform_post_action(current_module, { field => test_float }, field_payload, configs)
      expect(response[:code]).to eq(201), response.to_s
    end
  end

  it 'Create PO :: Requested Disbursement Value :: validations' do |e|
    field = 'Requested Disbursement Value'
    e.run_step "#{field} :: value - null :: expected response - 400" do
      field_payload = JSON.parse(ERB.new(erb_file).result(binding))['po']['create']
      response = common_api.perform_post_action(current_module, { field => nil }, field_payload, configs)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq "'' is not a valid Float"
    end
    e.run_step "#{field} :: value - empty :: expected response - 400" do
      field_payload = JSON.parse(ERB.new(erb_file).result(binding))['po']['create']
      response = common_api.perform_post_action(current_module, { field => '' }, field_payload, configs)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq "'' is not a valid Float"
    end
    e.run_step "#{field} :: String value - 'abcd' :: expected response - 400" do
      test_string = 'abcd'
      field_payload = JSON.parse(ERB.new(erb_file).result(binding))['po']['create']
      response = common_api.perform_post_action(current_module, { field => test_string }, field_payload, configs)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq "'#{test_string}' is not a valid Float"
    end
    e.run_step "#{field} :: Float value - 5000.25 :: expected response - 201" do
      test_float = 5000.25
      field_payload = JSON.parse(ERB.new(erb_file).result(binding))['po']['create']
      field_payload['Requested Disbursement Value'] = 4000
      response = common_api.perform_post_action(current_module, { field => test_float }, field_payload, configs)
      expect(response[:code]).to eq 201
    end
  end

  it 'Create PO :: PO Date :: validations' do |e|
    field = 'PO Date'
    e.run_step "#{field} :: value - null :: expected response - 400" do
      field_payload = JSON.parse(ERB.new(erb_file).result(binding))['po']['create']
      response = common_api.perform_post_action(current_module, { field => nil }, field_payload, configs)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq 'Invalid format/Parameter Missing. Expected format: yyyy-mm-dd'
    end
    e.run_step "#{field} :: value - empty :: expected response - 400" do
      field_payload = JSON.parse(ERB.new(erb_file).result(binding))['po']['create']
      response = common_api.perform_post_action(current_module, { field => '' }, field_payload, configs)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq 'Invalid format/Parameter Missing. Expected format: yyyy-mm-dd'
    end
    e.run_step "#{field} :: String value - 'abcd' :: expected response - 400" do
      test_string = 'abcd'
      field_payload = JSON.parse(ERB.new(erb_file).result(binding))['po']['create']
      response = common_api.perform_post_action(current_module, { field => test_string }, field_payload, configs)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq 'Invalid format/Parameter Missing. Expected format: yyyy-mm-dd'
    end
    e.run_step "#{field} :: Integer value - 100 :: expected response - 400" do
      test_integer = 100
      field_payload = JSON.parse(ERB.new(erb_file).result(binding))['po']['create']
      response = common_api.perform_post_action(current_module, { field => test_integer }, field_payload, configs)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq 'Invalid format/Parameter Missing. Expected format: yyyy-mm-dd'
    end
    e.run_step "#{field} :: Float value - 5000.25 :: expected response - 400" do
      test_float = 5000.25
      field_payload = JSON.parse(ERB.new(erb_file).result(binding))['po']['create']
      response = common_api.perform_post_action(current_module, { field => test_float }, field_payload, configs)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq 'Invalid format/Parameter Missing. Expected format: yyyy-mm-dd'
    end
    e.run_step "#{field} :: Different date format - dd-mm-yyyy :: expected response - 400" do
      test_date = Date.today.strftime('dd-mm-yyyy')
      field_payload = JSON.parse(ERB.new(erb_file).result(binding))['po']['create']
      response = common_api.perform_post_action(current_module, { field => test_date }, field_payload, configs)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq 'Invalid format/Parameter Missing. Expected format: yyyy-mm-dd'
    end
  end

  it 'Create PO :: GSTN of Anchor :: validations' do |e|
    field = 'GSTN of Anchor'
    e.run_step "#{field} :: value - null :: expected response - 400" do
      field_payload = JSON.parse(ERB.new(erb_file).result(binding))['po']['create']
      response = common_api.perform_post_action(current_module, { field => nil }, field_payload, configs)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq 'Parameter anchor_gstn must match format (?-mix:\\d{2}[A-Z]{5}\\d{4}[A-Z]{1}[A-Z\\d]{1}[Z]{1}[A-Z\\d]{1})'
    end
    e.run_step "#{field} :: value - empty :: expected response - 400" do
      field_payload = JSON.parse(ERB.new(erb_file).result(binding))['po']['create']
      response = common_api.perform_post_action(current_module, { field => '' }, field_payload, configs)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq 'Parameter anchor_gstn must match format (?-mix:\\d{2}[A-Z]{5}\\d{4}[A-Z]{1}[A-Z\\d]{1}[Z]{1}[A-Z\\d]{1})'
    end
    e.run_step "#{field} :: String value - 'abcd' :: expected response - 400" do
      test_string = 'abcd'
      field_payload = JSON.parse(ERB.new(erb_file).result(binding))['po']['create']
      response = common_api.perform_post_action(current_module, { field => test_string }, field_payload, configs)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq 'Parameter anchor_gstn must match format (?-mix:\\d{2}[A-Z]{5}\\d{4}[A-Z]{1}[A-Z\\d]{1}[Z]{1}[A-Z\\d]{1})'
    end
    e.run_step "#{field} :: Integer value - 100 :: expected response - 400" do
      test_integer = 100
      field_payload = JSON.parse(ERB.new(erb_file).result(binding))['po']['create']
      response = common_api.perform_post_action(current_module, { field => test_integer }, field_payload, configs)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq 'Parameter anchor_gstn must match format (?-mix:\\d{2}[A-Z]{5}\\d{4}[A-Z]{1}[A-Z\\d]{1}[Z]{1}[A-Z\\d]{1})'
    end
    e.run_step "#{field} :: Different Anchor GSTN other than logged in User - 17ABCDH0940E1ZV :: expected response - 400" do
      wrong_gstn = '17ABCDH0940E1ZV'
      field_payload = JSON.parse(ERB.new(erb_file).result(binding))['po']['create']
      response = common_api.perform_post_action(current_module, { field => wrong_gstn }, field_payload, configs)
      expect(response[:code]).to eq 422
      expect(response[:body][:error][:message]).to eq 'GSTN not matching the logged in entity'
    end
  end

  it 'Create PO :: GSTN of Vendor :: validations' do |e|
    field = 'GSTN of Vendor'
    e.run_step "#{field} :: value - null :: expected response - 400" do
      field_payload = JSON.parse(ERB.new(erb_file).result(binding))['po']['create']
      response = common_api.perform_post_action(current_module, { field => nil }, field_payload, configs)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq 'Parameter vendor_gstn must match format (?-mix:\\d{2}[A-Z]{5}\\d{4}[A-Z]{1}[A-Z\\d]{1}[Z]{1}[A-Z\\d]{1})'
    end
    e.run_step "#{field} :: value - empty :: expected response - 400" do
      field_payload = JSON.parse(ERB.new(erb_file).result(binding))['po']['create']
      response = common_api.perform_post_action(current_module, { field => '' }, field_payload, configs)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq 'Parameter vendor_gstn must match format (?-mix:\\d{2}[A-Z]{5}\\d{4}[A-Z]{1}[A-Z\\d]{1}[Z]{1}[A-Z\\d]{1})'
    end
    e.run_step "#{field} :: String value - 'abcd' :: expected response - 400" do
      test_string = 'abcd'
      field_payload = JSON.parse(ERB.new(erb_file).result(binding))['po']['create']
      response = common_api.perform_post_action(current_module, { field => test_string }, field_payload, configs)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq 'Parameter vendor_gstn must match format (?-mix:\\d{2}[A-Z]{5}\\d{4}[A-Z]{1}[A-Z\\d]{1}[Z]{1}[A-Z\\d]{1})'
    end
    e.run_step "#{field} :: Integer value - 100 :: expected response - 400" do
      test_integer = 100
      field_payload = JSON.parse(ERB.new(erb_file).result(binding))['po']['create']
      response = common_api.perform_post_action(current_module, { field => test_integer }, field_payload, configs)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq 'Parameter vendor_gstn must match format (?-mix:\\d{2}[A-Z]{5}\\d{4}[A-Z]{1}[A-Z\\d]{1}[Z]{1}[A-Z\\d]{1})'
    end
    e.run_step "#{field} :: Vendor not available for the anchor - 17YYYYH0940E1ZV :: expected response - 400" do
      wrong_gstn = '17YYYYH0940E1ZV'
      field_payload = JSON.parse(ERB.new(erb_file).result(binding))['po']['create']
      response = common_api.perform_post_action(current_module, { field => wrong_gstn }, field_payload, configs)
      expect(response[:code]).to eq 422
      expect(response[:body][:error][:message]).to eq 'Unable to find Vendor from the GSTN provided'
    end
  end
end
