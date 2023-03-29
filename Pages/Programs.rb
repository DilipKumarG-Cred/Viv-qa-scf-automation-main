module Pages
  class Programs
    def initialize(driver)
      @driver = driver
      @tarspect_methods = Common::Methods.new(@driver)
      @common_pages = Pages::CommonMethods.new(@driver)
      @disbursement_page = Pages::Disbursement.new(@driver)
      @wait = Selenium::WebDriver::Wait.new(timeout: MIN_LOADER_TIME)

      @transaction_summary = Tarspect::Locator.new(:xpath, '//section')
      @continue_with_selection = Tarspect::Locator.new(:xpath, "//button[contains(text(),'Continue with selection')]")
      @exp_value = Tarspect::Locator.new(:xpath, "//*[text()='Exposure per Vendor/Dealer']//parent::div//*[contains(@class,'text-value')]")
      @exp_value_input = Tarspect::Locator.new(:xpath, "//*[text()='Exposure per Vendor/Dealer']//parent::div//input")
      @exp_pricing = Tarspect::Locator.new(:xpath, "//*[text()='Expected Pricing']//parent::div//*[contains(@class,'text-value')]")
      @exp_pricing_input = Tarspect::Locator.new(:xpath, "//*[text()='Expected Pricing']//parent::div//input")
      @file_input = Tarspect::Locator.new(:xpath, "//input[@type='file']")
      @submit_btn = Tarspect::Locator.new(:xpath, "//button[text()='Submit' and not(contains(@class, 'disabled'))]")
      @delete_icon = Tarspect::Locator.new(:xpath, "//*[contains(@class,'nucleoinvest-delete')]")
      @i_ll_do_later = Tarspect::Locator.new(:xpath, "//*[contains(text(),'ll do it later')]")
      @interested_investor_list = Tarspect::Locator.new(:xpath, "//ul[@class='interest-list']//li")
      @investor_accept = Tarspect::Locator.new(:xpath, "//*[contains(@class,'vc-grid')]//button[text()='Accept']")
      @investor_decline = Tarspect::Locator.new(:xpath, "//*[contains(@class,'vc-grid')]//button[text()='Decline']")
      @new_rule = Tarspect::Locator.new(:xpath, "//div[@class='rule-item']/parent::div")
      @dd_program = Tarspect::Locator.new(:xpath, "//p[contains(text(),'Dynamic Discounting')]")

      # Investor view
      @explore_list = Tarspect::Locator.new(:xpath, "//a[contains(@href,'/explore-programs/all')]")
      @info_box = Tarspect::Locator.new(:xpath, "//div[@class='info ']")
      @success_banner = Tarspect::Locator.new(:xpath, "//*[contains(text(),'You expressed interest on this program.')]")
      @my_interests = Tarspect::Locator.new(:xpath, "//*[contains(text(),'My Interests')]")

      # Platform View
      @platform_fee = Tarspect::Locator.new(:xpath, "//p[text()='Platform Fee']/../div/input")
      @explore_pgm_list = Tarspect::Locator.new(:xpath, "//a[contains(@href,'/commercial-details/program')]")
    end

    def PROGRAM_LIST(where)
      where = 'investor_overview' if where == 'investor_explore'
      href_hash = {
        'investor_pending' => '/explore-programs/interests/by-status/pending',
        'product_explore' => '/commercial-details/program',
        'investor_approved' => '/explore-programs/interests/by-status/approved',
        'investor_declined' => '/explore-programs/interests/by-status/declined',
        'investor_overview' => '/explore-programs/all/programs'
      }
      Tarspect::Locator.new(:xpath, "//a[contains(@href,'#{href_hash[where]}')]")
    end

    def get_scf_anchor_details
      detail = Tarspect::Locator.new(:xpath, "//h6[text()='About the Anchor']/following-sibling::div")
      raise 'Anchor details not present' unless detail.is_present?

      details = detail.find_children(:xpath, "//div[contains(@class,'field')]")
      scf_hash = {}
      details.each do |element|
        split_value = element.text.split("\n")
        scf_hash[split_value[0].downcase] = split_value[1].delete(' ').upcase.gsub('LAC', 'L')
      end
      scf_hash
    end

    def move_to_credit_page
      Tarspect::Locator.new(:xpath, "//a[@href]/button[text()='View More Details']").click
      @tarspect_methods.switch_to_last_tab
      @tarspect_methods.wait_for_circular_to_disappear
      @tarspect_methods.wait_for_loader_to_disappear
    end

    def get_credit_anchor_details
      @tarspect_methods.wait_for_circular_to_disappear(MAX_LOADER_TIME)
      @tarspect_methods.wait_for_loader_to_disappear(MAX_LOADER_TIME)
      industry = Tarspect::Locator.new(:xpath, "//div[@id='overview']//div[contains(@class,'ca-chip')][3]/span")
      hash = {}
      hash['industry'] = industry.text.delete(' ').upcase
      anchor_detail = Tarspect::Locator.new(:xpath, "//h6[text()='Summary']/../div/div/div[@direction='row']")
      @wait.until { anchor_detail.text.split("\n")[0] != '' }
      anchor_details = anchor_detail.text.split("\n")
      anchor_details.each_slice(2) do |c_detail|
        key = case c_detail[1].downcase
              when 'revenue'
                'turnover'
              when 'borrowings'
                'borrowing'
              else
                c_detail[1].downcase
              end
        hash[key] = c_detail[0].delete(' ').upcase
      end
      raise 'Could not fetch all details' unless hash.count == 6

      hash
    end

    def add_program_listing(type, values = nil)
      @tarspect_methods.click_button('Add Program')
      @tarspect_methods.wait_for_circular_to_disappear
      Tarspect::Locator.new(:xpath, "//*[text()='#{type}']//ancestor::div[contains(@class,'card')]//label").click
      @continue_with_selection.click
      fill_program_details(type, values) unless values.nil?
    end

    def fetch_program_flow_map
      heads = Tarspect::Locator.new(:xpath, "//p[contains(@class, 'flow-map-head')]")
      sub_texts = Tarspect::Locator.new(:xpath, "//p[contains(@class, 'flow-map-subtext')]")
      [heads.get_texts, sub_texts.get_texts]
    end

    def fill_program_details(type, values)
      Tarspect::Locator.new(:xpath, "//*[text()='#{type}']").click
      d = values.dup
      d.delete('Exposure Value')
      d.delete('Expected Pricing')
      @tarspect_methods.fill_form(d, 1, 2)
      slider_values = ['Exposure per Vendor/Dealer', 'Expected Pricing']
      slider_values.each do |slider_value|
        elements = @common_pages.PROGRAM_VALUES(slider_value)
        input = slider_value.include?('Exposure') ? 'Exposure Value' : 'Expected Pricing'
        @common_pages.set_slider_values(elements[0].fetch_elements[1].element, elements[1], values[input][1])
        @common_pages.set_slider_values(elements[0].fetch_elements[0].element, elements[1], values[input][0])
      end
      @tarspect_methods.wait_for_circular_to_disappear
      @tarspect_methods.BUTTON('Done').scroll_to_element
      sleep 0.2
      @tarspect_methods.click_button('Done')
    end

    def apply_slider_filter_in_programs(values)
      @common_pages.clear_filter.click unless @common_pages.clear_filter.element.nil?
      @tarspect_methods.wait_for_loader_to_disappear
      @common_pages.filter.click
      @common_pages.configure_slider_in_filter(values)
      @tarspect_methods.click_button('Apply')
    end

    def select_multiple_programs(programs)
      @tarspect_methods.click_button('Add Program')
      sleep 0.5
      @tarspect_methods.wait_for_loader_to_disappear
      [programs].flatten!.each do |type|
        element = Tarspect::Locator.new(:xpath, "//*[text()='#{type}']//ancestor::div[contains(@class,'card')]//label")
        @wait.until { element.is_displayed? }
        element.click
        sleep 0.5
      end
      @continue_with_selection.click
    end

    def add_values_for_multiple_programs(program_values)
      program_values.each do |type, values|
        fill_program_details(type, values)
        @tarspect_methods.wait_for_circular_to_disappear
      end
    end

    def add_program_available?
      @tarspect_methods.BUTTON('Add Program').is_displayed?(2)
    end

    def draft_state?
      @tarspect_methods.BUTTON('Publish').is_displayed?(2) && @delete_icon.is_displayed?(2)
    end

    def get_program_details_in_info_page
      overall_results = []
      Tarspect::Locator.new(:xpath, "//p[contains(@class,'highlight')]").get_texts.each_with_index do |type, index|
        result = {}
        result['Program type'] = type
        result['Program size'] = Tarspect::Locator.new(:xpath, "//p[contains(text(),'Program Size')]//preceding-sibling::h4").get_texts[index]
        result['Pricing'] = Tarspect::Locator.new(:xpath, "//p[contains(text(),'PRICING EXPECTATION')]//preceding-sibling::p").get_texts[index]
        result['Tenor'] = Tarspect::Locator.new(:xpath, "//p[contains(text(),'Tenor')]//preceding-sibling::p[1]").get_texts[index]
        overall_results << result
      end
      overall_results.count == 1 ? overall_results[0] : overall_results
    end

    def click_publish_in_the_modal
      @tarspect_methods.BUTTON('Publish').fetch_elements[-1].click
      @tarspect_methods.wait_for_circular_to_disappear
    end

    def delete_program_from_info_page
      @delete_icon.click
      sleep 2
      @tarspect_methods.click_button('Continue')
    end

    def click_i_ll_do_later
      @i_ll_do_later.scroll_to_element
      @i_ll_do_later.click
      @tarspect_methods.wait_for_circular_to_disappear
    end

    def verify_details_in_programs_page(program, values)
      row_element = Tarspect::Locator.new(:xpath, "//p[contains(text(),'#{program}')]//ancestor::div[contains(@direction,'row')]")
      @wait.until { row_element.text.delete("\n").delete('‌‌‌‌‌‌‌‌').strip != '' }
      errors = []
      values.each do |x|
        flag = row_element.text.include? x
        errors << "Value not found :: #{x} in #{row_element.text}" unless flag
      end
      errors.empty? ? true : errors
    end

    def choose_program_listing_action(program, action = nil)
      @tarspect_methods.wait_for_loader_to_disappear
      row_element = Tarspect::Locator.new(:xpath, "//p[contains(text(),'#{program}')]")
      row_element.mouse_hover
      if action.nil?
        row_element.click
        return
      end
      action_element = Tarspect::Locator.new(:xpath, "//p[contains(text(),'#{program}')]//ancestor::div[contains(@direction,'row')]//p[contains(text(),'#{action}')]//preceding-sibling::i")
      action_element.mouse_hover
      action_element.click
      @tarspect_methods.wait_for_circular_to_disappear
    end

    def publish_success?
      Tarspect::Locator.new(:xpath, "//*[contains(text(),'Your program has published successfully!')]").is_displayed?(5)
    end

    def publish_success_for_multiple_program?(count)
      Tarspect::Locator.new(:xpath, "//*[contains(text(),'Your programs (#{count}) are published successfully!')]").is_displayed?(5)
    end

    def click_interested_investors
      Tarspect::Locator.new(:xpath, "//*[contains(text(),'Interested Investors')]").click
      @tarspect_methods.wait_for_circular_to_disappear
      @tarspect_methods.wait_for_loader_to_disappear(MAX_LOADER_TIME)
    end

    def verify_interested_investor_available?(investor_name, tab = nil)
      unless tab.nil?
        tab_value = tab == 'revoked' ? 'Revoked' : tab.downcase
        @tarspect_methods.click_button(tab_value)
        @tarspect_methods.wait_for_loader_to_disappear
      end
      @interested_investor_list.get_texts.each do |x|
        return true if x.include? investor_name
      end
      false
    end

    def choose_investor_action(investor_name, action)
      @tarspect_methods.click_button('all')
      @tarspect_methods.wait_for_circular_to_disappear
      @interested_investor_list.fetch_elements.each do |x|
        next unless x.text.include? investor_name

        x.mouse_hover
        @tarspect_methods.click_button(action)
        @tarspect_methods.wait_for_loader_to_disappear
        case action
        when 'Accept'
          @investor_accept.click
        when 'Reject'
          @investor_decline.click
        end
        break
      end
      @tarspect_methods.wait_for_circular_to_disappear
    end

    # Investor explore program page
    def investor_choose_program(values)
      explore_list = PROGRAM_LIST(values[:where])
      explore_list.wait_for_element

      loop do
        return true if verify_program_present(explore_list, values)
        return false unless @tarspect_methods.DYNAMIC_LOCATOR('Load more').is_displayed?

        scroll_page('down')
        5.times { $driver.action.send_keys(:up).perform }
        50.times { $driver.action.send_keys(:down).perform }
        @tarspect_methods.wait_for_loader_to_disappear(MAX_LOADER_TIME)
      end
      @tarspect_methods.wait_for_circular_to_disappear
      false
    end

    def get_all_program_lists
      results = []
      scroll_page('down')
      5.times { $driver.action.send_keys(:up).perform }
      50.times { $driver.action.send_keys(:down).perform }
      @tarspect_methods.wait_for_loader_to_disappear(MAX_LOADER_TIME)
      tiles = Tarspect::Locator.new(:xpath, "//*[contains(@href, 'programs')]//h6")
      results << tiles.get_texts
      results.flatten!.uniq!
      results
    end

    def verify_program_present(explore_list, values)
      @tarspect_methods.wait_for_loader_to_disappear
      explore_list.fetch_elements.each do |x|
        next unless x.text.include?(values[:type]) && x.text.include?(values[:anchor])

        x.click unless values[:validate_only]
        return true
      end
      @tarspect_methods.wait_for_circular_to_disappear
      @tarspect_methods.wait_for_loader_to_disappear
      false
    end

    def validate_modal_values(label)
      Tarspect::Locator.new(:xpath, "//*[contains(@class,'detail-content')]//p[text()='#{label}']//preceding-sibling::p").text
    end

    def pending_review_available?(anchor_name)
      @info_box.text.include?('Pending Review') &&
        @info_box.text.include?("You expressed interest on #{anchor_name}") &&
        @info_box.text.include?(Date.today.strftime('%d %b, %Y'))
    end

    def success_banner_available?
      @success_banner.is_displayed?(5)
    end

    def get_all_program_listings(state)
      results = []
      tiles = Tarspect::Locator.new(:xpath, "//*[contains(text(),'#{state.downcase}')]//..//following-sibling::div//a")
      return [] unless tiles.is_displayed?(5)

      @wait.until { tiles.is_displayed?(5) && (tiles.text.delete("\n").delete('‌‌‌‌‌‌‌‌').strip != '') }
      @next_arrow = Tarspect::Locator.new(:xpath, "//*[contains(text(),'#{state.downcase}')]//..//following-sibling::div//i[@class='nucleoinvest-small-right']")
      results << tiles.get_texts
      while @next_arrow.is_displayed?(2)
        @next_arrow.click
        results << tiles.get_texts
        sleep 1
      end
      results << tiles.get_texts
      results.flatten!.uniq!
      results.reject! { |x| x == '' || x.split("\n").length < 10 }
      results
    end

    def click_show_all_listings(state)
      Tarspect::Locator.new(:xpath, "//*[contains(text(),'#{state.downcase}')]//..//*[text()='Show All']").click
      @tarspect_methods.wait_for_circular_to_disappear
    end

    def verify_program_state(type, anchor, state)
      refer_hash = {
        'pending' => 'investor_pending',
        'declined' => 'investor_declined'
      }
      values = {
        header: state,
        where: refer_hash[state],
        anchor: anchor,
        validate_only: true,
        type: type
      }
      show_all = Tarspect::Locator.new(:xpath, "//*[contains(text(), '#{state}')]/following-sibling::a/*[text()='Show All']")
      if show_all.element.nil?
        available_programs = get_all_program_listings(state)
        available_programs.any? { |x| x.include?(type) && x.include?(anchor) }
      else
        show_all.click
        investor_choose_program(values)
      end
    end

    def fillout_ruleset(rules = [])
      error = Tarspect::Locator.new(:xpath, "//span[@class='error-text']")
      errors = []
      begin
        rules.each_with_index do |rule, i|
          @new_rule.element.find_element(:xpath, "./button[text()='+ Add New rule']").click if i.positive?
          unless rule['operator'].nil?
            Tarspect::Locator.new(:xpath, "//div[contains(@class,'rule-item-wrapper')]/div[contains(@class,'logical')]//div[contains(@class,'control')]").click
            Tarspect::Locator.new(:xpath, "//*[text()='#{rule['operator'].upcase}' and contains(@id, 'option')]").click
          end
          rule_wrap = Tarspect::Locator.new(:xpath, "//div[contains(@class,'rule-sub-item-wrapper')]").fetch_elements[i]
          rule['sub_rule'].each_with_index do |expression, j|
            sub_rules = rule_wrap.find_children(:xpath, "div[contains(@class,'rule-sub-item')]")
            unless rule['sub_rule'].size == sub_rules.length
              @tarspect_methods.click_button('+ Add New rule') if j.positive?
            end
            exp = rule_wrap.find_children(:xpath, "div[contains(@class,'rule-sub-item')]")[j]
            unless expression['operator'].nil?
              logical = exp.find_children(:xpath, "//div[@class='logical-column']//div[contains(@class,'control')]")
              logical[0].click
              Tarspect::Locator.new(:xpath, "//*[text()='#{expression['operator'].upcase}' and contains(@id, 'option')]").click
            end
            elems = exp.find_children(:xpath, "*//div[@class='others-column']/*")
            elems[0].click
            Tarspect::Locator.new(:xpath, "//*[text()='#{expression['name']}' and contains(@id, 'option')]").click
            sleep 1
            elems[1].click
            Tarspect::Locator.new(:xpath, "//*[text()='#{expression['condition']}' and contains(@id, 'option')]").click
            sleep 1
            inputBox = elems[2].find_children(:xpath, '*//input').first
            inputBox.clear_by_backspace
            inputBox.fill_and_press(expression['value'], :tab) unless expression['value'].nil?
            errors << error.text unless error.element.nil?
          end
        end
      rescue => e
        p e
        errors << error.text unless error.element.nil?
      end
      errors.empty? ? true : errors
    end

    def edit_or_remove_all_rules(action)
      @tarspect_methods.click_button(action) if click_on_dd_rules_options
    end

    def add_dd_rule
      return unless @tarspect_methods.BUTTON('Add Rule').is_displayed?(10)

      @tarspect_methods.click_button('Add Rule')
      Tarspect::Locator.new(:xpath, "//p[text()='Where']").wait_for_element
    end

    def click_on_dd_rules_options
      threeDots = Tarspect::Locator.new(:xpath, "//i[contains(@class,'nucleoinvest-menu')]")
      if threeDots.is_displayed?(10)
        threeDots.click
        sleep 1
        return true
      end
      false
    end

    def add_platform_fee(fee_value)
      sleep 1
      @dd_program.wait_for_element
      @wait.until { @tarspect_methods.DYNAMIC_TAG(:xpath, '//input').is_displayed? }
      if @tarspect_methods.BUTTON('Add Platform Fee').is_displayed?(3)
        @tarspect_methods.click_button('Add Platform Fee')
        sleep 2
        @platform_fee.fill(fee_value)
        @tarspect_methods.click_button('Save')
      end
      @wait.until { @platform_fee.element.enabled? == false }
    end

    def edit_platform_fee(fee_value)
      @tarspect_methods.click_button('Edit')
      @wait.until { @platform_fee.element.enabled? == true }
      @platform_fee.clear_by_backspace
      @platform_fee.fill(fee_value)
      @tarspect_methods.click_button('Save')
      @wait.until { @platform_fee.element.enabled? == false }
      @platform_fee.get_attribute('value').to_i
    end

    def get_cost_of_funds
      sleep 1
      @dd_program.wait_for_element
      @wait.until { @tarspect_methods.DYNAMIC_TAG(:xpath, '//input').is_displayed? }
      costoffund = Tarspect::Locator.new(:xpath, "//p[text()='Cost Of Fund']/../div/input")
      costoffund.get_attribute('value').to_i
    end

    def verify_multiple_values_can_be_chosen
      @common_pages.filter.click
      @tarspect_methods.wait_for_circular_to_disappear
      @tarspect_methods.wait_for_loader_to_disappear(MAX_LOADER_TIME)
      anchor_list = Tarspect::Locator.new(:xpath, "//*[text()='Anchor Rating']/ancestor::div[1]//*[text()='Select from the list']")
      anchor_list.click
      anchor_ratings = Tarspect::Locator.new(:xpath, "//*[text()='Anchor Rating']/ancestor::div[1]//*[contains(@class, 'option')]")
      ratings = []
      anchor_ratings.fetch_elements.each { |rating| ratings << rating.text }
      @common_pages.close_modal
      ratings
    end

    def diff_in_days
      @common_pages.filter.click
      @tarspect_methods.wait_for_loader_to_disappear
      hash = {
        'Industry' => 'Airlines',
        'Program Type' => 'Invoice Financing - Vendor Program'
      }
      @tarspect_methods.fill_form(hash, 1, 2)
      hash2 = {
        'Industry' => 'Banks',
        'Program Type' => 'PO Financing - Dealer Program'
      }
      @tarspect_methods.fill_form(hash2, 1, 2)
    end
  end
end
