require './spec_helper'
describe 'Vendor Assignment: Assign to other programs', :scf, :commercials, :onboarding do
  before(:all) do
    @anchor_actor = 'anchor'
    @erb_file = File.read("#{Dir.pwd}/test-data/erb/commercials_data.erb")
    @borrowing_document = "#{Dir.pwd}/test-data/attachments/borrowing_document.pdf"
    @created_vendors = []
    @created_dealers = []
  end

  after(:each) do
    delete_channel_partner('Vendor', @created_vendors)
    delete_channel_partner('Dealer', @created_dealers)
  end

  it 'PO Commercials: Assign PO Vendor to Invoice Programs' do |e|
    @program_name = 'PO Financing - Vendor Program'
    @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
    @commercials_data = @testdata['Commercials']
    @commercials_data['GSTN'] = "#{Faker::Number.number(digits: 2)}#{@commercials_data['PAN']}#{Faker::Number.number(digits: 1)}Z#{Faker::Internet.user_name(specifier: 1..1).upcase}"
    @created_vendors << @commercials_data['Entity Name']

    e.run_step 'Add a PO vendor' do
      resp = create_channel_partner(@commercials_data)
      @commercials_data['Name'] = @commercials_data['Entity Name']
      expect(resp[:code]).to eq(200)
    end

    e.run_step 'Verify PO vendor can be assigned Invoice vendor(Same entity type conflict)' do
      @vendor_response = fetch_list_all_vendors('Vendor', @anchor_actor, @commercials_data['Name'])
      @vendor_detail_id = @vendor_response[0][:vendor_detail_id]
      @map_program_values = {
        actor: @anchor_actor,
        program_id: $conf['programs']['Invoice Financing - Vendor'],
        vendor_detail_id: @vendor_detail_id
      }
      resp = map_program(@map_program_values)
      expect(resp[:code]).to eq(200)
    end

    e.run_step 'Verify PO vendor cannot be assigned PO vendor(Same program conflict)' do
      @map_program_values.merge!(program_id: $conf['programs']['PO Financing - Vendor'])
      resp = map_program(@map_program_values)
      expect(resp[:code]).to eq(422)
      expect(resp[:body][:error][:message]).to eq("#{@commercials_data['Name']} is already associated in PO-VENDOR program")
    end

    e.run_step 'Verify PO vendor can be assigned to PO dealer program' do
      @map_program_values.merge!(program_id: $conf['programs']['PO Financing - Dealer'])
      resp = map_program(@map_program_values)
      expect(resp[:code]).to eq(200)
      @created_dealers << @commercials_data['Name']
      @vendor_response = fetch_list_all_vendors('Dealer', @anchor_actor, @commercials_data['Name'])
      expect(@vendor_response.empty?).to eq(false)
    end
  end

  it 'Invoice Commercials: Assign Invoice Vendor to PO Programs' do |e|
    @program_name = 'Invoice Financing - Vendor Program'
    @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
    @commercials_data = @testdata['Commercials']
    @commercials_data['GSTN'] = "#{Faker::Number.number(digits: 2)}#{@commercials_data['PAN']}#{Faker::Number.number(digits: 1)}Z#{Faker::Internet.user_name(specifier: 1..1).upcase}"
    @created_vendors << @commercials_data['Entity Name']

    e.run_step 'Add a Invoice vendor' do
      resp = create_channel_partner(@commercials_data)
      expect(resp[:code]).to eq(200)
    end

    e.run_step 'Verify Invoice vendor can be assigned PO vendor(Same entity type conflict)' do
      @vendor_response = fetch_list_all_vendors('Vendor', @anchor_actor, @commercials_data['Entity Name'])
      @vendor_detail_id = @vendor_response[0][:vendor_detail_id]
      @map_program_values = {
        actor: @anchor_actor,
        program_id: $conf['programs']['PO Financing - Vendor'],
        vendor_detail_id: @vendor_detail_id
      }
      resp = map_program(@map_program_values)
      expect(resp[:code]).to eq(200)
    end

    e.run_step 'Verify Invoice vendor cannot be assigned Invoice vendor(Same program conflict)' do
      @map_program_values.merge!(program_id: $conf['programs']['Invoice Financing - Vendor'])
      resp = map_program(@map_program_values)
      expect(resp[:code]).to eq(422)
      expect(resp[:body][:error][:message]).to eq("#{@commercials_data['Entity Name']} is already associated in INVOICE-VENDOR program")
    end

    e.run_step 'Verify Invoice vendor can be assigned to PO dealer program' do
      @map_program_values.merge!(program_id: $conf['programs']['PO Financing - Dealer'])
      resp = map_program(@map_program_values)
      expect(resp[:code]).to eq(200)
      @created_dealers << @commercials_data['Entity Name']
      @vendor_response = fetch_list_all_vendors('Dealer', @anchor_actor, @commercials_data['Entity Name'])
      expect(@vendor_response.empty?).to eq(false)
    end
  end
end
