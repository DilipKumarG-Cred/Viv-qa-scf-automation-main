require './spec_helper'
require 'erb'
describe 'Disbursement: Invoice By GRN', :scf, :disbursements, :invoice_by_grn, :hover do
  before(:all) do
    @anchor_gstn = $conf['tvs_gstn']
    @counterparty_gstn = $conf['dozco_gstn']
    @anchor_name = $conf['grn_anchor_name']
    @vendor_name = $conf['grn_vendor_name']
    @investor_name = $conf['investor_name']
    @invoice_file = "#{Dir.pwd}/test-data/attachments/anchor_invoice.pdf"
    @payment_proof = "#{Dir.pwd}/test-data/attachments/payment_proof.pdf"
    @erb_file = File.read("#{Dir.pwd}/test-data/erb/testbed_data.erb")
    @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
    @testdata['GRN Invoice Details']['GRN'] = @testdata['GRN Invoice Details']['Invoice Value'] - 10_000
    @invoice_value = @testdata['GRN Invoice Details']['Invoice Value'].to_s.reverse.gsub(/(\d{3})(?=\d)/,
                                                                                         '\\1,').reverse
    @testdata['Transaction List']['Instrument Value'] = "₹#{@invoice_value}"
    @today_date = Date.today.strftime('%d %b, %Y')
    @due_date = (Date.today + $conf['vendor_tenor']).strftime('%d %b, %Y')
    @calculate_hash = {
      invoice_value: '',
      margin: $conf['margin'],
      yield: $conf['yield'],
      tenor: $conf['vendor_tenor'],
      type: 'frontend'
    }
    @download_path = "#{Dir.pwd}/test-data/downloaded/invoice_by_grn"
  end

  before(:each) do
    @driver = Tarspect::Browser.new($conf['browser'], @download_path).invoke
    @tarspect_methods = Common::Methods.new(@driver)
    @common_pages = Pages::CommonMethods.new(@driver)
    @transactions_page = Pages::Trasactions.new(@driver)
    @disbursement_page = Pages::Disbursement.new(@driver)
  end

  after(:each) do |e| # Captures screenshot of the current page when failure happens
    snap_screenshot(e)
    quit_browser
  end

  it 'Disbursement: Invoice value > GRN value', :sanity do |e|
    e.run_step 'Create a complete transaction as Anchor(Draft -> Released)' do
      @transaction_id = seed_transaction({
                                           actor: 'grn_anchor',
                                           counter_party: 'grn_vendor',
                                           invoice_details: @testdata['GRN Invoice Details'],
                                           invoice_file: @invoice_file,
                                           program: 'Invoice Financing - Vendor',
                                           program_group: 'invoice'
                                         })
      expect(@transaction_id).not_to include('Error while creating transaction')
    end

    e.run_step 'Login as Investor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['investor']['email'],
                                     $conf['users']['investor']['password'])).to eq true
    end

    e.run_step 'Verify the transaction details in list page' do
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @common_pages.click_transactions_tab(SHOW_ALL)
      @testdata['Transaction List']['Status'] = 'Released'
      @calculate_hash[:invoice_value] = @testdata['GRN Invoice Details']['Invoice Value']
      @transaction_values = calculate_transaction_values(@calculate_hash)
      @testdata['Transaction List']['Transaction Value'] =
        "₹#{comma_seperated_value(@transaction_values[0])}"
      @testdata['Transaction List']['Number'] = @testdata['GRN Invoice Details']['Invoice Number']
      expect(@transactions_page.verify_transaction_in_list_page(@testdata['Transaction List'], page: :investor, apply_filter: false)).to eq true
    end

    e.run_step 'Verify disbursement modal values' do
      expected_summary = {
        'Total Value' => "₹#{@invoice_value}",
        'Disbursement Amount' => "₹#{comma_seperated_value(rounded_half_down_value(@transaction_values[1]))}",
        'Vendor' => $conf['grn_vendor_name'],
        'GSTN' => $conf['dozco_gstn']
      }
      @common_pages.navigate_to_transaction(@transaction_id)
      @disbursement_page.click_disbursement
      expect(@disbursement_page.verify_summary_details(expected_summary)).to eq true
    end

    e.run_step 'Disburse the amount' do
      @disbursement_details = {
        'UTR Number' => "UTR#{DateTime.now.to_time.to_i}#{rand(1..999)}",
        'Date of Payment' => Date.today.strftime('%d-%b-%Y'),
        'Disbursement Amount' => @transaction_values[1],
        'Disbursement Account Number' => Faker::Number.number(digits: 10)
      }
      @disbursement_page.disburse(@payment_proof, @disbursement_details)
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['DisburseSuccess']
    end

    e.run_step 'Verify the transaction status and timeline status' do
      expect(@transactions_page.verify_transaction_status('Settled')).to eq true
      expect(@transactions_page.status_timeline_present?(@today_date, 'CA Approval')).to eq true
      expect(@transactions_page.status_timeline_present?(@today_date, 'Vendor/Dealer Approval')).to eq true
      expect(@transactions_page.status_timeline_present?(@today_date, 'CA Approval (Level 2)')).to eq true
      expect(@transactions_page.status_timeline_present?(@today_date, 'Settled')).to eq true
    end

    e.run_step 'Verify status timeline in the hovercard after disbursement' do
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @common_pages.click_transactions_tab(SETTLED)
      expect(@transactions_page.status_timeline_on_hover(@transaction_id, @today_date, 'CA Approval')).to eq true
      expect(@transactions_page.status_timeline_on_hover(@transaction_id, @today_date,
                                                         'Vendor/Dealer Approval')).to eq true
      expect(@transactions_page.status_timeline_on_hover(@transaction_id, @today_date,
                                                         'CA Approval (Level 2)')).to eq true
      expect(@transactions_page.status_timeline_on_hover(@transaction_id, @today_date, 'Settled')).to eq true
    end

    e.run_step 'Verify payment details and proofs in the payments tab' do
      @common_pages.navigate_to_transaction(@transaction_id)
      @tarspect_methods.click_link('Payment')
      expect(@disbursement_page.account_number).to eq @disbursement_details['Disbursement Account Number'].to_s
      expect(@disbursement_page.disbursement_amount).to eq "₹ #{comma_seperated_value(@transaction_values[1])}"
      expected_values = {
        'Date of Payment' => @today_date,
        'Amount' => "₹ #{comma_seperated_value(@transaction_values[1])}",
        'UTR Number' => @disbursement_details['UTR Number'],
        'Discrepancy Reason' => '-',
        'Discrepancy Receipt' => 'View Document  ',
        'Payment Receipt' => 'View Receipt'
      }
      actual_values = @disbursement_page.get_payment_details
      expect(actual_values).to eq expected_values
      expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq true
    end

    # e.run_step "Verify Due for Payment details" do
    #   expected_values = {
    #     "Due Date" => @due_date,
    #     "Principal Paid / Outstanding" => "₹ 0  /  ₹ #{comma_seperated_value(@transaction_values[0])}",
    #     "Interest Paid / Outstanding" => "₹ #{comma_seperated_value(@transaction_values[2])}  /  ₹ 0",
    #     "Charges Outstanding" => "₹ 0",
    #     "Total Outstanding" => "₹ #{comma_seperated_value(@transaction_values[0])}"
    #   }
    #   actual_values = @disbursement_page.get_due_for_payment_details
    #   expect(actual_values).to eq expected_values
    # end
  end

  it 'Disbursement: Anchor bulk upload GRN values', :sanity, :bulk do |e|
    e.run_step 'Login as anchor' do
      flush_directory(@download_path)
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['grn_anchor']['email'],
                                     $conf['users']['grn_anchor']['password'])).to eq true
    end

    e.run_step 'Import bulk transaction and verify summary report' do
      expected_results = @transactions_page.add_bulk_transaction('grn_anchor', 'Vendor Financing', 'Invoice')
      expect(@transactions_page.download_summary_report(@download_path)).to eq true
      expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq true
      report_link = @transactions_page.get_summary_report_link
      actual_results = @transactions_page.verify_summary_report(report_link)
      expect(actual_results).to eq expected_results
      @tarspect_methods.click_button('close')
    end

    e.run_step 'Move imported transactions to released state' do
      @imported_transactions = @transactions_page.imported_grn_transactions(page: :anchor)
      expect(@common_pages.logout).to eq true
      @transaction_ids = @imported_transactions[0]
      expect(@transaction_ids.size).to eq 3
      values = {
        counter_party: 'grn_vendor',
        transaction_id: '',
        program_id: 1,
        bulk_upload: true,
        program_group: 'invoice'
      }
      @transaction_ids.each do |transaction|
        values.merge!(transaction_id: transaction)
        expect(release_transaction(values)).to eq true
      end
    end

    e.run_step 'Login as Investor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['investor']['email'],
                                     $conf['users']['investor']['password'])).to eq true
    end

    e.run_step 'Verify anchor imported GRN transaction: NO GRN value' do
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @common_pages.click_transactions_tab(SHOW_ALL)
      transaction_details = @imported_transactions[1][0]
      @calculate_hash[:invoice_value] = transaction_details['Minimum value']
      @transaction_values = calculate_transaction_values(@calculate_hash)
      transaction_details['Status'] = 'Released'
      transaction_details['Transaction Value'] = "₹#{comma_seperated_value(@transaction_values[0])}"
      transaction_details.delete('Minimum value')
      tran_resp = get_transaction_details(@imported_transactions[0][0])
      transaction_details['Number'] = tran_resp[:body][:invoice_number]
      expect(@transactions_page.verify_transaction_in_list_page(transaction_details, page: :investor, apply_filter: false)).to eq true
    end

    e.run_step 'Verify anchor imported GRN transaction: Invoice value greater than GRN value' do
      transaction_details = @imported_transactions[1][1]
      @calculate_hash[:invoice_value] = transaction_details['Minimum value']
      @transaction_values = calculate_transaction_values(@calculate_hash)
      transaction_details['Status'] = 'Released'
      transaction_details['Transaction Value'] = "₹#{comma_seperated_value(@transaction_values[0])}"
      transaction_details.delete('Minimum value')
      tran_resp = get_transaction_details(@imported_transactions[0][1])
      transaction_details['Number'] = tran_resp[:body][:invoice_number]
      expect(@transactions_page.verify_transaction_in_list_page(transaction_details, page: :investor, apply_filter: false)).to eq true
    end

    e.run_step 'Verify anchor imported GRN transaction: Invoice value lesser than GRN value' do
      transaction_details = @imported_transactions[1][2]
      @calculate_hash[:invoice_value] = transaction_details['Minimum value']
      @transaction_values = calculate_transaction_values(@calculate_hash)
      transaction_details['Status'] = 'Released'
      transaction_details['Transaction Value'] = "₹#{comma_seperated_value(@transaction_values[0])}"
      transaction_details.delete('Minimum value')
      tran_resp = get_transaction_details(@imported_transactions[0][2])
      transaction_details['Number'] = tran_resp[:body][:invoice_number]
      expect(@transactions_page.verify_transaction_in_list_page(transaction_details, page: :investor, apply_filter: false)).to eq true
    end
  end

  it 'Disbursement: Vendor bulk upload GRN values', :sanity, :bulk do |e|
    e.run_step 'Login as vendor' do
      flush_directory(@download_path)
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['grn_vendor']['email'],
                                     $conf['users']['grn_vendor']['password'])).to eq true
    end

    e.run_step 'Vendor import bulk transaction and verify summary report' do
      expected_results = @transactions_page.add_bulk_transaction('grn_vendor', 'Vendor Financing')
      expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq true
      expect(@transactions_page.download_summary_report(@download_path)).to eq true
      report_link = @transactions_page.get_summary_report_link
      actual_results = @transactions_page.verify_summary_report(report_link)
      expect(actual_results).to eq expected_results
      @tarspect_methods.click_button('close')
    end

    e.run_step 'Move imported transactions to released state' do
      @imported_transactions = @transactions_page.imported_grn_transactions(page: :vendor)
      expect(@common_pages.logout).to eq true
      @transaction_ids = @imported_transactions[0]
      expect(@transaction_ids.size).to eq 3
      values = {
        counter_party: 'grn_anchor',
        transaction_id: '',
        program_id: 1,
        bulk_upload: true,
        program_group: 'invoice'
      }
      @transaction_ids.each do |transaction|
        values.merge!(transaction_id: transaction)
        expect(release_transaction(values)).to eq true
      end
    end

    e.run_step 'Login as Investor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['investor']['email'],
                                     $conf['users']['investor']['password'])).to eq true
    end

    e.run_step 'Verify vendor imported GRN transaction: NO GRN value' do
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @common_pages.click_transactions_tab(SHOW_ALL)
      transaction_details = @imported_transactions[1][0]
      @calculate_hash[:invoice_value] = transaction_details['Minimum value']
      @transaction_values = calculate_transaction_values(@calculate_hash)
      transaction_details['Status'] = 'Released'
      transaction_details['Transaction Value'] = "₹#{comma_seperated_value(@transaction_values[0])}"
      transaction_details.delete('Minimum value')
      tran_resp = get_transaction_details(@imported_transactions[0][0])
      transaction_details['Number'] = tran_resp[:body][:invoice_number]
      expect(@transactions_page.verify_transaction_in_list_page(transaction_details, page: :investor, apply_filter: false)).to eq true
    end

    e.run_step 'Verify vendor imported GRN transaction: Invoice value greater than GRN value' do
      transaction_details = @imported_transactions[1][1]
      @calculate_hash[:invoice_value] = transaction_details['Minimum value']
      @transaction_values = calculate_transaction_values(@calculate_hash)
      transaction_details['Status'] = 'Released'
      transaction_details['Transaction Value'] = "₹#{comma_seperated_value(@transaction_values[0])}"
      transaction_details.delete('Minimum value')
      tran_resp = get_transaction_details(@imported_transactions[0][1])
      transaction_details['Number'] = tran_resp[:body][:invoice_number]
      expect(@transactions_page.verify_transaction_in_list_page(transaction_details, page: :investor, apply_filter: false)).to eq true
    end

    e.run_step 'Verify vendor imported GRN transaction: Invoice value lesser than GRN value' do
      transaction_details = @imported_transactions[1][2]
      @calculate_hash[:invoice_value] = transaction_details['Minimum value']
      @transaction_values = calculate_transaction_values(@calculate_hash)
      transaction_details['Status'] = 'Released'
      transaction_details['Transaction Value'] = "₹#{comma_seperated_value(@transaction_values[0])}"
      transaction_details.delete('Minimum value')
      tran_resp = get_transaction_details(@imported_transactions[0][2])
      transaction_details['Number'] = tran_resp[:body][:invoice_number]
      expect(@transactions_page.verify_transaction_in_list_page(transaction_details, page: :investor, apply_filter: false)).to eq true
    end
  end
end
