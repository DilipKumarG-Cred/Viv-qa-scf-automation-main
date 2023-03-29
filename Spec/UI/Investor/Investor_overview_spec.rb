require './spec_helper'
describe 'Investor Overview: Dashboard Verification', :scf, :investor do
  before(:all) do
    @investor_admin = 'investor_profile_investor'
    @investor_id = $conf['users']['investor_profile_investor']['id']
    @anchor_actor = 'interest_calc_anchor'
    @anchor_id = $conf['users'][@anchor_actor]['id']
    @anchor_name = $conf['users'][@anchor_actor]['name']
    @vendor_actor = 'interest_calc_vendor'
    @vendor_name = $conf['users'][@vendor_actor]['name']
    @borrowing_document = "#{Dir.pwd}/test-data/attachments/borrowing_document.pdf"
    @invoice_file = @borrowing_document
    @payment_proof = @borrowing_document
    @commercials_data_erb = File.read("#{Dir.pwd}/test-data/erb/commercials_data.erb")
    @test_bed_erb = File.read("#{Dir.pwd}/test-data/erb/testbed_data.erb")
    @set_commercial_values = JSON.parse(ERB.new(@commercials_data_erb).result(binding))['Anchor Commercials'].transform_keys(&:to_sym)
    @set_commercial_values.merge!(
      actor: @investor_admin,
      investor_id: @investor_id,
      anchor_program_id: '',
      max_days_to_raise_invoice: 45
    )
  end

  before(:each) do
    @driver = Tarspect::Browser.new($conf['browser']).invoke
    @commercials_page = Pages::Commercials.new(@driver)
    @tarspect_methods = Common::Methods.new(@driver)
    @transactions_page = Pages::Trasactions.new(@driver)
    @common_pages = Pages::CommonMethods.new(@driver)
    @investor_page = Pages::Investor.new(@driver)
    @programs_page = Pages::Programs.new(@driver)
    @disbursement_page = Pages::Disbursement.new(@driver)
    delete_live_program('PO Financing', 'Vendor', @anchor_id)
    delete_draft_program('PO Financing - Vendor', @anchor_actor)
    @program = 'PO Financing'
    @type = 'Vendor'
    values = {
      actor: @investor_admin,
      comment: 'Declining transaction - before each regression',
      program_group: 'invoice',
      anchor_id: @anchor_id,
      vendor_id: $conf['users'][@vendor_actor]['id'],
      by_group_id: true
    }
    decline_all_up_for_disbursements(values)
    values = {
      investor_actor: @investor_admin,
      investor_id: @investor_id,
      anchor_id: @anchor_id,
      program_id: $conf['programs']['Invoice Financing - Vendor']
    }
    force_delete_anchor_commercials(values)
  end

  after(:each) do |e|
    snap_screenshot(e)
    quit_browser
  end

  it 'Investor : Verification of Investor Landing Page - Program tiles', :no_run do |e|
    e.run_step 'Publish a program for Anchor - GMR Infra' do
      @program_type = 'PO Financing - Vendor'
      @create_values = {
        max_tranche: 60,
        program_size: 600_000_000,
        exposure: [0, 600_000_000],
        price_expectation: [0, 11],
        type: @program_type,
        actor: @anchor_actor
      }
      draft_program = create_anchor_program(@create_values)
      expect(draft_program[:body][:errors].nil?).to eq(true), draft_program[:body][:errors].to_s

      expect(draft_program[:body][:anchor_programs][0][:status]).to eq('draft')
      @program_id = draft_program[:body][:anchor_programs][0][:id]
      resp = publish_anchor_program(@anchor_actor, @program_id)
      expect(resp[:body][:available_programs][:published_programs][0][:id]).to eq(@program_id)
    end

    e.run_step 'Login as Investor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users'][@investor_admin]['email'], $conf['users'][@investor_admin]['password'])).to be true
    end

    e.run_step 'Verify program is shown in Recently added program list' do
      @choose_program_values = {
        anchor: 'GMR Infra',
        validate_only: true,
        type: 'Purchase Order Financing - Vendor'
      }
      @tarspect_methods.wait_for_circular_to_disappear
      @tarspect_methods.wait_for_loader_to_disappear
      explore_list = @programs_page.PROGRAM_LIST('investor_overview')
      expect(@programs_page.verify_program_present(explore_list, @choose_program_values)).to eq(true)
    end

    @before_tile_values = @investor_page.fetch_dashboard_tile_values

    e.run_step 'Verify interest can be expressed' do
      resp = express_interest_on_deal(@program_id, @investor_admin)
      expect(resp[:code]).to eq(200), resp.to_s
      expect(resp[:body][:customer_interest_relation][0][:deal_details][:express_interest_status]).to eq('pending_for_approval')
    end

    e.run_step 'Verify Express Interest State in SCF' do
      sleep 10 # Wait for data reflection
      program = get_interested_program(@investor_admin, 'pending', @program_id)
      expect(program.empty?).to eq(false)
    end

    e.run_step 'Verify interest can be accepted by anchor' do
      values = {
        actor: @anchor_actor,
        id: @program_id,
        remarks: 'Testing Investor Dashboard',
        action: 'accepted'
      }
      resp = act_on_express_interest(values)
      expect(resp[:code]).to eq(200), resp.to_s
      expect(resp[:body][:customer_interest_relation][:status]).to eq('active')
    end

    e.run_step 'Verify Discussion in Progress tile count is increased by 1' do
      @after_tile_values = @investor_page.fetch_dashboard_tile_values
      expect(@after_tile_values[:discussion_in_progress]).to eq(@before_tile_values[:discussion_in_progress] + 1)
    end

    e.run_step 'Verify Program shown in Discussion in Progress dasboard tile' do
      @investor_page.DASHBOARD_CLICK_OPEN('Discussion in Progress').click
      sleep 2
      @tarspect_methods.wait_for_loader_to_disappear
      explore_list = @programs_page.PROGRAM_LIST('investor_explore')
      e_list = @tarspect_methods.DYNAMIC_TAG(:xpath, "//*[@id='modal-root']#{explore_list.what}")
      expect(@programs_page.verify_program_present(e_list, @choose_program_values)).to eq(true)
      @common_pages.close_modal
      @tarspect_methods.wait_for_loader_to_disappear
      sleep 1
    end

    e.run_step 'Verify anchor commercials can be set' do
      anchor_details = fetch_anchor_details(@investor_admin, @anchor_id)
      anchor_program = anchor_details[:body][:anchor_programs].select { |programs| programs[:id] == $conf['programs']['PO Financing - Vendor'] }
      @anchor_program_id = anchor_program[0][:anchor_program_id]
      @set_commercial_values[:anchor_program_id] = @anchor_program_id
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
      resp1 = set_anchor_commercials(@set_commercial_values, action: :submit)
      expect(resp1[:code]).to eq(200), resp1.to_s
      expect(resp1[:body][:result][:status]).to eq('pending_effective_date')
    end

    e.run_step 'Verify Commercials finalized tile count is increased by 1' do
      @after_tile_values = @investor_page.fetch_dashboard_tile_values
      expect(@after_tile_values[:commercial_finalized]).to eq(@before_tile_values[:commercial_finalized] + 1)
    end

    e.run_step 'Verify Program shown in Commercials Finalized dasboard tile' do
      @investor_page.DASHBOARD_CLICK_OPEN('Commercials Finalized').click
      sleep 2
      @tarspect_methods.wait_for_loader_to_disappear
      explore_list = @programs_page.PROGRAM_LIST('investor_explore')
      e_list = @tarspect_methods.DYNAMIC_TAG(:xpath, "//*[@id='modal-root']#{explore_list.what}")
      expect(@programs_page.verify_program_present(e_list, @choose_program_values)).to eq(true)
      @common_pages.close_modal
      @tarspect_methods.wait_for_loader_to_disappear
      sleep 1
    end

    e.run_step 'Verify Discussion in Progress tile count is decreased by 1' do
      expect(@after_tile_values[:discussion_in_progress]).to eq(@before_tile_values[:discussion_in_progress])
    end
  end

  it 'Investor : Verification of Investor Landing Page - Tranasaction tiles' do |e|
    @program_name = 'Invoice Financing - Vendor'
    @anchor_actor = 'interest_calc_anchor'
    @anchor_gstn = $conf['users']['interest_calc_anchor']['gstn']
    @counterparty_gstn = $conf['users'][@vendor_actor]['gstn']
    clear_all_overdues({ anchor: 'GMR Infra', vendor: @vendor_name, investor: @investor_admin })

    e.run_step 'Login as Investor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users'][@investor_admin]['email'], $conf['users'][@investor_admin]['password'])).to be true
    end

    e.run_step 'Verify Disbursement dashboard values before creating transaction' do
      @before_tile_values = @investor_page.fetch_dashboard_tile_values
      invester_profile_resp = get_investor_profile(@investor_admin)
      @invester_profile = invester_profile_resp[:body][:investor_dashboard_details]
      expect(@invester_profile[:total_disbursement_today]).to eq(@before_tile_values[:up_for_disbursement])
    end

    e.run_step 'Create a transaction (Draft -> Released)' do
      @testdata = JSON.parse(ERB.new(@test_bed_erb).result(binding))
      @testdata['Invoice Details']['Invoice Date'] = (Date.today - 60).strftime('%d-%b-%Y')
      @transaction_id = seed_transaction(
        {
          actor: @anchor_actor,
          counter_party: @vendor_actor,
          invoice_details: @testdata['Invoice Details'],
          invoice_file: @invoice_file,
          program: @program_name,
          investor_id: @investor_id,
          investor_actor: @investor_admin,
          program_group: 'invoice'
        }
      )
      expect(@transaction_id.to_s).not_to include('Error while creating transaction')
    end

    e.run_step 'Verify transaction tiles are updated' do
      sleep 60
      @tran_resp = get_transaction_details(@transaction_id)
      @disbursed_value = @tran_resp[:body][:disbursement_amount]
      @after_tile_values = @investor_page.fetch_dashboard_tile_values
      expect(@after_tile_values[:up_for_disbursement]).to eq(@before_tile_values[:up_for_disbursement] + @disbursed_value)
    end

    e.run_step 'Disburse the transaction' do
      @disbursement_values = disburse_transaction(
        {
          transaction_id: @transaction_id,
          invoice_value: @testdata['Invoice Details']['Invoice Value'],
          type: 'frontend',
          date_of_payment: @testdata['Invoice Details']['Invoice Date'],
          payment_proof: @payment_proof,
          program: 'Invoice Financing - Vendor',
          investor_actor: @investor_admin,
          strategy: 'simple_interest'
        }
      )
      expect(@disbursement_values).not_to include('Error while disbursements')
    end

    e.run_step 'Verify Available limit, limit utilised and remaining' do
      count = 0 # Wait for data reflection
      loop do
        sleep 1
        invester_profile_resp = get_investor_profile(@investor_admin)
        @after_invester_profile = invester_profile_resp[:body][:investor_dashboard_details]
        break unless @invester_profile[:total_available_limit] == @after_invester_profile[:total_available_limit]
        break if count > 20

        count += 1
      end
      expect(@invester_profile[:total_available_limit] - @after_invester_profile[:total_available_limit]).to eq(@disbursement_values[0][0])
      limit_utilised = ((@after_invester_profile[:total_sanction_limit] - @after_invester_profile[:total_available_limit]) / @after_invester_profile[:total_sanction_limit]) * 100
      expect(@after_invester_profile[:limit_utilised]).to eq(rounded_half_down_value(limit_utilised))
      expect(@after_invester_profile[:limit_remaining]).to eq(100 - rounded_half_down_value(limit_utilised))
    end

    e.run_step 'Verify Due for payment tile is updated' do
      @after_tile_values = @investor_page.fetch_dashboard_tile_values
      expect(@after_tile_values[:due_for_payment]).to eq(@disbursement_values[0][0])
      expect(@after_tile_values[:up_for_disbursement]).to eq(@before_tile_values[:up_for_disbursement])
    end

    e.run_step 'Verify navigation is proper navigated from dashboard' do
      @common_pages.click_menu('Home')
      @investor_page.DASHBOARD_CLICK_OPEN('Up for Disbursement').click
      @tarspect_methods.click_button('Invoice Financing')
      @tarspect_methods.wait_for_loader_to_disappear
      expect(@driver.current_url).to include('invoice-financing/up-for-disbursement')
      @common_pages.click_menu('Home')
      @investor_page.DASHBOARD_CLICK_OPEN('Up for Disbursement').click
      @tarspect_methods.click_button('PO Financing')
      @tarspect_methods.wait_for_loader_to_disappear
      expect(@driver.current_url).to include('po-financing/up-for-disbursement')
    end

    e.run_step 'Verify navigation is properly navigated from dashboard Due for payment' do
      @common_pages.click_menu('Home')
      @tarspect_methods.wait_for_loader_to_disappear
      @investor_page.DASHBOARD_CLICK_OPEN('Due for Payment').click
      @tarspect_methods.click_button('Invoice Financing')
      @tarspect_methods.wait_for_loader_to_disappear
      expect(@driver.current_url).to include('invoice-financing/due-for-payment')
      @common_pages.click_menu('Home')
      @tarspect_methods.wait_for_loader_to_disappear
      @investor_page.DASHBOARD_CLICK_OPEN('Due for Payment').click
      @tarspect_methods.click_button('PO Financing')
      @tarspect_methods.wait_for_loader_to_disappear
      expect(@driver.current_url).to include('po-financing/due-for-payment')
    end
  end

  it 'Investor : Verification of Investor Landing Page - Commercial tiles' do |e|
    e.run_step 'Login as investor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['edit_commercial_investor']['email'], $conf['users']['edit_commercial_investor']['password'])).to be true
    end

    e.run_step 'Verify Limits for renewal card is shown' do
      p_resp = fetch_up_for_renewal_cards('edit_commercial_investor', 'pgmlimit')
      c_resp = fetch_up_for_renewal_cards('edit_commercial_investor', 'chnllimit')
      total_cards = p_resp[1] + c_resp[1]
      limits_count = @investor_page.DASHBOARD_TILES('Limits up for renewal').text.to_i
      expect(limits_count).to eq(total_cards)
    end

    e.run_step 'Verify proper navigation is present on clicking Renew button' do
      @investor_page.DASHBOARD_CLICK_OPEN('Limits up for renewal').click
      renew_buttons = @tarspect_methods.DYNAMIC_XPATH('a', 'text()', 'Renew').fetch_elements
      renew_buttons.each do |renew|
        href = renew.get_attribute('href')
        urls = href.split('tf-stg.go-yubi.in')[1].split('/')
        expect(urls[1]).to eq('anchors'), href
        expect(urls[3]).to eq('anchor-programs'), href
        expect(urls[5, 2]).to eq(['commercial-details', 'program']), href
        expect(urls[8]).to eq('program-details'), href
      end
      @tarspect_methods.DYNAMIC_LOCATOR('Channel Limits').click
      @tarspect_methods.wait_for_loader_to_disappear
      cl_renew_buttons = @tarspect_methods.DYNAMIC_XPATH('a', 'text()', 'Renew').fetch_elements
      cl_renew_buttons.each do |renew|
        href = renew.get_attribute('href')
        ['clients', 'details', 'commercial?anchorProgramId', 'vendorDetailId', 'anchorId', 'investorId', 'programId', 'type=info'].each do |k|
          expect(href).to include(k), "#{k} is not matched in #{href}"
        end
      end
    end
  end
end
