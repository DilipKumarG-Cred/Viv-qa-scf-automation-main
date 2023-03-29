require './spec_helper'
describe 'Dynamic Discounting', :scf, :platform_fee, :dd do
  before(:each) do
    @driver = Tarspect::Browser.new($conf['browser']).invoke
    @tarspect_methods = Common::Methods.new(@driver)
    @common_pages = Pages::CommonMethods.new(@driver)
    @transactions_page = Pages::Trasactions.new(@driver)
    @programs_page = Pages::Programs.new(@driver)
    @anchor_name = $conf['anchor_name']
    @anchor_gstn = $conf['users']['anchor']['gstn']
    @vendor_gstn = $conf['users']['dd_vendor']['gstn']
    @erb_file = File.read("#{Dir.pwd}/test-data/erb/testbed_data.erb")
    @due_date = Date.today + 30
    @desired_date = Date.today + 10
    @tds = 8
    @invoice_file = "#{Dir.pwd}/test-data/attachments/anchor_invoice.pdf"
    @actor = 'anchor'
  end

  after(:each) do |e| # Captures screenshot of the current page when failure happens
    snap_screenshot(e)
    quit_browser
  end

  it 'Dynamic discounting :: Platform fee setup' do |e|
    e.run_step 'Login as Platform' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['product']['email'], $conf['users']['product']['password'])).to be true
    end
    e.run_step 'Verify Platform Fee can be added and updated' do
      @common_pages.click_menu(MENU_ANCHOR_LIST)
      @common_pages.navigate_to_anchor(@anchor_name)
      @common_pages.select_program('Dynamic Discounting', 'Vendor')
      @tarspect_methods.click_button('Platform Fee')
      fee_value = 5
      @programs_page.add_platform_fee(fee_value)
      fee_value = 6
      platform_fee = @programs_page.edit_platform_fee(fee_value)
      expect(platform_fee).to eq fee_value
    end
  end

  it 'Dynamic discounting :: Additional Data display' do |e|
    e.run_step 'Set Platform fee' do
      resp = add_platform_fee(5, 'anchor', 'product')
      expect(resp[:code]).to eq(200)
      @fee = resp[:body][:anchor_program][:fee_percentage]
    end

    e.run_step 'Login as Anchor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['anchor']['email'], $conf['users']['anchor']['password'])).to be true
    end

    e.run_step 'Create a DD transaction' do
      @discount = 10
      @tds = 8
      @testdata = JSON.parse(ERB.new(@erb_file).result(binding))['DD Invoice Details']
      @invoice_value = @testdata['Invoice Value'] < @testdata['GRN'] ? @testdata['Invoice Value'] : @testdata['GRN']
      resp = create_transaction('anchor', @testdata, @invoice_file, 5)
      expect(resp[:code]).to eq 200
      @transaction_id = resp[:body][:id]
    end

    e.run_step 'Verify additional data is displayed' do
      @common_pages.click_menu(MENU_PROGRAMS)
      @programs_page.choose_program_listing_action('Dynamic Discounting')
      @tarspect_methods.click_button('Add cost of funds')
      costoffund = @programs_page.get_cost_of_funds
      hash_input = {
        'discount' => @discount,
        'invoice_value' => @invoice_value,
        'cost_of_fund' => costoffund,
        'fee' => @fee,
        'due_date' => @due_date,
        'desired_date' => @desired_date,
        'tds' => @tds
      }
      expected_hash = calculate_additional_data_dd(hash_input)
      @common_pages.click_menu(MENU_DYNAMIC_DISCOUNTING)
      @common_pages.click_transactions_tab(DRAFT)
      expect(@common_pages.transaction_listed?(@transaction_id)).to eq(true), "Transaction #{@transaction_id} is not listed"
      hash = @transactions_page.hover_dd_transaction(@transaction_id)
      expect(hash).to eq expected_hash
    end
  end

  it 'Dynamic discounting :: Rules [Addition, Updation and Deletion]' do |e|
    e.run_step 'Login as Anchor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['anchor']['email'], $conf['users']['anchor']['password'])).to be true
    end

    e.run_step 'Delete existing rule' do
      resp = delete_rule(@actor)
      expect(resp[:code]).to eq(200)
    end
    e.run_step 'Verify rules can be added' do
      @common_pages.click_menu(MENU_PROGRAMS)
      @programs_page.choose_program_listing_action('Dynamic Discounting')
      @tarspect_methods.click_button('Rules')
      @programs_page.add_dd_rule
      @rules = [
        {
          'sub_rule' => [
            { 'name' => 'Discount', 'condition' => 'Equal To', 'value' => 10 },
            { 'operator' => 'or', 'name' => 'Annualized Return', 'condition' => 'Lesser Than or Equal To', 'value' => 1000.50 },
            { 'operator' => 'and', 'name' => 'Annualized Gain', 'condition' => 'Lesser Than or Equal To', 'value' => 1000.50 }
          ]
        }
      ]
      resp = @programs_page.fillout_ruleset(@rules)
      expect(resp).to eq true
      @tarspect_methods.click_button('Submit')
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['Rules']['Created']
    end

    e.run_step 'Verify rules can be edited' do
      @programs_page.edit_or_remove_all_rules('Edit')
      @rules = [
        {
          'sub_rule' => [
            { 'name' => 'Discount', 'condition' => 'Not Equal To', 'value' => 5 },
            { 'name' => 'Annualized Gain', 'condition' => 'Greater Than or Equal To', 'value' => 500 },
            { 'name' => 'Annualized Return', 'condition' => 'Greater Than or Equal To', 'value' => 50000 }
          ]
        },
        {
          'operator' => 'or',
          'sub_rule' => [
            { 'name' => 'Discount', 'condition' => 'Not Equal To', 'value' => 10 }
          ]
        }
      ]
      @programs_page.fillout_ruleset(@rules)
      @tarspect_methods.click_button('Submit')
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['Rules']['Updated']
    end

    e.run_step 'Verify rules can be deleted' do
      @programs_page.edit_or_remove_all_rules('Remove')
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq $notifications['Rules']['Deleted']
    end

    e.run_step 'Verify Discount cannot be greater than 100' do
      @programs_page.add_dd_rule
      @rules = [
        {
          'sub_rule' => [
            { 'name' => 'Discount', 'condition' => 'Not Equal To', 'value' => 101 }
          ]
        }
      ]
      @programs_page.fillout_ruleset(@rules)
      @tarspect_methods.click_button('Submit')
      resp = @tarspect_methods.DYNAMIC_LOCATOR('error-text', '@class')
      expect(resp.text).to eq('Only 0-100 accepted')
      @tarspect_methods.click_button('Dismiss')
    end

    e.run_step 'Verify Annualized Gain and Return can be any value' do
      @programs_page.add_dd_rule
      @rules = [
        {
          'sub_rule' => [
            { 'name' => 'Annualized Return', 'condition' => 'Not Equal To', 'value' => 10000000000 },
            { 'name' => 'Annualized Gain', 'condition' => 'Not Equal To', 'value' => 1000000 }
          ]
        }
      ]
      resp = @programs_page.fillout_ruleset(@rules)
      expect(resp).to eq(true)
      @tarspect_methods.click_button('Dismiss')
    end
  end

  it 'Dynamic Discounting :: Auto Approval based on Single rule' do |e|
    e.run_step 'Set Rules with Discount Eq to 10' do
      resp = delete_rule(@actor)
      expect(resp[:code]).to eq(200)
      @rules = [
        {
          'sub_rules' => [
            { 'name' => 'discount', 'condition' => 'equal_to', 'value' => 10 }
          ]
        }
      ]
      resp = create_rule(@actor, @rules)
      expect(resp[:code]).to eq(200)
    end

    e.run_step 'Login as Anchor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['anchor']['email'], $conf['users']['anchor']['password'])).to be true
    end

    e.run_step 'Create two DD transactions [based on and against] the rule' do
      @discount = 10
      @tds = 8
      @testdata_1 = JSON.parse(ERB.new(@erb_file).result(binding))['DD Invoice Details']
      @discount = 5
      @testdata_2 = JSON.parse(ERB.new(@erb_file).result(binding))['DD Invoice Details']
      @common_pages.click_menu(MENU_DYNAMIC_DISCOUNTING)
      resp_1 = create_transaction('dd_vendor', @testdata_1, @invoice_file, 5)
      expect(resp_1[:code]).to eq(200), resp_1.to_s
      @transaction_id_1 = resp_1[:body][:invoice_id]
      exp = {
        'discount' => resp_1[:body][:discount],
        'annualized_gain_percentage' => resp_1[:body][:annualized_gain_percentage],
        'annualized_return_percentage' => resp_1[:body][:annualized_return_percentage]
      }
      @common_pages.click_transactions_tab(SETTLED)
      expect(@common_pages.transaction_listed?(@transaction_id_1)).to eq(true), "#{exp} , #{@rules}"
      resp_2 = create_transaction('dd_vendor', @testdata_2, @invoice_file, 5)
      expect(resp_2[:code]).to eq 200
      @transaction_id_2 = resp_2[:body][:id]
      @common_pages.click_transactions_tab(INVOICES_TO_APPROVE)
      expect(@common_pages.transaction_listed?(@transaction_id_2)).to eq true
    end
  end

  it 'Dynamic Discounting :: Auto Approval based on Multiple combinations rule 1' do |e|
    e.run_step 'Set Rules' do
      resp = delete_rule(@actor)
      expect(resp[:code]).to eq(200)
      platform_fee = get_platform_fee(@actor)
      costoffund = get_cost_of_funds(@actor)
      @discount = 11
      @testdata_1 = JSON.parse(ERB.new(@erb_file).result(binding))['DD Invoice Details']
      hash_input = {
        'discount' => @discount,
        'invoice_value' => @testdata_1['Invoice Value'],
        'cost_of_fund' => costoffund,
        'fee' => platform_fee,
        'due_date' => @due_date,
        'desired_date' => @desired_date,
        'tds' => @testdata_1['TDS']
      }
      expected_hash = calculate_additional_data_dd(hash_input)
      @rules = [
        {
          'sub_rules' => [
            { 'operator' => 'and', 'name' => 'discount', 'condition' => 'equal_to', 'value' => 10 },
            { 'operator' => 'or', 'name' => 'annualized_gain', 'condition' => 'greater_than_equal_to', 'value' => expected_hash['ANNUALIZED GAIN'].to_f },
            { 'operator' => 'or', 'name' => 'annualized_return', 'condition' => 'greater_than_equal_to', 'value' => expected_hash['ANNUALIZED RETURN'].to_f }
          ]
        }
      ]
      resp = create_rule(@actor, @rules)
      expect(resp[:code]).to eq(200)
    end

    e.run_step 'Create 2 transactions [based on and against the rules]' do
      @discount = 5
      @testdata_2 = JSON.parse(ERB.new(@erb_file).result(binding))['DD Invoice Details']
      resp_1 = create_transaction('dd_vendor', @testdata_1, @invoice_file, 5)
      expect(resp_1[:code]).to eq 200
      @transaction_id_1 = resp_1[:body][:id]
      exp = {
        'discount' => resp_1[:body][:discount],
        'annualized_gain_percentage' => resp_1[:body][:annualized_gain_percentage],
        'annualized_return_percentage' => resp_1[:body][:annualized_return_percentage]
      }
      expect(resp_1[:body][:display_status]).to eq('Settled'), [@rules, exp].to_s
      resp_2 = create_transaction('dd_vendor', @testdata_2, @invoice_file, 5)
      expect(resp_2[:code]).to eq 200
      @transaction_id_2 = resp_2[:body][:id]
      expect(resp_2[:body][:display_status]).to eq('Draft'), [@rules, exp].to_s
    end
  end

  it 'Dynamic Discounting :: Auto Approval based on Multiple combinations rule 2' do |e|
    e.run_step 'Set Rules' do
      resp = delete_rule(@actor)
      expect(resp[:code]).to eq(200)
      platform_fee = get_platform_fee(@actor)
      costoffund = get_cost_of_funds(@actor)
      @discount = 10
      @testdata_1 = JSON.parse(ERB.new(@erb_file).result(binding))['DD Invoice Details']
      hash_input = {
        'discount' => @testdata_1['Discount'],
        'invoice_value' => @testdata_1['Invoice Value'],
        'cost_of_fund' => costoffund,
        'fee' => platform_fee,
        'due_date' => @due_date,
        'desired_date' => @desired_date,
        'tds' => @testdata_1['TDS']
      }
      expected_hash = calculate_additional_data_dd(hash_input)
      @rules = [
        {
          'sub_rules' => [
            { 'operator' => 'and', 'name' => 'discount', 'condition' => 'equal_to', 'value' => 10 },
            { 'operator' => 'and', 'name' => 'annualized_gain', 'condition' => 'equal_to', 'value' => expected_hash['ANNUALIZED GAIN'].to_f },
            { 'operator' => 'and', 'name' => 'annualized_return', 'condition' => 'equal_to', 'value' => expected_hash['ANNUALIZED RETURN'].to_f }
          ]
        }
      ]
      resp = create_rule(@actor, @rules)
      expect(resp[:code]).to eq(200)
    end

    e.run_step 'Create 2 transactions [based on and against the rules]' do
      @discount = 5
      @testdata_2 = JSON.parse(ERB.new(@erb_file).result(binding))['DD Invoice Details']
      resp_1 = create_transaction('dd_vendor', @testdata_1, @invoice_file, 5)
      expect(resp_1[:code]).to eq 200
      @transaction_id_1 = resp_1[:body][:id]
      exp = {
        'discount' => resp_1[:body][:discount],
        'annualized_gain_percentage' => resp_1[:body][:annualized_gain_percentage],
        'annualized_return_percentage' => resp_1[:body][:annualized_return_percentage]
      }
      expect(resp_1[:body][:display_status]).to eq('Settled'), [@rules, exp].to_s
      resp_2 = create_transaction('dd_vendor', @testdata_2, @invoice_file, 5)
      expect(resp_2[:code]).to eq 200
      @transaction_id_2 = resp_2[:body][:id]
      expect(resp_2[:body][:display_status]).to eq('Draft'), [@rules, exp].to_s
    end
  end

  it 'Dynamic Discounting :: Auto Approval based on Multiple combinations rule 3' do |e|
    e.run_step 'Set Rules' do
      resp = delete_rule(@actor)
      expect(resp[:code]).to eq(200)
      platform_fee = get_platform_fee(@actor)
      costoffund = get_cost_of_funds(@actor)
      @discount = 10
      @testdata_1 = JSON.parse(ERB.new(@erb_file).result(binding))['DD Invoice Details']
      hash_input = {
        'discount' => @testdata_1['Discount'],
        'invoice_value' => @testdata_1['Invoice Value'],
        'cost_of_fund' => costoffund,
        'fee' => platform_fee,
        'due_date' => @due_date,
        'desired_date' => @desired_date,
        'tds' => @testdata_1['TDS']
      }
      expected_hash = calculate_additional_data_dd(hash_input)
      @rules = [
        {
          'sub_rules' => [
            { 'operator' => 'and', 'name' => 'discount', 'condition' => 'equal_to', 'value' => 10 }
          ]
        },
        {
          'operator' => 'and',
          'sub_rules' => [
            { 'operator' => 'or', 'name' => 'annualized_gain', 'condition' => 'equal_to', 'value' => expected_hash['ANNUALIZED GAIN'].to_f },
            { 'operator' => 'or', 'name' => 'annualized_return', 'condition' => 'equal_to', 'value' => expected_hash['ANNUALIZED RETURN'].to_f }
          ]
        }
      ]
      resp = create_rule(@actor, @rules)
      expect(resp[:code]).to eq(200)
    end

    e.run_step 'Create 3 transactions [based on and against the rules]' do
      @testdata_2 = JSON.parse(ERB.new(@erb_file).result(binding))['DD Invoice Details']
      resp_1 = create_transaction('dd_vendor', @testdata_1, @invoice_file, 5)
      expect(resp_1[:code]).to eq 200
      @transaction_id_1 = resp_1[:body][:id]
      exp = {
        'discount' => resp_1[:body][:discount],
        'annualized_gain_percentage' => resp_1[:body][:annualized_gain_percentage],
        'annualized_return_percentage' => resp_1[:body][:annualized_return_percentage]
      }
      expect(resp_1[:body][:display_status]).to eq('Settled'), [@rules, exp].to_s
      fee = 8
      resp = add_platform_fee(fee, 'anchor', 'product')
      expect(resp[:body][:anchor_program][:fee_percentage]).to eq fee.to_f
      resp_2 = create_transaction('dd_vendor', @testdata_2, @invoice_file, 5)
      expect(resp_2[:code]).to eq 200
      @transaction_id_2 = resp_2[:body][:id]
      exp = {
        'discount' => resp_2[:body][:discount],
        'annualized_gain_percentage' => resp_2[:body][:annualized_gain_percentage],
        'annualized_return_percentage' => resp_2[:body][:annualized_return_percentage]
      }
      expect(resp_2[:body][:display_status]).to eq('Settled'), [@rules, exp].to_s
      @discount = 12
      @testdata_3 = JSON.parse(ERB.new(@erb_file).result(binding))['DD Invoice Details']
      resp_3 = create_transaction('dd_vendor', @testdata_3, @invoice_file, 5)
      exp = {
        'discount' => resp_3[:body][:discount],
        'annualized_gain_percentage' => resp_3[:body][:annualized_gain_percentage],
        'annualized_return_percentage' => resp_3[:body][:annualized_return_percentage]
      }
      expect(resp_3[:body][:display_status]).to eq('Draft'), [@rules, exp].to_s
    end
  end
end
