require './spec_helper'
require 'erb'
describe 'Due Date Calculation', :scf, :disbursements, :due_date_calculation do
  before(:all) do
    @counterparty_gstn = $conf['myntra_gstn']
    @dealer_gstn = $conf['trends_gstn']
    @dealer_name = $conf['dealer_name']
    @anchor_name = $conf['anchor_name']
    @vendor_name = $conf['dealer_name']
    @invoice_file = "#{Dir.pwd}/test-data/attachments/anchor_invoice.pdf"
    @payment_proof = "#{Dir.pwd}/test-data/attachments/payment_proof.pdf"
    @erb_file = File.read("#{Dir.pwd}/test-data/erb/testbed_data.erb")
    @current_due_date = (Date.today - $conf['vendor_tenor']).strftime('%d-%b-%Y')
    @door_to_door_tenor = $conf['door_to_door_tenor']
    @calculate_hash = {
      invoice_value: '',
      margin: $conf['margin'],
      yield: $conf['yield'],
      tenor: 30,
      type: 'backend'
    }
  end

  before(:each) do
    clear_all_overdues({ anchor: $conf['anchor_name'], vendor: $conf['dealer_name'] })
    @driver = Tarspect::Browser.new($conf['browser']).invoke
    @tarspect_methods = Common::Methods.new(@driver)
    @common_pages = Pages::CommonMethods.new(@driver)
    @transactions_page = Pages::Trasactions.new(@driver)
    @disbursement_page = Pages::Disbursement.new(@driver)
    @payments_page = Pages::Payment.new(@driver)
    @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
  end

  after(:each) do |e| # Captures screenshot of the current page when failure happens
    snap_screenshot(e)
    quit_browser
  end

  it 'Due Date Calculation: Door to Door tenor', :sanity do |e|
    e.run_step 'Create a complete transaction as Anchor(Draft -> Released)' do
      @testdata['Dealer Invoice Details']['Invoice Date'] = (Date.today - 20).strftime('%d-%b-%Y')
      @transaction_id = seed_transaction({
                                           actor: 'dealer',
                                           counter_party: 'anchor',
                                           invoice_details: @testdata['Dealer Invoice Details'],
                                           invoice_file: @invoice_file,
                                           program: 'Invoice Financing - Dealer',
                                           program_group: 'invoice'
                                         })
      expect(@transaction_id).not_to include('Error while creating transaction')
    end

    e.run_step 'Login as Anchor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['anchor']['email'], $conf['users']['anchor']['password'])).to eq true
    end

    e.run_step 'Verify Tenor,Due Date in transaction details page before disbursement - D2D' do
      @common_pages.navigate_to_transaction(@transaction_id)
      @testdata['Transaction Details'].merge!(
        'Tenor' => '80  Days',
        'Due Date' => (Date.today + 80).strftime('%d %b, %Y'),
        'Instrument Value' => "₹#{comma_seperated_value(@testdata['Dealer Invoice Details']['Invoice Value'])}",
        'Instrument Date' => (Date.today - 20).strftime('%d %b, %Y')
      )
      expect(@transactions_page.verify_transaction_in_detail_page(@testdata['Transaction Details'])).to eq true
    end

    e.run_step 'Anchor Logs out' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Investor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['investor']['email'], $conf['users']['investor']['password'])).to eq true
    end

    e.run_step 'Disburse the amount' do
      details = disburse_transaction({
                                       transaction_id: @transaction_id,
                                       invoice_value: @testdata['Dealer Invoice Details']['Invoice Value'],
                                       type: 'rearend',
                                       date_of_payment: Date.today.strftime('%d-%b-%Y'),
                                       payment_proof: @payment_proof,
                                       program: 'Invoice Financing - Dealer'
                                     })
      expect(details).not_to include('Error while disbursements')
    end

    e.run_step 'Verify Due Date calculated based on Door to Door tenor' do
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @common_pages.click_transactions_tab(DUE_FOR_PAYMENT)
      @common_pages.apply_list_filter({ 'Vendor/Dealer' => @dealer_name })
      @payments_page.select_overdue_details(@dealer_name)
      # Due date calculation
      invoice_date = Date.strptime(@testdata['Dealer Invoice Details']['Invoice Date'], '%d-%b-%Y')
      due_date = invoice_date + @door_to_door_tenor
      # Verifying Due date under Transactions tab
      result = @payments_page.verify_transaction_in_due_for_payments(
        @testdata['Dealer Invoice Details']['Invoice Number'],
        due_date.strftime('%d %b, %Y')
      )
      expect(result).to eq true
      @tarspect_methods.DYNAMIC_LOCATOR(@testdata['Dealer Invoice Details']['Invoice Number']).click
      @testdata['Transaction Details']['Tenor'] = '80  Days'
      @testdata['Transaction Details']['Due Date'] = (Date.today + 80).strftime('%d %b, %Y')
      expect(@transactions_page.verify_transaction_in_detail_page(@testdata['Transaction Details'])).to eq true
    end
  end

  it 'Due Date Calculation: Tenor at Invoice level', :sanity do |e|
    e.run_step 'Create a complete transaction as Anchor(Draft -> Released)' do
      @testdata['Dealer Invoice Details']['Invoice Date'] = (Date.today - 120).strftime('%d-%b-%Y')
      @testdata['Dealer Invoice Details'].merge!('tenor' => 30)
      @transaction_id = seed_transaction({
                                           actor: 'dealer',
                                           counter_party: 'anchor',
                                           invoice_details: @testdata['Dealer Invoice Details'],
                                           invoice_file: @invoice_file,
                                           program: 'Invoice Financing - Dealer',
                                           program_group: 'invoice'
                                         })
      expect(@transaction_id).not_to include('Error while creating transaction')
    end

    e.run_step 'Login as Anchor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['anchor']['email'], $conf['users']['anchor']['password'])).to eq true
    end

    e.run_step 'Verify Tenor,Due Date in transaction details page before disbursement' do
      @common_pages.navigate_to_transaction(@transaction_id)
      @calculate_hash[:invoice_value] = @testdata['Dealer Invoice Details']['Invoice Value']
      @transaction_values = @disbursement_page.calculate_transaction_values(@calculate_hash)
      @testdata['Transaction Details'].merge!(
        'Tenor' => '30  Days',
        'Due Date' => (Date.today + 30).strftime('%d %b, %Y'),
        'Instrument Value' => "₹#{comma_seperated_value(@testdata['Dealer Invoice Details']['Invoice Value'])}",
        'Instrument Date' => (Date.today - 120).strftime('%d %b, %Y'),
        'Interest Chargeable' => "₹#{comma_seperated_value(@transaction_values[2])}"
      )
      expect(@transactions_page.verify_transaction_in_detail_page(@testdata['Transaction Details'])).to eq true
    end

    e.run_step 'Anchor Logs out' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Investor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['investor']['email'], $conf['users']['investor']['password'])).to eq true
    end

    e.run_step 'Disburse the amount' do
      details = disburse_transaction({
                                       transaction_id: @transaction_id,
                                       invoice_value: @testdata['Dealer Invoice Details']['Invoice Value'],
                                       type: 'rearend',
                                       date_of_payment: @current_due_date,
                                       payment_proof: @payment_proof,
                                       program: 'Invoice Financing - Dealer'
                                     })
      expect(details).not_to include('Error while disbursements')
    end

    e.run_step 'Verify Due Date and Interest chargeable calculated based on tenor at invoice level' do
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @common_pages.click_transactions_tab('Due For Payment')
      @common_pages.apply_list_filter({ 'Vendor/Dealer' => @dealer_name })
      @payments_page.select_overdue_details(@dealer_name)
      # Due date calculation
      # Disbursal date + tenor at invoice level should be minimum due date
      due_date2 = Date.parse(@current_due_date) + 30
      # Verifying Due date under Transactions tab
      @common_pages.apply_list_filter('date_range' => [{ 'Due Date' => due_date2.strftime('%d %b, %Y') }, { 'Due Date' => (Date.parse(@current_due_date) + 31).strftime('%d %b, %Y') }])
      result = @payments_page.verify_transaction_in_due_for_payments(
        @testdata['Dealer Invoice Details']['Invoice Number'],
        due_date2.strftime('%d %b, %Y')
      )
      expect(result).to eq true
      @tarspect_methods.DYNAMIC_LOCATOR(@testdata['Dealer Invoice Details']['Invoice Number']).click
      @testdata['Transaction Details']['Due Date'] = (Date.today - 30).strftime('%d %b, %Y')
      # Verified that the Interest Chargeable before and after disbursement remains same.
      expect(@transactions_page.verify_transaction_in_detail_page(@testdata['Transaction Details'])).to eq true
    end
  end
end
