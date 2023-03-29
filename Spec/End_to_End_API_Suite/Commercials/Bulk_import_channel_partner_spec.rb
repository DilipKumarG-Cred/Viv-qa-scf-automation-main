require './spec_helper'
describe 'Channel Partner: Bulk Import', :scf, :commercials, :api_vendor_bulk_import, :onboarding, :bulk do
  before(:all) do
    @created_vendors = []
    @created_dealers = []
    @po_vendors = []
    @po_dealers = []
    @current_module = 'create_bulk_cp'
    erb_file = File.read("#{Dir.pwd}/Api/test-data/create_channel_partner.erb")
    @configs = JSON.parse(ERB.new(erb_file).result(binding))['config']
    @common_api = Api::Pages::Common.new
    @myntra_anchor_actor = 'anchor'
    @tvs_anchor_actor = 'grn_anchor'
  end

  before(:each) do
    flush_directory($download_path)
    delete_channel_partner('Vendor', [['Maruthi Motors', 'PO FINANCING'], ['Dozco', 'PO FINANCING']], @tvs_anchor_actor)
    delete_channel_partner('Dealer', [['Exide', 'PO FINANCING'], ['Ramkay TVS', 'PO FINANCING']], @tvs_anchor_actor)
    delete_channel_partner('Vendor', [['Exide', 'INVOICE FINANCING']], @myntra_anchor_actor)
  end

  after(:each) do
    delete_channel_partner('Vendor', @created_vendors, @myntra_anchor_actor)
    delete_channel_partner('Dealer', @created_dealers, @myntra_anchor_actor)
    delete_channel_partner('Vendor', @po_vendors, @tvs_anchor_actor)
    delete_channel_partner('Dealer', @po_dealers, @tvs_anchor_actor)
    flush_directory($download_path)
  end

  $conf['programs'].each_key do |program|
    next if program == 'Dynamic Discounting - Vendor'

    @type = program.split(' - ')[1]
    it "Bulk Import: #{program} Program" do |e|
      e.run_step 'Bulk import vendor and verify summary report' do
        chosen_program = "#{program} Program"
        @valid_channel_partners, @expected_results, file, _menu = generate_bulk_vendor(chosen_program)
        @anchor_actor = program.include?('PO') ? @tvs_anchor_actor : @myntra_anchor_actor
        @configs['user'] = @anchor_actor
        vendor_hash = { 'actor' => @anchor_actor, 'Program' => program, 'document' => file }
        response = @common_api.perform_post_action(@current_module, {}, vendor_hash, @configs)
        expect(response[:code]).to eq 201
        values = { expected_state: 'processed', program_type: program, actor: @anchor_actor, id: response[:body][:id] }
        wait_till_vendor_import_file_processed(values)
        @status_resp = get_vendor_file_status(@anchor_actor, response[:body][:id])
        expect(@status_resp[:body][:state]).to eq('processed')
      end

      if program.include?('Invoice')
        @type == 'Vendor' ? @created_vendors = @valid_channel_partners : @created_dealers = @valid_channel_partners
      else
        @type == 'Vendor' ? @po_vendors = @valid_channel_partners : @po_dealers = @valid_channel_partners
      end

      e.run_step 'Verify summmary report is generated' do
        expect(@status_resp[:body][:report_url].nil?).to eq(false), 'report_url key is not found in response'
        expect(@status_resp[:body][:report_url].empty?).to eq(false), 'report_url value is empty in response'
      end

      e.run_step 'Verify report file' do
        actual_results = verify_vendor_import_summary_report(@status_resp[:body][:report_url])
        expect(actual_results).to eq(@expected_results)
      end

      e.run_step 'Verify summary report modal after bulk import' do
        summary = program.include?('Invoice') ? [6, 2, 4] : [7, 3, 4]
        expect(@status_resp[:body][:total_vendors]).to eq(summary[0])
        expect(@status_resp[:body][:number_of_accepted]).to eq(summary[1])
        expect(@status_resp[:body][:number_of_rejected]).to eq(summary[2])
      end

      e.run_step 'Verify new vendors present in the vendors list' do
        @valid_channel_partners.each do |channel_partner|
          channel_partner_name = channel_partner.is_a?(Array) ? channel_partner[0] : channel_partner
          @vendor_response = fetch_list_all_vendors(@type, @anchor_actor, channel_partner_name)
          expect(@vendor_response.empty?).to eq(false), "#{channel_partner} is not available in #{@anchor_actor} vendor list"
        end
      end
    end
  end

  %i[wrong_headers sheet_mismatch].each do |validation|
    file = "#{Dir.pwd}/test-data/attachments/bulk_import_wrong_headers.xlsx"
    file = "#{Dir.pwd}/test-data/attachments/bulk_import_inv_vendor.xlsx" if validation == :sheet_mismatch

    it "Bulk Import: Negative Validations #{validation}" do |e|
      e.run_step 'Verify bulk file can be imported' do
        vendor_hash = { 'actor' => @myntra_anchor_actor, 'Program' => 'PO Financing - Vendor Program', 'document' => file }
        response = @common_api.perform_post_action(@current_module, {}, vendor_hash, @configs)
        values = { expected_state: 'failed', program_type: 'PO Financing - Vendor', actor: @myntra_anchor_actor, id: response[:body][:id] }
        wait_till_vendor_import_file_processed(values)
        @status_resp = get_vendor_file_status(@myntra_anchor_actor, response[:body][:id])
        expect(@status_resp[:body][:state]).to eq('failed')
      end

      e.run_step 'Verify summmary report is generated' do
        expect(@status_resp[:body][:report_url].nil?).to eq(false), 'report_url key is not found in response'
        expect(@status_resp[:body][:report_url].empty?).to eq(false), 'report_url value is empty in response'
      end

      e.run_step 'Verify report file' do
        actual_results = verify_vendor_import_summary_report(@status_resp[:body][:report_url]).keys
        if validation == :sheet_mismatch
          expect(actual_results[0]).to eq 'Sheet name is invalid. Please verify with the existing template.'
        else
          expect(actual_results[0]).to include('Invalid Columns found in the sheet - ')
          expect(actual_results[0]).to include('Missing Columns found in the sheet - [')
          expect(actual_results[0]).to include('Please verify with the existing template.')
          invalid_columns = ['GST Number']
          missed_columns = ['GSTN']
          expect(validate_wrong_headers_message(actual_results[0], invalid_columns, missed_columns)).to eq(true)
        end
      end

      e.run_step 'Verify summary modal when Sheet name mismatch' do
        expect(@status_resp[:body][:total_vendors]).to eq(nil)
        expect(@status_resp[:body][:number_of_accepted]).to eq(nil)
        expect(@status_resp[:body][:number_of_rejected]).to eq(nil)
      end
    end
  end

  it 'Bulk Import: Negative Validations - Broken links' do |e|
    $conf['programs'].each_key do |program|
      file_name_lookup = {
        'Invoice Financing - Vendor' => 'invoice_vendor_bulk_upload.xlsx',
        'Invoice Financing - Dealer' => 'invoice_dealer_bulk_upload.xlsx',
        'PO Financing - Vendor' => 'po_vendor_bulk_upload.xlsx',
        'PO Financing - Dealer' => 'po_dealer_bulk_upload.xlsx'
      }
      e.run_step "Verify anchor can able to download template for bulk vendor import - #{program}" do
        values = { program_id: $conf['programs'][program], actor: @myntra_anchor_actor, which_template: 'vendor' }
        @doc_resp = get_document_template(values)
        expect(@doc_resp[:code]).to eq(200), @doc_resp.to_s
        expect(@doc_resp[:body][:file_name]).to eq(file_name_lookup[program])
      end

      e.run_step 'Verify template link is not broken' do
        resp = request_url(@doc_resp[:body][:file_url])
        expect(resp.code).to eq(200), resp.to_s
        expect(resp.headers[:content_type]).to eq('application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
      end
    end
  end
end
