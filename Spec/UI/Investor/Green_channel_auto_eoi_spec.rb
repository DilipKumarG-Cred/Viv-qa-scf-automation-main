require './spec_helper'
describe 'Investor: Green Channel - Auto EOI', :scf, :investor, :green_channel do
  before(:all) do
    @investor_actor = 'gc_investor'
    @anchor_actor = 'mi_anchor'
    @anchor_id = $conf['users'][@anchor_actor]['id']
    delete_live_program('PO Financing', 'Dealer', @anchor_id)
    delete_draft_program('Purchase Order Financing - Dealer', @anchor_actor)
    @time = 10
  end

  before(:each) do
    @driver = Tarspect::Browser.new($conf['browser']).invoke
    @tarspect_methods = Common::Methods.new(@driver)
    @common_pages = Pages::CommonMethods.new(@driver)
    @investor_page = Pages::Investor.new(@driver)
    set_program_preferences({}, @investor_actor)
  end

  after(:each) do |e|
    snap_screenshot(e)
    quit_browser
  end

  it 'Investor: Green Channel - Verification of Program Preferences', :gc_program_prefs do |e|
    e.run_step 'Login as Investor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users'][@investor_actor]['email'], $conf['users'][@investor_actor]['password'])).to be true
    end

    e.run_step 'Set Program Parameters' do
      @common_pages.click_menu('My Preferences')
      values = {
         'Industries to Avoid' => { enabled: true, values: 'Airlines', slider: false },
         'Minimum Credit Rating' => { enabled: true, values: 'A+', slider: false },
         'Revenue' => { enabled: true, values: { 'Revenue' => [1000, 2000] }, slider: true },
         'EBITDA' => { enabled: true, values: { 'EBITDA' => [1, 2000] }, slider: true },
         'Program' => { enabled: true, values: 'Invoice Financing - Vendor', slider: false },
         'Program Size' => { enabled: true, values: { 'Program Size' => [1, 100] }, slider: true },
         'Exposure per Channel Partner' => { enabled: true, values: { 'Exposure per Channel Partner' => [1, 100] }, slider: true },
         'Expected Pricing' => { enabled: true, values: { 'Expected Pricing' => [10, 50] }, slider: true },
         'Tenure' => { enabled: true, values: { 'Tenure' => [20, 90] }, slider: true },
         'Express interest automatically' => { enabled: false }
      }
      @investor_page.choose_program_parameters(values)
      @tarspect_methods.click_button('Save Changes')
      sleep 3
      @tarspect_methods.click_button('Save') if @tarspect_methods.DYNAMIC_LOCATOR('You’re about to confirm the preference you made.').is_present?
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq 'Preferences saved!'
    end

    e.run_step 'Verify changes are saved properly for Industry' do
      @preference_resp = fetch_program_preferences(@investor_actor)
      expect(@preference_resp[:code]).to eq(200)
      v = @preference_resp[:body][:program_preferences].select { |k| k[:attribute] == 'Industry' }
      expect(v[0][:program_values]).to eq(['airlines'])
    end

    e.run_step 'Verify changes are saved properly for MinCreditRating' do
      v = @preference_resp[:body][:program_preferences].select { |k| k[:attribute] == 'MinCreditRating' }
      expect(v[0][:program_values]).to eq(['A+'])
    end

    e.run_step 'Verify changes are saved properly for ExpectedPricing' do
      v = @preference_resp[:body][:program_preferences].select { |k| k[:attribute] == 'ExpectedPricing' }
      expect(v[0][:min_value]).to eq(10.0)
      expect(v[0][:max_value]).to eq(50.0)
    end

    e.run_step 'Verify changes are saved properly for ProgramSize' do
      v = @preference_resp[:body][:program_preferences].select { |k| k[:attribute] == 'ProgramSize' }
      expect(v[0][:min_value]).to eq(10000000.0)
      expect(v[0][:max_value]).to eq(1000000000.0)
    end

    e.run_step 'Verify changes are saved properly for Tenure' do
      v = @preference_resp[:body][:program_preferences].select { |k| k[:attribute] == 'Tenure' }
      expect(v[0][:min_value]).to eq(20.0)
      expect(v[0][:max_value]).to eq(90.0)
    end

    e.run_step 'Verify changes are saved properly for Ebitda' do
      v = @preference_resp[:body][:program_preferences].select { |k| k[:attribute] == 'Ebitda' }
      expect(v[0][:min_value]).to eq(10000000.0)
      expect(v[0][:max_value]).to eq(20000000000.0)
    end

    e.run_step 'Verify changes are saved properly for ProgramType' do
      v = @preference_resp[:body][:program_preferences].select { |k| k[:attribute] == 'ProgramType' }
      expect(v[0][:program_values]).to eq(['Invoice Financing - Vendor'])
    end

    e.run_step 'Verify changes are saved properly for Revenue' do
      v = @preference_resp[:body][:program_preferences].select { |k| k[:attribute] == 'Revenue' }
      expect(v[0][:min_value]).to eq(10000000000.0)
      expect(v[0][:max_value]).to eq(20000000000.0)
    end

    e.run_step 'Verify changes are saved properly for ExposurePerChannelPartner' do
      v = @preference_resp[:body][:program_preferences].select { |k| k[:attribute] == 'ExposurePerChannelPartner' }
      expect(v[0][:min_value]).to eq(10000000.0)
      expect(v[0][:max_value]).to eq(1000000000.0)
    end
  end

  it 'Investor: Green Channel - Auto EOI', :auto_ei do |e|
    e.run_step 'Verify EOI match based on program preference for program - PO Financing dealer' do
      values = {
        program_type: { is_enabled: true, values: ['PO Financing - Dealer'] }
      }
      resp = set_program_preferences(values, @investor_actor)
      expect(resp[:code]).to eq(200), resp.to_s
      params = { 'filters[min_total_score]': 100, 'filters[max_total_score]': 100 }
      sleep @time
      resp = get_all_anchor_programs(@investor_actor, params)
      resp.each { |r| expect(r[:name]).to eq('Purchase Order Financing - Dealer') }
    end

    e.run_step 'Verify EOI match based on program preference for Program Size' do
      values = { program_size: { is_enabled: true, min: 902100000, max: 902100000 } }
      resp = set_program_preferences(values, @investor_actor)
      expect(resp[:code]).to eq(200), resp.to_s
      params = { 'filters[min_total_score]': 100, 'filters[max_total_score]': 100 }
      sleep @time
      resp = get_all_anchor_programs(@investor_actor, params)
      resp.each { |r| expect(r[:program_size]).to eq(902100000) }
    end

    e.run_step 'Verify EOI match based on program preference for Exposure per Channel Partner' do
      values = {
        exposure_per_channel_partner: { is_enabled: true, min: 12848000, max: 65142000 }
      }
      resp = set_program_preferences(values, @investor_actor)
      expect(resp[:code]).to eq(200), resp.to_s
      params = { 'filters[min_total_score]': 100, 'filters[max_total_score]': 100 }
      sleep @time
      resp = get_all_anchor_programs(@investor_actor, params)
      resp.each do |r|
        expect(r[:min_exposure]).to be >= (12848000)
        expect(r[:max_exposure]).to be <= (65142000)
      end
    end

    e.run_step 'Verify EOI match based on program preference for Expected Pricing' do
      values = { expected_pricing: { is_enabled: true, min: 10, max: 90 } }
      resp = set_program_preferences(values, @investor_actor)
      expect(resp[:code]).to eq(200), resp.to_s
      params = { 'filters[min_total_score]': 100, 'filters[max_total_score]': 100 }
      sleep @time
      resp = get_all_anchor_programs(@investor_actor, params)
      resp.each do |r|
        expect(r[:min_price_expectation].to_f).to be >= (10)
        expect(r[:max_price_expectation].to_f).to be <= (90)
      end
    end

    e.run_step 'Verify EOI match based on program preference for Tenure' do
      values = { tenure: { is_enabled: true, min: 30, max: 120 } }
      resp = set_program_preferences(values, @investor_actor)
      expect(resp[:code]).to eq(200), resp.to_s
      params = { 'filters[min_total_score]': 100, 'filters[max_total_score]': 100 }
      sleep @time
      a_resp = get_all_anchor_programs(@investor_actor, params)
      resp = fetch_anchor_detail(@investor_actor, a_resp.sample[:id])
      expect(resp[:body][:anchor_program][:max_tranche]).to be_between(30, 120)
    end

    e.run_step 'Verify EOI match based on program preference for EBITDA' do
      values = { ebitda: { is_enabled: true, min: -4, max: 400 } }
      resp = set_program_preferences(values, @investor_actor)
      expect(resp[:code]).to eq(200), resp.to_s
      params = { 'filters[min_total_score]': 100, 'filters[max_total_score]': 100 }
      sleep @time
      a_resp = get_all_anchor_programs(@investor_actor, params)
      resp = fetch_anchor_detail(@investor_actor, a_resp.sample[:id])
      expect(resp[:body][:credit_info][:ebitda]).to be_between(-4, 400)
    end

    e.run_step 'Verify EOI match based on program preference for Revenue' do
      values = { revenue: { is_enabled: true, min: -1000, max: 877300000 } }
      resp = set_program_preferences(values, @investor_actor)
      expect(resp[:code]).to eq(200), resp.to_s
      params = { 'filters[min_total_score]': 100, 'filters[max_total_score]': 100 }
      sleep @time
      a_resp = get_all_anchor_programs(@investor_actor, params)
      resp = fetch_anchor_detail(@investor_actor, a_resp.sample[:id])
      expect(resp[:body][:credit_info][:turnover]).to be_between(-1000, 877300000)
    end

    e.run_step 'Verify EOI match based on program preference for Rating' do
      values = { min_credit_rating: { is_enabled: true, values: ['AA+'] } }
      resp = set_program_preferences(values, @investor_actor)
      expect(resp[:code]).to eq(200), resp.to_s
      params = { 'filters[min_total_score]': 100, 'filters[max_total_score]': 100 }
      sleep @time
      a_resp = get_all_anchor_programs(@investor_actor, params)
      resp = fetch_anchor_detail(@investor_actor, a_resp.sample[:id])
      expect(['aa+', 'aaa-', 'aaa', 'aaa+']).to include(resp[:body][:credit_info][:rating])
    end

    e.run_step 'Verify EOI match score is working properly' do
      hash = { p_min: 1000000, p_max: 900000000, price_min: 5, price_max: 90, exp_min: 1000000, exp_max: 900000000 }
      values = {
        program_size: { is_enabled: true, min: hash[:p_min], max: hash[:p_max] },
        exposure_per_channel_partner: { is_enabled: true, min: hash[:exp_min], max: hash[:exp_max] },
        expected_pricing: { is_enabled: true, min: hash[:exp_min], max: hash[:exp_max] }
      }
      resp = set_program_preferences(values, @investor_actor)
      expect(resp[:code]).to eq(200), resp.to_s
      params = { 'filters[min_total_score]': 50, 'filters[max_total_score]': 80 }
      sleep @time
      score = @investor_page.compute_score(@investor_actor, params, hash)
      resp = get_all_anchor_programs(@investor_actor, params)
      program = resp.sample
      count = 0
      count += 1 unless program[:program_size] >= 1000000 && program[:program_size] <= 900000000
      count += 1 unless program[:min_price_expectation].to_f >= 5 && program[:max_price_expectation].to_f <= 90
      count += 1 unless program[:min_exposure].to_f >= 1000000 && program[:max_exposure].to_f <= 900000000
      score = (9 - count) / 9.to_f * 100
      expect(program[:total_score].to_f - score).to be < (0.01)
    end

    e.run_step 'Create & Publish a program' do
      @program_type = 'PO Financing - Dealer'
      @anchor_actor = 'mi_anchor'
      @create_values = {
        max_tranche: 200,
        program_size: 900_000_000,
        exposure: [0, 600_000_000],
        price_expectation: [66, 99],
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

    e.run_step 'Verify Auto EOI is working properly' do
      values = {
        tenure: { is_enabled: true, min: 200, max: 200 },
        program_size: { is_enabled: true, min: 900_000_000, max: 900_000_000 },
        exposure_per_channel_partner: { is_enabled: true, min: 0, max: 600_000_000 },
        expected_pricing: { is_enabled: true, min: 66, max: 99 },
        is_auto_ei: { is_enabled: true }
      }
      resp = set_program_preferences(values, @investor_actor)
      params = { 'filters[min_total_score]': 100, 'filters[max_total_score]': 100 }
      sleep @time
      a_resp = get_all_anchor_programs(@investor_actor, params)
      resp = fetch_anchor_detail(@investor_actor, @program_id)
      expect(resp[:body][:anchor_program][:interest_status]).to eq('pending'), "Auto EOI is not expressed for Program #{@program_id}, status is #{resp[:body][:anchor_program][:interest_status]}"
    end
  end
end
