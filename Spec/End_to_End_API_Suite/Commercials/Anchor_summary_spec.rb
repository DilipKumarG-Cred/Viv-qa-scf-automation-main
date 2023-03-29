require './spec_helper'
describe 'Anchor Summary: Data Verification', :scf, :commercials, :anchor_summary do
  before(:all) do
    @mou = "#{Dir.pwd}/test-data/attachments/borrowing_document.pdf"
    @reupload_mou = "#{Dir.pwd}/test-data/attachments/reinitiate_invoice.pdf"
    @anchor_actor = 'anchor_summary_anchor'
    @investor_actor = 'investor'
    @anchor_name = $conf['users']['anchor_summary_anchor']['name']
    @dealer_name = $conf['users']['anchor_summary_dealer']['name']
    @vendor_name = $conf['users']['anchor_summary_vendor']['name']
    @counterparty_gstn = $conf['users']['anchor_summary_anchor']['gstn']
    @dealer_gstn = $conf['users']['anchor_summary_dealer']['gstn']
    @vendor_gstn = $conf['users']['anchor_summary_vendor']['gstn']
    @investor_name = $conf['investor_name']
    @investor_id = $conf['users'][@investor_actor]['id']
    @invoice_file = "#{Dir.pwd}/test-data/attachments/anchor_invoice.pdf"
    @payment_proof = "#{Dir.pwd}/test-data/attachments/payment_proof.pdf"
    @erb_file = File.read("#{Dir.pwd}/test-data/erb/testbed_data.erb")
    @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
    clear_all_overdues({ anchor: @anchor_name, vendor: @dealer_name })
    clear_all_overdues({ anchor: @anchor_name, vendor: @vendor_name })
  end

  it 'Verification of Anchor Summary', :no_run do |e|
    e.run_step 'Verify Anchor Profile' do
      resp = fetch_anchor_profile(@investor_actor, 128)
      expect(resp[:code]).to eq(200)
      total_program_limit = resp[:body][:profile][:sanction_limit]
      @before_hash = {
        'Vendors Disbursed' => resp[:body][:profile][:vendors_disbursed],
        'First Disbursal' => resp[:body][:profile][:date_of_first_disbursal],
        'Amount Outstanding as of ' => resp[:body][:profile][:total_outstanding_transaction_value],
        'Overdues as of ' => resp[:body][:profile][:total_overdue_transaction_value],
        'Max DPD' => resp[:body][:profile][:max_dpd],
        'Number of Live Transactions' => resp[:body][:profile][:live_transaction_count]
      }
      total = 0
      resp = get_all_anchor_programs(@anchor_actor)
      resp[:body][:available_programs][:published_programs].each do |program|
        resp = get_anchor_commercials(investor_actor: @investor_actor, investor_id: @investor_id, anchor_program_id: program[:id])
        total += resp[:body][:result][:max_sanction_limit]
      end
      expect(total_program_limit).to eq(total)
    end

    e.run_step 'Get borrowers list data before transaction initiation' do
      resp = single_view_data_aggregation('investor', "/?'anchor_ids[]'=128&'vendor_ids[]'=#{$conf['users']['anchor_summary_dealer']['id']}&'vendor_ids[]'=#{$conf['users']['anchor_summary_vendor']['id']}")
      @before_tran = resp[:body][:aggregations]
      expect(resp[:code]).to eq(200), resp.to_s
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
      @transaction_id1 = seed_transaction({
                                            actor: 'anchor_summary_vendor',
                                            counter_party: 'anchor_summary_anchor',
                                            invoice_details: @testdata['Vendor Invoice Details'],
                                            invoice_file: @invoice_file,
                                            program: 'Invoice Financing - Vendor',
                                            program_group: 'invoice'
                                          })
      expect(@transaction_id1).not_to include('Error while creating transaction')
      @current_due_date = (Date.today - 60).strftime('%d-%b-%Y')
      @details1 = disburse_transaction({
                                         transaction_id: @transaction_id1,
                                         invoice_value: @testdata['Vendor Invoice Details']['Invoice Value'],
                                         type: 'frontend',
                                         date_of_payment: @current_due_date,
                                         payment_proof: @payment_proof,
                                         program: 'Invoice Financing - Vendor',
                                         yield: 15
                                       })
      expect(@details1).not_to eq 'Error while disbursements'
    end

    e.run_step 'Get borrowers list data after transaction initiation' do
      sleep 45 # Wait for data to reflect in borrowers summary
      resp = single_view_data_aggregation('investor', "/?'anchor_ids[]'=128&'vendor_ids[]'=#{$conf['users']['anchor_summary_dealer']['id']}&'vendor_ids[]'=#{$conf['users']['anchor_summary_vendor']['id']}")
      expect(resp[:code]).to eq(200)
      @after_tran = resp[:body][:aggregations]
      @before_tran[:total_outstanding] += @details[0][0].to_f + @details1[0][0].to_f
      @before_tran[:live_transactions] += 2
      @before_tran[:total_available_limit] -= @details[0][0].to_f + @details1[0][0].to_f
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
      amount = @before_hash['Amount Outstanding as of '] + @details[0][0] + @details1[0][0]
      @before_hash['Amount Outstanding as of '] = amount.round(2)
      @before_hash['Number of Live Transactions'] += 2
      overdue = @before_hash['Overdues as of '] + (@details[0][0] + @details1[0][0])
      @before_hash['Overdues as of '] = overdue.round(2)
      expect(@after_hash).to eq(@before_hash)
    end
  end
end
