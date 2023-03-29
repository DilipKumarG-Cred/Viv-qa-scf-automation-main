require './spec_helper'
describe 'Create Channel Partner :: POST :: Field Validations', :create_cp, :create_bulk_cp, :api_field_validations do
  # Initialization
  common_api = Api::Pages::Common.new
  erb_file = File.read("#{Dir.pwd}/Api/test-data/create_channel_partner.erb")
  configs = JSON.parse(ERB.new(erb_file).result(binding))['config']
  current_module = 'create_bulk_cp'

  before(:all) do
    @valid_vendors = []
    @commercials_page = Pages::Commercials.new(@driver)
    delete_channel_partner('Vendor', [['Exide', 'INVOICE FINANCING']], 'grn_anchor')
  end

  after(:each) do
    delete_channel_partner('Vendor', @valid_vendors, 'grn_anchor')
  end

  it 'Bulk Upload - Invoice Financing - Vendor Program' do |e|
    e.run_step 'With all valid inputs :: expected response - 200' do
      program = 'Invoice Financing - Vendor Program'
      @valid_vendors, expected_hash, file, _menu = @commercials_page.generate_bulk_vendor(program)
      vendor_hash = {
        'actor' => 'grn_anchor',
        'Program' => program,
        'document' => file
      }
      response = common_api.perform_post_action(current_module, {}, vendor_hash, configs)
      expect(response[:code]).to eq 201
      sleep 2
      status_resp = get_vendor_file_status('grn_anchor', response[:body][:id])
      expect(status_resp[:code]).to eq 200
      count = 0
      until status_resp[:body][:state] == 'processed'
        sleep 5
        status_resp = get_vendor_file_status('grn_anchor', response[:body][:id])
        count += 1
        break if count > 10
      end
      expect(status_resp[:body][:state]).to eq('processed')
      expect(status_resp[:body][:total_vendors]).to eq(6)
      expect(status_resp[:body][:number_of_accepted]).to eq(2)
      expect(status_resp[:body][:number_of_rejected]).to eq(4)
      actual_results = @commercials_page.verify_vendor_import_summary_report(status_resp[:body][:report_url])
      expect(expected_hash).to eq(actual_results)
    end
  end

  it 'Bulk Upload - Invalid values [document]' do |e|
    e.run_step 'Invalid value - nil :: expected response - 400' do
      program = 'Invoice Financing - Vendor Program'
      vendor_hash = {
        'actor' => 'grn_anchor',
        'Program' => program,
        'document' => nil
      }
      response = common_api.perform_post_action(current_module, {}, vendor_hash, configs)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq 'Parameter document is required'
    end

    e.run_step 'Invalid value - empty :: expected response - 400' do
      program = 'Invoice Financing - Vendor Program'
      vendor_hash = {
        'actor' => 'grn_anchor',
        'Program' => program,
        'document' => ''
      }
      response = common_api.perform_post_action(current_module, {}, vendor_hash, configs)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq 'Parameter document is required'
    end
  end

  it 'Bulk Upload - Invalid values [program]' do |e|
    e.run_step 'Invalid Value - Wrong Program :: expected response - 200' do
      program = 'Invoice Financing - Vendor Program'
      @valid_vendors, _expected_hash, file, _menu = @commercials_page.generate_bulk_vendor(program)
      vendor_hash = {
        'actor' => 'grn_anchor',
        'Program' => program,
        'document' => file
      }
      response = common_api.perform_post_action(current_module, { 'Program' => 'PO Financing - Vendor Program' },
                                                vendor_hash, configs)
      expect(response[:code]).to eq 201
      sleep 2
      status_resp = get_vendor_file_status('grn_anchor', response[:body][:id])
      expect(status_resp[:code]).to eq 200
      count = 0
      until status_resp[:body][:state] == 'failed'
        sleep 5
        status_resp = get_vendor_file_status('grn_anchor', response[:body][:id])
        count += 1
        break if count > 10
      end
      expect(status_resp[:body][:state]).to eq('failed')
      expect(status_resp[:body][:total_vendors]).to eq(nil)
      expect(status_resp[:body][:number_of_accepted]).to eq(nil)
      expect(status_resp[:body][:number_of_rejected]).to eq(nil)
    end

    e.run_step 'Invalid Value - nil :: expected response - 200' do
      program = 'Invoice Financing - Vendor Program'
      @valid_vendors, _expected_hash, file, _menu = @commercials_page.generate_bulk_vendor(program)
      vendor_hash = {
        'actor' => 'grn_anchor',
        'Program' => program,
        'document' => file
      }
      response = common_api.perform_post_action(current_module, { 'Program' => nil }, vendor_hash, configs)
      expect(response[:code]).to eq 400
      expect(response[:body][:error][:message]).to eq("'' is not a valid Integer")
    end

    e.run_step "Invalid Value - '550000' :: expected response - 400" do
      program = 'Invoice Financing - Vendor Program'
      @valid_vendors, _expected_hash, file, _menu = @commercials_page.generate_bulk_vendor(program)
      vendor_hash = {
        'actor' => 'grn_anchor',
        'Program' => program,
        'document' => file
      }
      response = common_api.perform_post_action(current_module, { 'Program' => '550000' }, vendor_hash, configs)
      expect(response[:code]).to eq 400
    end
  end

  it 'Bulk Upload - File Status GET API Validation' do |e|
    e.run_step 'Invalid Value - empty :: expected response - 500' do
      status_resp = get_vendor_file_status('grn_anchor', '')
      expect(status_resp[:code]).to eq(204)
    end

    e.run_step "Invalid Value - 'abcde' :: expected response - 500" do
      status_resp = get_vendor_file_status('grn_anchor', 'abcde')
      expect(status_resp[:code]).to eq(500)
      expect(status_resp[:body][:error][:message]).to eq("Couldn't find VendorFile")
    end

    e.run_step "Invalid Value - '1543534' :: expected response - 500" do
      status_resp = get_vendor_file_status('grn_anchor', '1543534')
      expect(status_resp[:code]).to eq(500)
      expect(status_resp[:body][:error][:message]).to eq("Couldn't find VendorFile")
    end
  end
end
