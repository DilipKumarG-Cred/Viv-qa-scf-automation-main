require './spec_helper'
describe 'List of Due for Disbursement :: GET :: Field Validations', :funding_history, :api_field_validations, :anchor_integration do
  # Initialization
  common_api = Api::Pages::Common.new

  before(:all) do
    @actor = 'anchor'
    @action = 'due_disbursement'
  end

  it 'Valid Parameters' do |e|
    e.run_step 'Get List due of Disbursement with parameter [program_group - dynamic_discounting] :: expected response - 200' do
      hash = { 'program_group' => 'dynamic_discounting' }
      response = common_api.perform_get_action(@action, hash, @actor)
      p "#{response[:code]}, #{response[:body][:error][:message]}" if response[:code] != 200
      expect(response[:code]).to eq 200
      expect(response[:body][:vendor_list]).not_to eq []
    end
  end
end
