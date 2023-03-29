require './spec_helper'
describe 'Programs: Revoke Status validation', :scf, :programs, :ei_revoke do
  before(:all) do
    @anchor_actor = 'iem_anchor'
    @investor_actor = 'user_feedback_investor'
    @channel_partner_actor = 'iem_vendor'
    @anchor_name = $conf['users'][@anchor_actor]['name']
    @anchor_id = $conf['users'][@anchor_actor]['id']
    @investor_name = $conf['users'][@investor_actor]['name']
    @channel_partner_name = $conf['users'][@channel_partner_actor]['name']
    @program_type = 'PO Financing - Dealer'
    @file_to_upload = "#{Dir.pwd}/test-data/attachments/anchor_invoice.pdf"
  end

  before(:each) do
    @driver = Tarspect::Browser.new($conf['browser']).invoke
    @tarspect_methods = Common::Methods.new(@driver)
    @common_pages = Pages::CommonMethods.new(@driver)
    @programs_page = Pages::Programs.new(@driver)
    delete_draft_program('Purchase Order Financing - Dealer', @anchor_actor)
    delete_live_program('PO Financing', 'Dealer', @anchor_id)
  end

  after(:each) do |e|
    snap_screenshot(e)
  end

  it 'Programs : Revoke Status Validation' do |e|
    e.run_step 'Create & Publish a program' do
      @create_values = {
        max_tranche: 60,
        program_size: 600_000_000,
        exposure: [0, 600_000_000],
        price_expectation: [0, 11],
        type: @program_type,
        actor: @anchor_actor
      }
      draft_program = create_anchor_program(@create_values)
      expect(draft_program[:code]).to eq(200)
      expect(draft_program[:body][:anchor_programs][0][:status]).to eq('draft')
      @program_id = draft_program[:body][:anchor_programs][0][:id]
      resp = publish_anchor_program(@anchor_actor, @program_id)
      expect(resp[:body][:available_programs][:published_programs][0][:id]).to eq(@program_id)
    end

    e.run_step 'Express Interest on Program from Credit Platform' do
      resp = express_interest_on_deal(@program_id, 'investor')
      expect(resp[:code]).to eq(200), resp.to_s
      expect(resp[:body][:customer_interest_relation][0][:deal_details][:express_interest_status]).to eq('pending_for_approval')
    end

    e.run_step 'Verify Express Interest State in SCF' do
      sleep 10 # Wait for data reflection
      program = get_interested_program('investor', 'pending', @program_id)
      expect(program[0][:interest_status]).to eq('pending')
    end

    e.run_step 'Accept the EI by anchor' do
      values = { actor: @anchor_actor, id: @program_id, remarks: 'Testing EI Sync up', action: 'accepted' }
      resp = act_on_express_interest(values)
      expect(resp[:code]).to eq(200)
      expect(resp[:body][:customer_interest_relation][:status]).to eq('active')
    end

    e.run_step 'Verify expire time is present' do
      resp = retrieve_customer_relation_data(@program_id, 'investor')
      expect(resp[:code]).to eq(200)
      expiration_time = resp[:body][:customer_interest_relation][0][:expiry_time]
      expect(Date.parse(expiration_time)).to eq(Date.today + 120)
    end

    e.run_step 'Verify EI can be revoked' do
      values = { actor: @anchor_actor, id: @program_id, remarks: 'Regression - Test', action: 'revoke' }
      resp = act_on_express_interest(values)
      expect(resp[:code]).to eq(200), resp.to_s
      expect(resp[:body][:customer_interest_relation][:status]).to eq('revoke')
    end

    e.run_step 'Login as Anchor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users'][@anchor_actor]['email'], $conf['users'][@anchor_actor]['password'])).to eq true
    end

    e.run_step 'Verify Interested investor is moved to Revoked bucket' do
      @common_pages.click_menu(MENU_PROGRAMS)
      @programs_page.choose_program_listing_action('Purchase Order Financing - Dealer')
      @programs_page.click_interested_investors
      expect(@programs_page.verify_interested_investor_available?($conf['users']['investor']['name'])).to eq true
      expect(@programs_page.verify_interested_investor_available?($conf['users']['investor']['name'], 'revoked')).to eq true
      expect(@programs_page.verify_interested_investor_available?($conf['users']['investor']['name'], 'active')).to eq false
      expect(@programs_page.verify_interested_investor_available?($conf['users']['investor']['name'], 'pending')).to eq false
    end

    e.run_step 'Verify Deal can be expressed interest again from Credit Platform' do
      resp = express_interest_on_deal(@program_id, 'investor')
      expect(resp[:code]).to eq(200)
      expect(resp[:body][:customer_interest_relation][0][:deal_details][:express_interest_status]).to eq('pending_for_approval')
    end

    e.run_step 'Verify EI can be accepted again by anchor' do
      values = { actor: @anchor_actor, id: @program_id, remarks: 'Testing EI Sync up', action: 'accepted' }
      resp = act_on_express_interest(values)
      expect(resp[:code]).to eq(200)
      expect(resp[:body][:customer_interest_relation][:status]).to eq('active')
    end
  end
end
