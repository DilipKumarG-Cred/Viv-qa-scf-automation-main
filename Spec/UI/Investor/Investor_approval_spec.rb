require './spec_helper'
describe 'Investor Manual Approval', :scf, :investor_manual_approval do
  before(:all) do
    @investor_admin = 'investor_profile_investor'
    @anchor_actor = 'interest_calc_anchor'
    @vendor_actor = 'interest_calc_vendor'
    @vendor_name = $conf['users'][@vendor_actor]['name']
    @erb_file = File.read("#{Dir.pwd}/test-data/erb/testbed_data.erb")
    @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
    @invoice_file = "#{Dir.pwd}/test-data/attachments/anchor_invoice.pdf"
    @testdata['Invoice Details']['GSTN of Anchor'] = $conf['users'][@anchor_actor]['gstn']
    @testdata['Invoice Details']['GSTN of Channel Partner'] = $conf['users'][@vendor_actor]['gstn']
    @program_id = $conf['programs']['Invoice Financing - Vendor']
    @payment_proof = "#{Dir.pwd}/test-data/attachments/payment_proof.pdf"
    @re_initiate_file = "#{Dir.pwd}/test-data/attachments/reinitiate_invoice.pdf"
    @calculate_hash = { invoice_value: '', margin: $conf['margin'], yield: $conf['yield'], tenor: $conf['vendor_tenor'], type: 'frontend', strategy: 'simple_interest' }
  end

  before(:each) do
    @driver = Tarspect::Browser.new($conf['browser']).invoke
    @tarspect_methods = Common::Methods.new(@driver)
    @common_pages = Pages::CommonMethods.new(@driver)
    @transactions_page = Pages::Trasactions.new(@driver)
    @disbursement_page = Pages::Disbursement.new(@driver)
  end

  after(:each) do |e| # Captures screenshot of the current page when failure happens
    snap_screenshot(e)
    quit_browser
  end

  it 'Transaction : Investor Approval' do |e|
    e.run_step 'Login as Vendor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users'][@vendor_actor]['email'], $conf['users'][@vendor_actor]['password'])).to eq true
    end

    e.run_step 'Create a complete transaction as Vendor(Draft -> Released)' do
      @transaction_details = create_transaction(@vendor_actor, @testdata['Invoice Details'], @invoice_file, @program_id)
      expect(@transaction_details[:code]).to eq(200), @transaction_details.to_s
      @transaction_id = @transaction_details[:body][:id]
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @common_pages.click_transactions_tab(UNASSIGNED_INVESTOR)
      @tarspect_methods.click_button('Reassign')
      @common_pages.reassign_investor('State Bank Of India')
    end

    e.run_step 'Logout as vendor' do
      expect(@common_pages.logout).to eq true
    end

    ['product', @anchor_actor, 'product'].each do |actor|
      e.run_step "Approve transaction as #{actor}" do
        rel_values = {
          actor: actor,
          program_id: @program_id,
          transaction_id: @transaction_id,
          todo: 'approved',
          can_reinitiate: false,
          comment: 'Approved',
          program_group: 'invoice'
        }
        resp = approve_transcation(rel_values)
        expect(resp[:code]).to eq(200)
      end
    end

    e.run_step 'Login as anchor and verify the transaction is in Draft' do
      expect(@tarspect_methods.login($conf['users'][@anchor_actor]['email'], $conf['users'][@anchor_actor]['password'])).to eq true
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @common_pages.click_transactions_tab(SHOW_ALL)
      @common_pages.apply_list_filter({ 'Instrument Number' => @transaction_details[:body][:invoice_number] })
      expect(@transactions_page.verify_transaction_status('Draft')).to eq true
    end

    e.run_step 'Logout as anchor' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as vendor and verify the transaction is in Draft' do
      expect(@tarspect_methods.login($conf['users'][@vendor_actor]['email'], $conf['users'][@vendor_actor]['password'])).to eq true
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @common_pages.click_transactions_tab(SHOW_ALL)
      @common_pages.apply_list_filter({ 'Instrument Number' => @transaction_details[:body][:invoice_number] })
      expect(@transactions_page.verify_transaction_status('Draft')).to eq true
    end

    e.run_step 'Logout as vendor' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as platforms and verify the transaction is in Draft' do
      expect(@tarspect_methods.login($conf['users']['product']['email'], $conf['users']['product']['password'])).to eq true
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @common_pages.click_transactions_tab(SHOW_ALL)
      @common_pages.apply_list_filter({ 'Instrument Number' => @transaction_details[:body][:invoice_number] })
      expect(@transactions_page.verify_transaction_status('Draft')).to eq true
    end

    e.run_step 'Logout as product' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as investor and verify the transaction is in Draft' do
      expect(@tarspect_methods.login($conf['users'][@investor_admin]['email'], $conf['users'][@investor_admin]['password'])).to eq true
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @common_pages.click_transactions_tab(SHOW_ALL)
      @common_pages.apply_list_filter({ 'Instrument Number' => @transaction_details[:body][:invoice_number] })
      expect(@transactions_page.verify_transaction_status('Draft')).to eq true
    end

    e.run_step 'Approve transaction as investor and verify transaction is moved to Released state' do
      @common_pages.click_transactions_tab(INVOICES_TO_APPROVE)
      @common_pages.apply_list_filter({ 'Instrument Number' => @transaction_details[:body][:invoice_number] })
      @disbursement_page.select_transactions(@transaction_id)
      @transactions_page.approve_transaction
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['VendorApproved']
      @common_pages.click_transactions_tab(SHOW_ALL)
      @common_pages.apply_list_filter({ 'Instrument Number' => @transaction_details[:body][:invoice_number] })
      expect(@transactions_page.verify_transaction_status('Released')).to eq true
    end

    e.run_step 'Verify the approved transaction is moved to Up for Disbursement state' do
      @common_pages.click_transactions_tab('Up For Disbursement')
      @disbursement_page.select_vendor_in_up_for_disbursement(@vendor_name)
      @disbursement_page.select_clubbed_group(@testdata['Invoice Details']['Invoice Date'])
      @disbursement_page.select_transactions([@transaction_id])
      @disbursement_page.click_disbursement
      @calculate_hash[:invoice_value] = @testdata['Invoice Details']['Invoice Value']
      @transaction_values = calculate_transaction_values(@calculate_hash)
      @disbursement_details = {
        'UTR Number' => "UTR#{DateTime.now.to_time.to_i}#{rand(1..999)}",
        'Date of Payment' => Date.today.strftime('%d-%b-%Y'),
        'Disbursement Amount' => @transaction_values[1],
        'Disbursement Account Number' => Faker::Number.number(digits: 10)
      }
      @disbursement_page.disburse(@payment_proof, @disbursement_details)
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['DisburseSuccess']
      @tarspect_methods.click_button('close')
    end
  end

  it 'Transaction : Investor Reject and Re-initiate the transaction' do |e|
    e.run_step 'Login as Vendor' do
      @testdata1 = JSON.parse(ERB.new(@erb_file).result(binding))
      @testdata1['Invoice Details']['GSTN of Anchor'] = $conf['users'][@anchor_actor]['gstn']
      @testdata1['Invoice Details']['GSTN of Channel Partner'] = $conf['users'][@vendor_actor]['gstn']
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users'][@vendor_actor]['email'], $conf['users'][@vendor_actor]['password'])).to eq true
    end

    e.run_step 'Create a complete transaction as Vendor(Draft -> Released)' do
      @transaction_details = create_transaction(@vendor_actor, @testdata1['Invoice Details'], @invoice_file, @program_id)
      @transaction_id = @transaction_details[:body][:id]
      expect(@transaction_details).not_to include('Error while creating transaction')
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @common_pages.click_transactions_tab(UNASSIGNED_INVESTOR)
      @tarspect_methods.click_button('Reassign')
      @common_pages.reassign_investor('State Bank Of India')
    end

    e.run_step 'Logout as vendor' do
      expect(@common_pages.logout).to eq true
    end

    ['product', @anchor_actor, 'product'].each do |actor|
      e.run_step "Approve transaction as #{actor}" do
        rel_values = {
          actor: actor,
          program_id: @program_id,
          transaction_id: @transaction_id,
          todo: 'approved',
          can_reinitiate: false,
          comment: 'Approved',
          program_group: 'invoice'
        }
        resp = approve_transcation(rel_values)
        expect(resp[:code]).to eq(200)
      end
    end

    e.run_step 'Login as investor' do
      expect(@tarspect_methods.login($conf['users'][@investor_admin]['email'], $conf['users'][@investor_admin]['password'])).to eq true
    end

    e.run_step 'Investor reject and re-initiate the transaction and verify the transaction is moved to Rejected state' do
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @common_pages.click_transactions_tab(INVOICES_TO_APPROVE)
      @common_pages.apply_list_filter({ 'Instrument Number' => @transaction_details[:body][:invoice_number] })
      @disbursement_page.select_transactions(@transaction_id)
      @transactions_page.reject_transaction('Re-Initiate Transaction', @testdata['Reject Reason'])
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['VendorApproved']
    end

    e.run_step 'Logout as investor' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as anchor and verify the status of Rejected transaction' do
      expect(@tarspect_methods.login($conf['users'][@anchor_actor]['email'], $conf['users'][@anchor_actor]['password'])).to eq true
      @common_pages.click_transactions_tab(REJECTED)
      @common_pages.apply_list_filter({ 'Instrument Number' => @transaction_details[:body][:invoice_number] })
      expect(@transactions_page.verify_transaction_status('Declined')).to eq true
    end

    e.run_step 'Logout as anchor' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as vendor and re-initiate the transaction' do
      expect(@tarspect_methods.login($conf['users'][@vendor_actor]['email'], $conf['users'][@vendor_actor]['password'])).to eq true
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @common_pages.click_transactions_tab(REJECTED)
      @common_pages.apply_list_filter({ 'Instrument Number' => @transaction_details[:body][:invoice_number] })
      expect(@transactions_page.verify_transaction_status('Declined')).to eq true
      @common_pages.navigate_to_transaction(@transaction_id)
      @transactions_page.re_initiate_transaction(@re_initiate_file, @testdata['Re-Initiate Details'])
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['ReInitiateSucess']
    end

    e.run_step 'Logout as vendor' do
      expect(@common_pages.logout).to eq true
    end

    ['product', @anchor_actor, 'product'].each do |actor|
      e.run_step "Approve transaction as #{actor}" do
        rel_values = {
          actor: actor,
          program_id: @program_id,
          transaction_id: @transaction_id,
          todo: 'approved',
          can_reinitiate: false,
          comment: 'Approved',
          program_group: 'invoice'
        }
        resp = approve_transcation(rel_values)
        expect(resp[:code]).to eq(200)
      end
    end

    e.run_step 'Login as investor and reject the re-initiated transaction' do
      expect(@tarspect_methods.login($conf['users'][@investor_admin]['email'], $conf['users'][@investor_admin]['password'])).to eq true
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @common_pages.click_transactions_tab(INVOICES_TO_APPROVE)
      @common_pages.apply_list_filter({ 'Instrument Number' => @transaction_details[:body][:invoice_number] })
      @disbursement_page.select_transactions(@transaction_id)
      @transactions_page.reject_transaction('Reject', @testdata['Reject Reason'])
    end

    e.run_step 'Verify the status of the Rejected transaction' do
      @common_pages.click_transactions_tab(REJECTED)
      @common_pages.apply_list_filter({ 'Instrument Number' => @transaction_details[:body][:invoice_number] })
      expect(@transactions_page.verify_transaction_status('Declined')).to eq true
    end
  end
end
