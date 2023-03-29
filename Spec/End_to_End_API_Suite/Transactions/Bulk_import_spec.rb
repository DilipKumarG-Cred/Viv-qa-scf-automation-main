require './spec_helper'
describe 'Transactions: Bulk Import', :scf, :transactions, :bulk_import do
  before(:all) do
    @anchor_actor = 'anchor'
    @vendor_actor = 'vendor'

    @common_api = Api::Pages::Common.new
    @transactions_page = Pages::Trasactions.new(nil)
    @create_invoices_erb_file = File.read("#{Dir.pwd}/Api/test-data/create_invoices.erb")
    @configs = JSON.parse(ERB.new(@create_invoices_erb_file).result(binding))['invoice']['config']
    @current_module = 'create_bulk_invoice'
    @configs['user'] = @anchor_actor
  end

  %i[wrong_headers sheet_mismatch].each do |validation|
    it "Transactions: Bulk Import Validations - #{validation}" do |e|
      file = "#{Dir.pwd}/test-data/attachments/bulk_transactions_wrong_headers.xlsx"
      file = "#{Dir.pwd}/test-data/attachments/bulk_import_inv_vendor.xlsx" if validation == :sheet_mismatch
      e.run_step 'Verify bulk file can be imported' do
        field_payload = {
          'Invoice file' => file
        }
        response = @common_api.perform_post_action(@current_module, {}, field_payload, @configs)
        expect(response[:code]).to eq(201)
        values = { expected_state: 'failed', program_type: @configs['program_type'], actor: @anchor_actor, id: response[:body][:id] }
        wait_till_doc_processed(values)
        @status_resp = get_invoice_file_status(@configs['program_type'], @anchor_actor, response[:body][:id])
        expect(@status_resp[:code]).to eq(200)
        expect(@status_resp[:body][:state]).to eq('failed'), @status_resp[:body][:report_url].to_s
      end

      e.run_step 'Verify error message in report' do
        expect(@status_resp[:body][:report_url].nil?).to eq(false), @status_resp[:body].to_s
        expect(@status_resp[:body][:report_url].empty?).to eq(false), @status_resp[:body].to_s
        actual_results = verify_vendor_import_summary_report(@status_resp[:body][:report_url]).keys
        if validation == :sheet_mismatch
          expect(actual_results[0]).to include 'Sheet name is invalid. Please verify with the existing template.'
        else
          expect(actual_results[0]).to include('Invalid Columns found in the sheet - '), actual_results[0]
          expect(actual_results[0]).to include('Missing Columns found in the sheet - [')
          expect(actual_results[0]).to include('Please verify with the existing template.')
          invalid_columns = ['PO Number', 'PO Value', 'Requested Disbursement Value', 'PO Date', 'Tenor']
          missed_columns = ['Invoice Number', 'Invoice Value', 'Invoice Date', 'GRN (Optional)', 'GRN Date (Optional)', 'EWB No (Optional)', 'EWB Date (Optional)', 'Due Date (Optional)', 'Tenor (Optional)', 'Requested Disbursement Value (Optional)']
          expect(validate_wrong_headers_message(actual_results[0], invalid_columns, missed_columns)).to eq(true)
        end
      end

      e.run_step 'Verify summary report' do
        expect(@status_resp[:body][:number_of_accepted]).to eq(nil)
        expect(@status_resp[:body][:number_of_rejected]).to eq(nil)
        expect(@status_resp[:body][:total_value]).to eq(0.0)
      end
    end
  end

  ['vendor', 'dealer'].each do |actor|
    it "Transactions: Bulk Import by #{actor.upcase}" do |e|
      file = "#{Dir.pwd}/test-data/attachments/invoice_vendor_transaction_bulk_upload.xlsx"
      if actor == 'dealer'
        file = file.gsub('vendor', 'dealer')
        @configs.merge!('program_id' => $conf['programs']['Invoice Financing - Dealer'], 'program_type' => 'Invoice Financing - Dealer')
      end
      e.run_step 'Verify transactions can be bulk imported' do
        generate_bulk_invoice(actor, file)
        field_payload = {
          'Invoice file' => file
        }
        response = @common_api.perform_post_action(@current_module, {}, field_payload, @configs)
        expect(response[:code]).to eq(201)
        values = { expected_state: 'processed', program_type: @configs['program_type'], actor: @anchor_actor, id: response[:body][:id] }
        wait_till_doc_processed(values)
        @status_resp = get_invoice_file_status(@configs['program_type'], @anchor_actor, response[:body][:id])
        expect(@status_resp[:body][:state]).to eq('processed'), @status_resp[:body][:report_url].to_s
      end

      e.run_step 'Verify summmary report is generated' do
        expect(@status_resp[:body][:report_url].nil?).to eq(false), 'report_url key is not found in response'
        expect(@status_resp[:body][:report_url].empty?).to eq(false), 'report_url value is empty in response'
      end

      e.run_step 'Verify Summary report in exported file' do
        sheet_name = actor == 'dealer' ? 'Invoice - Dealer Program' : 'Invoice - Vendor Program'
        invoice_sheet = Roo::Spreadsheet.open(file).sheet(sheet_name)
        expected_hash = create_bulk_invoice_expected_hash(invoice_sheet, actor)
        actual_results = verify_summary_report(@status_resp[:body][:report_url])
        expect(expected_hash).to eq(actual_results)
      end

      e.run_step 'Verify summary report modal after bulk import' do
        if actor == 'vendor'
          expect(@status_resp[:body][:number_of_accepted]).to eq(6)
          expect(@status_resp[:body][:number_of_rejected]).to eq(8)
          expect(@status_resp[:body][:total_value]).to eq(69_000.0)
        else
          expect(@status_resp[:body][:number_of_accepted]).to eq(5)
          expect(@status_resp[:body][:number_of_rejected]).to eq(5)
          expect(@status_resp[:body][:total_value]).to eq(68_000.0)
        end
      end

      e.run_step 'Verify transactions present after bulk upload' do
        invoice_sheet = Roo::Spreadsheet.open(@status_resp[:body][:report_url]).sheet('Sheet1')
        transaction_ids = []
        invoice_sheet.entries[1..5].each { |row| transaction_ids << row[0] }
        queries = { actor: @anchor_actor, category: 'invoices', program_group: 'invoice' }
        transaction_ids.each do |transaction_id|
          expect(api_transaction_listed?(queries, transaction_id)[0]).to eq(true)
        end
      end
    end
  end
end
