require './spec_helper'
describe 'Create Invoice :: post :: Field Validations', :create_invoice, :api_field_validations do
  # Initialization
  common_api = Api::Pages::Common.new
  erb_file = File.read("#{Dir.pwd}/Api/test-data/create_invoices.erb")
  create_invoice_payload = JSON.parse(ERB.new(erb_file).result(binding))
  non_mandatory_fields = create_invoice_payload['invoice']['config']['non_mandatory_fields']
  configs = create_invoice_payload['invoice']['config']
  current_module = 'create_invoice'

  field_payload = create_invoice_payload['invoice']['create']
  fields = field_payload.keys

  fields.each do |field|
    unless non_mandatory_fields.include? field
      it "Create Invoice :: #{field} :: nil validations" do |e|
        e.run_step "#{field} :: value - null :: expected response - 400" do
          field_payload['Invoice Number'] = "INV#{Faker::Lorem.word.upcase}#{Faker::Number.number}" unless field == 'Invoice Number'
          response = common_api.perform_post_action(current_module, { field => nil }, field_payload, configs)
          if common_api.date_format?(field_payload[field])
            expect(response[:code]).to eq 400
            expect(response[:body][:error][:message]).to include 'Invalid format/Parameter Missing. Expected format: yyyy-mm-dd'
          elsif common_api.gstn_format?(field_payload[field]) && field == 'GSTN of Anchor'
            expect(response[:code]).to eq 400
            expect(response[:body][:error][:message]).to eq 'Parameter anchor_gstn cannot be blank'
          elsif common_api.gstn_format?(field_payload[field]) && field == 'GSTN of Vendor'
            expect(response[:code]).to eq 400
            expect(response[:body][:error][:message]).to eq 'Parameter vendor_gstn cannot be blank'
          elsif field_payload[field].is_a? Float
            expect(response[:code]).to eq 400
            expect(response[:body][:error][:message]).to eq 'Invoice value is required and should be of type float'
          elsif common_api.type_of_data(field_payload[field]) == 'file'
            expect(response[:code]).to eq 422
            expect(response[:body][:error][:message]).to eq 'Invoice file attachment is mandatory'
          else
            expect(response[:code]).to eq 400
            expect(response[:body][:error][:message]).to eq 'Invoice number is required'
          end
        end
      end
      it "Create Invoice :: #{field} :: empty value validations" do |e|
        e.run_step "#{field} :: value - empty :: expected response - 400" do
          field_payload['Invoice Number'] = "INV#{Faker::Lorem.word.upcase}#{Faker::Number.number}" unless field == 'Invoice Number'
          response = common_api.perform_post_action(current_module, { field => '' }, field_payload, configs)
          if common_api.date_format?(field_payload[field])
            expect(response[:code]).to eq 400
            expect(response[:body][:error][:message]).to include 'Invalid format/Parameter Missing. Expected format: yyyy-mm-dd'
          elsif common_api.gstn_format?(field_payload[field]) && field == 'GSTN of Anchor'
            expect(response[:code]).to eq 400
            expect(response[:body][:error][:message]).to eq 'Parameter anchor_gstn cannot be blank'
          elsif common_api.gstn_format?(field_payload[field]) && field == 'GSTN of Vendor'
            expect(response[:code]).to eq 400
            expect(response[:body][:error][:message]).to eq 'Parameter vendor_gstn cannot be blank'
          elsif field_payload[field].is_a? Float
            expect(response[:code]).to eq 400
            expect(response[:body][:error][:message]).to eq 'Invoice value is required and should be of type float'
          elsif common_api.type_of_data(field_payload[field]) == 'file'
            expect(response[:code]).to eq 422
            expect(response[:body][:error][:message]).to eq 'Invoice file attachment is mandatory'
          else
            expect(response[:code]).to eq 400
            expect(response[:body][:error][:message]).to eq 'Invoice number is required'
          end
        end
      end
    end

    data_type = common_api.type_of_data(field_payload[field])
    next if data_type.nil?

    it "Create Invoice :: #{field} :: data type validations" do |e|
      test_string = 'abcd'
      case data_type
      when 'date'
        e.run_step "Date - #{field} :: value - 'abcd' string value :: expected response - 400" do
          field_payload['Invoice Number'] = "INV#{Faker::Lorem.word.upcase}#{Faker::Number.number}"
          response = common_api.perform_post_action(current_module, { field => 'abcd' }, field_payload, configs)
          expect(response[:body][:error][:message]).to include 'Invalid format/Parameter Missing. Expected format: yyyy-mm-dd'
          expect(response[:code]).to eq 400
        end
        e.run_step "Date - #{field} :: value - 123 Integer value :: expected response - 400" do
          field_payload['Invoice Number'] = "INV#{Faker::Lorem.word.upcase}#{Faker::Number.number}"
          response = common_api.perform_post_action(current_module, { field => '12345' }, field_payload, configs)
          expect(response[:body][:error][:message]).to include 'Invalid format/Parameter Missing. Expected format: yyyy-mm-dd'
          expect(response[:code]).to eq 400
        end
      when 'float'
        e.run_step "Float - #{field} :: value - 'abcd' string value :: expected response - 400" do
          field_payload['Invoice Number'] = "INV#{Faker::Lorem.word.upcase}#{Faker::Number.number}"
          response = common_api.perform_post_action(current_module, { field => 'abcd' }, field_payload, configs)
          expect(response[:body][:error][:message]).to eq 'Invoice value is required and should be of type float' if field == 'Invoice Value'
          expect(response[:body][:error][:message]).to eq "'abcd' is not a valid Float" if field == 'GRN'
          expect(response[:code]).to eq 400
        end
        field_value_as_integer = field_payload[field].to_i
        e.run_step "Float - #{field} :: value - #{field_value_as_integer} integer value :: expected response - 200" do
          field_payload['Invoice Number'] = "INV#{Faker::Lorem.word.upcase}#{Faker::Number.number}"
          response = common_api.perform_post_action(current_module, { field => field_value_as_integer }, field_payload, configs)
          expect(response[:code]).to eq 200
        end
      when 'file'
        e.run_step "File - #{field} :: value - 'abcd' string value :: expected response - 400" do
          field_payload['Invoice Number'] = "INV#{Faker::Lorem.word.upcase}#{Faker::Number.number}"
          response = common_api.perform_post_action(current_module, { field => 'abcd' }, field_payload, configs)
          expect(response[:code]).to eq 400
          expect(response[:body][:error][:message]).to eq 'Upload a valid document!'
        end
      when 'gstn'
        response_validation_text = field == 'GSTN of Anchor' ? 'anchor_gstn' : 'vendor_gstn'
        e.run_step "GSTN - #{field} :: value - 'abcd' string value :: expected response - 400" do
          field_payload['Invoice Number'] = "INV#{Faker::Lorem.word.upcase}#{Faker::Number.number}"
          response = common_api.perform_post_action(current_module, { field => 'abcd' }, field_payload, configs)
          expect(response[:body][:error][:message]).to include "Parameter #{response_validation_text} must match format (?-mix:\\d{2}[A-Z]{5}\\d{4}[A-Z]{1}[A-Z\\d]{1}[Z]{1}[A-Z\\d]{1})"
          expect(response[:code]).to eq 400
        end
        e.run_step "GSTN - #{field} :: value - 1.5 Float value :: expected response - 400" do
          field_payload['Invoice Number'] = "INV#{Faker::Lorem.word.upcase}#{Faker::Number.number}"
          response = common_api.perform_post_action(current_module, { field => 1.5 }, field_payload, configs)
          expect(response[:body][:error][:message]).to include "Parameter #{response_validation_text} must match format (?-mix:\\d{2}[A-Z]{5}\\d{4}[A-Z]{1}[A-Z\\d]{1}[Z]{1}[A-Z\\d]{1})"
          expect(response[:code]).to eq 400
        end
        if field == 'GSTN of Anchor'
          wrong_gstn = '17ABCDH0940E1ZV'
          e.run_step "GSTN - #{field} :: wrong gstn  - #{wrong_gstn} value :: expected response - 400" do
            response = common_api.perform_post_action(current_module, { field => wrong_gstn }, field_payload, configs)
            expect(response[:body][:error][:message]).to include 'GSTN not matching the logged in entity'
            expect(response[:code]).to eq 422
          end
        elsif field == 'GSTN of Vendor'
          wrong_gstn = '54MCAZU0940F1ZV'
          e.run_step "GSTN - #{field} :: wrong gstn  - #{wrong_gstn} value :: expected response - 400" do
            response = common_api.perform_post_action(current_module, { field => wrong_gstn }, field_payload, configs)
            expect(response[:body][:error][:message]).to include('Commercial not signed with Investor & Vendor under this Anchor Program')
            expect(response[:code]).to eq 422
          end
        end
      end
    end
  end
end
