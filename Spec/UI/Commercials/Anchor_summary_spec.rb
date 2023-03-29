require './spec_helper'
describe 'Anchor Summary: Data Verification', :scf, :commercials, :anchor_summary do
  before(:all) do
    @mou = "#{Dir.pwd}/test-data/attachments/borrowing_document.pdf"
    @reupload_mou = "#{Dir.pwd}/test-data/attachments/reinitiate_invoice.pdf"
    @anchor_name = $conf['users']['anchor_summary_anchor']['name']
    @dealer_name = $conf['users']['anchor_summary_dealer']['name']
    @vendor_name = $conf['users']['anchor_summary_vendor']['name']
    @counterparty_gstn = $conf['users']['anchor_summary_anchor']['gstn']
    @dealer_gstn = $conf['users']['anchor_summary_dealer']['gstn']
    @vendor_gstn = $conf['users']['anchor_summary_vendor']['gstn']
    @investor_name = $conf['investor_name']
    @invoice_file = "#{Dir.pwd}/test-data/attachments/anchor_invoice.pdf"
    @payment_proof = "#{Dir.pwd}/test-data/attachments/payment_proof.pdf"
    @erb_file = File.read("#{Dir.pwd}/test-data/erb/testbed_data.erb")
    @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
    clear_all_overdues({ anchor: $conf['users']['anchor_summary_anchor']['name'], vendor: $conf['users']['anchor_summary_dealer']['name'] })
    clear_all_overdues({ anchor: $conf['users']['anchor_summary_anchor']['name'], vendor: $conf['users']['anchor_summary_vendor']['name'] })
  end

  before(:each) do
    @driver = Tarspect::Browser.new($conf['browser']).invoke
    @tarspect_methods = Common::Methods.new(@driver)
    @common_pages = Pages::CommonMethods.new(@driver)
    @commercials_page = Pages::Commercials.new(@driver)
    @disbursement_page = Pages::Disbursement.new(@driver)
  end

  after(:each) do |e|
    snap_screenshot(e)
  end

  it 'Verification of Anchor Summary', :no_run do |e|
    e.run_step 'Login as Investor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['investor']['email'], $conf['users']['investor']['password'])).to be true
    end

    e.run_step 'Go to Anchor Summary and Verify Sanction Limit' do
      @common_pages.click_menu(MENU_ANCHOR_LIST)
      @common_pages.apply_list_filter({ 'Anchor Name' => @anchor_name })
      @tarspect_methods.wait_for_loader_to_disappear
      @common_pages.navigate_to_anchor(@anchor_name)
      resp = fetch_anchor_profile('investor', 128)
      expect(resp[:code]).to eq(200)
      @before_hash = {
        'Vendors Disbursed' => resp[:body][:profile][:vendors_disbursed],
        'First Disbursal' => resp[:body][:profile][:date_of_first_disbursal],
        'Amount Outstanding as of ' => resp[:body][:profile][:total_outstanding_transaction_value],
        'Overdues as of ' => resp[:body][:profile][:total_overdue_transaction_value],
        'Max DPD' => resp[:body][:profile][:max_dpd],
        'Number of Live Transactions' => resp[:body][:profile][:live_transaction_count]
      }
      @common_pages.select_program('Invoice Financing', 'Vendor')
      limit = 0
      limit += @common_pages.get_max_limit.to_i
      @common_pages.click_back_button
      sleep 1
      @common_pages.select_program('Invoice Financing', 'Dealer')
      limit += @common_pages.get_max_limit.to_i
      @common_pages.click_back_button
      sleep 1
      @common_pages.select_program('PO Financing', 'Vendor')
      limit += @common_pages.get_max_limit.to_i
      @common_pages.click_back_button
      sleep 1
      @common_pages.select_program('PO Financing', 'Dealer')
      limit += @common_pages.get_max_limit.to_i
      @common_pages.click_back_button
      program_limits = @commercials_page.capture_program_limits
      expect(program_limits[0]).to eq(limit.to_s)
      expect(program_limits[1]).to eq(limit.to_s)
    end

    e.run_step 'Get borrowers list data before transaction initiation' do
      resp = single_view_data_aggregation('investor', "/?'anchor_ids[]'=128&'vendor_ids[]'=#{$conf['users']['anchor_summary_dealer']['id']}&'vendor_ids[]'=#{$conf['users']['anchor_summary_vendor']['id']}")
      @before_tran = resp[:body][:aggregations]
      expect(resp[:code]).to eq(200)
    end

    e.run_step 'Create a complete Invoice dealer transaction as Anchor(Draft -> Released)' do
      @testdata['Dealer Invoice Details']['Invoice Date'] = (Date.today - 45).strftime('%d-%b-%Y')
      @transaction_id = seed_transaction({
                                           actor: 'anchor_summary_dealer',
                                           counter_party: 'anchor_summary_anchor',
                                           invoice_details: @testdata['Dealer Invoice Details'],
                                           invoice_file: @invoice_file,
                                           program: 'Invoice Financing - Dealer',
                                           investor_id: 7,
                                           program_group: 'invoice'
                                         })
      expect(@transaction_id).not_to include('Error while creating transaction')
      @current_due_date = (Date.today - 45).strftime('%d-%b-%Y')
      @details = disburse_transaction({
                                        transaction_id: @transaction_id,
                                        invoice_value: @testdata['Dealer Invoice Details']['Invoice Value'],
                                        type: 'frontend',
                                        date_of_payment: @current_due_date,
                                        payment_proof: @payment_proof,
                                        program: 'Invoice Financing - Dealer',
                                        tenor: 45,
                                        yield: 12
                                      })
      expect(@details).not_to include('Error while disbursements')
    end

    e.run_step 'Create a complete Invoice vendor transaction as Anchor(Draft -> Released)' do
      @testdata['Vendor Invoice Details']['Invoice Date'] = (Date.today - 60).strftime('%d-%b-%Y')
      @transaction_id_1 = seed_transaction({
                                             actor: 'anchor_summary_vendor',
                                             counter_party: 'anchor_summary_anchor',
                                             invoice_details: @testdata['Vendor Invoice Details'],
                                             invoice_file: @invoice_file,
                                             program: 'Invoice Financing - Vendor',
                                             program_group: 'invoice'
                                           })
      expect(@transaction_id_1).not_to include('Error while creating transaction')
      @current_due_date = (Date.today - 60).strftime('%d-%b-%Y')
      @details_1 = disburse_transaction({
                                          transaction_id: @transaction_id_1,
                                          invoice_value: @testdata['Vendor Invoice Details']['Invoice Value'],
                                          type: 'frontend',
                                          date_of_payment: @current_due_date,
                                          payment_proof: @payment_proof,
                                          program: 'Invoice Financing - Vendor',
                                          yield: 15
                                        })
      expect(@details_1).not_to eq 'Error while disbursements'
    end

    e.run_step 'Get borrowers list data after transaction initiation' do
      sleep 45 # Wait for data to reflect in borrowers summary
      resp = single_view_data_aggregation('investor', "/?'anchor_ids[]'=128&'vendor_ids[]'=#{$conf['users']['anchor_summary_dealer']['id']}&'vendor_ids[]'=#{$conf['users']['anchor_summary_vendor']['id']}")
      expect(resp[:code]).to eq(200)
      @after_tran = resp[:body][:aggregations]
      @before_tran[:total_outstanding] += @details[0][0] + @details_1[0][0]
      @before_tran[:live_transactions] += 2
      @before_tran[:total_available_limit] -= @details[0][0] + @details_1[0][0]
      expect(@before_tran).to eq(@after_tran)
    end

    e.run_step 'Verify Data in Anchor Summary' do
      resp = fetch_anchor_profile('investor', 128)
      expect(resp[:code]).to eq(200)
      @after_hash = {
        'Vendors Disbursed' => resp[:body][:profile][:vendors_disbursed],
        'First Disbursal' => resp[:body][:profile][:date_of_first_disbursal],
        'Amount Outstanding as of ' => resp[:body][:profile][:total_outstanding_transaction_value].round(2),
        'Overdues as of ' => resp[:body][:profile][:total_overdue_transaction_value].round(2),
        'Max DPD' => resp[:body][:profile][:max_dpd],
        'Number of Live Transactions' => resp[:body][:profile][:live_transaction_count]
      }
      amount = @before_hash['Amount Outstanding as of '] + @details[0][0] + @details_1[0][0]
      @before_hash['Amount Outstanding as of '] = amount.round(2)
      @before_hash['Number of Live Transactions'] += 2
      overdue = @before_hash['Overdues as of '] + @details[0][0] + @details_1[0][0]
      @before_hash['Overdues as of '] = overdue.round(2)
      expect(@after_hash).to eq(@before_hash)
      refresh_page
      @tarspect_methods.click_button('Show More')
      @after_hash = @commercials_page.capture_anchor_summary('General')
      amount = rounded_half_down_value(amount / 100_000) if amount > 100_000
      overdue = rounded_half_down_value(overdue / 100_000) if overdue > 100_000
      expect(@after_hash['Amount Outstanding as of '].delete('LAC').to_f).to eq(amount.to_f)
      expect(@after_hash['Overdues as of '].delete('LAC').to_f).to eq(overdue.to_f)
    end
  end
end
