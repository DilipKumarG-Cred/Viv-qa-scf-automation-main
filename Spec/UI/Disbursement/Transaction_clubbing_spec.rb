require './spec_helper'
require 'erb'
describe 'Transaction Clubbing : Verification', :scf, :disbursements, :transaction_clubbing do
  before(:all) do
    @anchor_actor = 'grn_anchor'
    @vendor_actor = 'tranclub_vendor'
    @party_gstn = $conf['users'][@anchor_actor]['gstn']
    @counterparty_gstn = $conf['users'][@vendor_actor]['gstn']
    @vendor_name = $conf['users'][@vendor_actor]['name']
    @anchor_name = $conf['grn_anchor_name']
    @investor_name = $conf['user_feedback_investor']
    @invoice_file = "#{Dir.pwd}/test-data/attachments/anchor_invoice.pdf"
    @erb_file = File.read("#{Dir.pwd}/test-data/erb/testbed_data.erb")
    @payment_proof = "#{Dir.pwd}/test-data/attachments/payment_proof.pdf"
  end

  before(:each) do
    @driver = Tarspect::Browser.new($conf['browser']).invoke
    @tarspect_methods = Common::Methods.new(@driver)
    @common_pages = Pages::CommonMethods.new(@driver)
    @transactions_page = Pages::Trasactions.new(@driver)
    @disbursement_page = Pages::Disbursement.new(@driver)
    @payments_page = Pages::Payment.new(@driver)
    @investor_page = Pages::Investor.new(@driver)
    values = {
      actor: 'user_feedback_investor',
      comment: 'Declining transaction - before each regression',
      program_group: 'po',
      anchor_id: 5,
      vendor_id: 8935,
      by_group_id: true
    }
    decline_all_up_for_disbursements(values)
    @po_details = JSON.parse(ERB.new(@erb_file).result(binding))['PO Details']
  end

  after(:each) do |e|
    snap_screenshot(e)
    quit_browser
  end

  it 'Transaction Clubbing : Decline', :sanity, :Transaction_club_dec do |e|
    e.run_step 'Create 3 complete transaction with same invoice date' do
      @po_details['PO Date'] = (Date.today - 60).strftime('%d-%b-%Y')
      @transaction_id = seed_transaction(
        {
          actor: @anchor_actor,
          counter_party: @vendor_actor,
          po_details: @po_details,
          po_file: @invoice_file,
          program: 'PO Financing - Vendor',
          investor_id: 9,
          program_group: 'purchase_order'
        }
      )
      expect(@transaction_id).not_to include('Error while creating transaction')
      @po_details1 = JSON.parse(ERB.new(@erb_file).result(binding))['PO Details']
      @po_details1['PO Date'] = (Date.today - 60).strftime('%d-%b-%Y')
      @transaction_id1 = seed_transaction(
        {
          actor: @anchor_actor,
          counter_party: @vendor_actor,
          po_details: @po_details1,
          po_file: @invoice_file,
          program: 'PO Financing - Vendor',
          investor_id: 9,
          program_group: 'purchase_order'
        }
      )
      expect(@transaction_id1).not_to include('Error while creating transaction')
      @po_details2 = JSON.parse(ERB.new(@erb_file).result(binding))['PO Details']
      @po_details2['PO Date'] = (Date.today - 60).strftime('%d-%b-%Y')
      @transaction_id2 = seed_transaction(
        {
          actor: @anchor_actor,
          counter_party: @vendor_actor,
          po_details: @po_details2,
          po_file: @invoice_file,
          program: 'PO Financing - Vendor',
          investor_id: 9,
          program_group: 'purchase_order'
        }
      )
      expect(@transaction_id2).not_to include('Error while creating transaction')
    end

    e.run_step 'Create another transaction with different invoice date' do
      @po_details3 = JSON.parse(ERB.new(@erb_file).result(binding))['PO Details']
      @po_details3['PO Date'] = (Date.today - 61).strftime('%d-%b-%Y')
      @transaction_id3 = seed_transaction(
        {
          actor: @anchor_actor,
          counter_party: @vendor_actor,
          po_details: @po_details3,
          po_file: @invoice_file,
          program: 'PO Financing - Vendor',
          investor_id: 9,
          program_group: 'purchase_order'
        }
      )
      expect(@transaction_id3).not_to include('Error while creating transaction')
    end

    e.run_step 'Log in as Investor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['user_feedback_investor']['email'], $conf['users']['user_feedback_investor']['password'])).to be true
    end

    e.run_step 'Verify Up for disbursement grouping' do
      @common_pages.click_menu('PO Financing')
      @common_pages.click_transactions_tab('Up For Disbursement')
      @disbursement_page.select_vendor_in_up_for_disbursement(@vendor_name)
      headers = @disbursement_page.get_list_details_in_up_for_disbursement(@po_details['PO Date'])
      group_id = @disbursement_page.get_group_id(@transaction_id1)
      expect(headers[0]).to eq(group_id)
      expect(headers[1]).to eq('3')
      transaction_values = calculate_transaction_values(
        {
          invoice_value: @po_details['Requested Disbursement Value'],
          margin: 10,
          yield: 10,
          tenor: 60,
          type: 'frontend'
        }
      )
      transaction_values1 = calculate_transaction_values(
        {
          invoice_value: @po_details1['Requested Disbursement Value'],
          margin: 10,
          yield: 10,
          tenor: 60,
          type: 'frontend'
        }
      )
      transaction_values2 = calculate_transaction_values(
        {
          invoice_value: @po_details2['Requested Disbursement Value'],
          margin: 10,
          yield: 10,
          tenor: 60,
          type: 'frontend'
        }
      )
      disb_value = (transaction_values[1] + transaction_values1[1] + transaction_values2[1]).to_f
      disb_formatted = "₹ #{disb_value.round(2)}"
      expect("₹ #{remove_comma_in_numbers(headers[5])}").to eq(disb_formatted)
      @disbursement_page.select_clubbed_group(@po_details['PO Date'])
      data1 = { 'Disbursement Value' => "₹#{comma_seperated_value(transaction_values[1])}", 'Number' => @po_details['PO Number'] }
      data2 = { 'Disbursement Value' => "₹#{comma_seperated_value(transaction_values1[1])}", 'Number' => @po_details1['PO Number'] }
      data3 = { 'Disbursement Value' => "₹#{comma_seperated_value(transaction_values2[1])}", 'Number' => @po_details2['PO Number'] }
      expect(@transactions_page.verify_transaction_in_list_page(data1, page: :product, apply_filter: false)).to eq true
      expect(@transactions_page.verify_transaction_in_list_page(data2, page: :product, apply_filter: false)).to eq true
      expect(@transactions_page.verify_transaction_in_list_page(data3, page: :product, apply_filter: false)).to eq true
    end

    e.run_step 'Decline one transaction' do
      @disbursement_page.select_transactions([@transaction_id])
      @disbursement_page.decline.click
      sleep 1
      @investor_page.decline('Declining one transaction')
      @tarspect_methods.BUTTON('Done').wait_for_element
      sleep 1
      notifications = @investor_page.read_notifications
      expect(notifications[0]).to eq('You have declined (1) transactions from STG TranClub')
      @tarspect_methods.click_button('Done')
    end

    e.run_step 'Decline at root level' do
      refresh_page
      @tarspect_methods.wait_for_circular_to_disappear
      @tarspect_methods.wait_for_loader_to_disappear
      notifications = @disbursement_page.review_at_root_level(@po_details['PO Date'], :decline)
      expect(notifications[0]).to eq('You have declined transaction from STG TranClub')
    end
  end

  it 'Transaction Clubbing : Disbursal', :sanity, :transaction_club_disbursal do |e|
    e.run_step 'Create 3 complete transaction with same invoice date' do
      @po_details['PO Date'] = (Date.today - 60).strftime('%d-%b-%Y')
      @transaction_id = seed_transaction(
        {
          actor: @anchor_actor,
          counter_party: @vendor_actor,
          po_details: @po_details,
          po_file: @invoice_file,
          program: 'PO Financing - Vendor',
          investor_id: 9,
          program_group: 'purchase_order'
        }
      )
      expect(@transaction_id).not_to include('Error while creating transaction')
      @po_details1 = JSON.parse(ERB.new(@erb_file).result(binding))['PO Details']
      @po_details1['PO Date'] = (Date.today - 60).strftime('%d-%b-%Y')
      @transaction_id1 = seed_transaction(
        {
          actor: @anchor_actor,
          counter_party: @vendor_actor,
          po_details: @po_details1,
          po_file: @invoice_file,
          program: 'PO Financing - Vendor',
          investor_id: 9,
          program_group: 'purchase_order'
        }
      )
      expect(@transaction_id1).not_to include('Error while creating transaction')
      @po_details2 = JSON.parse(ERB.new(@erb_file).result(binding))['PO Details']
      @po_details2['PO Date'] = (Date.today - 60).strftime('%d-%b-%Y')
      @transaction_id2 = seed_transaction(
        {
          actor: @anchor_actor,
          counter_party: @vendor_actor,
          po_details: @po_details2,
          po_file: @invoice_file,
          program: 'PO Financing - Vendor',
          investor_id: 9,
          program_group: 'purchase_order'
        }
      )
      expect(@transaction_id2).not_to include('Error while creating transaction')
    end

    e.run_step 'Log in as Investor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['user_feedback_investor']['email'], $conf['users']['user_feedback_investor']['password'])).to be true
    end

    e.run_step 'Verify disburse modal after selecting Single transactions(Summary and Bank details of Vendor)' do
      @transaction_values = calculate_transaction_values(
        {
          invoice_value: @po_details['Requested Disbursement Value'],
          margin: 10,
          yield: 10,
          tenor: 60,
          type: 'frontend'
        }
      )
      @transaction_values1 = calculate_transaction_values(
        {
          invoice_value: @po_details1['Requested Disbursement Value'],
          margin: 10,
          yield: 10,
          tenor: 60,
          type: 'frontend'
        }
      )
      @transaction_values2 = calculate_transaction_values(
        {
          invoice_value: @po_details2['Requested Disbursement Value'],
          margin: 10,
          yield: 10,
          tenor: 60,
          type: 'frontend'
        }
      )
      @expected_summary = {
        'Total Value' => "₹#{comma_seperated_value(@po_details['Requested Disbursement Value'])}",
        'Disbursement Amount' => "₹#{comma_seperated_value(@transaction_values[1])}",
        'Vendor' => @vendor_name,
        'GSTN' => @counterparty_gstn
      }
      @bank_details = {
        'Bank Name' => $conf['users']['vendor']['bank_name'],
        'Account Number' => '12321312312',
        'IFSC Code' => $conf['users']['vendor']['ifsc_code']
      }
      @common_pages.click_menu('PO Financing')
      @common_pages.click_transactions_tab('Up For Disbursement')
      @disbursement_page.select_vendor_in_up_for_disbursement(@vendor_name)
      @disbursement_page.select_clubbed_group(@po_details['PO Date'])
      @disbursement_page.select_transactions([@transaction_id])
      @disbursement_page.click_disbursement
      expect(@disbursement_page.verify_summary_details(@expected_summary)).to eq true
      expect(@disbursement_page.verify_summary_details(@bank_details)).to eq true
    end

    e.run_step 'Disburse one transaction' do
      @disbursement_details = {
        'UTR Number' => "UTR#{DateTime.now.to_time.to_i}#{rand(1..999)}",
        'Date of Payment' => Date.today.strftime('%d-%b-%Y'),
        'Disbursement Amount' => @transaction_values[1],
        'Disbursement Account Number' => Faker::Number.number(digits: 10)
      }
      @disbursement_page.disburse(@payment_proof, @disbursement_details)
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['DisburseSuccess']
    end

    e.run_step 'Verify Summary of single transactions' do
      expect(@transactions_page.verify_summary('Total Value')).to eq "₹#{comma_seperated_value(@transaction_values[1])}"
      expect(@transactions_page.verify_summary('Vendor')).to eq @vendor_name
      expect(@disbursement_page.no_of_transactions_in_summary(1)).to eq true
      @tarspect_methods.click_button('close')
    end

    e.run_step 'Verify disburse modal at root level' do
      refresh_page
      @tarspect_methods.wait_for_loader_to_disappear
      @disbursement_page.review_at_root_level(@po_details['PO Date'], :disburse)
      @disb = @transaction_values1[1] + @transaction_values2[1]
      total = @po_details1['Requested Disbursement Value'] + @po_details2['Requested Disbursement Value']
      @expected_summary['Total Value'] = "₹#{comma_seperated_value(total)}"
      @expected_summary['Disbursement Amount'] = "₹#{comma_seperated_value(@disb)}"
      expect(@disbursement_page.verify_summary_details(@expected_summary)).to eq true
      expect(@disbursement_page.verify_summary_details(@bank_details)).to eq true
    end

    e.run_step 'Disburse multiple transaction' do
      @disbursement_details = {
        'UTR Number' => "UTR#{DateTime.now.to_time.to_i}#{rand(1..999)}",
        'Date of Payment' => Date.today.strftime('%d-%b-%Y'),
        'Disbursement Amount' => rounded_half_down_value(@disb),
        'Disbursement Account Number' => Faker::Number.number(digits: 10)
      }
      @disbursement_page.disburse(@payment_proof, @disbursement_details)
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['DisburseSuccess']
    end

    # e.run_step 'Verify Summary of multiple transactions' do
    #   expect(@transactions_page.verify_summary('Total Value')).to eq "₹#{comma_seperated_value(@transaction_values[1])}"
    #   expect(@transactions_page.verify_summary('Vendor')).to eq @vendor_name
    #   expect(@disbursement_page.no_of_transactions_in_summary(2)).to eq true
    #   @tarspect_methods.click_button('close')
    # end Bug 58679: After Root decline/disbursal, page navigates to invoice financing
  end
end
