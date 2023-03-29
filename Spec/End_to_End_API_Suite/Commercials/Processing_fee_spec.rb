require './spec_helper'
describe 'Commercials: Processing Fee', :scf, :commercials, :onboarding, :processing_fee, :pf, :mails do
  before(:each) do
    @counterparty_gstn = $conf['myntra_gstn']
    @invoice_file = "#{Dir.pwd}/test-data/attachments/dealer_invoice.pdf"
    @payment_proof = "#{Dir.pwd}/test-data/attachments/payment_proof.pdf"
    @invoice_erb = File.read("#{Dir.pwd}/test-data/erb/testbed_data.erb")
    @today_date = Date.today.strftime('%d %b, %Y')
    @due_date = (Date.today + $conf['vendor_tenor']).strftime('%d %b, %Y')
    @erb_file = File.read("#{Dir.pwd}/test-data/erb/commercials_data.erb")
    @borrowing_document = "#{Dir.pwd}/test-data/attachments/borrowing_document.pdf"
    @program_name = 'Invoice Financing - Vendor Program'
    @tarspect_methods = Common::Methods.new(nil)
    @calculate_hash = { invoice_value: '', margin: $conf['margin'], yield: $conf['yield'], tenor: $conf['vendor_tenor'], type: 'frontend' }
    @created_vendor = []
    @common_api = Api::Pages::Common.new
  end

  after(:each) do
    delete_channel_partner('Vendor', @created_vendor)
  end

  it 'Commercials : Processing Fee' do |e|
    @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
    @testdata['Commercials']['GSTN'] = "17#{@testdata['Commercials']['PAN']}#{Faker::Number.number(digits: 1)}Z#{Faker::Internet.user_name(specifier: 1..1).upcase}"
    @commercials_data = @testdata['Commercials']
    @company_info = @testdata['Company Info']
    @promoter_info = @testdata['Promoter Info']
    @km_person_info = @testdata['Key Managing Person Info']
    @company_kyc_docs = @testdata['Documents']['Company KYC Documents']
    @promoter_kyc_docs = @testdata['Documents']['Promoter KYC Documents']
    @financial_docs = @testdata['Documents']['Financials']
    @bank_statements = @testdata['Documents']['Bank Statements']
    @gst_returns = @testdata['Documents']['GST Returns']

    e.run_step 'Create a vendor and complete onboarding details' do
      expect(api_create_registered_channel_partner(@testdata)).to eq true
      @created_vendor << @commercials_data['Entity Name']
      @commercials_data['Name'] = @commercials_data['Entity Name']
    end

    e.run_step 'Verify vendors all document as a platform team' do
      @vendor = @testdata['Commercials']['Email'].split('@')[0]
      expect(review_all_docs({ actor: @vendor, doc_type: 'mandatory_docs' }, action: :approve)).to eq(true)
    end

    e.run_step 'Verify Channel Partner can be approved' do
      resp = review_vendor(@vendor, 'approved')
      expect(resp[:code]).to eq(200), resp.to_s
    end

    e.run_step 'Verify vendor is present for the Investor' do
      @expected_values = { status: '-', name: @commercials_data['Name'], city: @company_info['City'],
                           geography: @company_info['Geography'].downcase, incorporation_date: Date.today,
                           turnover: 0.0, live_transaction_count: 0 }
      @anchor_program_id = get_anchor_program_id('Invoice Financing', 'Vendor', 4)
      resp = verify_vendor_present(@anchor_program_id, 7, @commercials_data['Name'], actor: 'investor')
      expect(api_form_vendor_program_details(resp)).to eq(@expected_values)
    end

    e.run_step 'Verify vendor Commercials can be added for New Vendor' do
      @vendor_commercials = @testdata['Vendor Commercials']
      vendor_response = api_get_vendor_details(@vendor)
      @vendor_id = vendor_response[:body][:id]
      @vendor_commercials.merge!(
        'Investor GSTN' => $conf['dcb_gstn'],
        'Sanction Limit' => 10_000,
        'Tenor' => '60',
        'Yield' => '12',
        'Valid Till' => (Date.today + 300).strftime('%d-%b-%Y'),
        'Vendor ID' => @vendor_id,
        'Anchor Program ID' => @anchor_program_id,
        'Anchor ID' => 4,
        'Investor' => 'investor'
      )
      set_resp = set_commercials(@vendor_commercials)
      expect(set_resp[:code]).to eq(201)
      @program_limit_id = set_resp[:body][:program_limits][:id]
      @vendor_commercials['Program Limit ID'] = set_resp[:body][:program_limits][:id]
    end

    e.run_step 'Verify Vendor commercials status after adding Vendor program - Draft' do
      resp = verify_vendor_present(@anchor_program_id, 7, @commercials_data['Name'], actor: 'investor')
      @expected_values[:status] = 'Draft'
      expect(api_form_vendor_program_details(resp)).to eq(@expected_values)
    end

    e.run_step 'Verify borrowing document can be uploaded' do
      @uploaded_bd_response = upload_vendor_bd(@vendor_commercials)
      expect(@uploaded_bd_response[:code]).to eq(200)
    end

    e.run_step 'Approve the commercials' do
      @vendor_commercials.merge!('Program Limit ID' => @program_limit_id)
      set_resp = set_commercials(@vendor_commercials, action: :submit)
      expect([200, 201]).to include(set_resp[:code]), set_resp.to_s
    end

    e.run_step 'Verify Processing fee details for the commercials' do
      sleep 5
      hash = { 'Anchor ID' => 4, 'Investor ID' => 7, 'Program' => 'Invoice Financing', 'Type' => 'Vendor', 'Vendor Name' => @commercials_data['Name'], 'actor' => @vendor }
      vendor_commm = get_vendor_commercial(hash)
      expect(vendor_commm[:code]).to eq(200), vendor_commm.to_s
      @processing_fee_expected_values = { cgst: 9, sgst: 9, igst: 18, processing_fee: 200.0, cgst_fee: 18.0, sgst_fee: 18.0, igst_fee: 0.0, gst_fee: 36.0, processing_fee_payable: 236.0 }
      expect(vendor_commm.is_a?(Hash)).to eq(true), vendor_commm.to_s
      expect(vendor_commm[:body].is_a?(Hash)).to eq(true), vendor_commm.to_s
      expect(vendor_commm[:body][:program_limits].is_a?(Hash)).to eq(true), vendor_commm[:body].to_s
      expect(vendor_commm[:body][:program_limits][:fee].is_a?(Hash)).to eq(true), vendor_commm[:body][:program_limits].to_s
      fee_details = vendor_commm[:body][:program_limits][:fee]
      fee_details.delete(:id)
      expect(fee_details).to eq(@processing_fee_expected_values)
    end

    e.run_step 'Record Processing fee for the commercials' do
      values = { 'Program Limit ID' => @program_limit_id, 'UTR Number' => "UTR#{DateTime.now.to_time.to_i}#{rand(1..999)}",
                 'Payment Date' => Date.today.strftime('%d-%b-%Y'), 'Vendor' => @vendor }
      resp = vendor_fee_payment(values)
      expect(resp[:code]).to eq(200), resp.to_s
      @payment_receipts_id = []
      @payment_receipts_id << resp[:body][:program_limits][:payment_receipts][0][:id]
      @utr = []
      @utr << values['UTR Number']
    end

    e.run_step 'Verify Vendor status - Pending' do
      @expected_values[:status] = 'Pending'
      resp = verify_vendor_present(@anchor_program_id, 7, @commercials_data['Name'], actor: 'investor')
      expect(api_form_vendor_program_details(resp)).to eq(@expected_values)
    end

    e.run_step 'Create a transaction as a Vendor(for checking the disbursement across various stages)' do
      @vendor_gstn = @commercials_data['GSTN']
      @inv_testdata = JSON.parse(ERB.new(@invoice_erb).result(binding))
      @inv_testdata['Vendor Invoice Details']['Invoice Value'] = 10_000
      @transaction_id = seed_transaction(
        {
          actor: @vendor,
          counter_party: 'anchor',
          invoice_details: @inv_testdata['Vendor Invoice Details'],
          invoice_file: @invoice_file,
          program: 'Invoice Financing - Vendor',
          program_group: 'invoice'
        }
      )
      expect(@transaction_id).not_to include('Error while creating transaction')
    end

    e.run_step 'Verify Investor cannot do disbursements when Vendor status is pending' do
      @disbursed_values = {
        transaction_id: @transaction_id,
        invoice_value: @inv_testdata['Vendor Invoice Details']['Invoice Value'],
        type: 'frontend',
        date_of_payment: Date.today.strftime('%d-%b-%Y'),
        payment_proof: @payment_proof,
        program: 'Invoice Financing - Vendor',
        tenor: 60,
        yield: 12
      }
      @details = disburse_transaction(@disbursed_values)
      expect(@details).to include 'Processing fee is not yet approved'
    end

    e.run_step 'Verify processing fee details' do
      hash = { 'payment_receipt_id' => @payment_receipts_id[0] }
      response = @common_api.perform_get_action('transaction_history', hash, 'investor')
      actual_results = response[:body][:fee]
      actual_results.delete(:id)
      expect(actual_results).to eq(@processing_fee_expected_values)
    end

    e.run_step 'Verify Processing fee can be rejected' do
      values = { 'Payment Reciept ID' => @payment_receipts_id[0], 'Investor' => 'investor' }
      resp = review_processing_fee(values, action: 'reject', reason: @inv_testdata['Reject Reason'])
      expect(resp[:code]).to eq(200), resp.to_s
    end

    e.run_step 'View rejected reason for the Processing Fee as Channel Partner' do
      resp = fetch_fee_notifications(@vendor)
      expect(resp[:code]).to eq(200)
      notification_message = resp[:body].select { |notification| notification[:payment_receipt_id] == @payment_receipts_id[0] }
      expect(notification_message.empty?).to eq(false), "No matching notification found for payment receipt id #{@payment_receipts_id[0]}"
      expect(notification_message[0][:comment]).to eq(@inv_testdata['Reject Reason'])
    end

    e.run_step 'Record another Processing fee for the commercials as Vendor' do
      @processing_fee = { 'Program Limit ID' => @program_limit_id, 'UTR Number' => "UTR#{DateTime.now.to_time.to_i}#{rand(1..999)}",
                          'Payment Date' => Date.today.strftime('%d-%b-%Y'), 'Vendor' => @vendor }
      resp = vendor_fee_payment(@processing_fee)
      expect(resp[:code]).to eq(200), resp.to_s
      @payment_receipts_id << resp[:body][:program_limits][:payment_receipts][0][:id]
      @utr << @processing_fee['UTR Number']
    end

    ['Rejected', 'Pending'].each do |state|
      e.run_step "Verify Processing fee present in the Payment history as Vendor(#{state} payments)" do
        hash = { 'payment_type' => 'Processing Fee' }
        response = @common_api.perform_get_action('payment_history', hash, @vendor)
        if state == 'Rejected'
          payment_receipts_id = @payment_receipts_id[0]
          utr = @utr[0]
        else
          payment_receipts_id = @payment_receipts_id[1]
          utr = @utr[1]
        end
        payment_history_detail = response[:body][:payment_history].select { |history| history[:id] == payment_receipts_id }
        actual_results = {
          status: payment_history_detail[0][:status],
          paid_by: payment_history_detail[0][:paid_from][:name],
          date_of_payment: Date.parse(payment_history_detail[0][:invoice_date]).strftime('%d %b, %Y'),
          utr_number: payment_history_detail[0][:utr_number],
          payment_type: payment_history_detail[0][:payment_type],
          payment_amount: payment_history_detail[0][:payment_amount]
        }
        rejected_processing_fee = {
          status: state,
          paid_by: @commercials_data['Name'],
          date_of_payment: @today_date,
          utr_number: utr,
          payment_type: 'Processing Fee',
          payment_amount: 236.0
        }
        expect(actual_results).to eq(rejected_processing_fee)
      end
    end

    e.run_step 'Verify processing fee details' do
      hash = { 'payment_receipt_id' => @payment_receipts_id[1] }
      response = @common_api.perform_get_action('transaction_history', hash, 'investor')
      actual_results = response[:body][:fee]
      actual_results.delete(:id)
      expect(actual_results).to eq(@processing_fee_expected_values)
    end

    e.run_step 'Approve newly recorded processing fee' do
      values = { 'Payment Reciept ID' => @payment_receipts_id[1], 'Investor' => 'investor' }
      resp = review_processing_fee(values)
      expect(resp[:code]).to eq(200), resp.to_s
    end

    e.run_step 'Verify Vendor status - Pending' do
      @expected_values[:status] = 'Verified'
      @expected_values[:live_transaction_count] = 1
      resp = verify_vendor_present(@anchor_program_id, 7, @commercials_data['Name'], actor: 'investor')
      expect(api_form_vendor_program_details(resp)).to eq(@expected_values)
    end

    e.run_step 'Verify Investor can do disbursements till the sanctioned limits' do
      @details = disburse_transaction(@disbursed_values)
      expect(@details).not_to include 'Error while disbursements'
    end

    e.run_step 'Verify Investor cannot do disbursements once the sanctioned limit reached' do
      @vendor_gstn = @commercials_data['GSTN']
      @inv_testdata = JSON.parse(ERB.new(@invoice_erb).result(binding))
      @inv_testdata['Vendor Invoice Details']['Invoice Value'] = 10_000
      @transaction_id = seed_transaction(
        {
          actor: @vendor,
          counter_party: 'anchor',
          invoice_details: @inv_testdata['Vendor Invoice Details'],
          invoice_file: @invoice_file,
          program: 'Invoice Financing - Vendor',
          program_group: 'invoice'
        }
      )
      expect(@transaction_id).not_to include('Error while creating transaction')
      @disbursed_values[:transaction_id] = @transaction_id
      @disbursed_values[:invoice_value] = @inv_testdata['Vendor Invoice Details']['Invoice Value']
      @details = disburse_transaction(@disbursed_values)
      expect(@details).to include $notifications['MaxSanctionLimitReched']
    end

    ['Rejected', 'Verified'].each do |state|
      e.run_step "Verify Processing fee present in the Payment history(#{state} payments)" do
        hash = { 'payment_type' => 'Processing Fee' }
        response = @common_api.perform_get_action('payment_history', hash, @vendor)
        if state == 'Rejected'
          payment_receipts_id = @payment_receipts_id[0]
          utr = @utr[0]
        else
          payment_receipts_id = @payment_receipts_id[1]
          utr = @utr[1]
        end
        payment_history_detail = response[:body][:payment_history].select { |history| history[:id] == payment_receipts_id }
        actual_results = {
          status: payment_history_detail[0][:status],
          paid_by: payment_history_detail[0][:paid_from][:name],
          date_of_payment: Date.parse(payment_history_detail[0][:invoice_date]).strftime('%d %b, %Y'),
          utr_number: payment_history_detail[0][:utr_number],
          payment_type: payment_history_detail[0][:payment_type],
          payment_amount: payment_history_detail[0][:payment_amount]
        }
        processing_fee = {
          status: state,
          paid_by: @commercials_data['Name'],
          date_of_payment: @today_date,
          utr_number: utr,
          payment_type: 'Processing Fee',
          payment_amount: 236.0
        }
        expect(actual_results).to eq(processing_fee)
      end
    end

    e.run_step 'Clear refunds and delete vendor' do
      clear_all_overdues({ anchor: 'Myntra', vendor: @commercials_data['Name'] })
      delete_channel_partner('Vendor', @created_vendor)
    end
  end

  it 'Commercials : Processing Fee with 0%' do |e|
    @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
    @testdata['Commercials']['GSTN'] = "17#{@testdata['Commercials']['PAN']}#{Faker::Number.number(digits: 1)}Z#{Faker::Internet.user_name(specifier: 1..1).upcase}"
    @commercials_data = @testdata['Commercials']
    @company_info = @testdata['Company Info']
    @promoter_info = @testdata['Promoter Info']
    @km_person_info = @testdata['Key Managing Person Info']
    @company_kyc_docs = @testdata['Documents']['Company KYC Documents']
    @promoter_kyc_docs = @testdata['Documents']['Promoter KYC Documents']
    @financial_docs = @testdata['Documents']['Financials']
    @bank_statements = @testdata['Documents']['Bank Statements']
    @gst_returns = @testdata['Documents']['GST Returns']

    e.run_step 'Create a vendor and complete onboarding details' do
      expect(api_create_registered_channel_partner(@testdata)).to eq true
      @created_vendor << @commercials_data['Entity Name']
      @commercials_data['Name'] = @commercials_data['Entity Name']
    end

    e.run_step 'Verify vendors all document as a platform team' do
      @vendor = @testdata['Commercials']['Email'].split('@')[0]
      expect(review_all_docs({ actor: @vendor, doc_type: 'mandatory_docs' }, action: :approve)).to eq(true)
    end

    e.run_step 'Verify Channel Partner can be approved' do
      resp = review_vendor(@vendor, 'approved')
      expect(resp[:code]).to eq(200), resp.to_s
    end

    e.run_step 'Verify vendor is present for the Investor' do
      @expected_values = { status: '-', name: @commercials_data['Name'], city: @company_info['City'],
                           geography: @company_info['Geography'].downcase, incorporation_date: Date.today,
                           turnover: 0.0, live_transaction_count: 0 }
      @anchor_program_id = get_anchor_program_id('Invoice Financing', 'Vendor', 4)
      resp = verify_vendor_present(@anchor_program_id, 7, @commercials_data['Name'], actor: 'investor')
      expect(api_form_vendor_program_details(resp)).to eq(@expected_values)
    end

    e.run_step 'Verify vendor Commercials can be added for New Vendor with PF - 0%' do
      @vendor_commercials = @testdata['Vendor Commercials']
      vendor_response = api_get_vendor_details(@vendor)
      @vendor_id = vendor_response[:body][:id]
      @vendor_commercials.merge!(
        'Investor GSTN' => $conf['dcb_gstn'],
        'Sanction Limit' => 10_000,
        'Tenor' => '60',
        'Yield' => '12',
        'Processing Fee' => '0',
        'Valid Till' => (Date.today + 300).strftime('%d-%b-%Y'),
        'Vendor ID' => @vendor_id,
        'Anchor Program ID' => @anchor_program_id,
        'Anchor ID' => 4,
        'Investor' => 'investor'
      )
      set_resp = set_commercials(@vendor_commercials)
      expect(set_resp[:code]).to eq(201)
      @program_limit_id = set_resp[:body][:program_limits][:id]
      @vendor_commercials['Program Limit ID'] = set_resp[:body][:program_limits][:id]
    end

    e.run_step 'Verify Vendor commercials status after adding Vendor program - Draft' do
      resp = verify_vendor_present(@anchor_program_id, 7, @commercials_data['Name'], actor: 'investor')
      @expected_values[:status] = 'Draft'
      expect(api_form_vendor_program_details(resp)).to eq(@expected_values)
    end

    e.run_step 'Verify borrowing document can be uploaded' do
      @uploaded_bd_response = upload_vendor_bd(@vendor_commercials)
      expect(@uploaded_bd_response[:code]).to eq(200)
    end

    e.run_step 'Approve/Submit the commercials' do
      @vendor_commercials.merge!('Program Limit ID' => @program_limit_id)
      set_resp = set_commercials(@vendor_commercials, action: :submit)
      expect([200, 201]).to include(set_resp[:code]), set_resp.to_s
    end

    e.run_step 'Verify Vendor status - Verified (Pending is skipped since PF is zero)' do
      @expected_values[:status] = 'Verified'
      resp = verify_vendor_present(@anchor_program_id, 7, @commercials_data['Name'], actor: 'investor')
      expect(api_form_vendor_program_details(resp)).to eq(@expected_values)
    end

    e.run_step 'Create a transaction as a Vendor(for checking the disbursement across various stages)' do
      @vendor_gstn = @commercials_data['GSTN']
      @inv_testdata = JSON.parse(ERB.new(@invoice_erb).result(binding))
      @inv_testdata['Vendor Invoice Details']['Invoice Value'] = 10_000
      sleep 5
      @transaction_id = seed_transaction(
        {
          actor: @vendor,
          counter_party: 'anchor',
          invoice_details: @inv_testdata['Vendor Invoice Details'],
          invoice_file: @invoice_file,
          program: 'Invoice Financing - Vendor',
          program_group: 'invoice'
        }
      )
      expect(@transaction_id).not_to include('Error while creating transaction')
    end

    e.run_step 'Verify Investor can do disbursements without paying PF when PF is 0%' do
      @disbursed_values = {
        transaction_id: @transaction_id,
        invoice_value: @inv_testdata['Vendor Invoice Details']['Invoice Value'],
        type: 'frontend',
        date_of_payment: Date.today.strftime('%d-%b-%Y'),
        payment_proof: @payment_proof,
        program: 'Invoice Financing - Vendor',
        tenor: 60,
        yield: 12
      }
      @details = disburse_transaction(@disbursed_values)
      expect(@details).not_to include 'Error while disbursements'
    end
  end
end
