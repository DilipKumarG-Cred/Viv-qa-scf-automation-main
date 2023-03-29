module Utils
  module XLS
    def generate_bulk_import_vendor_csv(file, program)
      valid_vendors = []
      excel = RubyXL::Parser.parse(file)
      case program
      when 'Invoice Financing - Vendor Program'
        valid_vendors = [['Exide', 'INVOICE FINANCING']]
        sheet = excel['Invoice Financing']
      when 'Invoice Financing - Dealer Program'
        valid_vendors = [['Maruthi Motors', 'INVOICE FINANCING']]
        sheet = excel['Invoice Financing']
      when 'PO Financing - Vendor Program'
        valid_vendors = [['Maruthi Motors', 'PO FINANCING']]
        sheet = excel['PO Financing']
      when 'PO Financing - Dealer Program'
        valid_vendors = [['Exide', 'PO FINANCING']]
        sheet = excel['PO Financing']
      end
      name = "#{Faker::Name.first_name} #{Faker::Name.last_name.gsub("'", '')}"
      valid_vendors << name # Vendor name for cleanup data
      email = "#{Faker::Internet.user_name(specifier: 5..5)}@yopmail.com"
      pan = "#{Faker::Internet.user_name(specifier: 3..3).upcase}P#{Faker::Internet.user_name(specifier: 1..1).upcase}#{Faker::Number.number(digits: 4)}R"
      gstn = "#{Faker::Number.number(digits: 2)}#{pan}#{Faker::Number.number(digits: 1)}Z#{Faker::Internet.user_name(specifier: 1..1).upcase}"
      # We are modifying only 3rd row to new value for valid vendor.. all other rows are set to throw errors
      sheet.add_cell(3, 0, name)
      sheet.add_cell(3, 1, email)
      sheet.add_cell(3, 2, gstn)
      sheet.add_cell(4, 0, nil) # patch for nil value column handling
      ##################################################### expected hash to verify
      expected_hash = {
        sheet.sheet_data[1][0].value => ['failed', 'Invalid data - Campus Sutra is already associated in INVOICE-VENDOR program'],
        sheet.sheet_data[2][0].value => ['uploaded', ''],
        sheet.sheet_data[3][0].value => ['uploaded', ''],
        sheet.sheet_data[4][0].value => ['failed', 'Invalid name'],
        sheet.sheet_data[5][0].value => ['failed', 'Invalid email'],
        sheet.sheet_data[6][0].value => ['failed', 'Invalid gstn']
      }
      case program
      when 'Invoice Financing - Dealer Program'
        expected_hash.merge!(
          sheet.sheet_data[1][0].value => ['failed', 'Invalid data - Trends is already associated in INVOICE-DEALER program']
        )
      when 'PO Financing - Vendor Program'
        expected_hash.merge!(
          sheet.sheet_data[1][0].value => ['uploaded', ''],
          sheet.sheet_data[2][0].value => ['failed', 'Invalid data - MRF Tyres is already associated in PO-VENDOR program'],
          sheet.sheet_data[7][0].value => ['uploaded', '']
        )
      when 'PO Financing - Dealer Program'
        expected_hash.merge!(
          sheet.sheet_data[1][0].value => ['uploaded', ''],
          sheet.sheet_data[2][0].value => ['failed', 'Invalid data - Maruthi Motors is already associated in PO-DEALER program'],
          sheet.sheet_data[7][0].value => ['uploaded', '']
        )
      end
      ##########################################################
      excel.save
      [valid_vendors, expected_hash]
    end

    def generate_bulk_import_dd_vendor_csv(file, _program)
      valid_vendors = []
      excel = RubyXL::Parser.parse(file)
      sheet = excel['Dynamic Discounting']
      (2..4).each do |x| # modify 2nd, 3rd, 4th row..  bank details true, false and empty values(implicitly false)
        name = "#{Faker::Name.first_name} #{Faker::Name.last_name.gsub("'", '')}"
        valid_vendors << name # Vendor name for cleanup data
        email = "#{Faker::Internet.user_name(specifier: 5..5)}@yopmail.com"
        pan = "#{Faker::Internet.user_name(specifier: 3..3).upcase}P#{Faker::Internet.user_name(specifier: 1..1).upcase}#{Faker::Number.number(digits: 4)}R"
        gstn = "#{Faker::Number.number(digits: 2)}#{pan}#{Faker::Number.number(digits: 1)}Z#{Faker::Internet.user_name(specifier: 1..1).upcase}"
        gst = Faker::Number.number(digits: 2)

        sheet.add_cell(x, 0, name)
        sheet.add_cell(x, 1, email)
        sheet.add_cell(x, 2, gstn)
        sheet.add_cell(x, 7, gst)
      end
      ##################################################### expected hash to verify
      expected_hash = {
        sheet.sheet_data[1][0].value => ['failed', 'Invalid data - Tyka is already associated in DYNAMIC_DISCOUNTING-VENDOR program'],
        sheet.sheet_data[2][0].value => ['uploaded', ''],
        sheet.sheet_data[3][0].value => ['uploaded', ''],
        sheet.sheet_data[4][0].value => ['uploaded', ''],
        sheet.sheet_data[5][0].value => ['failed', 'Invalid name'],
        sheet.sheet_data[6][0].value => ['failed', 'Invalid email'],
        sheet.sheet_data[7][0].value => ['failed', 'Invalid gstn'],
        sheet.sheet_data[8][0].value => ['failed', 'Invalid gst']
      }
      ##########################################################
      excel.save
      valid_vendors.flatten!
      [valid_vendors, expected_hash]
    end

    def generate_bulk_vendor(program)
      case program
      when 'Invoice Financing - Vendor Program'
        file = "#{Dir.pwd}/test-data/attachments/bulk_import_inv_vendor.xlsx"
        menu = 'Vendors'
      when 'Invoice Financing - Dealer Program'
        file = "#{Dir.pwd}/test-data/attachments/bulk_import_inv_dealer.xlsx"
        menu = 'Dealers'
      when 'PO Financing - Vendor Program'
        file = "#{Dir.pwd}/test-data/attachments/bulk_import_po_vendor.xlsx"
        menu = 'Vendors'
      when 'PO Financing - Dealer Program'
        file = "#{Dir.pwd}/test-data/attachments/bulk_import_po_dealer.xlsx"
        menu = 'Dealers'
      when 'Dynamic Discounting - Vendor Program'
        file = "#{Dir.pwd}/test-data/attachments/bulk_import_dd_vendor.xlsx"
        menu = 'Vendors'
      end
      if program == 'Dynamic Discounting - Vendor Program'
        valid_vendors, expected_hash = generate_bulk_import_dd_vendor_csv(file, program)
      else
        valid_vendors, expected_hash = generate_bulk_import_vendor_csv(file, program)
      end
      [valid_vendors, expected_hash, file, menu]
    end

    def verify_vendor_import_summary_report(file = "#{$download_path}/report.xlsx")
      invoice_file = Roo::Spreadsheet.open(file)
      invoice_sheet = invoice_file.sheet('Sheet1')
      actual_results = {}
      invoice_sheet.entries[1..-1].each do |x|
        actual_results[x[0]] = [x[3], x[4]]
      end
      actual_results
    end

    def generate_bulk_invoice(type, file, _records = 10)
      excel = RubyXL::Parser.parse(file)
      sheet = if type == 'dealer'
                excel['Invoice - Dealer Program']
              else
                excel['Invoice - Vendor Program']
              end
      total_rows = sheet.sheet_data.rows.size
      date = Date.today.strftime('%d-%b-%Y')
      total_rows.times do |row|
        next if row.zero? # header row

        @invoice_number = "INV#{Faker::Lorem.word.upcase}#{Faker::Number.number}"
        sheet.add_cell(row, 0, @invoice_number) unless row == 6 # for null invoice number
        sheet.add_cell(row, 2, date) unless row == 8 # for null invoice date
        sheet.add_cell(row, 8, date) unless row == 4 # for null ewb date
        sheet.add_cell(row, 6, date) unless row == 5 # for null grn date
        case type
        when 'anchor', 'vendor'
          sheet.add_cell(row, 3, $conf['myntra_gstn']) unless row == 9 # for anchor gstn and row condition for invalid GSTN
          sheet.add_cell(row, 4, $conf['libas_gstn']) unless row == 10 # for counterparty gstn and row condition for invalid GSTN
        when 'dealer'
          sheet.add_cell(row, 3, $conf['myntra_gstn']) unless row == 9 # for dealer gstn and row condition for invalid GSTN
          sheet.add_cell(row, 4, $conf['trends_gstn'])
          sheet.add_cell(row, 4, '99ABREE1288F8ZY') if row == 10 # for counterparty gstn and row condition for invalid GSTN
        when 'grn_anchor', 'grn_vendor'
          sheet.add_cell(row, 3, $conf['tvs_gstn']) unless row == 9 # for GRN anchor gstn and row condition for invalid GSTN
          sheet.add_cell(row, 4, $conf['dozco_gstn']) unless row == 10 # for GRN counterparty gstn and row condition for invalid GSTN
        end
      end
      excel.save
    end

    # PO Bulk transactions
    def add_po_bulk_transaction(type, program, instrument = 'PO')
      case type
      when 'grn_anchor', 'po_vendor'
        file = "#{Dir.pwd}/test-data/attachments/po_vendor_transaction_bulk_upload.xlsx"
      when 'po_dealer'
        file = "#{Dir.pwd}/test-data/attachments/po_dealer_transaction_bulk_upload.xlsx"
      end
      generate_po_bulk_invoice(type, file)
      @common_pages.click_menu(MENU_PO_FINANCING)
      @tarspect_methods.click_button('Add Transaction')
      @tarspect_methods.wait_for_loader_to_disappear
      @initiate_transaction_page.wait_for_element
      select_transaction_program(program, 1)
      select_transaction_program(instrument, 2)
      @file_input2.fill_without_clear file
      @extra_wait.until { @uploading_btn.element.nil? == true }
      @tarspect_methods.BUTTON('close').wait_for_element
      invoice_file = Roo::Spreadsheet.open(file)
      invoice_sheet = if type == 'po_dealer'
                        invoice_file.sheet('PO - Dealer Program')
                      else
                        invoice_file.sheet('PO - Vendor Program')
                      end
      create_bulk_po_expected_hash(invoice_sheet)
    end

    def create_bulk_po_expected_hash(invoice_sheet)
      {
        invoice_sheet.entries[1][0] => ['uploaded', '', ''],
        invoice_sheet.entries[2][0] => ['uploaded', '', 'Failed to upload Invoice Image'],
        invoice_sheet.entries[3][0] => ['failed', 'Invalid po_number', ''],
        invoice_sheet.entries[4][0] => ['failed', 'Invalid po_value', ''],
        invoice_sheet.entries[5][0] => ['failed', 'Invalid po_eligible_value', ''],
        invoice_sheet.entries[6][0] => ['failed', 'Invalid po_date', ''],
        invoice_sheet.entries[7][0] => ['failed', 'Unable to find Anchor from the GSTN provided', ''],
        invoice_sheet.entries[8][0] => ['failed', 'Unable to find Vendor from the GSTN provided', ''],
        invoice_sheet.entries[9][0] => ['failed', 'GSTN not matching the logged in entity', ''],
        invoice_sheet.entries[10][0] => ['failed', 'Invalid vendor_gstn', '']
      }
    end

    def generate_po_bulk_invoice(type, file, _records = 10)
      excel = RubyXL::Parser.parse(file)
      sheet = if type == 'po_dealer'
                excel['PO - Dealer Program']
              else
                excel['PO - Vendor Program']
              end
      total_rows = sheet.sheet_data.rows.size
      date = Date.today.strftime('%d-%b-%Y')
      total_rows.times do |row|
        next if [0, 9, 10].include? row # header row and empty GSTN values

        po_number = "PO#{Faker::Lorem.word.upcase}#{Faker::Number.number}"
        sheet.add_cell(row, 0, po_number) unless row == 3 # for null invoice number
        sheet.add_cell(row, 3, date) unless row == 6 # for null invoice date
        sheet.add_cell(row, 4, $conf['users']['grn_anchor']['gstn']) unless row == 7 # for invalid anchor GSTN
        case type
        when 'grn_anchor', 'po_vendor'
          sheet.add_cell(row, 5, $conf['users']['po_vendor']['gstn']) unless row == 8 # for invalid vendor GSTN
        when 'po_dealer'
          sheet.add_cell(row, 5, $conf['users']['po_dealer']['gstn']) unless row == 8 # for invalid vendor GSTN
        end
      end
      excel.save
    end

    # DD Bulk transactions
    def add_dd_bulk_transaction
      file = "#{Dir.pwd}/test-data/attachments/dd_vendor_transaction_bulk_upload.xlsx"
      generate_dd_bulk_invoice(file)
      @tarspect_methods.click_button('Add Transaction')
      @initiate_transaction_page.wait_for_element
      select_transaction_program('Dynamic Discounting - Vendor')
      @file_input2.fill_without_clear file
      @extra_wait.until { @uploading_btn.element.nil? == true }
      @tarspect_methods.BUTTON('close').wait_for_element
      invoice_file = Roo::Spreadsheet.open(file)
      create_bulk_dd_invoice_expected_hash(invoice_file)
    end

    def create_bulk_dd_invoice_expected_hash(invoice_file)
      invoice_sheet = invoice_file.sheet('Dynamic Discounting - Vendor')
      {
        invoice_sheet.entries[1][0] => ['uploaded', '', ''],
        invoice_sheet.entries[2][0] => ['uploaded', '', 'Failed to upload Invoice Image'],
        invoice_sheet.entries[3][0] => ['failed', 'Invalid invoice_number', ''],
        invoice_sheet.entries[4][0] => ['failed', 'Invalid invoice_value', ''],
        invoice_sheet.entries[5][0] => ['failed', 'Invalid invoice_date', ''],
        invoice_sheet.entries[6][0] => ['failed', 'Unable to find Anchor from the GSTN provided', ''],
        invoice_sheet.entries[7][0] => ['failed', 'Unable to find Vendor from the GSTN provided', ''],
        invoice_sheet.entries[8][0] => ['failed', 'Invalid anchor_gstn', ''],
        invoice_sheet.entries[9][0] => ['failed', 'Invalid vendor_gstn', ''],
        invoice_sheet.entries[10][0] => ['failed', 'Invalid discount', ''],
        invoice_sheet.entries[11][0] => ['failed', 'Invalid tds', ''],
        invoice_sheet.entries[12][0] => ['failed', 'Desired date cannot be more than invoice due date', ''],
        invoice_sheet.entries[13][0] => ['failed', 'Invalid due_date', ''],
        invoice_sheet.entries[14][0] => ['failed', 'Invalid desired_date', '']
      }
    end

    def generate_dd_bulk_invoice(file)
      excel = RubyXL::Parser.parse(file)
      sheet = excel['Dynamic Discounting - Vendor']
      total_rows = sheet.sheet_data.rows.size
      date = Date.today.strftime('%d-%b-%Y')
      due_date = (Date.today + 30).strftime('%d-%b-%Y')
      desired_date = (Date.today + 10).strftime('%d-%b-%Y')
      total_rows.times do |row|
        next if [0, 8, 9].include? row # header row and empty GSTN values

        invoice_number = "INV#{Faker::Lorem.word.upcase}#{Faker::Number.number}"
        sheet.add_cell(row, 0, invoice_number) unless row == 3 # for null invoice number
        sheet.add_cell(row, 2, date) unless row == 5 # for null invoice date
        sheet.add_cell(row, 3, $conf['users']['anchor']['gstn']) unless row == 6 # for invalid anchor GSTN
        sheet.add_cell(row, 4, $conf['users']['dd_vendor']['gstn']) unless row == 7 # for invalid vendor GSTN
        sheet.add_cell(row, 5, due_date) unless row == 13 # for empty due date
        sheet.add_cell(row, 6, desired_date) unless row == 14 # for empty desired date
        sheet.add_cell(row, 6, (Date.today + 40).strftime('%d-%b-%Y')) if row == 12 # for desired date greater that due date
      end
      excel.save
    end

    def verify_summary_report(file = "#{$download_path}/report.xlsx")
      invoice_file = Roo::Spreadsheet.open(file)
      invoice_sheet = invoice_file.sheet('Sheet1')
      actual_results = {}
      invoice_sheet.entries[1..-1].each do |x|
        remarks = x[5].nil? ? '' : x[5]
        actual_results[x[1]] = [x[3], x[4], remarks]
      end
      actual_results
    end

    # imported grn transcations
    def imported_grn_transactions(page:)
      file = "#{Dir.pwd}/test-data/attachments/invoice_vendor_transaction_bulk_upload.xlsx"
      uploaded_file = Roo::Spreadsheet.open(file)
      uploaded_sheet = uploaded_file.sheet('Invoice - Vendor Program')
      ids = []
      transaction_details = []
      grn_optional_index = uploaded_sheet.entries[0].find_index('GRN (Optional)')
      uploaded_sheet.entries[1..3].each do |grn_row|
        temp = {
          'Status' => 'Draft',
          'Vendor Name' => $conf['grn_vendor_name'],
          'Anchor Name' => $conf['grn_anchor_name'],
          'Invoice Value' => "₹#{comma_seperated_value(grn_row[1])}",
          'Date of Initiation' => Date.today.strftime('%d %b, %Y')
        }
        temp_dup = temp.dup
        temp_dup.delete('Vendor Name') if page == :vendor
        temp_dup.delete('Anchor Name') if page == :anchor
        ids << @common_pages.get_transaction_id(temp_dup)
        temp['Minimum value'] = if grn_row[grn_optional_index].nil? # nil GRN value
                                  grn_row[1]
                                elsif grn_row[1] < grn_row[grn_optional_index] # invoice value less than GRN value
                                  grn_row[1]
                                else # invoice value greatee than GRN value
                                  grn_row[grn_optional_index]
                                end
        transaction_details << temp
      end
      [ids, transaction_details]
    end

    # Imported invoice transactions
    def verify_valid_dd_transactions(page:)
      @common_pages.click_transactions_tab(SHOW_ALL)
      file = "#{Dir.pwd}/test-data/attachments/dd_vendor_transaction_bulk_upload.xlsx"
      excel = RubyXL::Parser.parse(file)
      vendor_name = $conf['users']['dd_vendor']['name']
      sheet = excel['Dynamic Discounting - Vendor']
      errors = []
      sheet.sheet_data[1..2].each do |row|
        due_date = (Date.today + 30).strftime('%d-%b-%Y')
        desired_date = (Date.today + 10).strftime('%d-%b-%Y')
        value = row[1].value > row[9].value ? row[9].value : row[1].value
        calculated_values = calculate_payable_value({
                                                      invoice_value: value,
                                                      discount: 10,
                                                      gst: $conf['gst'],
                                                      tds: 8
                                                    })
        @total_payable = calculated_values[0]
        data = {
          'Invoice Number' => row[0].value,
          'Anchor Name' => $conf['users']['anchor']['name'],
          'Date of Initiation' => Date.today.strftime('%d %b, %Y'),
          'Desired Date' => (Date.today + 10).strftime('%d %b, %Y'),
          'Invoice Value' => comma_seperated_value(row[1].value),
          'Discount' => '10.0',
          'Days Gained' => '20',
          'Status' => 'Draft',
          'Total Payable' => comma_seperated_value(@total_payable)
        }
        result = verify_transaction_in_list_page(data, page: page, apply_filter: false)
        errors << "[DD Transaction not found] #{data}" unless result
      end
      errors.empty? ? true : errors
    end

    # Imported invoice transactions
    def verify_valid_po_transactions(type, page:)
      @common_pages.click_transactions_tab(SHOW_ALL)
      file = ''
      vendor_name = ''
      case type
      when 'grn_anchor', 'po_vendor'
        vendor_name = $conf['users']['po_vendor']['name']
        file = "#{Dir.pwd}/test-data/attachments/po_vendor_transaction_bulk_upload.xlsx"
        excel = RubyXL::Parser.parse(file)
        sheet = excel['PO - Vendor Program']
      when 'po_dealer'
        vendor_name = $conf['users']['po_dealer']['name']
        file = "#{Dir.pwd}/test-data/attachments/po_dealer_transaction_bulk_upload.xlsx"
        excel = RubyXL::Parser.parse(file)
        sheet = excel['PO - Dealer Program']
      end
      errors = []
      sheet.sheet_data[1..2].each do |row|
        data = {
          'Number' => row[0].value,
          'Status' => 'Draft',
          'Vendor Name' => vendor_name,
          'Anchor Name' => $conf['users']['grn_anchor']['name'],
          'Instrument Value' => "₹#{row[2].value.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}",
          'Date of Initiation' => Date.today.strftime('%d %b, %Y')
        }
        result = verify_transaction_in_list_page(data, page: page, apply_filter: false)
        errors << "[Transaction not found] #{data}" unless result
      end
      errors.empty? ? true : errors
    end

    # imported invoice transactions
    def verify_valid_transactions(type, page:)
      @common_pages.click_transactions_tab(SHOW_ALL)
      file = ''
      vendor_name = ''
      case type
      when 'anchor', 'vendor'
        file = "#{Dir.pwd}/test-data/attachments/invoice_vendor_transaction_bulk_upload.xlsx"
        vendor_name = $conf['vendor_name']
      when 'dealer'
        file = "#{Dir.pwd}/test-data/attachments/invoice_dealer_transaction_bulk_upload.xlsx"
        vendor_name = $conf['dealer_name']
      end
      excel = RubyXL::Parser.parse(file)
      sheet = type == 'dealer' ? excel['Invoice - Dealer Program'] : excel['Invoice - Vendor Program']
      errors = []
      sheet.sheet_data[1..5].each do |row|
        data = {
          'Status' => 'Draft',
          'Vendor Name' => vendor_name,
          'Anchor Name' => $conf['anchor_name'],
          'Invoice Value' => "₹#{row[1].value.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}",
          'Date of Initiation' => Date.today.strftime('%d %b, %Y'),
          'Number' => row[0].value
        }
        result = verify_transaction_in_list_page(data, page: page, apply_filter: false)
        errors << "[Transaction not found] #{data}" unless result
      end
      errors.empty? ? true : errors
    end

    def validate_doc_uploaded(type, file = "#{$download_path}/report.xlsx")
      invoice_file = Roo::Spreadsheet.open(file)
      invoice_sheet = invoice_file.sheet('Sheet1')
      trans_ids = []
      invoice_sheet.entries[1..2].each { |x| trans_ids << x[0] }
      errors = []
      trans_ids.each do |tran_id|
        resp = type == 'invoice' ? get_transaction_details(tran_id) : get_po_details(tran_id)
        errors << "Transaction not found #{resp[:code]}" unless resp[:code] == 200
        flag = resp[:body][:documents] == []
        flag &= resp[:body][:documents].select { |doc| doc[:document_type] == 'invoice' && !doc[:file_url].nil? } == [] unless resp[:body][:documents] == []
        errors << "Documents not present for #{tran_id}" if flag
      end
      errors.empty? ? true : errors
    end

    def create_bulk_invoice_expected_hash(invoice_sheet, type)
      expected_hash = {
        invoice_sheet.entries[1][0] => ['uploaded', '', ''],
        invoice_sheet.entries[2][0] => ['uploaded', '', 'Failed to upload Invoice Image'],
        invoice_sheet.entries[3][0] => ['uploaded', '', ''],
        invoice_sheet.entries[4][0] => ['uploaded', '', ''],
        invoice_sheet.entries[5][0] => ['uploaded', '', ''],
        invoice_sheet.entries[6][0] => ['failed', 'Invalid invoice_number', ''],
        invoice_sheet.entries[7][0] => ['failed', 'Invalid invoice_value', ''],
        invoice_sheet.entries[8][0] => ['failed', 'Invalid invoice_date', ''],
        invoice_sheet.entries[9][0] => ['failed', 'Unable to find Anchor from the GSTN provided', ''],
        invoice_sheet.entries[10][0] => ['failed', 'Unable to find Vendor from the GSTN provided', '']
      }

      if type != 'dealer'
        expected_hash.merge!(
          invoice_sheet.entries[11][0] => ['failed', 'Requested Disbursement Value cannot be greater than the entered Invoice/GRN value', ''],
          invoice_sheet.entries[12][0] => ['failed', 'GRN Value cannot be greater than the Invoice value', ''],
          invoice_sheet.entries[13][0] => ['failed', 'Requested Disbursement Value cannot be greater than the entered Invoice/GRN value', ''],
          invoice_sheet.entries[14][0] => ['uploaded', '', '']
        )
      end
      expected_hash
    end

    def validate_utilization_report(values)
      csv_data = values[:csv_data]
      for row in 0...csv_data.length do
        if csv_data[row][0] == values[:program_type].split(' - ')[0] &&
           csv_data[row][1].downcase == values[:channel_partner].downcase &&
           csv_data[row][4].downcase == values[:investor].downcase
          return [csv_data[row][5], csv_data[row][7]]
        end
      end
      errors = []
      for row in 0...csv_data.length do
        errors << "#{csv_data[row][0]}, #{csv_data[row][1]}, #{csv_data[row][2]}"
      end
      errors
    end

    def validate_wrong_headers_message(message, invalid_columns, missed_columns)
      test = message.tr('\"', '')
      ['Invalid Columns found in the sheet - ', 'Missing Columns found in the sheet - ', 'Please verify with the existing template.'].each { |str| test = test.gsub(str, '') }
      a_invalid_columns = []
      test.split('] ')[0].delete('[').split(',').each { |column| a_invalid_columns << column.strip }
      a_missed_columns = []
      test.split('] ')[1].delete('[].').split(',').each { |column| a_missed_columns << column.strip }
      invalid_columns_error = []
      invalid_columns.each { |column| invalid_columns_error << column unless a_invalid_columns.include? column }
      missed_columns_error = []
      missed_columns.each { |column| missed_columns_error << column unless a_missed_columns.include? column }
      return true if invalid_columns_error.empty? && missed_columns_error.empty?

      ["Invalid Columns mismatch #{invalid_columns_error}", "Missed column mismatch #{missed_columns_error}", "Actual invalid columns #{a_invalid_columns}", "Actual missed columns #{a_missed_columns}"]
    end

    def validate_tranche_overdue(values)
      csv_data = values[:csv_data]
      invoice_datas = @common_pages.payment_list
      row_id = rand(1..5)
      expected_hash = [invoice_number: csv_data[row_id][4],
                       principal_amount: csv_data[row_id][6].to_i.to_s,
                       repayment_due_date: Date.parse(csv_data[row_id][7], 'dd-mmm-yyyy').strftime('%d %b %Y'),
                       disbursal_date: Date.parse(csv_data[row_id][1], 'dd-mmm-yyyy').strftime('%d %b %Y')]
      for row in 0..invoice_datas.fetch_elements.size do
        data = invoice_datas.fetch_elements[row].text.gsub(',', '').gsub('₹', '')
        next unless data.include?(csv_data[row_id][4])

        data = data.split("\n")
        actual_values = [invoice_number: data[2],
                         principal_amount: data[5],
                         repayment_due_date: data[4],
                         disbursal_date: data[7]]
        break
      end
      [actual_values, expected_hash]
    end

    def validate_borrower_list(values)
      csv_data = values[:csv_data]
      @tarspect_methods.wait_for_loader_to_disappear(MAX_LOADER_TIME)
      borrower_data = @common_pages.payment_list
      row_id = rand(0...csv_data.length)
      actual_values = {
        borrower_name: csv_data[row_id][1],
        anchor_name: csv_data[row_id][2],
        channel_partner: csv_data[row_id][3],
        program: csv_data[row_id][4],
        region: csv_data[row_id][5],
        sanction_limit: csv_data[row_id][6].to_i.to_s,
        first_disbursal_date: Date.parse(csv_data[row_id][7], 'dd-mmm-yyyy').strftime('%d %b %Y'),
        overdue: csv_data[row_id][10].to_i.to_s,
        max_dpd: csv_data[row_id][11],
        live_transactions: csv_data[row_id][12],
        interest_due_as_on_date: csv_data[row_id][13].to_i.to_s
      }
      for row in 0...borrower_data.fetch_elements.size do
        data = borrower_data.fetch_elements[row].text.gsub(',', '').gsub('₹', '')
        next unless data.include?(csv_data[row_id][1]) && data.include?(csv_data[row_id][2])

        data = data.split("\n")
        expected_values = {
          borrower_name: data[0],
          anchor_name: data[2],
          channel_partner: data[3],
          program: data[4],
          region: data[5],
          sanction_limit: (data[6].gsub('LAC', '').to_i * 100000).to_s,
          first_disbursal_date: data[7],
          overdue: data[10].to_i.to_s,
          max_dpd: data[11].to_i.to_s,
          live_transactions: data[12].to_i.to_s,
          interest_due_as_on_date: data[13].to_i.to_s
        }
        break
      end
      [actual_values, expected_values]
    end
  end
end
