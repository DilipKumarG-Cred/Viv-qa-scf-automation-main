require './spec_helper'
describe 'Repayment Payment History :: GET :: Field Validations', :payment_history, :api_field_validations, :anchor_integration do
  # Initialization
  common_api = Api::Pages::Common.new

  before(:all) do
    @actor = 'grn_anchor'
    @action = 'payment_history'
  end

  it 'Valid Mandatory Parameters' do |e|
    e.run_step 'With only mandatory parameter [payment_type - Repayment] :: expected response - 200' do
      hash = { 'payment_type' => 'Repayment' }
      response = common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 200
      expect(response[:body][:payment_history][0][:payment_type]).to eq 'Repayment'
    end

    e.run_step 'With only mandatory parameter [payment_type - Processing Fee] :: expected response - 200' do
      hash = { 'payment_type' => 'Processing Fee' }
      response = common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 200
    end

    e.run_step 'With only mandatory parameter [payment_type - Settlement] :: expected response - 200' do
      hash = { 'payment_type' => 'Settlement' }
      response = common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 200
    end
  end

  it 'Including valid Optional params' do |e|
    e.run_step 'With all valid parameters :: expected response - 200' do
      hash = {
        'payment_type' => 'Repayment',
        'date_from' => (Date.today - 10).strftime('%Y-%m-%d'),
        'date_to' => Date.today.strftime('%Y-%m-%d')
      }
      response = common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 200
      expect(response[:body][:payment_history][0][:payment_type]).to eq 'Repayment'
    end
  end

  it 'Empty Parameter' do |e|
    e.run_step 'Empty parameter :: expected response - 200' do
      hash = {}
      response = common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 200
    end
  end

  it 'Payment Type :: Invalid Value' do |e|
    e.run_step 'Payment Type :: Incorrect Value - RefundInvalid :: expected response - 400' do
      hash = { 'payment_type' => 'RefundInvalid' }
      response = common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq('Parameter payment_type must be within ["Settlement", "Repayment", "Processing Fee"]')
    end

    e.run_step 'Payment Type :: Float Value - 0.01 :: expected response - 400' do
      hash = { 'payment_type' => '0.01' }
      response = common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq('Parameter payment_type must be within ["Settlement", "Repayment", "Processing Fee"]')
    end

    e.run_step "Payment Type :: Special Char Value - @\#@ :: expected response - 400" do
      hash = { 'payment_type' => '@#@' }
      response = common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq('Parameter payment_type must be within ["Settlement", "Repayment", "Processing Fee"]')
    end

    e.run_step 'Payment Type :: Value - Empty :: expected response - 400' do
      hash = {
        'payment_type' => ''
      }
      response = common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq('Parameter payment_type must be within ["Settlement", "Repayment", "Processing Fee"]')
    end

    e.run_step 'Payment Type :: Value - nil :: expected response - 200' do
      hash = {
        'payment_type' => nil
      }
      response = common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 200
    end
  end

  it 'Date From :: Invalid Value' do |e|
    e.run_step 'date-from :: Incorrect format - dd-mm-yyyy :: expected response - 400' do
      hash = {
        'payment_type' => 'Repayment',
        'date_from' => '21-09-2021',
        'date_to' => '2021-09-30'
      }
      response = common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq('Invalid format/Parameter Missing. Expected format: yyyy-mm-dd')
    end

    e.run_step 'date-from :: Integer value - 2 :: expected response - 400' do
      hash = {
        'payment_type' => 'Repayment',
        'date_from' => '2',
        'date_to' => '2021-09-30'
      }
      response = common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq('Invalid format/Parameter Missing. Expected format: yyyy-mm-dd')
    end

    e.run_step 'date-from :: String value - abcde :: expected response - 400' do
      hash = {
        'payment_type' => 'Repayment',
        'date_from' => 'abcde',
        'date_to' => '2021-09-30'
      }
      response = common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq('Invalid format/Parameter Missing. Expected format: yyyy-mm-dd')
    end

    e.run_step 'date-from :: Empty value :: expected response - 500' do
      hash = {
        'payment_type' => 'Repayment',
        'date_from' => '',
        'date_to' => '2021-09-30'
      }
      response = common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq("'' is not a valid Date")
    end

    e.run_step 'date-from :: value - nil :: expected response - 200' do
      hash = {
        'payment_type' => 'Repayment',
        'date_from' => nil,
        'date_to' => '2021-09-30'
      }
      response = common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 200
    end
  end

  it 'Date To :: Invalid Value' do |e|
    e.run_step 'date-to :: Incorrect format - dd-mm-yyyy :: expected response - 400' do
      hash = {
        'payment_type' => 'Repayment',
        'date_from' => '2021-09-29',
        'date_to' => '30-09-2021'
      }
      response = common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq('Invalid format/Parameter Missing. Expected format: yyyy-mm-dd')
    end

    e.run_step 'date-to :: Integer value - 2 :: expected response - 400' do
      hash = {
        'payment_type' => 'Repayment',
        'date_from' => '2021-09-30',
        'date_to' => '2'
      }
      response = common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq('Invalid format/Parameter Missing. Expected format: yyyy-mm-dd')
    end

    e.run_step 'date-to :: String value - abcde :: expected response - 400' do
      hash = {
        'payment_type' => 'Repayment',
        'date_from' => '2021-09-30',
        'date_to' => 'abcde'
      }
      response = common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq('Invalid format/Parameter Missing. Expected format: yyyy-mm-dd')
    end

    e.run_step 'date-to :: Empty value :: expected response - 400' do
      hash = {
        'payment_type' => 'Repayment',
        'date_from' => '2021-09-30',
        'date_to' => ''
      }
      response = common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq("'' is not a valid Date")
    end

    e.run_step 'date-to :: value - nil :: expected response - 200' do
      hash = {
        'payment_type' => 'Repayment',
        'date_from' => '2021-09-30',
        'date_to' => nil
      }
      response = common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 200
    end
  end
end
