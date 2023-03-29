require './spec_helper'
describe 'Pending Dues at Entity Level :: GET :: Field Validations', :pending_dues, :api_field_validations, :anchor_integration do
  # Initialization
  common_api = Api::Pages::Common.new

  before(:all) do
    @actor = 'anchor'
    @action = 'pending_dues_entity'
  end

  it 'Pending Dues at Entity Level :: Valid Parameters' do |e|
    e.run_step 'With Mandatory fields :: expected response - 200' do
      hash = {
        'program_group' => 'invoice',
        'page' => 1
      }
      response = common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 200
    end

    e.run_step 'With Optional params :: expected response - 200' do
      hash = {
        'program_group' => 'invoice',
        'page' => 1,
        'vendor_id' => 9,
        'investor_id' => 2
      }
      response = common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 200
    end
  end

  it 'Pending Dues at Entity Level :: Empty Parameter' do |e|
    e.run_step 'Empty parameter :: expected response - 400' do
      hash = {}
      response = common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq('Parameter program_group is required')
    end
  end

  it 'Pending Dues at Entity Level :: program_group :: Invalid Value' do |e|
    e.run_step 'Incorrect Value - Invalid :: expected response - 400' do
      hash = { 'program_group' => 'Invalid' }
      response = common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq('Parameter program_group must be within ["invoice", "po"]')
    end

    e.run_step 'Float Value - 0.01 :: expected response - 400' do
      hash = { 'program_group' => '0.01' }
      response = common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq('Parameter program_group must be within ["invoice", "po"]')
    end

    e.run_step "Special Char Value - @\#@ :: expected response - 400" do
      hash = { 'program_group' => '@#@' }
      response = common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq('Parameter program_group must be within ["invoice", "po"]')
    end

    e.run_step 'Value - Empty :: expected response - 400' do
      hash = {
        'program_group' => ''
      }
      response = common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq('Parameter program_group must be within ["invoice", "po"]')
    end

    e.run_step 'Value - nil :: expected response - 400' do
      hash = {
        'program_group' => nil
      }
      response = common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq('Parameter program_group is required')
    end
  end

  it 'Pending Dues at Entity Level :: page :: Invalid Value' do |e|
    e.run_step 'Incorrect Value - 23333 :: expected response - 400' do
      hash = { 'page' => 23214123, 'program_group' => 'invoice' }
      response = common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 200
      expect(response[:body][:investor_vendors]).to eq([])
    end

    e.run_step 'Float Value - 0.01 :: expected response - 400' do
      hash = { 'page' => '0.01', 'program_group' => 'invoice' }
      response = common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq("'0.01' is not a valid Integer")
    end

    e.run_step "Special Char Value - @\#@ :: expected response - 400" do
      hash = { 'page' => '@#@', 'program_group' => 'invoice' }
      response = common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq("'@\#@' is not a valid Integer")
    end

    e.run_step 'Value - Empty :: expected response - 400' do
      hash = { 'page' => '', 'program_group' => 'invoice' }
      response = common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq("'' is not a valid Integer")
    end

    e.run_step 'Value - nil :: expected response - 200' do
      hash = { 'page' => nil, 'program_group' => 'invoice' }
      response = common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 200
    end
  end

  it 'Pending Dues at Entity Level :: vendor_id :: Invalid Value' do |e|
    e.run_step 'Incorrect Value - 232 :: expected response - 200' do
      hash = { 'vendor_id' => 232, 'program_group' => 'invoice' }
      response = common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 200
      expect(response[:body][:investor_vendors]).to eq([])
    end

    e.run_step 'String Value - Invalid :: expected response - 400' do
      hash = { 'vendor_id' => 'Invalid', 'program_group' => 'invoice' }
      response = common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq "'Invalid' is not a valid Integer"
    end

    e.run_step 'Float Value - 0.01 :: expected response - 400' do
      hash = { 'vendor_id' => '0.01', 'program_group' => 'invoice' }
      response = common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq "'0.01' is not a valid Integer"
    end

    e.run_step "Special Char Value - @\#@ :: expected response - 400" do
      hash = { 'vendor_id' => '@#@', 'program_group' => 'invoice' }
      response = common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq("'@\#@' is not a valid Integer")
    end

    e.run_step 'Value - Empty :: expected response - 400' do
      hash = { 'vendor_id' => '', 'program_group' => 'invoice' }
      response = common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq "'' is not a valid Integer"
    end

    e.run_step 'Value - nil :: expected response - 200' do
      hash = { 'vendor_id' => nil, 'program_group' => 'invoice' }
      response = common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 200
    end
  end

  it 'Pending Dues at Entity Level :: investor_id :: Invalid Value' do |e|
    e.run_step 'Incorrect Value - 23221 :: expected response - 200' do
      hash = { 'investor_id' => 23221, 'program_group' => 'invoice' }
      response = common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 200
      expect(response[:body][:investor_vendors]).to eq([])
    end

    e.run_step 'String Value - Invalid :: expected response - 400' do
      hash = { 'investor_id' => 'Invalid', 'program_group' => 'invoice' }
      response = common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq("'Invalid' is not a valid Integer")
    end

    e.run_step 'Float Value - 0.01 :: expected response - 400' do
      hash = { 'investor_id' => '0.01', 'program_group' => 'invoice' }
      response = common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq("'0.01' is not a valid Integer")
    end

    e.run_step "Special Char Value - @\#@ :: expected response - 400" do
      hash = { 'investor_id' => '@#@', 'program_group' => 'invoice' }
      response = common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq("'@\#@' is not a valid Integer")
    end

    e.run_step 'Value - Empty :: expected response - 400' do
      hash = { 'investor_id' => '', 'program_group' => 'invoice' }
      response = common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq("'' is not a valid Integer")
    end

    e.run_step 'Value - nil :: expected response - 200' do
      hash = { 'investor_id' => nil, 'program_group' => 'invoice' }
      response = common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 200
    end
  end
end
