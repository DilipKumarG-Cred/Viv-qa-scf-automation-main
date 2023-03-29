require './spec_helper'
describe 'Disbursement Funding History :: GET :: Field Validations', :funding_history, :api_field_validations, :anchor_integration do
  # Initialization
  common_api = Api::Pages::Common.new

  before(:all) do
    @actor = 'grn_anchor'
    @action = 'funding_history'
  end

  it 'Valid Parameters' do |e|
    e.run_step 'Get Funding History with only mandatory parameter [Payment type - Funding] :: expected response - 200' do
      hash = { 'payment_type' => 'Funding' }
      response = common_api.perform_get_action(@action, hash, @actor)
      p "#{response[:code]}, #{response[:body][:error][:message]}" if response[:code] != 200
      expect(response[:code]).to eq 200
      expect(response[:body][:funding_history][0][:funding_type]).to eq 'Funding'
    end

    e.run_step 'Get Funding History with different parameter [Payment Type - Settlement] :: expected response - 200' do
      hash = { 'payment_type' => 'Settlement' }
      response = common_api.perform_get_action(@action, hash, @actor)
      p "#{response[:code]}, #{response[:body][:error][:message]}" if response[:code] != 200
      expect(response[:code]).to eq 200
    end

    e.run_step 'Get Funding History with parameter [Payment Type - Refund] :: expected response - 200' do
      hash = { 'payment_type' => 'Refund' }
      response = common_api.perform_get_action(@action, hash, @actor)
      p "#{response[:code]}, #{response[:body][:error][:message]}" if response[:code] != 200
      expect(response[:code]).to eq 200
    end

    e.run_step 'Including Optional valid parameters :: expected response - 200' do
      hash = {
        'payment_type' => 'Funding',
        'date_from' => '2021-09-21',
        'date_to' => '2021-09-30'
      }
      response = common_api.perform_get_action(@action, hash, @actor)
      p "#{response[:code]}, #{response[:body][:error][:message]}" if response[:code] != 200
      expect(response[:code]).to eq 200
    end
  end

  it 'Empty Parameter' do |e|
    e.run_step 'Without any parameter :: expected response - 200' do
      hash = {}
      response = common_api.perform_get_action(@action, hash, @actor)
      p "#{response[:code]}, #{response[:body][:error][:message]}" if response[:code] != 200
      expect(response[:code]).to eq 200
    end
  end

  it 'Payment Type :: Invalid Value' do |e|
    e.run_step 'Payment Type :: Incorrect Value - RefundInvalid :: expected response - 400' do
      hash = { 'payment_type' => 'RefundInvalid' }
      response = common_api.perform_get_action(@action, hash, @actor)
      p "#{response[:code]}, #{response[:body][:error][:message]}" if response[:code] != 200
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq('Parameter payment_type must be within ["Funding", "Refund", "Settlement"]')
    end

    e.run_step 'Payment Type :: Float Value - 0.01 :: expected response - 400' do
      hash = { 'payment_type' => '0.01' }
      response = common_api.perform_get_action(@action, hash, @actor)
      p "#{response[:code]}, #{response[:body][:error][:message]}" if response[:code] != 200
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq('Parameter payment_type must be within ["Funding", "Refund", "Settlement"]')
    end

    e.run_step "Payment Type :: Special Char Value - @\#@ :: expected response - 400" do
      hash = { 'payment_type' => '@#@' }
      response = common_api.perform_get_action(@action, hash, @actor)
      p "#{response[:code]}, #{response[:body][:error][:message]}" if response[:code] != 200
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq('Parameter payment_type must be within ["Funding", "Refund", "Settlement"]')
    end

    e.run_step 'Payment Type :: Value - Empty :: expected response - 400' do
      hash = {
        'payment_type' => ''
      }
      response = common_api.perform_get_action(@action, hash, @actor)
      p "#{response[:code]}, #{response[:body][:error][:message]}" if response[:code] != 200
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq('Parameter payment_type must be within ["Funding", "Refund", "Settlement"]')
    end

    e.run_step 'Payment Type :: Value - nil :: expected response - 200' do
      hash = {
        'payment_type' => nil
      }
      response = common_api.perform_get_action(@action, hash, @actor)
      p "#{response[:code]}, #{response[:body][:error][:message]}" if response[:code] != 200
      expect(response[:code]).to eq 200
    end
  end

  it 'Date From :: Invalid Value' do |e|
    e.run_step 'date-from :: Incorrect format - dd-mm-yyyy :: expected response - 400' do
      hash = {
        'payment_type' => 'Funding',
        'date_from' => '21-09-2021',
        'date_to' => '2021-09-30'
      }
      response = common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq('Invalid format/Parameter Missing. Expected format: yyyy-mm-dd')
    end

    e.run_step 'date-from :: Integer value - 2 :: expected response - 400' do
      hash = {
        'payment_type' => 'Funding',
        'date_from' => '2',
        'date_to' => '2021-09-30'
      }
      response = common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq('Invalid format/Parameter Missing. Expected format: yyyy-mm-dd')
    end

    e.run_step 'date-from :: String value - abcde :: expected response - 500' do
      hash = {
        'payment_type' => 'Funding',
        'date_from' => 'abcde',
        'date_to' => '2021-09-30'
      }
      response = common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq('Invalid format/Parameter Missing. Expected format: yyyy-mm-dd')
    end

    e.run_step 'date-from :: Empty value :: expected response - 400' do
      hash = {
        'payment_type' => 'Funding',
        'date_from' => '',
        'date_to' => '2021-09-30'
      }
      response = common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq("'' is not a valid Date")
    end

    e.run_step 'date-from :: value - nil :: expected response - 200' do
      hash = {
        'payment_type' => 'Funding',
        'date_from' => nil,
        'date_to' => '2021-09-30'
      }
      response = common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 200
    end
  end

  it 'Date To :: Invalid Value' do |e|
    e.run_step 'date-to :: Incorrect format - dd-mm-yyyy :: expected response - 500' do
      hash = {
        'payment_type' => 'Funding',
        'date_from' => '2021-09-29',
        'date_to' => '30-09-2021'
      }
      response = common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq('Invalid format/Parameter Missing. Expected format: yyyy-mm-dd')
    end

    e.run_step 'date-from :: Integer value - 2 :: expected response - 500' do
      hash = {
        'payment_type' => 'Funding',
        'date_from' => '2021-09-30',
        'date_to' => '2'
      }
      response = common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq('Invalid format/Parameter Missing. Expected format: yyyy-mm-dd')
    end

    e.run_step 'date-from :: String value - abcde :: expected response - 500' do
      hash = {
        'payment_type' => 'Funding',
        'date_from' => '2021-09-30',
        'date_to' => 'abcde'
      }
      response = common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq('Invalid format/Parameter Missing. Expected format: yyyy-mm-dd')
    end

    e.run_step 'date-from :: Empty value :: expected response - 500' do
      hash = {
        'payment_type' => 'Funding',
        'date_from' => '2021-09-30',
        'date_to' => ''
      }
      response = common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq("'' is not a valid Date")
    end

    e.run_step 'date-from :: value - nil :: expected response - 200' do
      hash = {
        'payment_type' => 'Funding',
        'date_from' => '2021-09-30',
        'date_to' => nil
      }
      response = common_api.perform_get_action(@action, hash, @actor)
      expect(response[:code]).to eq 200
    end
  end
end
