require './spec_helper'
require 'csv'
describe 'Statement of Accounts: Reports Verification', :scf, :soa, :reports, :mails do
  before(:all) do
    @anchor_name = $conf['anchor_name']
    @dealer_name = $conf['users']['Soa_Stg_dealer']['name']
    @dealer_gstn = $conf['users']['Soa_Stg_dealer']['gstn']
    @counterparty_gstn = $conf['myntra_gstn']
    @dealer = 'Stg Sonerto'
    @investor_name = $conf['investor_name']
    @erb_file = File.read("#{Dir.pwd}/test-data/erb/testbed_data.erb")
    @testdata = JSON.parse(ERB.new(@erb_file).result(binding))['Dealer Invoice Details']
    @invoice_file = "#{Dir.pwd}/test-data/attachments/dealer_invoice.pdf"
    @payment_proof = "#{Dir.pwd}/test-data/attachments/payment_proof.pdf"
    @download_path = "#{Dir.pwd}/test-data/downloaded/soa"
    @vendor_id = $conf['users']['Soa_Stg_dealer']['id']
    @anchor_id = $conf['users']['anchor']['id']
  end

  before(:each) do
    @driver = Tarspect::Browser.new($conf['browser'], @download_path).invoke
    @tarspect_methods = Common::Methods.new(@driver)
    @common_pages = Pages::CommonMethods.new(@driver)
    @commercials_page = Pages::Commercials.new(@driver)
    @transactions_page = Pages::Trasactions.new(@driver)
    @disbursement_page = Pages::Disbursement.new(@driver)
    clear_all_overdues({ anchor: $conf['anchor_name'], vendor: @dealer_name })
  end

  after(:each) do |e| # Captures screenshot of the current page when failure happens
    flush_directory(@download_path)
    snap_screenshot(e)
    quit_browser
  end

  it 'SOA: Report Generation by Anchor', :soa_anchor do |e|
    e.run_step 'Create a transaction -> Disbursement -> Repayment' do
      @testdata['Invoice Date'] = (Date.today - 60).strftime('%d-%b-%Y')
      @transaction_id = seed_transaction({
                                           actor: 'anchor',
                                           counter_party: 'Soa_Stg_dealer',
                                           invoice_details: @testdata,
                                           invoice_file: @invoice_file,
                                           program: 'Invoice Financing - Dealer',
                                           program_group: 'invoice'
                                         })
      expect(@transaction_id).not_to include('Error while creating transaction')
      @details = disburse_transaction({
                                        transaction_id: @transaction_id,
                                        invoice_value: @testdata['Invoice Value'],
                                        type: 'rearend',
                                        date_of_payment: @testdata['Invoice Date'],
                                        payment_proof: @payment_proof,
                                        program: 'Invoice Financing - Dealer'
                                      })
      expect(@details).not_to include('Error while disbursements')
      sleep MAX_LOADER_TIME # Wait for data reflection
      repay_hash = { overdue_amount: @details[0][0], investor_id: 7, program_id: $conf['programs']['Invoice Financing - Dealer'],
                     vendor_id: @vendor_id, anchor_id: @anchor_id, payment_date: Date.today }
      resp = repay(repay_hash, 'investor')
      expect(resp[:code]).to eq(200), resp.to_s
      expect(resp).not_to include('No dues present for')
      expect(resp[:code]).to eq(200), resp.to_s
      @repayment_amount = resp[:body][:payment_amount]
    end

    e.run_step "Login as Anchor : #{@anchor_name}" do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['anchor']['email'], $conf['users']['anchor']['password'])).to be true
    end

    e.run_step 'Verify Statement of Accounts can be generated for Dealer' do
      @common_pages.click_menu(MENU_REPORTS)
      hash = {
        'Report Name' => 'Statement Of Accounts',
        'Program Type' => 'Dealer Financing',
        'Instrument Type' => 'Invoice',
        'Vendor/Dealer' => @dealer,
        'Investor' => @investor_name,
        'date_range' => [get_todays_date(-60, '%d-%m-%Y'), get_todays_date(nil, '%d-%m-%Y')]
      }
      sleep 200
      # Waiting for data reflection
      expect(@common_pages.generate_report(hash, $conf['users']['anchor']['email'], 'Statement Of Accounts')).to eq true
    end

    e.run_step 'Verify mail recieved on report generation and verify the file' do
      @from = Date.today - 60
      @to = Date.today
      from = @from.strftime('%Y-%m-%d')
      to = @to.strftime('%Y-%m-%d')
      email_values = {
        mail_box: $conf['notification_mailbox'],
        subject: "SOA Report for #{from} to #{to}",
        body: "#{from} to #{to}",
        link_text: 'statement_of_accounts'
      }
      filename = "STATEMENT_OF_ACCOUNTS_#{from}_to_#{to}_#{Date.today.strftime('%Y%m%d')}"
      @common_pages.get_link_from_mail(email_values, new_tab: false)
      downloadedfile = @common_pages.check_for_file(filename, @download_path)
      expect(downloadedfile).to include(filename), "File not downloaded #{downloadedfile} <> #{filename}"
      @csv_data = CSV.parse(File.read("#{@download_path}/#{downloadedfile}.csv"), headers: true)
      expected_data = {
        'disburse_data' => [from, @details[0][0].to_f],
        'repayment_data' => [to, @repayment_amount.to_f]
      }
      expect(@common_pages.validate_csv(@csv_data, expected_data)).to eq(true)
    end

    e.run_step "Logout as Anchor : #{@anchor_name}" do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Product' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['product']['email'], $conf['users']['product']['password'])).to be true
    end

    e.run_step 'Verify report can be generated by product' do
      @common_pages.click_menu(MENU_REPORTS)
      hash = { 'User Type' => 'Anchor' }
      @tarspect_methods.fill_form(hash, 1, 2)
      @common_pages.select_report_menu('Anchor', 'Myntra')
      hash = {
        'Report Name' => 'Statement Of Accounts',
        'Program Type' => 'Dealer Financing',
        'Instrument Type' => 'Invoice',
        'Vendor/Dealer' => @dealer,
        'Investor' => @investor_name,
        'date_range' => [get_todays_date(-60, '%d-%m-%Y'), get_todays_date(nil, '%d-%m-%Y')]
      }
      sleep 2
      @common_pages.generate_report(hash, $conf['users']['product']['email'], 'Statement Of Accounts')
    end

    e.run_step 'Verify mail recieved on report generation and verify the file' do
      @from = Date.today - 60
      @to = Date.today
      from = @from.strftime('%Y-%m-%d')
      to = @to.strftime('%Y-%m-%d')
      email_values = {
        mail_box: $conf['notification_mailbox'],
        subject: "SOA Report for #{from} to #{to}",
        body: "#{from} to #{to}",
        link_text: 'statement_of_accounts'
      }
      filename = "STATEMENT_OF_ACCOUNTS_#{from}_to_#{to}_#{Date.today.strftime('%Y%m%d')}"
      report_link = @common_pages.get_link_from_mail(email_values, new_tab: true)
      expect(report_link.to_s.empty?).to eq(false), 'No link present in mail'
      downloadedfile = @common_pages.check_for_file(filename, @download_path)
      expect(downloadedfile).to include(filename), "File not downloaded #{downloadedfile} <> #{filename}"
      @csv_data = CSV.parse(File.read("#{@download_path}/#{downloadedfile}.csv"), headers: true)

      expected_data = {
        'disburse_data' => [from, @details[0][0].to_f],
        'repayment_data' => [to, @repayment_amount.to_f]
      }
      expect(@common_pages.validate_csv(@csv_data, expected_data)).to eq(true)
    end
  end

  it 'SOA: Verify SOA cannot be generated for more than 180 days', :soa_morethan_180 do |e|
    e.run_step "Login as Anchor : #{@anchor_name}" do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['anchor']['email'], $conf['users']['anchor']['password'])).to be true
    end

    e.run_step 'Verify SOA cannot be generated for more than 180 days' do
      @common_pages.click_menu(MENU_REPORTS)
      hash = {
        'Report Name' => 'Statement Of Accounts',
        'Program Type' => 'Dealer Financing',
        'Instrument Type' => 'Invoice',
        'Vendor/Dealer' => @dealer,
        'Investor' => @investor_name,
        'date_range' => [get_todays_date(-190, '%d-%m-%Y'), get_todays_date(nil, '%d-%m-%Y')]
      }
      sleep 2
      expect(@common_pages.generate_report(hash, $conf['users']['anchor']['email'], 'Statement Of Accounts', postive_case: false)).to eq($notifications['SOA_Maximum_Duration'])
    end

    e.run_step "Logout as Anchor : #{@anchor_name}" do
      expect(@common_pages.logout).to eq true
    end
  end

  it 'SOA: Report Generation by Vendor/Dealer', :no_run do |e|
    @vendor_name = $conf['users']['vendor']['name']
    e.run_step "Login as Vendor : #{@vendor_name}" do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['vendor']['email'], $conf['users']['vendor']['password'])).to be true
    end

    e.run_step 'Verify Statement of Accounts can be generated by Vendor/Dealer' do
      @common_pages.click_menu(MENU_PO_FINANCING)
      @common_pages.wait_for_transactions_to_load
      @common_pages.click_menu(MENU_REPORTS)
      hash = {
        'Report Name' => 'Statement Of Accounts',
        'Program Type' => 'Vendor Financing',
        'Instrument Type' => 'Invoice',
        'Anchor' => 'Myntra',
        'Investor' => @investor_name,
        'date_range' => [get_todays_date(-60, '%d-%m-%Y'), get_todays_date(nil, '%d-%m-%Y')]
      }
      expect(@common_pages.generate_report(hash, $conf['users']['vendor']['email'], 'Statement Of Accounts')).to eq true
    end

    e.run_step 'Verify mail recieved on report generation and download the file' do
      @from = (Date.today - 60).strftime('%Y-%m-%d')
      @to = Date.today.strftime('%Y-%m-%d')
      email_values = {
        mail_box: $conf['notification_mailbox'],
        subject: "SOA Report for #{@from} to #{@to}",
        body: "#{@from} to #{@to}",
        link_text: 'statement_of_accounts'
      }
      filename = "STATEMENT_OF_ACCOUNTS_#{@from}_to_#{@to}_#{Date.today.strftime('%Y%m%d')}"
      @common_pages.get_link_from_mail(email_values, new_tab: false)
      downloadedfile = @common_pages.check_for_file(filename, @download_path)
      expect(downloadedfile).to include(filename), "File not downloaded #{downloadedfile} <> #{filename}"
    end

    e.run_step "Logout as Vendor : #{@vendor_name}" do
      navigate_to($conf['base_url'])
      expect(@common_pages.logout).to eq true
    end
  end
end
