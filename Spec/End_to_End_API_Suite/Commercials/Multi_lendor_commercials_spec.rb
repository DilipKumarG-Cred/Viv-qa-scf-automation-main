require './spec_helper'
describe 'Multi lendor to Channel partners:', :scf, :commercials, :multi_lendor, :ml_commercials do
  before(:all) do
    @mou = "#{Dir.pwd}/test-data/attachments/borrowing_document.pdf"
    @reupload_mou = "#{Dir.pwd}/test-data/attachments/reinitiate_invoice.pdf"
    @borrowing_document = "#{Dir.pwd}/test-data/attachments/borrowing_document.pdf"
    @anchor_actor = 'anchor'
    @vendor_actor = 'ml_vendor'
    @first_investor_actor = 'investor'
    @second_investor_actor = 'user_feedback_investor'
    @anchor_name = $conf['users'][@anchor_actor]['name']
    @vendor_name = $conf['users'][@vendor_actor]['name']
    @anchor_id = $conf['users'][@anchor_actor]['id']
    @vendor_id = $conf['users'][@vendor_actor]['id']
    @first_investor_id = $conf['users'][@first_investor_actor]['id']
    @second_investor_id = $conf['users'][@second_investor_actor]['id']

    @different_anchor_id = $conf['users']['grn_anchor']['id']
    @second_vendor = 'Carroll Spencer'
    @third_vendor = 'Unique STG'
    @fourth_vendor = 'Priya TVS'
    @anchor_program_id = $conf['programs']['Invoice Financing - Vendor']
    @expected_values = { status: '-', name: 'Just Buy Cycles', city: 'Bodinayakanur',
                         geography: 'south', incorporation_date: Date.parse('4/1/2022'), turnover: 0.0, live_transaction_count: 0 }
    @erb_file = File.read("#{Dir.pwd}/test-data/erb/commercials_data.erb")
  end

  before(:each) do
    @uniq_id = 'UNIQUEID'
    @values = { 'Program' => 'Invoice Financing', 'Type' => 'Vendor', 'Anchor ID' => @anchor_id,
                'Investor ID' => @second_investor_id, 'Vendor Name' => @vendor_name, 'actor' => @second_investor_actor }
    delete_vendor_commercials(@values)
    @testdata = JSON.parse(ERB.new(@erb_file).result(binding))['Vendor Commercials']
  end

  it 'Vendor Commercials: Setup and Approval', :mails do |e|
    e.run_step 'Verify Vendor is Approved for investor Kotak' do
      resp = verify_vendor_present(@anchor_program_id, @first_investor_id, @vendor_name, actor: @first_investor_actor)
      expect(resp[:status]).to eq('Verified')
      expect(resp[:name]).to eq(@vendor_name)
    end

    e.run_step 'Verify vendor is available to other investor' do
      resp = verify_vendor_present(@anchor_program_id, @second_investor_id, @vendor_name, actor: @second_investor_actor)
      act_values = api_form_vendor_program_details(resp)
      act_values.delete(:status)
      ex_values = @expected_values.dup
      ex_values.delete(:status)
      expect(act_values).to eq(ex_values)
    end

    e.run_step 'Verify Vendor Commercials can be set by other investors as well' do
      @testdata.merge!(
        'Investor GSTN' => $conf['dcb_gstn'],
        'Sanction Limit' => 100_000,
        'Tenor' => '30',
        'Yield' => '8',
        'Unique Identifier' => @uniq_id,
        'Valid Till' => (Date.today + 300).strftime('%d-%b-%Y'),
        'Vendor ID' => @vendor_id,
        'Anchor Program ID' => @anchor_program_id,
        'Anchor ID' => @anchor_id
      )
      set_resp = set_commercials(@testdata)
      expect(set_resp[:code]).to eq(201), set_resp.to_s
      @program_limit_id = set_resp[:body][:program_limits][:id]
    end

    # Commenting this step as mail is not recieved in Outlook
    # e.run_step 'Verify mail recieved on commercial setup' do
    #   email_values = { mail_box: $conf['notification_mailbox'], subject: 'New action from DCB Bank on your Yubi Flow program',
    #                    body: 'Invoice Financing - Vendor', link_text: 'live-investors' }
    #   activation_link = $mail_helper.get_activation_link(email_values, 25)
    #   expect(activation_link.empty?).to eq(false)
    # end

    e.run_step 'Verify Interested investor details' do
      resp = fetch_interested_investors(@vendor_actor, @anchor_program_id)
      interested_investor_details = resp[:body][:interested_investors].select { |interested_investor| interested_investor[:investor][:name] == 'DCB Bank' }
      actual_values = {
        name: interested_investor_details[0][:investor][:name],
        sanction_limit: interested_investor_details[0][:vendor_commercials][0][:max_sanction_limit],
        processing_fee_percentage: interested_investor_details[0][:vendor_commercials][0][:processing_fee_percentage],
        tenor: interested_investor_details[0][:vendor_commercials][0][:tenor],
        payment_strategy: interested_investor_details[0][:vendor_commercials][0][:payment_strategy]
      }
      investor_details = {
        name: 'DCB Bank',
        sanction_limit: 100_000.0,
        processing_fee_percentage: '2.0',
        tenor: 30,
        payment_strategy: 'IPC'
      }
      expect(actual_values).to eq(investor_details)
    end

    e.run_step 'Add approving document' do
      values = { 'Investor' => @second_investor_actor, 'Borrowing Document' => @borrowing_document, 'Program Limit ID' => @program_limit_id }
      @uploaded_bd_response = upload_vendor_bd(values)
      expect(@uploaded_bd_response[:code]).to eq(200), @uploaded_bd_response.to_s
    end

    e.run_step 'Approve the commercials' do
      @testdata.merge!('Program Limit ID' => @program_limit_id)
      set_resp = set_commercials(@testdata, action: :submit)
      expect([200, 201]).to include(set_resp[:code]), set_resp.to_s
    end

    e.run_step 'Verify Processing fee details for the commercials' do
      sleep 5
      hash = { 'Anchor ID' => @anchor_id, 'Investor ID' => @second_investor_id, 'Program' => 'Invoice Financing', 'Type' => 'Vendor', 'Vendor Name' => @vendor_name, 'actor' => @vendor_actor }
      vendor_commm = get_vendor_commercial(hash)
      expect(vendor_commm[:code]).to eq(200), vendor_commm.to_s
      expected_values = { cgst: 9, sgst: 9, igst: 18, processing_fee: 2000.0, cgst_fee: 0.0, sgst_fee: 0.0, igst_fee: 360.0, gst_fee: 360.0, processing_fee_payable: 2360.0 }
      expect(vendor_commm.is_a?(Hash)).to eq(true), vendor_commm.to_s
      expect(vendor_commm[:body].is_a?(Hash)).to eq(true), vendor_commm.to_s
      expect(vendor_commm[:body][:program_limits].is_a?(Hash)).to eq(true), vendor_commm[:body].to_s
      expect(vendor_commm[:body][:program_limits][:fee].is_a?(Hash)).to eq(true), vendor_commm[:body][:program_limits].to_s
      fee_details = vendor_commm[:body][:program_limits][:fee]
      fee_details.delete(:id)
      expect(fee_details).to eq(expected_values)
    end

    e.run_step 'Record Processing fee for the commercials' do
      values = { 'Program Limit ID' => @program_limit_id, 'UTR Number' => "UTR#{DateTime.now.to_time.to_i}#{rand(1..999)}",
                 'Payment Date' => Date.today.strftime('%d-%b-%Y'), 'Vendor' => @vendor_actor }
      resp = vendor_fee_payment(values)
      expect(resp[:code]).to eq(200), resp.to_s
      @payment_receipts_id = resp[:body][:program_limits][:payment_receipts][0][:id]
    end

    e.run_step 'Verify if Unique Identifier is shown for PRODUCT' do
      hash = { 'Anchor ID' => @anchor_id, 'Investor ID' => @second_investor_id, 'Program' => 'Invoice Financing', 'Type' => 'Vendor', 'Vendor Name' => @vendor_name, 'actor' => 'product' }
      resp = get_vendor_commercial(hash)
      expect(resp[:body][:cc_account_identifier]).to eq(nil)
    end

    e.run_step 'Verify Vendor status - Pending' do
      @expected_values[:status] = 'Pending'
      resp = verify_vendor_present(@anchor_program_id, @second_investor_id, @vendor_name, actor: @second_investor_actor)
      expect(api_form_vendor_program_details(resp)).to eq(@expected_values)
    end

    e.run_step 'Verify Processing fee for the commercials' do
      values = { 'Payment Reciept ID' => @payment_receipts_id, 'Investor' => @second_investor_actor }
      resp = review_processing_fee(values)
      expect(resp[:code]).to eq(200), resp.to_s
    end

    e.run_step 'Verify Vendor status - Approved' do
      @expected_values[:status] = 'Verified'
      resp = verify_vendor_present(@anchor_program_id, @second_investor_id, @vendor_name, actor: @second_investor_actor)
      expect(api_form_vendor_program_details(resp)).to eq(@expected_values)
    end

    e.run_step 'Verify Same Unique Identifier CANNOT be added for another vendor in SAME program' do
      second_vendor = verify_vendor_present(@anchor_program_id, @second_investor_id, @second_vendor, actor: @second_investor_actor)
      @testdata.merge!('Vendor ID' => second_vendor[:id])
      set_resp = set_commercials(@testdata)
      expect(set_resp[:code]).to eq(422), set_resp.to_s
      expect(set_resp[:body][:error][:message]).to eq('identifier should be unique for investor anchor vendor combination')
    end

    e.run_step 'Verify Same Unique Identifier CAN be added for another vendor in DIFFERENT program' do
      @anchor_program_id = get_anchor_program_id('PO Financing', 'Vendor', @anchor_id)
      third_vendor = verify_vendor_present(@anchor_program_id, @second_investor_id, @third_vendor, actor: @second_investor_actor)
      hash = { 'Anchor ID' => @anchor_id, 'Investor ID' => @second_investor_id, 'Program' => 'PO Financing', 'Type' => 'Vendor', 'Vendor Name' => @third_vendor, 'actor' => @second_investor_actor }
      resp = get_vendor_commercial(hash)
      @testdata.merge!('Vendor ID' => third_vendor[:id], 'Anchor Program ID' => @anchor_program_id, 'Program Limit ID' => resp[:body][:program_limits][:id])
      set_resp = set_commercials(@testdata, action: :update)
      expect([200, 201]).to include(set_resp[:code]), set_resp.to_s
    end

    e.run_step 'Verify Same Unique Identifier can be added for another vendor with anchor program' do
      @anchor_program_id = get_anchor_program_id('Invoice Financing', 'Dealer', @different_anchor_id)
      fourth_vendor = verify_vendor_present(@anchor_program_id, @second_investor_id, @fourth_vendor, actor: @second_investor_actor)
      hash = { 'Anchor ID' => @different_anchor_id, 'Investor ID' => @second_investor_id, 'Program' => 'Invoice Financing', 'Type' => 'Dealer', 'Vendor Name' => @fourth_vendor, 'actor' => @second_investor_actor }
      resp = get_vendor_commercial(hash)
      @testdata.merge!('Vendor ID' => fourth_vendor[:id], 'Anchor Program ID' => @anchor_program_id, 'Program Limit ID' => resp[:body][:program_limits][:id])
      set_resp = set_commercials(@testdata, action: :update)
      expect([200, 201]).to include(set_resp[:code]), set_resp.to_s
    end

    e.run_step 'Delete commercials' do
      resp = delete_vendor_commercials(@values)
      expect(resp[:code]).to eq(200), resp.to_s
    end
  end
end
