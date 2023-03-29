require './spec_helper'
describe 'Create Bulk PO :: POST :: Field Validations', :create_bulk_po, :api_field_validations do
  # Initialization
  common_api = Api::Pages::Common.new
  transactions_page = Pages::Trasactions.new(@driver)
  erb_file = File.read("#{Dir.pwd}/Api/test-data/create_invoices.erb")
  configs = JSON.parse(ERB.new(erb_file).result(binding))['po']['config']
  current_module = 'create_bulk_invoice'
  file = "#{Dir.pwd}/test-data/attachments/po_vendor_transaction_bulk_upload.xlsx"

  it 'Create Bulk PO :: POST :: Valid Inputs' do |e|
    e.run_step 'With all valid inputs :: expected response - 200' do
      transactions_page.generate_po_bulk_invoice('PO - Vendor Program', file)
      field_payload = {
        'Invoice file' => file
      }
      response = common_api.perform_post_action(current_module, {}, field_payload, configs)
      expect(response[:code]).to eq(201)
      status_resp = get_invoice_file_status(configs['program_type'], 'grn_anchor', response[:body][:id])
      expect(status_resp[:code]).to eq(200)
      count = 0
      until status_resp[:body][:state] == 'processed'
        sleep 5
        status_resp = get_invoice_file_status(configs['program_type'], 'grn_anchor', response[:body][:id])
        count += 1
        break if count > 10
      end
      expect(status_resp[:body][:state]).to eq('processed')
      invoice_sheet = Roo::Spreadsheet.open(file).sheet('PO - Vendor Program')
      expected_hash = transactions_page.create_bulk_po_expected_hash(invoice_sheet)
      expect(status_resp[:body][:report_url]).not_to eq(nil), 'Report is not generated'
      expect(status_resp[:body][:report_url].empty?).to eq(false) unless status_resp[:body][:report_url].nil?
      actual_results = transactions_page.verify_summary_report(status_resp[:body][:report_url])
      expect(expected_hash).to eq(actual_results)
      expect(status_resp[:body][:number_of_accepted]).to eq(2)
      expect(status_resp[:body][:number_of_rejected]).to eq(8)
      expect(status_resp[:body][:total_value]).to eq(15_000.0)
    end
  end

  it 'Create Bulk PO :: POST :: Document :: Invalid Inputs' do |e|
    e.run_step 'Invalid value - nil :: expected response - 200' do
      field_payload = {
        'Invoice file' => nil
      }
      response = common_api.perform_post_action(current_module, {}, field_payload, configs)
      expect(response[:code]).to eq(400)
      expect(response[:body][:error][:message]).to eq('Parameter document is required')
    end
    e.run_step 'Invalid value - empty :: expected response - 200' do
      field_payload = {
        'Invoice file' => ''
      }
      response = common_api.perform_post_action(current_module, {}, field_payload, configs)
      expect(response[:code]).to eq(400)
      expect(response[:body][:error][:message]).to eq('Parameter document is required')
    end
  end

  it 'Create Bulk PO :: POST :: Program ID :: Invalid Inputs' do |e|
    e.run_step 'Invalid value - nil :: expected response - 200' do
      transactions_page.generate_po_bulk_invoice('PO - Vendor Program', file)
      field_payload = {
        'Invoice file' => file
      }
      configs['program_id'] = nil
      response = common_api.perform_post_action(current_module, {}, field_payload, configs)
      expect(response[:code]).to eq(400)
      expect(response[:body][:error][:message]).to eq("'' is not a valid Integer")
    end
    e.run_step 'Invalid value - empty :: expected response - 200' do
      transactions_page.generate_po_bulk_invoice('PO - Vendor Program', file)
      field_payload = {
        'Invoice file' => file
      }
      configs['program_id'] = ''
      response = common_api.perform_post_action(current_module, {}, field_payload, configs)
      expect(response[:code]).to eq(400)
      expect(response[:body][:error][:message]).to eq("'' is not a valid Integer")
    end
    e.run_step 'Invalid value - Float value :: expected response - 200' do
      transactions_page.generate_po_bulk_invoice('PO - Vendor Program', file)
      field_payload = {
        'Invoice file' => file
      }
      configs['program_id'] = 1.23
      response = common_api.perform_post_action(current_module, {}, field_payload, configs)
      expect(response[:code]).to eq(400)
      expect(response[:body][:error][:message]).to eq("'1.23' is not a valid Integer")
    end
    e.run_step 'Invalid value - Float value :: expected response - 200' do
      transactions_page.generate_po_bulk_invoice('PO - Vendor Program', file)
      field_payload = {
        'Invoice file' => file
      }
      configs['program_id'] = 'abcd'
      response = common_api.perform_post_action(current_module, {}, field_payload, configs)
      expect(response[:code]).to eq(400)
      expect(response[:body][:error][:message]).to eq("'abcd' is not a valid Integer")
    end
    e.run_step 'Invalid value - Wrong value :: expected response - 200' do
      transactions_page.generate_po_bulk_invoice('PO - Vendor Program', file)
      field_payload = {
        'Invoice file' => file
      }
      configs['program_id'] = 78911
      response = common_api.perform_post_action(current_module, {}, field_payload, configs)
      expect(response[:code]).to eq(400)
      expect(response[:body][:error][:message]).to eq('Invalid request values ["Program not present"] , cannot be accepted!!')
    end
  end

  it 'Get Invoice File status :: GET :: Document :: Invalid Inputs' do |e|
    e.run_step 'Invalid value - Wrong value :: expected response - 500' do
      status_resp = get_invoice_file_status(configs['program_type'], 'grn_anchor', 10_000)
      expect(status_resp[:code]).to eq(500)
      expect(status_resp[:body][:error][:message]).to eq("Couldn't find PurchaseOrderFile")
    end
    e.run_step 'Invalid value - nil :: expected response - 200' do
      status_resp = get_invoice_file_status(configs['program_type'], 'grn_anchor', nil)
      expect(status_resp[:code]).to eq(200)
    end
    e.run_step 'Invalid value - Float value :: expected response - 500' do
      status_resp = get_invoice_file_status(configs['program_type'], 'grn_anchor', '12233.4')
      expect(status_resp[:code]).to eq(500)
      expect(status_resp[:body][:error][:message]).to eq("Couldn't find PurchaseOrderFile")
    end
    e.run_step 'Invalid value - String value :: expected response - 500' do
      status_resp = get_invoice_file_status(configs['program_type'], 'grn_anchor', 'abcd')
      expect(status_resp[:code]).to eq(500)
      expect(status_resp[:body][:error][:message]).to eq("Couldn't find PurchaseOrderFile")
    end
  end
end
