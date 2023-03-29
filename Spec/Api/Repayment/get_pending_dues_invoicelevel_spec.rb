require './spec_helper'
describe 'Pending Dues at Invoice Level :: GET :: Field Validations', :pending_dues, :api_field_validations, :anchor_integration do
  # Initialization
  common_api = Api::Pages::Common.new

  before(:all) do
    @actor = 'anchor'
    @action = 'pending_dues_invoice'
  end

  it 'Pending Dues at Invoice Level :: Valid Parameters' do |e|
    e.run_step 'With all valid params :: expected response - 200' do
      hash = {
        'program_id' => 1,
        'vendor_id' => 1,
        'investor_id' => 2
      }
      response = common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 200
    end
  end

  it 'Pending Dues at Invoice Level :: Empty/Missing Parameter' do |e|
    e.run_step 'Missing parameter :: program_id :: expected response - 400' do
      hash = { 'investor_id' => 2, 'vendor_id' => 1 }
      response = common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq 'Parameter program_id is required'
    end

    e.run_step 'Missing parameter :: investor_id :: expected response - 400' do
      hash = {
        'program_id' => 1
      }
      response = common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq 'Parameter investor_id is required'
    end

    e.run_step 'Missing parameter :: vendor_id :: expected response - 400' do
      hash = {
        'program_id' => 1,
        'investor_id' => 2
      }
      response = common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq 'Parameter vendor_id is required'
    end

    e.run_step 'Missing parameter :: investor_id :: expected response - 400' do
      hash = {}
      response = common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq 'Parameter investor_id is required'
    end
  end

  it 'Pending Dues at Invoice Level :: program_id :: Invalid Value' do |e|
    e.run_step 'Incorrect Value - 32131 :: expected response - 200' do
      hash = {
        'program_id' => 32131,
        'vendor_id' => 1,
        'investor_id' => 2
      }
      response = common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 200
      expect(response[:body][:invoice_transactions]).to eq([])
    end

    e.run_step 'String Value - Invalid :: expected response - 400' do
      hash = {
        'program_id' => 'Invalid',
        'vendor_id' => 1,
        'investor_id' => 2
      }
      response = common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq "'Invalid' is not a valid Integer"
    end

    e.run_step 'Float Value - 0.01 :: expected response - 400' do
      hash = {
        'program_id' => '0.01',
        'vendor_id' => 1,
        'investor_id' => 2
      }
      response = common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq "'0.01' is not a valid Integer"
    end

    e.run_step "Special Char Value - @\#@ :: expected response - 400" do
      hash = {
        'program_id' => '@#@',
        'vendor_id' => 1,
        'investor_id' => 2
      }
      response = common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq("'@\#@' is not a valid Integer")
    end

    e.run_step 'Value - Empty :: expected response - 400' do
      hash = {
        'program_id' => '',
        'vendor_id' => 1,
        'investor_id' => 2
      }
      response = common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq "'' is not a valid Integer"
    end

    e.run_step 'Value - nil :: expected response - 400' do
      hash = {
        'program_id' => nil,
        'vendor_id' => 1,
        'investor_id' => 2
      }
      response = common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq('Parameter program_id is required')
    end
  end

  it 'Pending Dues at Invoice Level :: vendor_id :: Invalid Value' do |e|
    e.run_step 'Incorrect Value - 2322 :: expected response - 200' do
      hash = { 'vendor_id' => 2322, 'program_id' => 1, 'investor_id' => 2 }
      response = common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 200
      expect(response[:body][:invoice_transactions]).to eq([])
    end

    e.run_step 'String Value - Invalid :: expected response - 400' do
      hash = { 'vendor_id' => 'Invalid', 'program_id' => 1, 'investor_id' => 2 }
      response = common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq "'Invalid' is not a valid Integer"
    end

    e.run_step 'Float Value - 0.01 :: expected response - 400' do
      hash = { 'vendor_id' => '0.01', 'program_id' => 1, 'investor_id' => 2 }
      response = common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq "'0.01' is not a valid Integer"
    end

    e.run_step "Special Char Value - @\#@ :: expected response - 400" do
      hash = { 'vendor_id' => '@#@', 'program_id' => 1, 'investor_id' => 2 }
      response = common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq("'@\#@' is not a valid Integer")
    end

    e.run_step 'Value - Empty :: expected response - 400' do
      hash = { 'vendor_id' => '', 'program_id' => 1, 'investor_id' => 2 }
      response = common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq("'' is not a valid Integer")
    end

    e.run_step 'Value - nil :: expected response - 400' do
      hash = { 'vendor_id' => nil, 'program_id' => 1, 'investor_id' => 2 }
      response = common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq('Parameter vendor_id is required')
    end
  end

  it 'Pending Dues at Invoice Level :: investor_id :: Invalid Value' do |e|
    e.run_step 'Incorrect Value - 23221 :: expected response - 200' do
      hash = { 'investor_id' => 23221, 'vendor_id' => 1, 'program_id' => 1 }
      response = common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 200
      expect(response[:body][:invoice_transactions]).to eq([])
    end

    e.run_step 'String Value - Invalid :: expected response - 400' do
      hash = { 'investor_id' => 'Invalid', 'vendor_id' => 1, 'program_id' => 1 }
      response = common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq "'Invalid' is not a valid Integer"
    end

    e.run_step 'Float Value - 0.01 :: expected response - 400' do
      hash = { 'investor_id' => '0.01', 'vendor_id' => 1, 'program_id' => 1 }
      response = common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq "'0.01' is not a valid Integer"
    end

    e.run_step "Special Char Value - @\#@ :: expected response - 400" do
      hash = { 'investor_id' => '@#@', 'vendor_id' => 1, 'program_id' => 1 }
      response = common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq("'@\#@' is not a valid Integer")
    end

    e.run_step 'Value - Empty :: expected response - 400' do
      hash = { 'investor_id' => '', 'vendor_id' => 1, 'program_id' => 1 }
      response = common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq "'' is not a valid Integer"
    end

    e.run_step 'Value - nil :: expected response - 400' do
      hash = { 'investor_id' => nil, 'vendor_id' => 1, 'program_id' => 1 }
      response = common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq('Parameter investor_id is required')
    end
  end
end
