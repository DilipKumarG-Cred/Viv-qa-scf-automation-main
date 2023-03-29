require './spec_helper'
describe 'Commercials: Edit Commercials : Anchor and Vendor', :scf, :commercials, :edit_commericals do
  before(:all) do
    @commercials_data_erb = File.read("#{Dir.pwd}/test-data/erb/commercials_data.erb")
    @erb_file = File.read("#{Dir.pwd}/test-data/erb/testbed_data.erb")
    @mou = "#{Dir.pwd}/test-data/attachments/borrowing_document.pdf"
    @reupload_mou = "#{Dir.pwd}/test-data/attachments/reinitiate_invoice.pdf"
    @anchor_actor = 'grn_anchor'
    @vendor_actor = 'edit_commercial_vendor'
    @investor_actor = 'edit_commercial_investor'
    @anchor_name = $conf['users'][@anchor_actor]['name']
    @vendor_name = $conf['users'][@vendor_actor]['name']
    @anchor_id = $conf['users'][@anchor_actor]['id']
    @vendor_id = $conf['users'][@vendor_actor]['id']
    @investor_id = $conf['users'][@investor_actor]['id']
    @anchor_program_id = 5
    @counterparty_gstn = $conf['users'][@anchor_actor]['gstn']
    @vendor_gstn = $conf['users']['edit_commercial_vendor']['gstn']
    @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
    @borrowing_document = "#{Dir.pwd}/test-data/attachments/borrowing_document.pdf"
    @vendor_commercials = JSON.parse(ERB.new(@commercials_data_erb).result(binding))['Vendor Commercials']
  end

  it 'Commercials: Edit Anchor Commercials: Verification', :anchor_edit_commercials do |e|
    e.run_step 'Edit anchor commercials changing margin value' do
      @commercial_response = get_anchor_commercials(investor_actor: @investor_actor, investor_id: @investor_id, anchor_program_id: @anchor_program_id)
      expect(@commercial_response[:code]).to eq(200)
      @set_commercial_values = JSON.parse(ERB.new(@commercials_data_erb).result(binding))['Anchor Commercials'].transform_keys(&:to_sym)
      @discount = Faker::Number.between(from: 10, to: 30)
      @discount = @discount == @commercial_response[:body][:result][:discount_percentage] ? Faker::Number.between(from: 10, to: 30) : @discount
      @set_commercial_values.merge!(
        actor: @investor_actor,
        anchor_program_id: @anchor_program_id,
        discount_percentage: @discount, # Changing values
        valid_from: get_todays_date,
        valid_till: get_todays_date(5),
        effective_date: get_todays_date,
        investor_id: @investor_id,
        max_sanction_limit: 10_000_000_000,
        instrument: 1
      )
      resp = set_anchor_commercials(@set_commercial_values, action: :edit)
      expect(resp[:code]).to eq(200)
      expect(resp[:body][:result][:status]).to eq('pending_document')
      @commercial_id = resp[:body][:result][:id]
    end

    e.run_step 'Verify old commercials are not seen to anchor before submitting' do
      @commercial_response = get_anchor_commercials(investor_actor: @anchor_actor, investor_id: @investor_id, anchor_program_id: @anchor_program_id)
      expect(@commercial_response[:code]).to eq(200)
      expect(@commercial_response[:body][:result][:discount_percentage]).not_to eq(@discount), 'Edited commercials are seen before submitting'
    end

    e.run_step 'Freeze anchor commercials' do
      values = { actor: @investor_actor, borr_doc: @mou, id: @commercial_id }
      resp = upload_anchor_mou(values)
      expect(resp[:code]).to eq(200), resp.to_s
      expect(resp[:body][:result][:status]).to eq('pending_document')
      resp = set_anchor_commercials(@set_commercial_values, action: :submit)
      expect(resp[:code]).to eq(200)
      expect(resp[:body][:result][:status]).to eq('pending_effective_date')
      sleep MAX_LOADER_TIME
      resp = get_anchor_commercials(investor_actor: @investor_actor, investor_id: @investor_id, anchor_program_id: @anchor_program_id)
      expect(resp[:body][:result][:status]).to eq('approved')
    end

    e.run_step 'Verify transaction disburses based on old commercials' do
      @testdata['Vendor Invoice Details']['Invoice Date'] = Date.parse('01-04-2022').strftime('%d-%b-%Y')
      @transaction_id = seed_transaction({
        actor: @anchor_actor,
        counter_party: @vendor_actor,
        invoice_details: @testdata['Vendor Invoice Details'],
        invoice_file: @invoice_file,
        program: 'Invoice Financing - Vendor',
        investor_id: @investor_id,
        bulk_upload: true,
        investor_actor: @investor_actor,
        program_group: 'invoice'
      })
      details = disburse_transaction(
        {
          transaction_id: @transaction_id,
          invoice_value: @testdata['Vendor Invoice Details']['Invoice Value'],
          tenor: 60,
          type: 'frontend',
          date_of_payment: Date.parse('01-04-2022').strftime('%d-%b-%Y'),
          payment_proof: @reupload_mou,
          program: 'Invoice Financing - Vendor',
          investor_actor: @investor_actor,
          yield: 12,
          margin: 12
        }
      )
      expect(details).not_to include('Error while disbursements')
    end

    e.run_step 'Verify transaction disburses with new commercials based on Date of payment' do
      hash = { 'Anchor ID' => @anchor_id, 'Investor ID' => @investor_id, 'Program' => 'Invoice Financing', 'Type' => 'Vendor', 'Vendor Name' => @vendor_name, 'actor' => 'product' }
      @vendor_commercial_response = get_vendor_commercial(hash)
      expect(@vendor_commercial_response[:code]).to eq(200)
      @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
      @testdata['Vendor Invoice Details']['Invoice Date'] = get_todays_date
      @transaction_id = seed_transaction({
        actor: @anchor_actor,
        counter_party: @vendor_actor,
        invoice_details: @testdata['Vendor Invoice Details'],
        invoice_file: @invoice_file,
        program: 'Invoice Financing - Vendor',
        investor_id: @investor_id,
        bulk_upload: true,
        investor_actor: @investor_actor,
        program_group: 'invoice'
      })
      details = disburse_transaction(
        {
          transaction_id: @transaction_id,
          invoice_value: @testdata['Vendor Invoice Details']['Invoice Value'],
          tenor: 60,
          type: 'frontend',
          date_of_payment: Date.today.strftime('%d-%b-%Y'),
          payment_proof: @reupload_mou,
          program: 'Invoice Financing - Vendor',
          investor_actor: @investor_actor,
          yield: @vendor_commercial_response[:body][:program_limits][:yield],
          margin: @discount
        }
      )
      expect(details).not_to include('Error while disbursements')
    end
    # Case needs to be verified by pooja.
    # e.run_step 'Verify transaction disbursed on in between the commercials validity' do
    #   hash = { 'Anchor ID' => @anchor_id, 'Investor ID' => @investor_id, 'Program' => 'Invoice Financing', 'Type' => 'Vendor', 'Vendor Name' => @vendor_name, 'actor' => 'product' }
    #   @vendor_commercial_response = get_vendor_commercial(hash)
    #   expect(@vendor_commercial_response[:code]).to eq(200)
    #   @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
    #   @testdata['Vendor Invoice Details']['Invoice Date'] = (Date.parse('01-07-2022')).strftime('%d-%b-%Y')
    #   @transaction_id = seed_transaction({
    #     actor: @anchor_actor,
    #     counter_party: @vendor_actor,
    #     invoice_details: @testdata['Vendor Invoice Details'],
    #     invoice_file: @invoice_file,
    #     program: 'Invoice Financing - Vendor',
    #     investor_id: @investor_id,
    #     bulk_upload: true
    #   })
    #   details = disburse_transaction(
    #     {
    #       transaction_id: @transaction_id,
    #       invoice_value: @testdata['Vendor Invoice Details']['Invoice Value'],
    #       tenor: 60,
    #       type: 'frontend',
    #       date_of_payment: (Date.parse('01-07-2022')).strftime('%d-%b-%Y'),
    #       payment_proof: @reupload_mou,
    #       program: 'Invoice Financing - Vendor',
    #       investor_actor: @investor_actor,
    #       yield: 12,
    #       margin: 12
    #     }
    #   )
    #   expect(details).not_to include('Error while disbursements')
    # end
  end

  it 'Commercials: Edit Vendor Commercials: Verification' do |e|
    e.run_step 'Fetch anchor and vendor commercial data' do
      @commercial_response = get_anchor_commercials(investor_actor: @investor_actor, investor_id: @investor_id, anchor_program_id: @anchor_program_id)
      expect(@commercial_response[:code]).to eq(200), @commercial_response.to_s
      hash = { 'Anchor ID' => @anchor_id, 'Investor ID' => @investor_id, 'Program' => 'Invoice Financing', 'Type' => 'Vendor', 'Vendor Name' => @vendor_name, 'actor' => 'product' }
      @vendor_commercial_response = get_vendor_commercial(hash)
      expect(@vendor_commercial_response[:code]).to eq(200), @vendor_commercial_response.to_s
    end

    e.run_step 'Edit Vendor Commercials' do
      @vendor_commercials.merge!(
        'Investor' => @investor_actor,
        'Investor ID' => @investor_id,
        'Sanction Limit' => 10_00_000,
        'Valid Till' => get_todays_date(5),
        'Vendor ID' => @vendor_id,
        'Anchor Program ID' => 5,
        'Vendor' => @vendor_actor,
        'Payment Date' => get_todays_date,
        action: :update,
        'Processing Fee' => 1,
        'Program Limit ID' => @vendor_commercial_response[:body][:program_limits][:id],
        'Yield' => Faker::Number.between(from: @commercial_response[:body][:result][:min_yield], to: @commercial_response[:body][:result][:max_yield]).to_i
      )
      set_resp = set_commercials(@vendor_commercials, action: :update)
      @vendor_commercials['Program Limit ID'] = set_resp[:body][:program_limits][:id]
      resp = upload_vendor_bd(@vendor_commercials)
      expect(resp[:code]).to eq(200), resp.to_s
    end

    e.run_step 'Verify commercials are not shown to Channel Partner' do
      hash = { 'Anchor ID' => @anchor_id, 'Investor ID' => @investor_id, 'Program' => 'Invoice Financing', 'Type' => 'Vendor', 'Vendor Name' => @vendor_name, 'actor' => @vendor_actor }
      u_vendor_commercial_response = get_vendor_commercial(hash)
      expect(u_vendor_commercial_response[:body][:program_limits][:yield].to_f).not_to eq(@vendor_commercials['Yield'].to_f)
    end

    e.run_step 'Submit the Vendor commercials' do
      resp = set_commercials(@vendor_commercials, action: :submit)
      expect(resp[:code]).to eq(200)
    end

    e.run_step 'Disburse transaction with due date before current commercial' do
      @counterparty_gstn = $conf['users']['grn_anchor']['gstn']
      @vendor_gstn = $conf['users']['edit_commercial_vendor']['gstn']
      @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
      @testdata['Vendor Invoice Details']['Invoice Date'] = Date.parse('01-04-2022').strftime('%d-%b-%Y')
      @transaction_id = seed_transaction({
        actor: @anchor_actor,
        counter_party: @vendor_actor,
        invoice_details: @testdata['Vendor Invoice Details'],
        invoice_file: @invoice_file,
        program: 'Invoice Financing - Vendor',
        investor_id: @investor_id,
        bulk_upload: true,
        investor_actor: @investor_actor,
        program_group: 'invoice'
      })
      details = disburse_transaction(
        {
          transaction_id: @transaction_id,
          invoice_value: @testdata['Vendor Invoice Details']['Invoice Value'],
          tenor: 60,
          type: 'frontend',
          date_of_payment: Date.parse('01-04-2022').strftime('%d-%b-%Y'),
          payment_proof: @reupload_mou,
          program: 'Invoice Financing - Vendor',
          investor_actor: @investor_actor,
          yield: 12,
          margin: 12
        }
      )
      expect(details).not_to include('Error while disbursements')
    end

    e.run_step 'Verify transaction disburses with new commercials based on Date of payment' do
      hash = { 'Anchor ID' => @anchor_id, 'Investor ID' => @investor_id, 'Program' => 'Invoice Financing', 'Type' => 'Vendor', 'Vendor Name' => @vendor_name, 'actor' => 'product' }
      @vendor_commercial_response = get_vendor_commercial(hash)
      expect(@vendor_commercial_response[:code]).to eq(200)
      @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
      @testdata['Vendor Invoice Details']['Invoice Date'] = Date.today.strftime('%d-%b-%Y')
      @transaction_id = seed_transaction({
        actor: @anchor_actor,
        counter_party: @vendor_actor,
        invoice_details: @testdata['Vendor Invoice Details'],
        invoice_file: @invoice_file,
        program: 'Invoice Financing - Vendor',
        investor_id: @investor_id,
        bulk_upload: true,
        investor_actor: @investor_actor,
        program_group: 'invoice'
      })
      details = disburse_transaction(
        {
          transaction_id: @transaction_id,
          invoice_value: @testdata['Vendor Invoice Details']['Invoice Value'],
          tenor: 60,
          type: 'frontend',
          date_of_payment: Date.today.strftime('%d-%b-%Y'),
          payment_proof: @reupload_mou,
          program: 'Invoice Financing - Vendor',
          investor_actor: @investor_actor,
          yield: @vendor_commercial_response[:body][:program_limits][:yield],
          margin: @commercial_response[:body][:result][:discount_percentage]
        }
      )
      expect(details).not_to include('Error while disbursements')
    end
  end

  it 'Commercials: Edit Commercials: Mail Notification Verification' do |e|
    e.run_step "Verify mails are received with subject 'limits are about to expire'" do
      p_resp = fetch_up_for_renewal_cards(@investor_actor, 'pgmlimit')
      c_resp = fetch_up_for_renewal_cards(@investor_actor, 'chnllimit')
      total_cards_about_to_expire = p_resp[0].count + c_resp[0].count
      subject = "#{total_cards_about_to_expire} limits are about to expire"
      body_content = ['HOME CREDIT INDIA FINANCE PRIVATE LIMITED', 'Here is a list of limits which are expiring in the next 45 days',
                      'Please review and renew limits to keep the programs running']
      email_body = $mail_helper.fetch_mail({ subject: subject, body: body_content }, 25)
      [p_resp, c_resp].each do |resp|
        resp.each do |comm|
          expect(email_body.include?(comm[:anchor_name])).to eq(true)
          expect(email_body.include?(comm[:program_name])).to eq(true)
        end
      end
    end
  end
end
