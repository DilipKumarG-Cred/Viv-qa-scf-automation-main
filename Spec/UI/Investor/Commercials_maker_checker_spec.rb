require './spec_helper'
describe 'Anchor Commercials: Maker Checker Verification', :scf, :commercials, :maker_checker do
  before(:all) do
    @investor_admin = 'investor_profile_investor'
    @investor_maker = 'investor_profile_investor_maker'
    @investor_checker1 = 'investor_profile_investor_checker1'
    @investor_checker2 = 'investor_profile_investor_checker2'
    @investor_id = $conf['users']['investor_profile_investor']['id']
    @anchor_id = $conf['users']['anchor_summary_anchor']['id']
    @anchor_name = $conf['users']['anchor_summary_anchor']['name']
    @borrowing_document = "#{Dir.pwd}/test-data/attachments/borrowing_document.pdf"
    @commercials_data_erb = File.read("#{Dir.pwd}/test-data/erb/commercials_data.erb")
    @set_commercial_values = JSON.parse(ERB.new(@commercials_data_erb).result(binding))['Anchor Commercials'].transform_keys(&:to_sym)
  end

  before(:each) do
    @driver = Tarspect::Browser.new($conf['browser']).invoke
    @commercials_page = Pages::Commercials.new(@driver)
    @tarspect_methods = Common::Methods.new(@driver)
    @transactions_page = Pages::Trasactions.new(@driver)
    @common_pages = Pages::CommonMethods.new(@driver)
    @investor_page = Pages::Investor.new(@driver)
    @values = {
      'Program' => 'Invoice Financing',
      'Type' => 'Dealer',
      'Anchor ID' => @anchor_id,
      'Investor ID' => @investor_id,
      'Vendor Name' => 'South Deals AS',
      'actor' => @investor_admin
    }
    delete_vendor_commercials(@values)
    values = {
      investor_actor: @investor_admin,
      investor_id: @investor_id,
      anchor_id: @anchor_id,
      program_id: $conf['programs']['Invoice Financing - Dealer']
    }
    force_delete_anchor_commercials(values)
    @eyes = {
      '4eye' => '4-eye validation (1 Maker and 1 Checker)',
      '6eye' => '6-eye validation (1 Maker and 2 Checkers)'
    }
    @program = 'Dealer Financing'
  end

  after(:each) do |e|
    snap_screenshot(e)
    quit_browser
  end

  it 'Verification of Investor Program Terms', :program_terms do |e|
    e.run_step 'Login as Investor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users'][@investor_admin]['email'], $conf['users'][@investor_admin]['password'])).to be true
    end

    e.run_step 'Verify Interest Calculation and type is set and saved' do
      @common_pages.click_menu('My Preferences')
      interest_types = ['Simple Interest', 'Fixed Interest']
      @investor_page.choose_prefs(interest_types)
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq('Program Terms updated successfully!')
    end

    e.run_step 'Verify commercials are predefined accordingly when Type = Fixed & Calc - Simple Interest' do
      @investor_page.go_to_program(anchor: @anchor_name, program: @program)
      exp_hash = {
        min_pricing_value: '0%',
        min_pricing_text_box: '5',
        interest_calculation: 'true'
      }
      values = {
        int_calc: 'Simple',
        int_type: 'Fixed'
      }
      hash, errors = @investor_page.get_anchor_commercial_values(values)
      expect(errors.empty?).to eq(true), errors
      expect(exp_hash).to eq(hash)
    end

    e.run_step 'Verify Interest Calculation and type is set and saved' do
      @common_pages.click_menu('My Preferences')
      @daily_rest = ['Daily', 'Monthly', 'Quarterly'].sample
      interest_types = ['Compound Interest', @daily_rest, 'Floating Interest']
      @investor_page.choose_prefs(interest_types)
      hash = {
        'MCLR' => 8,
        'RLLR' => 10,
        'MCLR_Effective' => { 'Effective from' => (Date.today - 1).strftime('%d %b, %Y') },
        'RLLR_Effective' => { 'Effective from' => (Date.today - 1).strftime('%d %b, %Y') }
      }
      @investor_page.add_base_rates(hash)
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq('Program Terms updated successfully!')
    end

    e.run_step 'Verify terms can be edited and saved' do
      edit_hash = {
        'MCLR' => 9,
        'RLLR' => 11,
        'MCLR_Effective' => { 'Effective from' => (Date.today - 1).strftime('%d %b, %Y') },
        'RLLR_Effective' => { 'Effective from' => (Date.today - 1).strftime('%d %b, %Y') }
      }
      @investor_page.add_base_rates(edit_hash, edit: true)
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq('Program Terms updated successfully!')
    end

    e.run_step 'Verify commercials are predefined accordingly when Type = Floating & Calc - Compound Interest' do
      @investor_page.go_to_program(anchor: @anchor_name, program: @program)
      resp = get_investor_profile(@investor_admin)
      expect(resp[:body][:investor_details][:interest_calculation_strategy]).to eq('compound_interest')
      expect(resp[:body][:investor_details][:current_investor_profile][:mclr]).to eq('9.0')
      expect(resp[:body][:investor_details][:current_investor_profile][:rllr]).to eq('11.0')
      exp_hash = {
        min_pricing_value: '9%',
        min_pricing_text_box: '9.0',
        interest_calculation: 'true',
        interest_calculation_rest: 'true'
      }
      values = {
        int_calc: 'Compound',
        int_calc_rest: @daily_rest,
        int_type: 'Floating'
      }
      hash, errors = @investor_page.get_anchor_commercial_values(values)
      expect(errors.empty?).to eq(true), errors
      expect(exp_hash).to eq(hash)
    end

    e.run_step 'Verify Anchor Commercials can be set' do
      @set_commercial_values[:actor] = @investor_admin
      @set_commercial_values[:anchor_program_id] = 332
      @set_commercial_values[:valid_till] = get_todays_date(300, '%Y-%m-%d')
      resp = set_anchor_commercials(@set_commercial_values)
      expect(resp[:code]).to eq(200), resp.to_s
      expect(resp[:body][:result][:status]).to eq('pending_document')
      values = {
        actor: @investor_admin,
        borr_doc: @borrowing_document,
        id: resp[:body][:result][:id]
      }
      resp = upload_anchor_mou(values)
      expect(resp[:code]).to eq(200), resp.to_s
      expect(resp[:body][:result][:status]).to eq('pending_document')
      resp = set_anchor_commercials(@set_commercial_values, action: :submit)
      expect(resp[:code]).to eq(200)
      expect(resp[:body][:result][:status]).to eq('pending_effective_date')
    end

    e.run_step 'Verify Vendor Commercials can be set' do
      vendor_commercials = JSON.parse(ERB.new(@commercials_data_erb).result(binding))['Vendor Commercials']
      vendor_commercials.merge!(
        'Tenor' => '60 days',
        'Spread Value' => '10.0',
        'Agreement Validity' => [get_todays_date(-5, '%d-%b-%Y'), get_todays_date(300, '%d-%b-%Y')],
        'Invocie Upload (Days) ' => '45'
      )
      ['Valid Till', 'Vendor ID', 'Anchor Program ID', 'Anchor ID', 'Vendor', 'Investor ID', 'Borrowing Document', 'Payment Document', 'Program ID', 'UTR Number'].each { |field| vendor_commercials.delete(field) }
      refresh_page
      @transactions_page.select_vendor(@values['Vendor Name'])
      @commercials_page.add_vendor_commercials(vendor_commercials, floating: true)
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['VendorProgramAdded']
    end
  end

  it 'Verification of Maker Checker Terms for Anchor Commercials - 4 EYE validation', :eye_validation_4 do |e|
    e.run_step 'Login as Investor ADMIN' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users'][@investor_admin]['email'], $conf['users'][@investor_admin]['password'])).to be true
    end

    e.run_step 'Verify Maker Checker terms are set and saved' do
      @common_pages.click_menu('My Preferences')
      interest_types = ['Simple Interest', 'Fixed Interest']
      @investor_page.choose_prefs(interest_types)
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq('Program Terms updated successfully!')
      @common_pages.click_menu('My Preferences')
      prefs = ['Anchor Program Terms', 'Vendor Commercials', @eyes['4eye']]
      @investor_page.choose_prefs(prefs, menu: 'Approval mechanism', enable: true)
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq('Approval mechanism updated successfully!')
    end

    e.run_step 'Investor ADMIN Logs out' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Verify Anchor Commercials can be set by MAKER' do
      @set_commercial_values[:actor] = @investor_maker
      @set_commercial_values[:anchor_program_id] = 332 # Invoice Financing - Dealer Program
      @set_commercial_values[:valid_till] = get_todays_date(300, '%Y-%m-%d')
      resp = set_anchor_commercials(@set_commercial_values)
      expect(resp[:code]).to eq(200)
      expect(wait_till_checker1_approval(@investor_maker, @investor_id, 332)).to eq('pending_final_checker_approval')
      @commercial_id = resp[:body][:result][:id]
    end

    e.run_step 'Login as Investor - Checker' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users'][@investor_checker2]['email'], $conf['users'][@investor_checker2]['password'])).to be true
    end

    e.run_step 'Verify Checker can approve Anchor Commercials' do
      @investor_page.go_to_program(anchor: @anchor_name, program: @program)
      @tarspect_methods.click_button('Submit')
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq('Commercial verified.')
      all_status = @investor_page.get_program_status
      expect(all_status.count).to eq(2)
      expect(all_status[0]).to include('Approved')
      expect(all_status[0]).to include('Approval from checker')
      expect(all_status[1]).to include('Pending')
      expect(all_status[1]).to include('Approval from checker')
    end

    e.run_step 'Investor Checker Logs out' do
      expect(@common_pages.logout).to eq true
    end
  end

  it 'Verification of Maker Checker Terms for Anchor Commercials - 6 EYE validation' do |e|
    e.run_step 'Verify Maker Checker terms are set and saved by Investor ADMIN' do
      values = {
        preferences_type: 'approval_mechanism',
        is_maker_checker_enabled: true,
        anchor_commercial: true,
        checker_type: '6eye',
        investor_actor: @investor_admin,
        investor_id: @investor_id
      }
      resp = update_investor_profile(values)
      expect(resp[:code]).to eq(200)
      expect(resp[:body][:investor_details][:anchor_commercial_approval_levels]).to eq('anchor_two_checkers')
    end

    e.run_step 'Verify Anchor Commercials can be set by MAKER' do
      @set_commercial_values[:actor] = @investor_maker
      @set_commercial_values[:anchor_program_id] = 332 # Invoice Financing - Dealer Program
      @set_commercial_values[:valid_till] = get_todays_date(300, '%Y-%m-%d')
      resp = set_anchor_commercials(@set_commercial_values)
      expect(resp[:code]).to eq(200)
      expect(resp[:body][:result][:status]).to eq('pending_checker_1_approval')
      @commercial_id = resp[:body][:result][:id]
    end

    e.run_step 'Login as Investor - Maker' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users'][@investor_maker]['email'], $conf['users'][@investor_maker]['password'])).to be true
    end

    e.run_step 'Verify commercials can be edited after setting once' do
      @investor_page.go_to_program(anchor: @anchor_name, program: @program)
      @tarspect_methods.BUTTON('Edit').click
      @tarspect_methods.wait_for_loader_to_disappear
      vendor_commercials = {
        'Agreement Validity' => [get_todays_date(nil, '%d-%b-%Y'), get_todays_date(300, '%d-%b-%Y')],
        'Effective Date' => get_todays_date(nil, '%d-%b-%Y')
      }
      @commercials_page.skip_counterparty.scroll_to_element
      @tarspect_methods.fill_form({ 'Effective Date' => vendor_commercials['Effective Date'] }, 2, 2, true)
      @tarspect_methods.fill_form({ 'Agreement Validity ' => vendor_commercials['Agreement Validity'][0] }, 1, 1)
      @tarspect_methods.fill_form({ 'Agreement Validity ' => vendor_commercials['Agreement Validity'][1] }, 2, 1)
      @tarspect_methods.click_button('Save as Draft')
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq('No enough permission to update or verify anchor commercial')
      @tarspect_methods.click_button('Cancel')
      all_status = @investor_page.get_program_status
      expect(all_status.count).to eq(1)
      expect(all_status[0]).to include('Pending')
      expect(all_status[0]).to include('Approval from checker - 01')
    end

    e.run_step 'Investor Maker Logs out' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Verify Investor - Checker 2 cannot see commercials before Checker 1' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users'][@investor_checker2]['email'], $conf['users'][@investor_checker2]['password'])).to be true
      @investor_page.go_to_program(anchor: @anchor_name, program: @program)
      expect(@tarspect_methods.BUTTON('Edit').get_attribute('disabled')).to eq('true'), "Checker can edit commercials before Checker 1's action"
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Investor - Checker 1' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users'][@investor_checker1]['email'], $conf['users'][@investor_checker1]['password'])).to be true
    end

    e.run_step 'Verify Checker 1 can decline Anchor Commercials' do
      @investor_page.go_to_program(anchor: @anchor_name, program: @program)
      decline_message = 'Testing'
      values = { commercial: 'anchor', action: 'Decline', decline_message: decline_message }
      notifications = @investor_page.review_commercial(values)
      expect(notifications[0]).to eq('Commercial verified.')
      expect(notifications[1]).to eq('Reason for declining')
      expect(notifications[2]).to eq('Snapdeal')
      expect(notifications[3]).to eq(decline_message)
      all_status = @investor_page.get_program_status
      expect(all_status.count).to eq(2)
      expect(all_status[0]).to include('Declined')
      expect(all_status[0]).to include('Sbi Checker 1')
      expect(all_status[1]).to include('Approval from checker - 01')
      expect(all_status[1]).to include('Pending')
    end

    e.run_step 'Verify Anchor Commercials can be set with changes by MAKER' do
      @set_commercial_values[:actor] = @investor_maker
      @set_commercial_values[:anchor_program_id] = 332 # Invoice Financing - Dealer Program
      @set_commercial_values[:discount_percentage] = 10 # Changing values
      resp = set_anchor_commercials(@set_commercial_values, action: :edit)
      expect(resp[:code]).to eq(200)
      expect(resp[:body][:result][:status]).to eq('pending_checker_1_approval')
      @commercial_id = resp[:body][:result][:id]
    end

    e.run_step 'Verify Checker 1 can approve Anchor Commercials' do
      @investor_page.go_to_program(anchor: @anchor_name, program: @program)
      values = { commercial: 'anchor', action: 'Approve' }
      notifications = @investor_page.review_commercial(values)
      expect(notifications[0]).to eq('Commercial verified.')
      all_status = @investor_page.get_program_status
      expect(all_status.count).to eq(5)
      expect(all_status[4]).to include('Approval from checker - 01')
      expect(all_status[4]).to include('Pending')
      expect(all_status[3]).to include('Approval from checker - 01')
      expect(all_status[3]).to include('Declined')
      expect(all_status[2]).to include('Approval from checker - 01')
      expect(all_status[2]).to include('Pending')
      expect(all_status[1]).to include('Approval from checker - 01')
      expect(all_status[1]).to include('Approved')
      expect(all_status[0]).to include('Approval from checker - 02')
      expect(all_status[0]).to include('Pending')
    end

    e.run_step 'Investor Checker 1 Logs out' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Investor - Checker 2' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users'][@investor_checker2]['email'], $conf['users'][@investor_checker2]['password'])).to be true
    end

    e.run_step 'Verify Checker 2 can approve Anchor Commercials' do
      @investor_page.go_to_program(anchor: @anchor_name, program: @program)
      @tarspect_methods.click_button('Submit')
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq('Commercial verified.')
      all_status = @investor_page.get_program_status
      expect(all_status.count).to eq(6)
      expect(all_status[5]).to include('Approval from checker - 01')
      expect(all_status[5]).to include('Pending')
      expect(all_status[4]).to include('Approval from checker - 01')
      expect(all_status[4]).to include('Declined')
      expect(all_status[3]).to include('Approval from checker - 01')
      expect(all_status[3]).to include('Pending')
      expect(all_status[2]).to include('Approval from checker - 01')
      expect(all_status[2]).to include('Approved')
      expect(all_status[1]).to include('Approval from checker - 02')
      expect(all_status[1]).to include('Pending')
      expect(all_status[0]).to include('Approval from checker - 02')
      expect(all_status[0]).to include('Approved')
    end

    e.run_step 'Investor Checker 2 Logs out' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Verify Anchor can see commercials' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['anchor_summary_anchor']['email'], $conf['users']['anchor_summary_anchor']['password'])).to be true
      @common_pages.click_menu(MENU_PROGRAMS)
      @common_pages.select_program('Invoice Financing', 'Vendor')
      @common_pages.click_interested_investors
      @common_pages.navigate_to_investor($conf['users'][@investor_admin]['name'])
      expect(@commercials_page.check_anchor_commercial_cannot_be_edited).to eq(false), 'Draft Anchor Commercials are not editable'
    end

    e.run_step 'Upload Borrowing document as MAKER' do
      values = {
        actor: @investor_maker,
        borr_doc: @borrowing_document,
        id: @commercial_id
      }
      resp = upload_anchor_mou(values)
      expect(resp[:code]).to eq(200)
    end
  end

  it 'Vendor Commercials : Maker Checker 4 EYE Verification', :four_eye_validation do |e|
    e.run_step 'Verify anchor commercials are set' do
      @set_commercial_values[:actor] = @investor_admin
      @set_commercial_values[:anchor_program_id] = 332 # Invoice Financing - Dealer Program
      @set_commercial_values[:valid_till] = get_todays_date(300, '%Y-%m-%d')
      @set_commercial_values[:instrument_ids] = 1
      resp = set_anchor_commercials(@set_commercial_values)
      expect(resp[:code]).to eq(200)
      expect(resp[:body][:result][:status]).to eq('pending_document')
      @commercial_id = resp[:body][:result][:id]
      values = {
        actor: @investor_admin,
        borr_doc: @borrowing_document,
        id: @commercial_id
      }
      resp = upload_anchor_mou(values)
      expect(resp[:code]).to eq(200)
      expect(resp[:body][:result][:status]).to eq('pending_document')
      resp = set_anchor_commercials(@set_commercial_values, action: :submit)
      expect(resp[:code]).to eq(200)
      expect(resp[:body][:result][:status]).to eq('pending_effective_date')
    end

    e.run_step 'Verify Maker Checker terms are set and saved by Investor ADMIN' do
      values = {
        preferences_type: 'approval_mechanism',
        is_maker_checker_enabled: true,
        vendor_commercial: true,
        anchor_commercial: false,
        checker_type: '4eye',
        investor_actor: @investor_admin,
        investor_id: @investor_id
      }
      resp = update_investor_profile(values)
      expect(resp[:code]).to eq(200)
      expect(resp[:body][:investor_details][:vendor_commercial_approval_levels]).to eq('vendor_one_checker')
      values = {
        preferences_type: 'program_terms',
        interest_calculation_rest: 'daily_rest',
        interest_calculation_strategy: 'simple_interest',
        interest_type: 'fixed_interest',
        investor_actor: @investor_admin,
        investor_id: @investor_id
      }
      resp = update_investor_profile(values)
      expect(resp[:code]).to eq(200)
    end

    e.run_step 'Add Vendor Commercials as Investor - Maker' do
      @vendor_id = 5278 # South Deals AS
      @commercials_data = JSON.parse(ERB.new(@commercials_data_erb).result(binding))['Vendor Commercials']
      @commercials_data.merge!(
        'Anchor Program ID' => @set_commercial_values[:anchor_program_id],
        'Anchor ID' => @anchor_id,
        'Investor' => @investor_maker,
        # 'Interest Type' => 'Floating',
        # 'ROI Calculation Basis' => 'mclr',
        # 'Spread Percentage' => 10,
        'Valid Till' => (Date.today + 300).strftime('%Y-%m-%d')
      )
      resp = set_commercials(@commercials_data)
      expect(resp[:code]).to eq(201), resp.to_s
      expect(resp[:body][:program_limits][:status]).to eq('Pending Final Checker Approval')
      @program_limit_id = resp[:body][:program_limits][:id]
    end

    e.run_step 'Login as Maker and verify program status' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users'][@investor_maker]['email'], $conf['users'][@investor_maker]['password'])).to be true
      @investor_page.go_to_program(anchor: @anchor_name, program: @program)
      @investor_page.go_to_commercials('South Deals AS')
      all_status = @investor_page.get_program_status
      expect(all_status.count).to eq(1)
      expect(all_status[0]).to include('Pending')
      expect(all_status[0]).to include('Approval from checker')
      expect(@common_pages.logout).to eq(true)
    end

    e.run_step 'Login as Investor - Checker 1' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users'][@investor_checker1]['email'], $conf['users'][@investor_checker1]['password'])).to be true
    end

    e.run_step 'Verify Checker 1 can approve Anchor Commercials' do
      @investor_page.go_to_program(anchor: @anchor_name, program: @program)
      values = { commercial: 'vendor', action: 'Submit', vendor: 'South Deals AS' }
      notifications = @investor_page.review_commercial(values)
      expect(notifications[0]).to eq($notifications['Investor']['Commercial_Approval'])
      all_status = @investor_page.get_program_status
      expect(all_status.count).to eq(2)
      expect(all_status[0]).to include('Approved')
      expect(all_status[0]).to include('Approval from checker')
      expect(all_status[0]).to include('Sbi Checker 1')
      expect(all_status[1]).to include('Approval from checker')
      expect(all_status[1]).to include('Pending')
    end

    e.run_step 'Investor Checker 1 Logs out' do
      expect(@common_pages.logout).to eq true
    end
  end

  it 'Vendor Commercials : Maker Checker 6 EYE Verification', :six_eye_maker_checker do |e|
    e.run_step 'Verify anchor commercials are set' do
      @set_commercial_values[:actor] = @investor_admin
      @set_commercial_values[:anchor_program_id] = 332 # Invoice Financing - Dealer Program
      @set_commercial_values[:valid_till] = get_todays_date(300, '%Y-%m-%d')
      resp = set_anchor_commercials(@set_commercial_values)
      expect(resp[:code]).to eq(200)
      expect(resp[:body][:result][:status]).to eq('pending_document')
      @commercial_id = resp[:body][:result][:id]
      values = {
        actor: @investor_admin,
        borr_doc: @borrowing_document,
        id: @commercial_id
      }
      resp = upload_anchor_mou(values)
      expect(resp[:code]).to eq(200)
      expect(resp[:body][:result][:status]).to eq('pending_document')
      resp = set_anchor_commercials(@set_commercial_values, action: :submit)
      expect(resp[:code]).to eq(200)
      expect(resp[:body][:result][:status]).to eq('pending_effective_date')
    end

    e.run_step 'Verify Maker Checker terms are set and saved by Investor ADMIN' do
      values = {
        preferences_type: 'approval_mechanism',
        is_maker_checker_enabled: true,
        vendor_commercial: true,
        anchor_commercial: false,
        checker_type: '6eye',
        investor_actor: @investor_admin,
        investor_id: @investor_id
      }
      resp = update_investor_profile(values)
      expect(resp[:code]).to eq(200)
      expect(resp[:body][:investor_details][:vendor_commercial_approval_levels]).to eq('vendor_two_checkers')
      values = {
        preferences_type: 'program_terms',
        interest_calculation_rest: 'daily_rest',
        interest_calculation_strategy: 'simple_interest',
        interest_type: 'fixed_interest',
        investor_actor: @investor_admin,
        investor_id: @investor_id
      }
      resp = update_investor_profile(values)
      expect(resp[:code]).to eq(200)
    end

    e.run_step 'Add Vendor Commercials as Investor - Maker' do
      @vendor_id = 5278 # South Deals AS
      @commercials_data = JSON.parse(ERB.new(@commercials_data_erb).result(binding))['Vendor Commercials']
      @commercials_data.merge!(
        'Anchor Program ID' => @set_commercial_values[:anchor_program_id],
        'Anchor ID' => @anchor_id,
        'Investor' => @investor_maker,
        'Valid Till' => (Date.today + 300).strftime('%Y-%m-%d')
      )
      resp = set_commercials(@commercials_data)
      expect(resp[:code]).to eq(201), resp.to_s
      expect(resp[:body][:program_limits][:status]).to eq('Pending Checker 1 Approval')
      @commercial_id = resp[:body][:program_limits][:id]
    end

    e.run_step 'Login as Maker and verify program status' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users'][@investor_maker]['email'], $conf['users'][@investor_maker]['password'])).to be true
      @investor_page.go_to_program(anchor: @anchor_name, program: @program)
      @investor_page.go_to_commercials('South Deals AS')
      all_status = @investor_page.get_program_status
      expect(all_status.count).to eq(1)
      expect(all_status[0]).to include('Pending')
      expect(all_status[0]).to include('Approval from checker - 01')
      expect(@common_pages.logout).to eq(true)
    end

    e.run_step 'Login as Investor - Checker 1' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users'][@investor_checker1]['email'], $conf['users'][@investor_checker1]['password'])).to be true
    end

    e.run_step 'Verify Checker 1 can decline Vendor Commercials' do
      @investor_page.go_to_program(anchor: @anchor_name, program: @program)
      values = { commercial: 'vendor', action: 'Decline', decline_message: 'Testing', vendor: 'South Deals AS' }
      @commercials_page.commercials_tab.click
      notifications = @investor_page.review_commercial(values)
      expect(notifications[0]).to eq('Reason for declining')
      expect(notifications[1]).to eq('Testing')
      all_status = @investor_page.get_program_status
      expect(all_status.count).to eq(2)
      expect(all_status[0]).to include('Declined')
      expect(all_status[0]).to include('Sbi Checker 1')
      expect(all_status[1]).to include('Approval from checker - 01')
      expect(all_status[1]).to include('Pending')
    end

    e.run_step 'Verify Vendor Commercials can be set with changes by MAKER' do
      @commercials_data['Yield'] = '15'
      @commercials_data['Program Limit ID'] = @commercial_id
      resp = set_commercials(@commercials_data, action: :update)
      expect(resp[:code]).to eq(200), resp.to_s
      expect(resp[:body][:program_limits][:status]).to eq('Pending Checker 1 Approval')
    end

    e.run_step 'Verify Checker 1 can approve Vendor Commercials' do
      @investor_page.go_to_program(anchor: @anchor_name, program: @program)
      values = { commercial: 'vendor', action: 'Approve', vendor: 'South Deals AS' }
      notifications = @investor_page.review_commercial(values)
      expect(notifications[0]).to eq($notifications['Investor']['Commercial_Approval'])
      expect(notifications[1]).to eq('The data is now available for Checker-02 to validate')
      all_status = @investor_page.get_program_status
      expect(all_status.count).to eq(5)
      expect(all_status[0]).to include('Approval from checker - 02')
      expect(all_status[0]).to include('Pending')
      expect(all_status[1]).to include('Approved')
      expect(all_status[1]).to include('Sbi Checker 1')
      expect(all_status[2]).to include('Approval from checker - 01')
      expect(all_status[2]).to include('Pending')
      expect(all_status[3]).to include('Declined')
      expect(all_status[3]).to include('Sbi Checker 1')
      expect(all_status[4]).to include('Approval from checker - 01')
      expect(all_status[4]).to include('Pending')
    end

    e.run_step 'Investor Checker 1 Logs out' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Investor - Checker 2' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users'][@investor_checker2]['email'], $conf['users'][@investor_checker2]['password'])).to be true
    end

    e.run_step 'Verify Checker 2 can approve Anchor Commercials' do
      @investor_page.go_to_program(anchor: @anchor_name, program: @program)
      values = { commercial: 'vendor', action: 'Submit', vendor: 'South Deals AS' }
      notifications = @investor_page.review_commercial(values)
      expect(notifications[0]).to eq($notifications['Investor']['Commercial_Approval'])
      refresh_page # temporary fix
      @tarspect_methods.wait_for_circular_to_disappear
      @tarspect_methods.wait_for_loader_to_disappear
      all_status = @investor_page.get_program_status
      expect(all_status.count).to eq(6)
      expect(all_status[0]).to include('Approved')
      expect(all_status[0]).to include('sbi checker 2')
      expect(all_status[1]).to include('Approval from checker - 02')
      expect(all_status[1]).to include('Pending')
      expect(all_status[2]).to include('Approved')
      expect(all_status[2]).to include('Sbi Checker 1')
      expect(all_status[3]).to include('Approval from checker - 01')
      expect(all_status[3]).to include('Pending')
      expect(all_status[4]).to include('Declined')
      expect(all_status[4]).to include('Sbi Checker 1')
      expect(all_status[5]).to include('Approval from checker - 01')
      expect(all_status[5]).to include('Pending')
    end

    e.run_step 'Upload Borrowing document as Investor ADMIN' do
      values = {
        'Investor' => @investor_admin,
        'Borrowing Document' => @borrowing_document,
        'Program Limit ID' => @commercial_id
      }
      resp = upload_vendor_bd(values)
      expect(resp[:code]).to eq(200)
    end
  end
end
