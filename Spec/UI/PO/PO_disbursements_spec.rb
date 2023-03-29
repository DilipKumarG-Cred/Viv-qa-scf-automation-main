require './spec_helper'
require 'erb'
describe 'PO Disbursements', :scf, :disbursements, :po, :po_disbursement, :hover do
  before(:all) do
    @party_gstn = $conf['users']['grn_anchor']['gstn']
    @counterparty_gstn = $conf['users']['po_vendor']['gstn']
    @vendor_name = $conf['users']['po_vendor']['name']
    @anchor_name = $conf['users']['grn_anchor']['name']
    @investor_name = $conf['investor_name']
    @invoice_file = "#{Dir.pwd}/test-data/attachments/anchor_invoice.pdf"
    @payment_proof = "#{Dir.pwd}/test-data/attachments/payment_proof.pdf"
    @erb_file = File.read("#{Dir.pwd}/test-data/erb/testbed_data.erb")
    @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
    @total_po_value = @testdata['PO Details']['PO Value'].to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
    @eligile_po_value = @testdata['PO Details']['Requested Disbursement Value'].to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
    @testdata['Transaction List']['Instrument Value'] = "₹#{@eligile_po_value}"
    @today_date = Date.today.strftime('%d %b, %Y')
    @due_date = (Date.today + $conf['vendor_tenor']).strftime('%d %b, %Y')
    clear_all_overdues({ anchor: $conf['grn_anchor_name'], vendor: $conf['users']['po_dealer']['name'] })
    @calculate_hash = {
      invoice_value: '',
      margin: $conf['margin'],
      yield: $conf['yield'],
      tenor: $conf['vendor_tenor'],
      type: 'frontend'
    }
  end

  before(:each) do
    @driver = Tarspect::Browser.new($conf['browser']).invoke
    @tarspect_methods = Common::Methods.new(@driver)
    @common_pages = Pages::CommonMethods.new(@driver)
    @transactions_page = Pages::Trasactions.new(@driver)
    @disbursement_page = Pages::Disbursement.new(@driver)
  end

  after(:each) do |e|
    snap_screenshot(e)
    quit_browser
  end

  after(:all) do
    # quit_browser #Tear down
  end

  it 'PO Disbursement: Frontend', :sanity do |e|
    e.run_step 'Create a complete transaction as Anchor(Draft -> Released)' do
      @transaction_id = seed_transaction({
                                           actor: 'grn_anchor',
                                           counter_party: 'po_vendor',
                                           po_details: @testdata['PO Details'],
                                           po_file: @invoice_file,
                                           program: 'PO Financing - Vendor',
                                           program_group: 'purchase_order'
                                         })
      expect(@transaction_id).not_to include('Error while creating transaction')
    end

    e.run_step 'Login as Investor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['investor']['email'], $conf['users']['investor']['password'])).to eq true
    end

    e.run_step 'Verify the transaction details in list page' do
      @testdata['Transaction List']['Status'] = 'Released'
      @calculate_hash[:invoice_value] = @testdata['PO Details']['Requested Disbursement Value']
      @transaction_values = calculate_transaction_values(@calculate_hash)
      @testdata['Transaction List']['Transaction Value'] = "₹#{comma_seperated_value(@transaction_values[0])}"
      @tran_resp = get_po_details(@transaction_id, actor: 'investor')
      expect(api_verify_transaction_in_list_page(@tran_resp[:body], @testdata['Transaction List'])).to eq(true)
    end

    e.run_step 'Verify disbursement modal values' do
      @common_pages.click_menu(MENU_PO_FINANCING)
      expected_summary = {
        'Total Value' => "₹#{@eligile_po_value}",
        'Disbursement Amount' => "₹#{comma_seperated_value(@transaction_values[1])}",
        'Vendor' => @vendor_name,
        'GSTN' => @counterparty_gstn
      }
      @common_pages.apply_filter({ 'Instrument Number' => @testdata['PO Details']['PO Number'] })
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
      @common_pages.click_menu(MENU_PO_FINANCING)
      @common_pages.click_transactions_tab(SETTLED)
      expect(@transactions_page.status_timeline_on_hover(@transaction_id, @today_date, 'CA Approval')).to eq true
      expect(@transactions_page.status_timeline_on_hover(@transaction_id, @today_date, 'Vendor/Dealer Approval')).to eq true
      expect(@transactions_page.status_timeline_on_hover(@transaction_id, @today_date, 'CA Approval (Level 2)')).to eq true
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

    e.run_step 'Investor logs out' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Anchor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['grn_anchor']['email'], $conf['users']['grn_anchor']['password'])).to eq true
    end

    e.run_step 'Verify status timeline in the hovercard after disbursement as Anchor' do
      @common_pages.click_menu(MENU_PO_FINANCING)
      @common_pages.click_transactions_tab(SETTLED)
      expect(@transactions_page.status_timeline_on_hover(@transaction_id, @today_date, 'CA Approval')).to eq true
      expect(@transactions_page.status_timeline_on_hover(@transaction_id, @today_date, 'Vendor/Dealer Approval')).to eq true
      expect(@transactions_page.status_timeline_on_hover(@transaction_id, @today_date, 'CA Approval (Level 2)')).to eq true
      expect(@transactions_page.status_timeline_on_hover(@transaction_id, @today_date, 'Settled')).to eq true
    end

    e.run_step 'Verify payment details and proofs in the payments tab as Anchor' do
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
  end

  it 'PO Disbursement: Rearend', :sanity, :po_dis_rearend do |e|
    @counterparty_gstn = $conf['users']['po_dealer']['gstn']
    @vendor_name = $conf['users']['po_dealer']['name']
    @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
    @total_po_value = @testdata['PO Details']['PO Value'].to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
    @eligile_po_value = @testdata['PO Details']['Requested Disbursement Value'].to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
    @testdata['Transaction List']['Instrument Value'] = "₹#{@eligile_po_value}"
    @testdata['Transaction List']['Vendor Name'] = @vendor_name
    @due_date = (Date.today + $conf['dealer_tenor']).strftime('%d %b, %Y')

    e.run_step 'Create a complete transaction as Anchor(Draft -> Released)' do
      @transaction_id = seed_transaction({
                                           actor: 'grn_anchor',
                                           counter_party: 'po_dealer',
                                           po_details: @testdata['PO Details'],
                                           po_file: @invoice_file,
                                           program: 'PO Financing - Dealer',
                                           investor_id: 7,
                                           program_group: 'purchase_order'
                                         })
      expect(@transaction_id).not_to include('Error while creating transaction')
    end

    e.run_step 'Login as Investor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['investor']['email'], $conf['users']['investor']['password'])).to eq true
    end

    e.run_step 'Verify the transaction details in list page' do
      @testdata['Transaction List']['Status'] = 'Released'
      @calculate_hash[:invoice_value] = @testdata['PO Details']['Requested Disbursement Value']
      @calculate_hash[:tenor] = $conf['dealer_tenor']
      @calculate_hash[:type] = 'rearend'
      @transaction_values = calculate_transaction_values(@calculate_hash)
      @testdata['Transaction List']['Transaction Value'] = "₹#{comma_seperated_value(@transaction_values[0])}"
      @tran_resp = get_po_details(@transaction_id, actor: 'investor')
      expect(api_verify_transaction_in_list_page(@tran_resp[:body], @testdata['Transaction List'])).to eq(true)
    end

    e.run_step 'Verify disbursement modal values' do
      expected_summary = {
        'Total Value' => "₹#{@eligile_po_value}",
        'Disbursement Amount' => "₹#{comma_seperated_value(@transaction_values[1])}",
        'Anchor' => @anchor_name,
        'GSTN' => @party_gstn
      }
      @common_pages.click_menu(MENU_PO_FINANCING)
      @common_pages.apply_filter({ 'Instrument Number' => @testdata['PO Details']['PO Number'] })
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

    e.run_step 'Verify payment details and proofs in the payments tab' do
      @common_pages.click_menu(MENU_PO_FINANCING)
      @common_pages.click_transactions_tab(SETTLED)
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

    e.run_step 'Verify Due for Payment details' do
      expected_values = {
        'Due Date' => @due_date,
        'Principal Paid / Outstanding' => "₹ 0  /  ₹ #{comma_seperated_value(@transaction_values[0])}",
        'Interest Paid / Outstanding' => '₹ 0  /  ₹ 0',
        'Charges Outstanding' => '₹ 0',
        'Total Outstanding' => "₹ #{comma_seperated_value(@transaction_values[0])}"
      }
      actual_values = @disbursement_page.get_due_for_payment_details
      expect(actual_values).to eq expected_values
    end

    e.run_step 'Investor logs out' do
      expect(@common_pages.logout).to eq true
    end
  end
end
