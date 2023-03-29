require './spec_helper'
describe 'Program Listing', :scf, :programs, :program_listing do
  before(:all) do
    @anchor_actor = 'multi_program'
    @anchor_name = $conf['users']['commercials_anchor']['name']
    @anchor_id = $conf['users']['commercials_anchor']['id']
    @anchor_id1 = $conf['users'][@anchor_actor]['id']
  end

  before(:each) do
    @driver = Tarspect::Browser.new($conf['browser']).invoke
    @tarspect_methods = Common::Methods.new(@driver)
    @common_pages = Pages::CommonMethods.new(@driver)
    @commercials_page = Pages::Commercials.new(@driver)
    @programs_page = Pages::Programs.new(@driver)
    @transactions_page = Pages::Trasactions.new(@driver)
    delete_live_program('Invoice Financing', 'Dealer', @anchor_id)
    delete_draft_program('Invoice Financing - Dealer', 'commercials_anchor')
    delete_live_program('PO Financing', 'Vendor', @anchor_id)
    delete_live_program('PO Financing', 'Dealer', @anchor_id)
    delete_draft_program('Purchase Order Financing - Vendor', 'commercials_anchor')
    delete_draft_program('Purchase Order Financing - Dealer', 'commercials_anchor')
    delete_draft_program('Dynamic Discounting', 'commercials_anchor')
    delete_live_program('Invoice Financing', 'Dealer', @anchor_id1)
    delete_live_program('Invoice Financing', 'Vendor', @anchor_id1)
    delete_draft_program('Invoice Financing - Vendor', @anchor_actor)
    delete_draft_program('Invoice Financing - Dealer', @anchor_actor)
    @choose_program_values = {
      header: 'Explore Programs',
      where: 'investor_explore',
      anchor: @anchor_name,
      validate_only: true,
      type: ''
    }
  end

  after(:each) do |e|
    snap_screenshot(e)
    quit_browser
  end

  it 'Program listing: CRUD' do |e|
    @program_type = 'Invoice Financing - Dealer'
    @create_values = {
      'Program size' => '50',
      'Tenor' => '60',
      'Exposure Value' => ['0', '50'],
      'Expected Pricing' => ['0', '11']
    }
    @edit_values = {
      'Program size' => '60',
      'Tenor' => '90',
      'Exposure Value' => ['0', '60'],
      'Expected Pricing' => ['0', '15']
    }
    e.run_step 'Login as Anchor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['commercials_anchor']['email'], $conf['users']['commercials_anchor']['password'])).to be true
    end

    e.run_step 'Verify Add program button available for anchor' do
      @common_pages.click_menu(MENU_PROGRAMS)
      expect(@programs_page.add_program_available?).to eq true
    end

    e.run_step 'Validate Anchor flow map' do
      @tarspect_methods.click_button('Add Program')
      @tarspect_methods.wait_for_circular_to_disappear
      steps_head = ['STEP 01', 'STEP 02', 'STEP 03', 'STEP 04', 'STEP 05', 'STEP 06', 'STEP 07', 'STEP 08']
      steps_sub_text = [
        'Create and Publish a Program',
        'Receive Expression of Interest from Lender',
        'Accept Expression of Interest',
        'Receive Program Terms from Lender',
        'Accept MOU for the Program',
        'Invite Vendors/Dealers to the Program',
        'Lender signs borrowing document with Vendor/Dealer',
        'Ready for Disbursals'
      ]
      act_steps_head, act_steps_sub_text = @programs_page.fetch_program_flow_map
      expect(act_steps_head).to eq(steps_head)
      expect(act_steps_sub_text).to eq(steps_sub_text)
      @programs_page.click_i_ll_do_later
      @tarspect_methods.wait_for_loader_to_disappear
    end

    e.run_step 'Add program as anchor - Info page validations' do
      @programs_page.add_program_listing(@program_type, @create_values.dup)
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['DraftSaved']
    end

    e.run_step 'Verify program details in the info page' do
      expected_values = {
        'Program type' => @program_type.upcase,
        'Program size' => "₹ #{@create_values['Program size']} CR",
        'Pricing' => '0.0% - 11.0%',
        'Tenor' => "#{@create_values['Tenor']}D"
      }
      actual_values = @programs_page.get_program_details_in_info_page
      expect(actual_values).to eq expected_values
    end

    e.run_step 'Verify Program is in Draft state' do
      expect(@programs_page.draft_state?).to eq true
    end

    e.run_step 'Logout as Anchor' do
      @programs_page.click_i_ll_do_later
      expect(@common_pages.logout).to eq(true)
    end

    e.run_step 'Verify Product user can view draft programs as well' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['product']['email'], $conf['users']['product']['password'])).to be true
      @common_pages.click_menu('Explore Programs')
      @common_pages.search_program(@anchor_name)
      @choose_program_values[:type] = @program_type
      @choose_program_values[:validate_only] = true
      @choose_program_values[:where] = 'product_explore'
      expect(@programs_page.investor_choose_program(@choose_program_values)).to eq(true), "#{@program_type}, #{@anchor_name} not found"
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Anchor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['commercials_anchor']['email'], $conf['users']['commercials_anchor']['password'])).to be true
    end

    e.run_step 'Verify Draft programs can be deleted from info page' do
      @common_pages.click_menu(MENU_PROGRAMS)
      @programs_page.choose_program_listing_action(@program_type, 'Edit')
      @programs_page.delete_program_from_info_page
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['ProgramDeleted']
    end

    e.run_step 'Add program as anchor - Program List page validations' do
      @programs_page.add_program_listing(@program_type, @create_values.dup)
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['DraftSaved']
    end

    e.run_step 'Verify program details in the Programs list page' do
      values = ['₹ 50', '60d', '0.0 - 11.0%']
      @programs_page.click_i_ll_do_later
      expect(@programs_page.verify_details_in_programs_page(@program_type, values)).to eq true
    end

    e.run_step 'Edit draft programs' do
      @programs_page.choose_program_listing_action(@program_type, 'Edit')
      @programs_page.fill_program_details(@program_type, @edit_values.dup)
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['DraftUpdated']
    end

    e.run_step 'Verify Edited program details in the info page' do
      expected_values = {
        'Program type' => @program_type.upcase,
        'Program size' => "₹ #{@edit_values['Program size']} CR",
        'Pricing' => '0.0% - 15.0%',
        'Tenor' => "#{@edit_values['Tenor']}D"
      }
      actual_values = @programs_page.get_program_details_in_info_page
      expect(actual_values).to eq expected_values
    end

    e.run_step 'Delete program from Programs listing page' do
      @programs_page.click_i_ll_do_later
      @programs_page.choose_program_listing_action(@program_type, 'Delete')
      @tarspect_methods.click_button('Continue')
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['ProgramDeleted']
    end
  end

  it 'Program listing: Publish Program to investor', :publish_program_investor do |e|
    @program_type = 'Invoice Financing - Dealer'
    @create_values = {
      'Program size' => '50',
      'Tenor' => '60',
      'Exposure Value' => ['0', '50'],
      'Expected Pricing' => ['0', '11']
    }
    e.run_step 'Login as Anchor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['commercials_anchor']['email'], $conf['users']['commercials_anchor']['password'])).to be true
    end

    e.run_step 'Verify Exposure limit cannot be greater than program limit' do
      values = @create_values.dup
      values.merge!('Exposure Value' => ['0', '90'])
      @common_pages.click_menu(MENU_PROGRAMS)
      @programs_page.add_program_listing(@program_type, values)
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to include $notifications['MaxExposureFailure']
      navigate_to($conf['base_url'])
    end

    e.run_step 'Add program as anchor' do
      @common_pages.click_menu(MENU_PROGRAMS)
      @programs_page.add_program_listing(@program_type, @create_values.dup)
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['DraftSaved']
    end

    e.run_step 'Publish the program to Investors' do
      @programs_page.click_i_ll_do_later
      @programs_page.choose_program_listing_action(@program_type, 'Publish')
      @tarspect_methods.click_button('Publish')
      expect(@programs_page.publish_success?).to eq true
      @common_pages.close_modal
    end

    #     e.run_step 'Verify mail recieved on publishing the program' do
    #       flag = @transactions_page.read_transaction_mail(
    #         subject: 'One New Program on CredSCF',
    #         body_content: ['Hi Kotak,', @program_type, 'Honda Motor Corp'],
    #         text: 'SCF program'
    #       )
    #       expect(flag).to eq true
    #     end. For email validation, we are currently checking upto 15 mails, For new program creation, more mails are sent with same subject

    e.run_step 'Logout as anchor' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Product user and verify if program can be viewed' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['product']['email'], $conf['users']['product']['password'])).to be true
      @common_pages.click_menu(MENU_EXPLORE_PROGRAMS)
      @common_pages.search_program(@anchor_name)
      @choose_program_values[:type] = @program_type
      @choose_program_values[:validate_only] = false
      @choose_program_values[:where] = 'product_explore'
      expect(@programs_page.investor_choose_program(@choose_program_values)).to eq(true), "#{@program_type}, #{@anchor_name} not found"
      expect(@driver.current_url).to include('vendor-list')
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Investor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['investor']['email'], $conf['users']['investor']['password'])).to be true
    end

    e.run_step 'Validate program is available for investor' do
      @common_pages.click_menu('Explore Programs')
      @common_pages.search_program(@anchor_name)
      @choose_program_values[:type] = @program_type
      @choose_program_values[:validate_only] = true
      @choose_program_values[:where] = 'investor_explore'
      expect(@programs_page.investor_choose_program(@choose_program_values)).to eq(true), "#{@program_type}, #{@anchor_name} not found"
    end

    e.run_step 'Validate Program values as Investor' do
      @common_pages.search_program(@anchor_name)
      @choose_program_values[:type] = @program_type
      @choose_program_values[:validate_only] = false
      @programs_page.investor_choose_program(@choose_program_values)
      expect(@programs_page.validate_modal_values('Program Size')).to eq "₹ #{@create_values['Program size']} CR"
      expect(@programs_page.validate_modal_values('Exposure')).to eq "₹ 0 - ₹ #{@create_values['Exposure Value'][1]} CR"
      expect(@programs_page.validate_modal_values('Pricing')).to eq '0.0% - 11.0%'
      expect(@programs_page.validate_modal_values('Tenure')).to eq "#{@create_values['Tenor']}d"
    end

    e.run_step 'Validate anchor details in Program' do
      scf_hash = @programs_page.get_scf_anchor_details
      @programs_page.move_to_credit_page
      sleep 5
      credit_hash = @programs_page.get_credit_anchor_details
      @tarspect_methods.close_tab
      expect(scf_hash).to eq(credit_hash)
    end

    e.run_step 'Investor express interest for the program' do
      @tarspect_methods.click_button('Express Interest')
      @tarspect_methods.wait_for_loader_to_disappear
      expect(@programs_page.pending_review_available?(@anchor_name)).to eq true
    end

    e.run_step 'Verify the success banner once Investor express interest' do
      expect(@programs_page.success_banner_available?).to eq true
      @common_pages.close_modal
    end

    e.run_step 'Verify the expressed interest in My interests page - Pending' do
      programs = get_interested_programs('investor', 'pending')
      pending_program = programs.select { |program| program[:created_by] == @anchor_name && program[:name] == @program_type }
      expect(pending_program.empty?).to eq(false), "#{@anchor_name} #{@program_type} is not found in Pending Interest List"
    end

    e.run_step 'Logout as Investor' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as anchor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['commercials_anchor']['email'], $conf['users']['commercials_anchor']['password'])).to be true
    end

    e.run_step 'Verify Interested Investors for the program under Pending state' do
      @common_pages.click_menu(MENU_PROGRAMS)
      @programs_page.choose_program_listing_action(@program_type)
      @programs_page.click_interested_investors
      expect(@programs_page.verify_interested_investor_available?($conf['users']['investor']['name'])).to eq true
      expect(@programs_page.verify_interested_investor_available?($conf['users']['investor']['name'], 'pending')).to eq true
      expect(@programs_page.verify_interested_investor_available?($conf['users']['investor']['name'])).to eq true
    end

    e.run_step 'Verify Interested Investors for the program not available under Active state before approving' do
      expect(@programs_page.verify_interested_investor_available?($conf['users']['investor']['name'], 'active')).to eq false
    end

    e.run_step 'Anchor accepts the investor' do
      @programs_page.choose_investor_action($conf['users']['investor']['name'], 'Accept')
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['InterestVerified']
    end

    e.run_step 'Verify Interested Investors for the program available under Active state after approving' do
      expect(@programs_page.verify_interested_investor_available?($conf['users']['investor']['name'], 'active')).to eq true
    end

    e.run_step 'Verify Interested Investors for the program not available under pending state after approving' do
      expect(@programs_page.verify_interested_investor_available?($conf['users']['investor']['name'], 'pending')).to eq false
    end

    e.run_step 'Logout as Anchor' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Investor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['investor']['email'], $conf['users']['investor']['password'])).to be true
    end

    e.run_step 'Verify Interest is in not in pending state under My Interests' do
      programs = get_interested_programs('investor', 'pending')
      pending_program = programs.select { |program| program[:created_by] == @anchor_name && program[:name] == @program_type }
      expect(pending_program.empty?).to eq(true), "#{@anchor_name} #{@program_type} is found in Pending Interest List"
    end
  end

  it 'Program listing: Add and Publish Multiple programs', :publish_multiple_program do |e|
    @programs = ['Invoice Financing - Dealer', 'Invoice Financing - Vendor']
    @anchor_name = $conf['users'][@anchor_actor]['name']
    @program_values = {
      @programs[0] => {
        'Program size' => '50',
        'Tenor' => '60',
        'Exposure Value' => ['0', '50'],
        'Expected Pricing' => ['0', '11']
      },
      @programs[1] => {
        'Program size' => '60',
        'Tenor' => '90',
        'Exposure Value' => ['0', '40'],
        'Expected Pricing' => ['0', '15']
      }
    }

    e.run_step 'Login as anchor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users'][@anchor_actor]['email'], $conf['users'][@anchor_actor]['password'])).to be true
    end

    e.run_step 'Add multiple programs' do
      @common_pages.click_menu(MENU_PROGRAMS)
      @programs_page.select_multiple_programs(@programs)
      @programs_page.add_values_for_multiple_programs(@program_values.deep_dup)
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['DraftSaved']
    end

    e.run_step 'Verify program details in the info page' do
      expected_values1 = {
        'Program type' => @programs[0].upcase,
        'Program size' => "₹ #{@program_values[@programs[0]]['Program size']} CR",
        'Pricing' => '0.0% - 11.0%',
        'Tenor' => "#{@program_values[@programs[0]]['Tenor']}D"
      }
      expected_values2 = {
        'Program type' => @programs[1].upcase,
        'Program size' => "₹ #{@program_values[@programs[1]]['Program size']} CR",
        'Pricing' => '0.0% - 15.0%',
        'Tenor' => "#{@program_values[@programs[1]]['Tenor']}D"
      }
      actual_values = @programs_page.get_program_details_in_info_page
      expect(actual_values).to include expected_values1
      expect(actual_values).to include expected_values2
    end

    e.run_step 'Publish Programs from the info page' do
      @tarspect_methods.click_button('Publish')
      @tarspect_methods.wait_for_circular_to_disappear
      @programs_page.click_publish_in_the_modal
      expect(@programs_page.publish_success_for_multiple_program?(@programs.count)).to eq true
      @common_pages.close_modal
      refresh_page
    end

    e.run_step 'Logout as Anchor' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Investor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['investor']['email'], $conf['users']['investor']['password'])).to be true
    end

    e.run_step 'Investor express interest for program' do
      @common_pages.click_menu('Explore Programs')
      @common_pages.search_program(@anchor_name)
      @choose_program_values[:type] = @programs[0]
      @choose_program_values[:validate_only] = false
      @choose_program_values[:anchor] = @anchor_name
      @programs_page.investor_choose_program(@choose_program_values)
      @tarspect_methods.click_button('Express Interest')
      @tarspect_methods.wait_for_loader_to_disappear
      expect(@programs_page.pending_review_available?(@anchor_name)).to eq true
      @common_pages.close_modal
    end

    e.run_step 'Logout as Investor' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as anchor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users'][@anchor_actor]['email'], $conf['users'][@anchor_actor]['password'])).to be true
    end

    e.run_step 'Anchor rejects the investor' do
      @common_pages.click_menu(MENU_PROGRAMS)
      @programs_page.choose_program_listing_action(@programs[0])
      @programs_page.click_interested_investors
      @programs_page.choose_investor_action($conf['users']['investor']['name'], 'Reject')
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['InterestVerified']
    end

    e.run_step 'Verify Interested Investors for the program available under Active state after rejecting' do
      expect(@programs_page.verify_interested_investor_available?($conf['users']['investor']['name'], 'rejected')).to eq true
    end

    e.run_step 'Verify Interested Investors for the program not available under pending state after rejecting' do
      expect(@programs_page.verify_interested_investor_available?($conf['users']['investor']['name'], 'pending')).to eq false
    end

    e.run_step 'Logout as Anchor' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Investor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['investor']['email'], $conf['users']['investor']['password'])).to be true
    end

    e.run_step 'Verify Interest is in rejected state under My Interests' do
      programs = get_interested_programs('investor', 'declined')
      pending_program = programs.select { |program| program[:created_by] == @anchor_name && program[:name] == @programs[0] }
      expect(pending_program.empty?).to eq(false), "#{@anchor_name} #{@programs[0]} is not found in Declined Interest List"
    end
  end

  it 'Program listing: DD program validations', :dd do |e|
    @program_type = 'Dynamic Discounting'
    e.run_step 'Login as Anchor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['commercials_anchor']['email'], $conf['users']['commercials_anchor']['password'])).to be true
    end

    e.run_step 'Add DD program as anchor and validate info in details page' do
      @common_pages.click_menu(MENU_PROGRAMS)
      @programs_page.add_program_listing(@program_type)
      expected_values = {
        'Program type' => @program_type.upcase,
        'Program size' => 'NA',
        'Pricing' => 'NA% - NA%',
        'Tenor' => 'NA'
      }
      actual_values = @programs_page.get_program_details_in_info_page
      expect(actual_values).to eq expected_values
    end

    e.run_step 'Verify DD Program details in the Programs list page' do
      values = ['NA', 'NA', 'NA']
      @programs_page.click_i_ll_do_later
      expect(@programs_page.verify_details_in_programs_page(@program_type, values)).to eq true
    end
  end

  it 'Program Listing :: Express Interest Tie-in', :express_tie_in, :mails do |e|
    @program_type2 = 'Invoice Financing - Dealer'
    @create_values2 = {
      max_tranche: 60,
      program_size: 600_000_000,
      exposure: [0, 600_000_000],
      price_expectation: [0, 11],
      type: @program_type2,
      actor: 'commercials_anchor'
    }
    e.run_step 'Create a Program' do
      draft_program2 = create_anchor_program(@create_values2)
      expect(draft_program2[:code]).to eq(200)
      expect(draft_program2[:body][:anchor_programs][0][:status]).to eq('draft')
      @program_id2 = draft_program2[:body][:anchor_programs][0][:id]
      resp2 = publish_anchor_program('commercials_anchor', @program_id2)
      expect(resp2[:body][:available_programs][:published_programs][0][:id]).to eq(@program_id2)
    end

    # e.run_step 'Verify mail recieved to Investor on publishing the program' do
    # Once other programs are deleted, it will work
    # flag = @transactions_page.read_transaction_mail(
    #   subject: 'One New Program on CredSCF',
    #   body_content: ['Hi Kotak,', @program_type2, 'Honda Motor Corp'],
    #   text: 'SCF program'
    # )
    # expect(flag).to eq true
    # end

    e.run_step 'Verify Express Interest State in SCF' do
      program = get_anchor_program_by_investor(@program_id2, 'investor')
      expect(program[0][:interest_status]).to eq('NA')
    end

    e.run_step 'Verify Deal is present for expressing interest in Credit platform' do
      expect(retrieve_deals_from_credit('investor', 'Invoice Financing - Dealer', 'Honda Motor Corp')).not_to eq []
    end

    e.run_step 'Express Interest on Program from Credit Platform' do
      resp = express_interest_on_deal(@program_id2, 'investor')
      expect(resp[:code]).to eq(200)
      expect(resp[:body][:customer_interest_relation][0][:deal_details][:express_interest_status]).to eq('pending_for_approval')
    end

    e.run_step 'Verify Express Interest State in SCF' do
      sleep 10 # Wait for data reflection
      program = get_interested_program('investor', 'pending', @program_id2)
      expect(program[0][:interest_status]).to eq('pending')
    end

    e.run_step 'Verify mail recieved to anchor on expressing interest to the program' do
      full_program = 'Invoice Financing - Dealer'
      flag = verify_mail_present(
        subject: "New Interest on your #{full_program}",
        body_content: ['Hi Honda Motor Corp,', 'Kotak has expressed interest'],
        text: full_program
      )
      expect(flag).to eq true
    end

    e.run_step 'Decline the EI by anchor' do
      values = {
        actor: 'commercials_anchor',
        id: @program_id2,
        remarks: 'Testing EI Sync up',
        action: 'rejected'
      }
      resp = act_on_express_interest(values)
      expect(resp[:code]).to eq(200)
      expect(resp[:body][:customer_interest_relation][:status]).to eq('rejected')
    end

    e.run_step 'Verify Express Interest State as Rejected in SCF' do
      sleep 10 # Wait for data reflection
      program = get_interested_program('investor', 'declined', @program_id2)
      flag = program.is_a?(Array)
      expect(flag).to eq(true), "No Programs found #{@program_id2}"
      expect(program[0][:interest_status]).to eq('rejected')
    end

    e.run_step 'Verify Express Interest State as Rejected in Credit' do
      resp = retrieve_customer_relation_data(@program_id2, 'investor')
      expect(resp[:body][:customer_interest_relation][0][:deal_details][:express_interest_status]).to eq('rejected')
    end
  end
end
