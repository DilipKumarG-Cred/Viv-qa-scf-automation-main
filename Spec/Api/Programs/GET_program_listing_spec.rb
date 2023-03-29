require './spec_helper'
describe 'Program Listing :: GET :: Field Validations', :program_listing, :api_field_validations do
  before(:all) do
    @common_api = Api::Pages::Common.new
    @actor = 'grn_anchor'
  end

  it 'Valid Parameters' do |e|
    e.run_step 'Positive Scenario :: expected response - 200' do
      program = get_anchor_program('Invoice Financing - Vendor', @actor)
      expect(program[0][:id]).to eq(5)
    end
  end
end
