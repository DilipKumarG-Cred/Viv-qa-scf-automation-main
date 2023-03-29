require './spec_helper'
describe 'Invoice Assignment', :scf, :commercials, :invoice_assign, :no_run do
  before(:all) do
    @party_gstn = $conf['users']['grn_anchor']['gstn']
    @counterparty_gstn = $conf['users']['assignment_vendor']['gstn']
    @anchor_name = $conf['grn_anchor_name']
    @vendor_name = $conf['users']['assignment_vendor']['name']
    @vendor_actor = 'assignment_vendor'
    @vendor_id = '5083' # CH28 Stores
    @investor_actor = 'investor'
    @second_investor_actor = 'user_feedback_investor'
    @first_investor_name = $conf['investor_name']
    @second_investor_name = $conf['user_feedback_investor']
    @borrowing_document = "#{Dir.pwd}/test-data/attachments/borrowing_document.pdf"
    @payment_proof = "#{Dir.pwd}/test-data/attachments/payment_proof.pdf"
    @erb_file = File.read("#{Dir.pwd}/test-data/erb/commercials_data.erb")
    @invoice_erb = File.read("#{Dir.pwd}/test-data/erb/testbed_data.erb")
    clear_all_overdues({ anchor: $conf['grn_anchor_name'], vendor: $conf['users']['assignment_vendor']['name'] })
  end

  before(:each) do
    @driver = Tarspect::Browser.new($conf['browser']).invoke
    @tarspect_methods = Common::Methods.new(@driver)
    @common_pages = Pages::CommonMethods.new(@driver)
    @transactions_page = Pages::Trasactions.new(@driver)
    @disbursement_page = Pages::Disbursement.new(@driver)
    @commercials_page = Pages::Commercials.new(@driver)
    @invoice_data = JSON.parse(ERB.new(@invoice_erb).result(binding))['PO Details']
    @testdata = JSON.parse(ERB.new(@erb_file).result(binding))['Vendor Commercials']
    @testdata['Program'] = 'PO Financing'
    @testdata['Type'] = 'Vendor'
    @testdata['Vendor Name'] = @vendor_name
    @testdata['actor'] = @second_investor_actor
  end

  after(:each) do |e| # Captures screenshot of the current page when failure happens
    snap_screenshot(e)
  end

  after(:all) do
    quit_browser # Tear down
  end

  it 'Invoice Assignment : Verification of Assignment based on ROI', :sanity do |e|
    e.run_step 'Capture Vendor Commercial for Kotak' do
      hash = {
        'Anchor ID' => 5,
        'Investor ID' => 7,
        'Program' => 'PO Financing',
        'Type' => 'Vendor',
        'Vendor Name' => @vendor_name,
        'actor' => @investor_actor
      }
      resp = get_vendor_commercial(hash)
      expect(resp[:code]).to eq 200
      @commercial_kotak = {
        'Yield' => resp[:body][:program_limits][:yield],
        'Sanction Limit' => resp[:body][:program_limits][:sanction_limit],
        'Tenor' => resp[:body][:program_limits][:tenor],
        'Invoice Days' => resp[:body][:program_limits][:days_to_raise_invoice]
      }
    end

    e.run_step 'Vendor Commercial setup and approval for DCB' do
      @testdata.merge!(
        'Payment Date' => get_todays_date,
        'Valid Till' => get_todays_date(300),
        'Yield' => @commercial_kotak['Yield'] - 2,
        'Sanction Limit' => @commercial_kotak['Sanction Limit'],
        'Tenor' => @commercial_kotak['Tenor'],
        'Invoice Days' => @commercial_kotak['Invoice Days'],
        'Effective Date' => get_todays_date
      )
      resp = set_and_approve_commercials(@testdata)
      expect(resp[0]).to eq(201), "Error in Commercial setup and approval #{resp}"
    end

    e.run_step 'Initiate invoice Transaction' do
      @invoice_data['PO Date'] = get_todays_date(-30)
      values = {
        po_details: @invoice_data,
        program_id: 4,
        actor: 'assignment_vendor'
      }
      resp = create_po_transaction(values)
      expect(resp[:code]).to eq(201), resp.to_s
      expect(resp[:body][:status]).to eq('pending_investor_assignment')
      @transaction_id = resp[:body][:id]
    end

    e.run_step 'Login as Vendor : CH28 Stores' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['assignment_vendor']['email'], $conf['users']['assignment_vendor']['password'])).to be true
    end

    e.run_step 'Verify Invoice is assigned to Investor based on ROI' do
      @common_pages.click_menu(MENU_PO_FINANCING)
      @common_pages.click_transactions_tab(UNASSIGNED_INVESTOR)
      expect(@common_pages.transaction_listed?(@transaction_id)).to eq(true), "Transaction #{@transaction_id} is not listed"
      expect(@common_pages.TRANSACTION(@transaction_id).text).to include(@second_investor_name), 'Investor assgined as not expected'
      @common_pages.navigate_to_transaction(@transaction_id)
      expect(@common_pages.get_investor_in_details).to eq(@second_investor_name)
      @common_pages.click_back_button
    end

    e.run_step 'Verify Investor Commercials are displayed correctly' do
      @transactions_page.deselect_checkbox_in_unassigned_investor
      @disbursement_page.select_transactions(@transaction_id)
      @tarspect_methods.click_button('Reassign')
      expect(@common_pages.verify_assignment_dialog(@second_investor_name, 'Available Limit')).to eq("₹#{format('%g', @testdata['Sanction Limit'] / 100000)}LACAvailable Limit")
      expect(@common_pages.verify_assignment_dialog(@second_investor_name, 'ROI')).to eq("#{format('%g', @testdata['Yield'])} %ROI")
      expect(@common_pages.verify_assignment_dialog(@second_investor_name, 'Tenor')).to eq("#{@testdata['Tenor']} daysTenor")
      expect(@common_pages.verify_assignment_dialog(@first_investor_name, 'Available Limit')).to eq("₹#{format('%g', @commercial_kotak['Sanction Limit'] / 100000)}LACAvailable Limit")
      expect(@common_pages.verify_assignment_dialog(@first_investor_name, 'ROI')).to eq("#{format('%g', @commercial_kotak['Yield'])} %ROI")
      expect(@common_pages.verify_assignment_dialog(@first_investor_name, 'Tenor')).to eq("#{@commercial_kotak['Tenor']} daysTenor")
      @common_pages.close_modal
    end

    e.run_step 'Verify transaction is not present in Unassigned Investor' do
      expect(@transactions_page.assign_investor).to eq('You have successfully assigned 1 invoices to the Assigned Investors')
      @tarspect_methods.BUTTON('Done').wait_for_element
      @tarspect_methods.click_button('Done')
      expect(@common_pages.transaction_listed?(@transaction_id)).to eq(false), "Transaction #{@transaction_id} is listed, Ideally it should not be present"
    end
  end

  it 'Invoice Assignment : Verification of Assignment based on Available Limit', :sanity, :no_run do |e|
    e.run_step 'Capture Vendor Commercial for Kotak' do
      hash = {
        'Anchor ID' => 5,
        'Investor ID' => 7,
        'Program' => 'PO Financing',
        'Type' => 'Vendor',
        'Vendor Name' => @vendor_name,
        'actor' => @investor_actor
      }
      resp = get_vendor_commercial(hash)
      expect(resp[:code]).to eq 200
      @commercial_kotak = {
        'Yield' => resp[:body][:program_limits][:yield],
        'Sanction Limit' => resp[:body][:program_limits][:sanction_limit],
        'Tenor' => resp[:body][:program_limits][:tenor],
        'Invoice Days' => resp[:body][:program_limits][:days_to_raise_invoice]
      }
    end

    e.run_step 'Vendor Commercial setup and approval' do
      @testdata.merge!(
        'Payment Date' => get_todays_date,
        'Valid Till' => get_todays_date(300),
        'Yield' => @commercial_kotak['Yield'] + 2,
        'Sanction Limit' => @commercial_kotak['Sanction Limit'] + 100000,
        'Tenor' => @commercial_kotak['Tenor'],
        'Invoice Days' => @commercial_kotak['Invoice Days'],
        'Effective Date' => get_todays_date
      )
      resp = set_and_approve_commercials(@testdata)
      expect(resp[0]).to eq(201), "Error in Commercial setup and approval #{resp}"
    end

    e.run_step 'Initiate invoice Transaction' do
      @invoice_data['PO Date'] = get_todays_date(-30)
      @invoice_data['PO Value'] = 150000
      @invoice_data['Requested Disbursement Value'] = @invoice_data['PO Value'] - 10000
      values = {
        po_details: @invoice_data,
        program_id: 4,
        actor: 'assignment_vendor'
      }
      resp = create_po_transaction(values)
      expect(resp[:code]).to eq(201), resp.to_s
      expect(resp[:body][:status]).to eq('pending_investor_assignment')
      @transaction_id = resp[:body][:id]
    end

    e.run_step 'Login as Vendor : CH28 Stores' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['assignment_vendor']['email'], $conf['users']['assignment_vendor']['password'])).to be true
    end

    e.run_step 'Verify Invoice is assigned to Investor based on Available Limit' do
      @common_pages.click_menu(MENU_PO_FINANCING)
      @common_pages.click_transactions_tab(UNASSIGNED_INVESTOR)
      expect(@common_pages.transaction_listed?(@transaction_id)).to eq(true), "Transaction #{@transaction_id} is not listed"
      expect(@common_pages.TRANSACTION(@transaction_id).text).to include(@second_investor_name), 'Investor assgined as not expected'
      @common_pages.navigate_to_transaction(@transaction_id)
      expect(@common_pages.get_investor_in_details).to eq(@second_investor_name)
      @common_pages.click_back_button
    end

    e.run_step 'Verify Investor Commercials are displayed correctly' do
      @transactions_page.deselect_checkbox_in_unassigned_investor
      @disbursement_page.select_transactions(@transaction_id)
      @tarspect_methods.click_button('Reassign')
      expect(@common_pages.verify_assignment_dialog(@second_investor_name, 'Available Limit')).to eq("₹#{format('%g', @testdata['Sanction Limit'] / 100000)}LACAvailable Limit")
      expect(@common_pages.verify_assignment_dialog(@second_investor_name, 'ROI')).to eq("#{format('%g', @testdata['Yield'])} %ROI")
      expect(@common_pages.verify_assignment_dialog(@second_investor_name, 'Tenor')).to eq("#{@testdata['Tenor']} daysTenor")
      expect(@common_pages.verify_assignment_dialog(@first_investor_name, 'Available Limit')).to eq("₹#{format('%g', @commercial_kotak['Sanction Limit'] / 100000)}LACAvailable Limit")
      expect(@common_pages.verify_assignment_dialog(@first_investor_name, 'ROI')).to eq("#{format('%g', @commercial_kotak['Yield'])} %ROI")
      expect(@common_pages.verify_assignment_dialog(@first_investor_name, 'Tenor')).to eq("#{@commercial_kotak['Tenor']} daysTenor")
      @common_pages.close_modal
    end

    e.run_step 'Verify transaction is not present in Unassigned Investor' do
      expect(@transactions_page.assign_investor).to eq('You have successfully assigned 1 invoices to the Assigned Investors')
      @tarspect_methods.BUTTON('Done').wait_for_element
      @tarspect_methods.click_button('Done')
      expect(@common_pages.transaction_listed?(@transaction_id)).to eq(false), "Transaction #{@transaction_id} is listed, Ideally it should not be present"
    end
  end

  it 'Invoice Assignment : Verification of Assignment based on Invoice Ageing', :sanity, :no_run do |e|
    e.run_step 'Capture Vendor Commercial for Kotak' do
      hash = {
        'Anchor ID' => 5,
        'Investor ID' => 7,
        'Program' => 'PO Financing',
        'Type' => 'Vendor',
        'Vendor Name' => @vendor_name,
        'actor' => @investor_actor
      }
      resp = get_vendor_commercial(hash)
      expect(resp[:code]).to eq 200
      @commercial_kotak = {
        'Yield' => resp[:body][:program_limits][:yield],
        'Sanction Limit' => resp[:body][:program_limits][:sanction_limit],
        'Tenor' => resp[:body][:program_limits][:tenor]
      }
    end

    e.run_step 'Get Invoice Agening for Kotak with Anchor Program' do
      resp = get_anchor_commercials(investor_actor: 'investor', investor_id: 7, anchor_program_id: 16)
      @commercial_kotak['Invoice Ageing Threshold'] = resp[:body][:result][:invoice_ageing_threshold]
    end

    e.run_step 'Vendor Commercial setup and approval' do
      @testdata.merge!(
        'Payment Date' => get_todays_date,
        'Valid Till' => get_todays_date(300),
        'Yield' => @commercial_kotak['Yield'] + 2,
        'Sanction Limit' => @commercial_kotak['Sanction Limit'],
        'Tenor' => @commercial_kotak['Tenor'],
        'Effective Date' => get_todays_date
      )
      resp = set_and_approve_commercials(@testdata)
      expect(resp[0]).to eq(201), "Error in Commercial setup and approval #{resp}"
    end

    e.run_step 'Initiate invoice Transaction' do
      @invoice_data['PO Date'] = get_todays_date(@commercial_kotak['Invoice Ageing Threshold'] - 10)
      values = {
        po_details: @invoice_data,
        program_id: 4,
        actor: 'assignment_vendor'
      }
      resp = create_po_transaction(values)
      expect(resp[:code]).to eq(201), resp.to_s
      expect(resp[:body][:status]).to eq('pending_investor_assignment')
      @transaction_id = resp[:body][:id]
    end

    e.run_step 'Login as Vendor : CH28 Stores' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['assignment_vendor']['email'], $conf['users']['assignment_vendor']['password'])).to be true
    end

    e.run_step 'Verify Invoice is assigned to Investor based on Invoice Ageing' do
      @common_pages.click_menu(MENU_PO_FINANCING)
      @common_pages.click_transactions_tab(UNASSIGNED_INVESTOR)
      expect(@common_pages.transaction_listed?(@transaction_id)).to eq(true), "Transaction #{@transaction_id} is not listed"
      expect(@common_pages.TRANSACTION(@transaction_id).text).to include(@second_investor_name), 'Investor assgined as not expected'
      @common_pages.navigate_to_transaction(@transaction_id)
      expect(@common_pages.get_investor_in_details).to eq(@second_investor_name)
      @common_pages.click_back_button
    end

    e.run_step 'Verify Investor Commercials are displayed correctly' do
      @transactions_page.deselect_checkbox_in_unassigned_investor
      @disbursement_page.select_transactions(@transaction_id)
      @tarspect_methods.click_button('Reassign')
      expect(@common_pages.verify_assignment_dialog(@second_investor_name, 'Available Limit')).to eq("₹#{format('%g', @testdata['Sanction Limit'] / 100000)}LACAvailable Limit")
      expect(@common_pages.verify_assignment_dialog(@second_investor_name, 'ROI')).to eq("#{format('%g', @testdata['Yield'])} %ROI")
      expect(@common_pages.verify_assignment_dialog(@second_investor_name, 'Tenor')).to eq("#{@testdata['Tenor']} daysTenor")
      expect(@common_pages.verify_assignment_dialog(@first_investor_name, 'Available Limit')).to eq("₹#{format('%g', @commercial_kotak['Sanction Limit'] / 100000)}LACAvailable Limit")
      expect(@common_pages.verify_assignment_dialog(@first_investor_name, 'ROI')).to eq("#{format('%g', @commercial_kotak['Yield'])} %ROI")
      expect(@common_pages.verify_assignment_dialog(@first_investor_name, 'Tenor')).to eq("#{@commercial_kotak['Tenor']} daysTenor")
      @common_pages.close_modal
    end

    e.run_step 'Verify transaction is not present in Unassigned Investor' do
      expect(@transactions_page.assign_investor).to eq('You have successfully assigned 1 invoices to the Assigned Investors')
      @tarspect_methods.BUTTON('Done').wait_for_element
      @tarspect_methods.click_button('Done')
      expect(@common_pages.transaction_listed?(@transaction_id)).to eq(false), "Transaction #{@transaction_id} is listed, Ideally it should not be present"
    end
  end

  it 'Invoice Assignment : Re-Assign', :sanity, :invoice_assignment, :no_run do |e|
    e.run_step 'Capture Vendor Commercial for Kotak' do
      hash = {
        'Anchor ID' => 5,
        'Investor ID' => 7,
        'Program' => 'PO Financing',
        'Type' => 'Vendor',
        'Vendor Name' => @vendor_name,
        'actor' => @investor_actor
      }
      resp = get_vendor_commercial(hash)
      expect(resp[:code]).to eq 200
      @commercial_kotak = {
        'Yield' => resp[:body][:program_limits][:yield],
        'Sanction Limit' => resp[:body][:program_limits][:sanction_limit],
        'Tenor' => resp[:body][:program_limits][:tenor],
        'Invoice Days' => resp[:body][:program_limits][:days_to_raise_invoice]
      }
    end

    e.run_step 'Vendor Commercial setup and approval' do
      @testdata.merge!(
        'Payment Date' => get_todays_date,
        'Valid Till' => get_todays_date(300),
        'Yield' => @commercial_kotak['Yield'] - 2,
        'Sanction Limit' => @commercial_kotak['Sanction Limit'],
        'Tenor' => @commercial_kotak['Tenor'],
        'Invoice Days' => @commercial_kotak['Invoice Days'] + 15,
        'Effective Date' => get_todays_date
      )
      resp = set_and_approve_commercials(@testdata)
      expect(resp[0]).to eq(201), "Error in Commercial setup and approval #{resp}"
    end

    e.run_step 'Initiate invoice Transaction' do
      @invoice_data['PO Date'] = get_todays_date(-30)
      values = {
        po_details: @invoice_data,
        program_id: 4,
        actor: 'assignment_vendor'
      }
      resp = create_po_transaction(values)
      expect(resp[:code]).to eq(201), resp.to_s
      expect(resp[:body][:status]).to eq('pending_investor_assignment')
      @transaction_id = resp[:body][:id]
    end

    e.run_step 'Login as Vendor : CH28 Stores' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['assignment_vendor']['email'], $conf['users']['assignment_vendor']['password'])).to be true
    end

    e.run_step 'Verify Invoice is assigned to Investor based on ROI' do
      @common_pages.click_menu(MENU_PO_FINANCING)
      @common_pages.click_transactions_tab(UNASSIGNED_INVESTOR)
      expect(@common_pages.transaction_listed?(@transaction_id)).to eq(true), "Transaction #{@transaction_id} is not listed"
      expect(@common_pages.TRANSACTION(@transaction_id).text).to include(@second_investor_name), 'Investor assgined as not expected'
      @common_pages.navigate_to_transaction(@transaction_id)
      expect(@common_pages.get_investor_in_details).to eq(@second_investor_name)
      $driver.navigate.back
    end

    e.run_step 'Verify Investor Commercials are displayed correctly' do
      @transactions_page.deselect_checkbox_in_unassigned_investor
      @disbursement_page.select_transactions(@transaction_id)
      @tarspect_methods.click_button('Reassign')
      expect(@common_pages.verify_assignment_dialog(@second_investor_name, 'Available Limit')).to eq("₹#{format('%g', @testdata['Sanction Limit'] / 100000)}LACAvailable Limit")
      expect(@common_pages.verify_assignment_dialog(@second_investor_name, 'ROI')).to eq("#{format('%g', @testdata['Yield'])} %ROI")
      expect(@common_pages.verify_assignment_dialog(@second_investor_name, 'Tenor')).to eq("#{@testdata['Tenor']} daysTenor")
      expect(@common_pages.verify_assignment_dialog(@first_investor_name, 'Available Limit')).to eq("₹#{format('%g', @commercial_kotak['Sanction Limit'] / 100000)}LACAvailable Limit")
      expect(@common_pages.verify_assignment_dialog(@first_investor_name, 'ROI')).to eq("#{format('%g', @commercial_kotak['Yield'])} %ROI")
      expect(@common_pages.verify_assignment_dialog(@first_investor_name, 'Tenor')).to eq("#{@commercial_kotak['Tenor']} daysTenor")
      expect(@common_pages.reassign_investor('Kotak')).to eq(true)
    end

    e.run_step 'Verify transaction is not present in Unassigned Investor' do
      expect(@common_pages.transaction_listed?(@transaction_id)).to eq(false), "Transaction #{@transaction_id} is listed, Ideally it should not be present"
    end
  end

  it 'Invoice Assignment : Bulk Re-Assign', :sanity, :no_run do |e|
    e.run_step 'Capture Vendor Commercial for Kotak' do
      hash = {
        'Anchor ID' => 5,
        'Investor ID' => 7,
        'Program' => 'PO Financing',
        'Type' => 'Vendor',
        'Vendor Name' => @vendor_name,
        'actor' => @investor_actor
      }
      resp = get_vendor_commercial(hash)
      expect(resp[:code]).to eq 200
      @commercial_kotak = {
        'Yield' => resp[:body][:program_limits][:yield],
        'Sanction Limit' => resp[:body][:program_limits][:sanction_limit],
        'Tenor' => resp[:body][:program_limits][:tenor],
        'Invoice Days' => resp[:body][:program_limits][:days_to_raise_invoice]
      }
    end

    e.run_step 'Vendor Commercial setup and approval' do
      @testdata.merge!(
        'Payment Date' => get_todays_date,
        'Valid Till' => get_todays_date(300),
        'Yield' => @commercial_kotak['Yield'] - 2,
        'Sanction Limit' => @commercial_kotak['Sanction Limit'],
        'Tenor' => @commercial_kotak['Tenor'],
        'Invoice Days' => @commercial_kotak['Invoice Days'] + 15,
        'Effective Date' => get_todays_date
      )
      resp = set_and_approve_commercials(@testdata)
      expect(resp[0]).to eq(201), "Error in Commercial setup and approval #{resp}"
    end

    e.run_step 'Initiate Multiple invoice Transactions' do
      @invoice_data['PO Date'] = get_todays_date(-55)
      values = {
        po_details: @invoice_data,
        program_id: 4,
        actor: 'assignment_vendor'
      }
      resp = create_po_transaction(values)
      expect(resp[:code]).to eq(201), resp.to_s
      expect(resp[:body][:status]).to eq('pending_investor_assignment')
      @transaction_id_1 = resp[:body][:id]
      @invoice_data = JSON.parse(ERB.new(@invoice_erb).result(binding))['PO Details']
      @invoice_data['PO Date'] = get_todays_date(-55)
      values = {
        po_details: @invoice_data,
        program_id: 4,
        actor: 'assignment_vendor'
      }
      resp = create_po_transaction(values)
      expect(resp[:code]).to eq(201), resp.to_s
      expect(resp[:body][:status]).to eq('pending_investor_assignment')
      @transaction_id_2 = resp[:body][:id]
    end

    e.run_step 'Login as Vendor : CH28 Stores' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['assignment_vendor']['email'], $conf['users']['assignment_vendor']['password'])).to be true
    end

    e.run_step 'Verify Invoice is assigned to Investor based on ROI' do
      @common_pages.click_menu(MENU_PO_FINANCING)
      @common_pages.click_transactions_tab(UNASSIGNED_INVESTOR)
      expect(@common_pages.transaction_listed?(@transaction_id_1)).to eq true
      expect(@common_pages.transaction_listed?(@transaction_id_2)).to eq true
    end

    e.run_step 'Verify Investor Commercials are displayed correctly' do
      @transactions_page.deselect_checkbox_in_unassigned_investor
      @disbursement_page.select_transactions(@transaction_id_1)
      @disbursement_page.select_transactions(@transaction_id_2)
      @tarspect_methods.click_button('Reassign')
      expect(@common_pages.verify_assignment_dialog(@second_investor_name, 'Available Limit')).to eq("₹#{format('%g', @testdata['Sanction Limit'] / 100000)}LACAvailable Limit")
      expect(@common_pages.verify_assignment_dialog(@second_investor_name, 'ROI')).to eq("#{format('%g', @testdata['Yield'])} %ROI")
      expect(@common_pages.verify_assignment_dialog(@second_investor_name, 'Tenor')).to eq("#{@testdata['Tenor']} daysTenor")
      expect(@common_pages.verify_assignment_dialog(@first_investor_name, 'Available Limit')).to eq("₹#{format('%g', @commercial_kotak['Sanction Limit'] / 100000)}LACAvailable Limit")
      expect(@common_pages.verify_assignment_dialog(@first_investor_name, 'ROI')).to eq("#{format('%g', @commercial_kotak['Yield'])} %ROI")
      expect(@common_pages.verify_assignment_dialog(@first_investor_name, 'Tenor')).to eq("#{@commercial_kotak['Tenor']} daysTenor")
      expect(@common_pages.reassign_investor('Kotak')).to eq(true)
    end

    e.run_step 'Verify transaction is not present in Unassigned Investor' do
      expect(@common_pages.transaction_listed?(@transaction_id_1)).to eq false
      expect(@common_pages.transaction_listed?(@transaction_id_2)).to eq false
    end
  end
end
