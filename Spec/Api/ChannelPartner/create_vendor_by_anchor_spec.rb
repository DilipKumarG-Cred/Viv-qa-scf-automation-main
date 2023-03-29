require './spec_helper'
describe 'Create Channel Partner :: POST :: Field Validations', :create_cp, :api_field_validations do
  # Initialization
  common_api = Api::Pages::Common.new
  erb_file = File.read("#{Dir.pwd}/Api/test-data/create_channel_partner.erb")
  configs = JSON.parse(ERB.new(erb_file).result(binding))['config']
  current_module = 'create_cp'
  actor = 'grn_anchor'

  it 'Valid Inputs' do |e|
    e.run_step 'With all valid inputs :: expected response - 200' do
      field_payload = JSON.parse(ERB.new(erb_file).result(binding))['vendor']['create']
      response = common_api.perform_post_action(current_module, {}, field_payload, configs)
      expect(response[:code]).to eq 200
      values = {
        program_id: response[:body][:anchor_programs][0][:anchor_program_id],
        program_type: response[:body][:anchor_programs][0][:program_type],
        actor: actor,
        vendors: [field_payload['Name']]
      }
      expect(delete_vendor(values)).to eq true
    end
    # e.run_step 'With all valid inputs :: DD Program :: expected response - 200' do
    #   field_payload = JSON.parse(ERB.new(erb_file).result(binding))['vendor']['create_dd']
    #   response = common_api.perform_post_action(current_module, {}, field_payload, configs)
    #   expect(response[:code]).to eq(200), response.to_s
    #   values = {
    #     program_id: response[:body][:anchor_programs][0][:anchor_program_id],
    #     program_type: response[:body][:anchor_programs][0][:program_type],
    #     actor: actor,
    #     vendors: [field_payload['Name']]
    #   }
    #   expect(delete_vendor(values)).to eq true
    # end
  end

  it 'GSTN :: Invalid inputs' do |e|
    field = 'GSTN'
    e.run_step 'Value - null :: expected response - 400' do
      field_payload = JSON.parse(ERB.new(erb_file).result(binding))['vendor']['create']
      response = common_api.perform_post_action(current_module, { field => nil }, field_payload, configs)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq 'Please provide a valid GSTN'
    end
    e.run_step 'Value - empty :: expected response - 400' do
      field_payload = JSON.parse(ERB.new(erb_file).result(binding))['vendor']['create']
      response = common_api.perform_post_action(current_module, { field => '' }, field_payload, configs)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq 'Please provide a valid GSTN'
    end
    e.run_step "String value - 'abcd' :: expected response - 400" do
      test_string = 'abcd'
      field_payload = JSON.parse(ERB.new(erb_file).result(binding))['vendor']['create']
      response = common_api.perform_post_action(current_module, { field => test_string }, field_payload, configs)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq 'Please provide a valid GSTN'
    end
    e.run_step 'Integer value - 100 :: expected response - 400' do
      test_integer = 100
      field_payload = JSON.parse(ERB.new(erb_file).result(binding))['vendor']['create']
      response = common_api.perform_post_action(current_module, { field => test_integer }, field_payload, configs)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq 'Please provide a valid GSTN'
    end
    e.run_step 'Existing vendor in Anchor - 38SSSZU0940F1ZV :: expected response - 400' do
      existing_gstn = '17ABCDH0940E1ZV'
      field_payload = JSON.parse(ERB.new(erb_file).result(binding))['vendor']['create']
      response = common_api.perform_post_action(current_module, { field => existing_gstn }, field_payload, configs)
      expect(response[:code]).to eq 422
      expect(response[:body][:error][:message]).to eq "Invalid data - #{field_payload['Entity Name']} is already associated in PO-VENDOR program"
    end
  end

  it 'Email :: Invalid inputs' do |e|
    field = 'Email'
    e.run_step 'Value - null :: expected response - 400' do
      field_payload = JSON.parse(ERB.new(erb_file).result(binding))['vendor']['create']
      response = common_api.perform_post_action(current_module, { field => nil }, field_payload, configs)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq 'Please provide a valid email'
    end
    e.run_step 'Value - empty :: expected response - 400' do
      field_payload = JSON.parse(ERB.new(erb_file).result(binding))['vendor']['create']
      response = common_api.perform_post_action(current_module, { field => '' }, field_payload, configs)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq 'Please provide a valid email'
    end
    e.run_step "String value - 'abcd' :: expected response - 400" do
      test_string = 'abcd'
      field_payload = JSON.parse(ERB.new(erb_file).result(binding))['vendor']['create']
      response = common_api.perform_post_action(current_module, { field => test_string }, field_payload, configs)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq 'Please provide a valid email'
    end
    e.run_step 'Existing Email ID :: expected response - 400' do
      existing_email = 'ch28stores@gmail.com'
      field_payload = JSON.parse(ERB.new(erb_file).result(binding))['vendor']['create']
      response = common_api.perform_post_action(current_module, { field => existing_email }, field_payload, configs)
      expect(response[:code]).to eq 200
    end
  end

  it 'GST :: Invalid inputs', :dd do |e|
    field = 'GST'
    e.run_step 'Value - null :: expected response - 400' do
      field_payload = JSON.parse(ERB.new(erb_file).result(binding))['vendor']['create_dd']
      response = common_api.perform_post_action(current_module, { field => nil }, field_payload, configs)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq "'' is not a valid Float"
    end
    e.run_step 'Value - empty :: expected response - 400' do
      field_payload = JSON.parse(ERB.new(erb_file).result(binding))['vendor']['create_dd']
      response = common_api.perform_post_action(current_module, { field => '' }, field_payload, configs)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq "'' is not a valid Float"
    end
    e.run_step 'String Value - abcd :: expected response - 400' do
      field_payload = JSON.parse(ERB.new(erb_file).result(binding))['vendor']['create_dd']
      response = common_api.perform_post_action(current_module, { field => 'abcd' }, field_payload, configs)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq "'abcd' is not a valid Float"
    end
  end
end
