require './spec_helper'
describe 'Payment : Repayment: Bulk Upload', :scf, :payments, :bulk, :bulk_repay do
  before(:all) do
    @anchor_actor = 'grn_anchor'
    @anchor_actor1 = 'anchor_summary_anchor'
    @anchor_actor2 = 'anchor'
    @dealer_actor = 'stg_bulk_dealer'
    @dealer_actor1 = 'stg_bulk_lms'
    @dealer_actor2 = 'lms_bulk_dealer'
    @dealer_actor3 = 'lms_po_dealer'
    @investor_actor = 'user_feedback_investor'
    @party_gstn = $conf['users'][@anchor_actor]['gstn']
    @counterparty_gstn = $conf['users'][@dealer_actor]['gstn']
    @dealer_name = $conf['users'][@dealer_actor]['name']
    @dealer_name1 = $conf['users'][@dealer_actor1]['name']
    @dealer_name2 = $conf['users'][@dealer_actor2]['name']
    @dealer_name3 = $conf['users'][@dealer_actor3]['name']
    @anchor_name = $conf['users'][@anchor_actor]['name']
    @anchor_name1 = $conf['users'][@anchor_actor1]['name']
    @anchor_name2 = $conf['users'][@anchor_actor2]['name']
    @dealer_id = $conf['users'][@dealer_actor]['id']
    @invoice_file = "#{Dir.pwd}/test-data/attachments/anchor_invoice.pdf"
    @upload_file = "#{Dir.pwd}/test-data/attachments/repayment_bulk_upload.xlsx"
    @erb_file = File.read("#{Dir.pwd}/test-data/erb/testbed_data.erb")
    @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
    # Due date will be calculated to Today's date - 60. Hence, payments can be paid with interest
    @initiation_date = (Date.today - ($conf['vendor_tenor'] * 2)).strftime('%d-%b-%Y')
    @first_repay_date = (Date.today - ($conf['vendor_tenor'] + 1)).strftime('%d-%b-%Y')
    [[@anchor_name, @dealer_name], [@anchor_name, @dealer_name1], [@anchor_name, @dealer_name2], [@anchor_name1, @dealer_name3], [@anchor_name2, @dealer_name3]].each do |actor|
      @due_date = get_todays_date(nil, '%d-%b-%Y')
      clear_all_overdues({ anchor: actor[0], vendor: actor[1], investor: @investor_actor, payment_date: @due_date })
    end
    @download_path = "#{Dir.pwd}/test-data/downloaded/bulk_repayment"
    flush_directory(@download_path)
    @upload_doc = "#{Dir.pwd}/test-data/attachments/repayment_po_dealer_bulk_upload.xlsx"
    @payment_proof = "#{Dir.pwd}/test-data/attachments/payment_proof.pdf"
  end

  before(:each) do
    @driver = Tarspect::Browser.new($conf['browser'], @download_path).invoke
    @tarspect_methods = Common::Methods.new(@driver)
    @common_pages = Pages::CommonMethods.new(@driver)
    @disbursement_page = Pages::Disbursement.new(@driver)
    @payments_page = Pages::Payment.new(@driver)
    @transactions_page = Pages::Trasactions.new(@driver)
  end

  after(:each) do |e|
    snap_screenshot(e)
    quit_browser
  end

  it 'Payment : Repayment: Bulk Upload', :sanity do |e|
    e.run_step 'Create multiple transactions (Draft -> Released)' do
      resp = get_all_refunds(@dealer_name, @investor_actor)
      expect(resp[:code]).to eq(200), resp.to_s
      @previous_refund_amount = resp[:body][:refund_entities].empty? ? 0 : resp[:body][:refund_entities][0][:refund_amount]
      @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
      @testdata['PO Details']['PO Date'] = @initiation_date
      @transaction_id = seed_transaction({ actor: @dealer_actor, counter_party: @anchor_actor, po_details: @testdata['PO Details'], po_file: @invoice_file, program: 'PO Financing - Dealer', program_group: 'purchase_order' })
      expect(@transaction_id).not_to include('Error while creating transaction')
    end

    e.run_step 'Disburse transactions' do
      @details = disburse_transaction(
        {
          transaction_id: @transaction_id,
          invoice_value: @testdata['PO Details']['Requested Disbursement Value'],
          type: 'frontend',
          date_of_payment: @initiation_date,
          payment_proof: @payment_proof,
          program: 'PO Financing - Dealer',
          investor_actor: @investor_actor,
          tenor: 60,
          strategy: 'simple_interest',
          yield: 10
        }
      )
      expect(@details).not_to eq 'Error while disbursements'
      @payment = @details[0][1] + @details[0][2] + 1000 # Principal amount + Interest + 1000 (Amount to be refunded)
    end

    e.run_step 'Login as Investor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users'][@investor_actor]['email'], $conf['users'][@investor_actor]['password'])).to be true
    end

    e.run_step 'Verify bulk repayment data is uploaded' do
      @common_pages.click_menu(MENU_PO_FINANCING)
      @tarspect_methods.click_button('Add Settlement details')
      @utrs = @payments_page.create_test_data_for_bulk_repayment(@payment, @upload_file)
      @actual_summary, @report_link = @disbursement_page.upload_bulk_disbursement(@upload_file, 'Repayment')
      expect(@report_link.empty?).to eq(false), 'Report link is empty'
    end

    e.run_step 'Verify report of bulk disbursement' do
      expected_report = @payments_page.create_expected_data_for_bulk_repay(@utrs)
      actual_report = @disbursement_page.verify_bulk_disbursment_summary_report(@report_link, 'Repayment')
      expect(actual_report).to eq(expected_report)
    end

    e.run_step 'Verify summary report of bulk disbursement' do
      amount = @payment + 14400 # Remaining amount that are rejected in validation
      formatted_amount = if amount > 100_000
                           "₹ #{get_formatted_amount(amount)} LAC"
                         else
                           "₹ #{get_formatted_amount(amount)}"
                         end
      expected_summary = { 'Total Repayment Value' => formatted_amount, 'Payment accepted' => '6', 'Payment rejected' => '8' }
      expect(@actual_summary).to eq(expected_summary)
    end

    e.run_step 'Verify payment history values' do
      @expected_values = {
        'Payment Status' => 'Success',
        'Paid By' => @dealer_name,
        'Date of Payment' => Date.today.strftime('%d %b, %Y'),
        'UTR Number' => @utrs[0],
        'Payment Type' => 'Repayment',
        'Amount' => "₹ #{comma_seperated_value(@payment / 2.to_f)}"
      }
      @tarspect_methods.DYNAMIC_LOCATOR('do it later').click
      @common_pages.click_menu(MENU_PAYMENT_HISTORY)
      @common_pages.apply_list_filter({ 'Paid By' => "#{@dealer_name} - Vendor / Dealer", 'Type Of Payment' => 'Repayment' })
      expect(@payments_page.verify_transaction_in_payment_history(@expected_values.values)).to eq true
    end

    e.run_step 'Verify payment breakup values' do
      @payments_page.view_detailed_breakup(@expected_values['UTR Number'])
      principal = @payment / 2.to_f - @details[0][2]
      payment_breakup = {
        'Due of Payment' => Date.today.strftime('%d %b, %Y'),
        'Date of Payment' => Date.today.strftime('%d %b, %Y'),
        'DPD' => '-',
        'Payment Type' => 'Late-Payment',
        'Interest Paid' => "₹ #{comma_seperated_value(@details[0][2])}",
        'Total Amount Paid' => "₹ #{comma_seperated_value(@payment / 2.to_f)}",
        'Payment Charges' => '₹ 0'
      }
      expect(@payments_page.verify_transaction_in_payment_history(payment_breakup.values)).to eq true
    end

    e.run_step 'Verify extra payment moved to refund' do
      resp = get_all_refunds(@dealer_name, @investor_actor)
      actual = resp[:body][:refund_entities][0][:refund_amount]
      expected = @previous_refund_amount
      expect(actual - expected).to be_between(-0.1, 0.1)
    end
  end

  [['grn_anchor', 'stg_bulk_lms', 'lms_bulk_dealer'], ['lms_po_dealer', 'anchor', 'anchor_summary_anchor']].each do |actor|
    it 'Payment : Repayment: Bulk Upload with Optional Anchor Pan and Optional Channel Partner Pan' do |e|
      e.run_step 'Create 2 transactions (Draft -> Released) with multiple anchors and multiple channel partners' do
        @testdata1 = JSON.parse(ERB.new(@erb_file).result(binding))
        @testdata2 = JSON.parse(ERB.new(@erb_file).result(binding))
        if actor[2].eql?('lms_bulk_dealer')
          @testdata1['PO Details']['GSTN of Channel Partner'] = $conf['users'][actor[1]]['gstn']
          @testdata2['PO Details']['GSTN of Channel Partner'] = $conf['users'][actor[2]]['gstn']
          @testdata1['PO Details']['GSTN of Anchor'] = $conf['users'][actor[0]]['gstn']
          @testdata2['PO Details']['GSTN of Anchor'] = $conf['users'][actor[0]]['gstn']
        else
          @testdata1['PO Details']['GSTN of Channel Partner'] = $conf['users'][actor[0]]['gstn']
          @testdata1['PO Details']['GSTN of Anchor'] = $conf['myntra_gstn']
          @testdata2['PO Details']['GSTN of Channel Partner'] = $conf['users'][actor[0]]['gstn']
          @testdata2['PO Details']['GSTN of Anchor'] = $conf['users'][actor[2]]['gstn']
          @upload_doc = "#{Dir.pwd}/test-data/attachments/repayment_po_dealer_upload.xlsx"
        end
        @transaction_id = seed_transaction({ actor: actor[1], counter_party: actor[0], po_details: @testdata1['PO Details'], po_file: @invoice_file, program: 'PO Financing - Dealer', program_group: 'purchase_order' })
        expect(@transaction_id).not_to include('Error while creating transaction')
        @transaction_id1 = seed_transaction({ actor: actor[2], counter_party: actor[0], po_details: @testdata2['PO Details'], po_file: @invoice_file, program: 'PO Financing - Dealer', program_group: 'purchase_order' })
        expect(@transaction_id1).not_to include('Error while creating transaction')
      end

      e.run_step 'Disburse all the transactions' do
        @details = disburse_transaction(
          {
            transaction_id: @transaction_id,
            invoice_value: @testdata1['PO Details']['Requested Disbursement Value'],
            type: 'frontend',
            date_of_payment: @testdata1['PO Details']['PO Date'],
            payment_proof: @payment_proof,
            program: 'PO Financing - Dealer',
            investor_actor: @investor_actor,
            tenor: 60,
            strategy: 'simple_interest',
            yield: 10
          }
        )
        expect(@details).not_to eq 'Error while disbursements'

        @details1 = disburse_transaction(
          {
            transaction_id: @transaction_id1,
            invoice_value: @testdata2['PO Details']['Requested Disbursement Value'],
            type: 'frontend',
            date_of_payment: @initiation_date,
            payment_proof: @payment_proof,
            program: 'PO Financing - Dealer',
            investor_actor: @investor_actor,
            tenor: 60,
            strategy: 'simple_interest',
            yield: 10
          }
        )
        expect(@details1).not_to eq 'Error while disbursements'
      end

      e.run_step 'Login as Investor' do
        navigate_to($conf['base_url'])
        expect(@tarspect_methods.login($conf['users'][@investor_actor]['email'], $conf['users'][@investor_actor]['password'])).to be true
      end

      e.run_step 'Verify bulk repayment data is uploaded' do
        @common_pages.click_menu(MENU_PO_FINANCING)
        @tarspect_methods.click_button('Add Settlement details')
        @tran_resp = get_po_details(@transaction_id)
        @tran_resp1 = get_po_details(@transaction_id1)
        @due_date1 = Date.parse(@tran_resp[:body][:settlement_date], 'dd-mmm-yyyy')
        @due_date2 = Date.parse(@tran_resp1[:body][:settlement_date], 'dd-mmm-yyyy')
        if @due_date1 < @due_date2 || @due_date1 == @due_date2
          @payment = @tran_resp[:body][:total_outstanding] + 1000
          @po_number = @tran_resp[:body][:po_number]
          @trans_id = @transaction_id
          @re_payment = @tran_resp1[:body][:total_outstanding] + 1000
          @cp_name = $conf['users'][actor[2]]['name']
        else
          @payment = @tran_resp1[:body][:total_outstanding] + 1000
          @po_number = @tran_resp1[:body][:po_number]
          @trans_id = @transaction_id1
          @re_payment = @tran_resp[:body][:total_outstanding] + 1000
          @cp_name = $conf['users'][actor[1]]['name']
        end
        @cp_name = $conf['users'][actor[0]]['name'] if actor[0].eql?('lms_po_dealer')
        @utrs = @payments_page.create_test_data_for_repayment(@payment, @upload_doc)
        @actual_summary, @report_link = @disbursement_page.upload_bulk_disbursement(@upload_doc, 'Repayment')
        expect(@report_link.empty?).to eq(false), 'Report link is empty'
      end

      e.run_step 'Verify the first overdue transaction is moved to matured state' do
        navigate_to($conf['base_url'])
        @common_pages.click_menu(MENU_PO_FINANCING)
        @common_pages.click_transactions_tab(MATURED)
        @common_pages.navigate_to_transaction(@trans_id)
        expect(@transactions_page.verify_transaction_status('Matured')).to eq true
      end

      e.run_step 'Clear all the initiated transactions' do
        [[@anchor_name, @dealer_name], [@anchor_name, @dealer_name1], [@anchor_name, @dealer_name2], [@anchor_name1, @dealer_name3], [@anchor_name2, @dealer_name3]].each do |role|
          @due_date = get_todays_date(nil, '%d-%b-%Y')
          clear_all_overdues({ anchor: role[0], vendor: role[1], investor: @investor_actor, payment_date: @due_date })
        end
      end
    end
  end
end
