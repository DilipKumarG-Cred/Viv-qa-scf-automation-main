module Pages
  class Investor
    attr_accessor :add_query_btn

    def initialize(driver)
      @driver = driver
      @tarspect_methods = Common::Methods.new(@driver)
      @common_pages = Pages::CommonMethods.new(@driver)
      @commercials_page = Pages::Commercials.new(@driver)
      @wait = Selenium::WebDriver::Wait.new(timeout: MIN_LOADER_TIME)

      # Page Properties
      @close_modal_root = Tarspect::Locator.new(:xpath, "//div[@id='modal-root']//i[contains(@class,'nucleoinvest-close')]")
      @decline_button_under_modal = Tarspect::Locator.new(:xpath, "//div[@id='modal-root']//button[text()='Decline']")
      @header_message_under_modal = Tarspect::Locator.new(:xpath, "//div[@id='modal-root']//h4")
      @sub_message_under_modal = Tarspect::Locator.new(:xpath, "//div[@id='modal-root']//div/p")

      @add_query_btn = Tarspect::Locator.new(:xpath, "//*[contains(text(), 'Add Query')]")
    end

    def PROGRAM_TERMS(type)
      Tarspect::Locator.new(:xpath, "//div[contains(@class,'radio-item')]/label[text()='#{type}']")
    end

    def BASE_RATE(rate)
      Tarspect::Locator.new(:xpath, "//p[text()='#{rate}']/../input")
    end

    def REST_TYPE(type)
      Tarspect::Locator.new(:id, type)
    end

    def DASHBOARD_TILES(tile)
      Tarspect::Locator.new(:xpath, "//*[text()='#{tile}']/..//h3")
    end

    def DASHBOARD_CLICK_OPEN(dashboard_tile)
      Tarspect::Locator.new(:xpath, "//*[text()='#{dashboard_tile}']/ancestor::li//button")
    end

    def QUERY_BOX(query)
      Tarspect::Locator.new(:xpath, "//*[text()='#{query}']/ancestor::li")
    end

    def TOGGLE(element, action_element, ivalue)
      evalue = element.get_attribute('value')
      action_element.click unless evalue == ivalue.to_s
    end

    def choose_program_parameters(values)
      hash = {
        'Industries to Avoid' => 'industry.isEnabled',
        'Minimum Credit Rating' => 'minCreditRating.isEnabled',
        'Revenue' => 'revenue.isEnabled',
        'EBITDA' => 'ebitda.isEnabled',
        'Program' => 'programType.isEnabled',
        'Program Size' => 'programSize.isEnabled',
        'Exposure per Channel Partner' => 'exposurePerChannelPartner.isEnabled',
        'Expected Pricing' => 'expectedPricing.isEnabled',
        'Tenure' => 'tenure.isEnabled',
        'Express interest automatically' => 'isAutoEi.isEnabled'
      }
      @tarspect_methods.DYNAMIC_LOCATOR('Program Parameters').click
      values.each do |k, v|
        e_d = @tarspect_methods.DYNAMIC_TAG(:id, hash[k])
        action_element = @tarspect_methods.DYNAMIC_TAG(:xpath, "//input[@id='#{hash[k]}']/following-sibling::div/i")
        TOGGLE(e_d, action_element, v[:enabled])
        clear = @tarspect_methods.DYNAMIC_TAG(:xpath, "//*[text()='#{k}']/parent::label/following-sibling::div//div[@aria-hidden='true']")
        clear.fetch_elements[0].click if clear.fetch_elements.size > 1
        next if v[:slider].nil?

        if v[:slider]
          @common_pages.configure_slider_in_filter(v[:values])
        else
          @tarspect_methods.fill_form({ k => v[:values] }, 1, 2)
        end
      end
    end

    def choose_prefs(prefs, menu: 'Program Terms', enable: false)
      @tarspect_methods.wait_for_loader_to_disappear
      Tarspect::Locator.new(:xpath, "//p[text()='#{menu}']/../following::div/button").click
      @tarspect_methods.wait_for_circular_to_disappear(MAX_LOADER_TIME)
      if menu == 'Program Terms'
        prefs.each { |pref| PROGRAM_TERMS(pref).click }
      else
        toggle = Tarspect::Locator.new(:name, 'isMakerCheckerEnabled')
        toggle_switch = Tarspect::Locator.new(:xpath, "//*[contains(@class,'nucleoinvest-toggle')]")
        toggle_switch.click unless enable == (toggle.get_attribute('Checked') == 'true')
        prefs.each { |pref| Tarspect::Locator.new(:xpath, "//*[contains(text(),'#{pref}')]").click }
      end
      sleep 1
      @tarspect_methods.click_button('Save Changes')
    end

    def get_program_status
      refresh_page
      @tarspect_methods.wait_for_loader_to_disappear(MAX_LOADER_TIME)
      r_count = 0
      begin
        @commercials_page.commercials_tab.click
        @tarspect_methods.wait_for_loader_to_disappear(MAX_LOADER_TIME)
        @tarspect_methods.DYNAMIC_LOCATOR('Program Term Status').wait_for_element
      rescue
        r_count += 1
        retry if r_count < 3
      end
      @tarspect_methods.DYNAMIC_LOCATOR('Program Term Status').click
      @tarspect_methods.wait_for_loader_to_disappear(MAX_LOADER_TIME)
      program_status = Tarspect::Locator.new(:xpath, "//div//ul//div[contains(@class,'detail-container')]")
      all_status = []
      program_status.fetch_elements.each { |status| all_status << status.text }
      all_status.flatten!
      all_status
    end

    def get_vendor_commercial_values
      hash = {}
      @commercials_page.commercials_tab.click
      @tarspect_methods.click_button('Edit')
      @tarspect_methods.wait_for_loader_to_disappear
      mclr = Tarspect::Locator.new(:xpath, "//label[@for='mclr-radio']/div")
      rllr = Tarspect::Locator.new(:xpath, "//label[@for='rllr-radio']/div")
      hash[:mclr] = mclr.text
      hash[:rllr] = rllr.text
      @common_pages.close_modal
      hash
    end

    def get_anchor_commercial_values(values)
      hash = {}
      errors = []
      @tarspect_methods.click_button('Edit')
      @tarspect_methods.wait_for_loader_to_disappear
      min_pricing_value = Tarspect::Locator.new(:xpath, "//span[@class='input-range__label input-range__label--min']/span")
      min_pricing_text_box = Tarspect::Locator.new(:xpath, "//div[contains(text(),'Pricing')]/../following-sibling::div//div//input")
      hash[:min_pricing_value] = min_pricing_value.text
      hash[:min_pricing_text_box] = min_pricing_text_box.get_attribute('value')
      begin
        min_pricing_text_box.clear_by_backspace
        min_pricing_text_box.fill(6)
      rescue Selenium::WebDriver::Error::ElementNotInteractableError
        flag = true unless values[:int_type] == 'Floating'
      end
      errors << 'Min Pricing Text box Field is not editable' if flag
      if values[:int_calc] == 'Simple'
        interest_strategy = Tarspect::Locator.new(:xpath, "//*[@id='simple_interest']")
        interest_strategy.scroll_to_element
        interest_strategy.click
        hash[:interest_calculation] = interest_strategy.get_attribute('checked')
      else
        interest_strategy = Tarspect::Locator.new(:xpath, "//*[@id='compound_interest']")
        hash[:interest_calculation] = interest_strategy.get_attribute('checked')
        hash_lookup = {
          'Daily' => 'daily_rest',
          'Monthly' => 'monthly_rest',
          'Quarterly' => 'quarterly_rest'
        }
        rest_type = hash_lookup[values[:int_calc_rest]]
        rest_type_calculation = REST_TYPE(rest_type)
        rest_type_calculation.scroll_to_element
        rest_type_calculation.click
        hash[:interest_calculation_rest] = REST_TYPE(rest_type).get_attribute('checked')
      end
      @tarspect_methods.click_button('Cancel')
      [hash, errors]
    end

    def add_base_rates(hash, edit: false)
      @tarspect_methods.wait_for_loader_to_disappear
      @tarspect_methods.click_button('Add base rate.') unless edit
      @tarspect_methods.click_button('Edit') if edit
      sleep 1
      @tarspect_methods.fill_form(hash['MCLR_Effective'], 1, 1)
      @tarspect_methods.fill_form(hash['RLLR_Effective'], 2, 1)
      hash.delete('MCLR_Effective')
      hash.delete('RLLR_Effective')
      @tarspect_methods.fill_form(hash, 1, 1)
      @tarspect_methods.click_button('Add')
      sleep 1
      @tarspect_methods.click_button('Save Changes')
    end

    def go_to_commercials(vendor)
      @common_pages.VENDOR_INVESTOR_ROW(vendor).click
      @tarspect_methods.wait_for_loader_to_disappear(MAX_LOADER_TIME)
      @commercials_page.commercials_tab.click
      @tarspect_methods.wait_for_loader_to_disappear
    end

    def decline(decline_message)
      Tarspect::Locator.new(:xpath, "//p[text()='Reason for declining']").wait_for_element
      Tarspect::Locator.new(:xpath, '//textarea').fill decline_message
      @decline_button_under_modal.click
    end

    def read_notifications
      @header_message_under_modal.is_displayed?(MIN_LOADER_TIME)
      notifications = []
      notifications << @header_message_under_modal.text unless @header_message_under_modal.element.nil?
      @sub_message_under_modal.fetch_elements.each do |s_message|
        notifications << s_message.text unless s_message.element.nil?
      end
      notifications
    end

    def review_commercial(values)
      notifications = []
      if values[:commercial] == 'anchor'
        @tarspect_methods.click_button(values[:action])
        sleep 2
        if values[:action] == 'Decline'
          decline(values[:decline_message])
          notifications << @tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)
          sleep 2
          notifications << read_notifications
          @close_modal_root.click
        end
        notifications << @tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)
      else
        go_to_commercials(values[:vendor])
        @tarspect_methods.click_button(values[:action])
        sleep 2
        if values[:action] == 'Decline'
          decline(values[:decline_message])
          sleep 2
        end
        notifications << read_notifications
        sleep 1
        @close_modal_root.click
      end
      notifications.flatten!
      notifications
    end

    def go_to_program(anchor:, program:)
      @common_pages.click_menu(MENU_ANCHOR_LIST)
      @common_pages.apply_filter({ 'Anchor Name' => anchor })
      @common_pages.navigate_to_anchor(anchor)
      @common_pages.select_program(program)
    end

    def validate_export_disbursement(csv_data, tran_id)
      report_hash = {}
      resp = get_po_details(tran_id)
      instrument_id = resp[:body][:id]
      exp_hash = {
        anchor_name: resp[:body][:anchor][:name],
        vendor_name: resp[:body][:vendor][:name],
        program_name: "#{resp[:body][:program][:program_group].downcase} - #{resp[:body][:program][:program_type].downcase}",
        lender_name: resp[:body][:investor][:name],
        amount: resp[:body][:po_value].to_s,
        grn_amount: resp[:body][:po_eligible_value].to_s,
        disbursement_amount: resp[:body][:disbursement_amount].to_s,
        group_identifier: resp[:body][:group_id],
        initiation_date: Date.parse(resp[:body][:created_at])
      }
      for row in 0...csv_data.length do
        next unless csv_data[row]['Instrument Id'] == instrument_id.to_s

        report_hash = {
          anchor_name: csv_data[row]['Anchor name'],
          vendor_name: csv_data[row]['Channel partner name'],
          program_name: csv_data[row]['Program name'].downcase,
          lender_name: csv_data[row]['Lender name'],
          amount: csv_data[row]['Instrument amount'],
          grn_amount: csv_data[row]['GRN / Eligible amount'],
          disbursement_amount: csv_data[row]['Disbursement amount'],
          group_identifier: csv_data[row]['Group Identifier'],
          initiation_date: Date.parse(csv_data[row]['Date of Initiation'])
        }
      end
      [report_hash, exp_hash]
    end

    def validate_export_contains_only_filtered_data(csv_data, tran_id, values)
      resp = get_po_details(tran_id)
      for row in 0...csv_data.length do
        flag = csv_data[row][values[0][0]] == resp[:body][values[1][0]][:name]
        flag &= csv_data[row][values[0][1]] == resp[:body][values[1][1]][:name]
        return "#{csv_data[row][values[0][0]]}, #{csv_data[row][values[0][1]]}" unless flag
      end
      true
    end

    def validate_export_repayment(csv_data, tran_id)
      report_hash = {}
      resp = get_po_details(tran_id)
      instrument_number = resp[:body][:po_number]
      exp_hash = {
        channel_partner_name: resp[:body][:anchor][:name],
        lender_name: resp[:body][:investor][:name],
        instrument_type: resp[:body][:transaction_type],
        principal: resp[:body][:principal_outstanding].to_s,
        interest: resp[:body][:interest_outstanding].to_s,
        total_outstanding: resp[:body][:total_outstanding].to_s,
        due_date: Date.parse(resp[:body][:settlement_date]).strftime('%Y-%m-%d')
      }
      for row in 0...csv_data.length do
        next unless csv_data[row]['Invoice/PO number'] == instrument_number.to_s

        report_hash = {
          channel_partner_name: csv_data[row]['Channel partner name'],
          lender_name: csv_data[row]['Investor Name'],
          instrument_type: csv_data[row]['Instrument Type'],
          principal: csv_data[row]['Principal'],
          interest: csv_data[row]['Interest demanded'],
          total_outstanding: csv_data[row]['Outstanding amount'],
          due_date: csv_data[row]['Due date']
        }
      end
      [report_hash, exp_hash]
    end

    def click_download_all_docs(name, details_page: false)
      if details_page
        @tarspect_methods.click_link('Documents')
        @tarspect_methods.click_button('Download All')
      else
        Tarspect::Locator.new(:xpath, "//li[text()='#{name}']/parent::ul//*[text()='Documents']").click
      end
      @common_pages.alert_message.wait_for_element
      sleep 2 # For zip file to be saved
    end

    def fetch_dashboard_tile_values
      refresh_page
      @tarspect_methods.wait_for_loader_to_disappear(120)
      up_for_disbursement = remove_comma_in_numbers(DASHBOARD_TILES('Up for Disbursement').text.delete('Today'))
      due_for_payment = remove_comma_in_numbers(DASHBOARD_TILES('Due for Payment').text.delete('Today'))
      {
        live_programs: DASHBOARD_TILES('Live Programs').text.to_i,
        commercial_finalized: DASHBOARD_TILES('Commercials Finalized').text.to_i,
        discussion_in_progress: DASHBOARD_TILES('Discussion in Progress').text.to_i,
        up_for_disbursement: up_for_disbursement.to_f,
        due_for_payment: due_for_payment.to_f
      }
    end

    def add_query(query)
      @tarspect_methods.wait_for_circular_to_disappear
      sleep 1
      hash = { 'Query Type': query[:type] }
      @tarspect_methods.fill_form(hash, 1, 2)
      query_area = Tarspect::Locator.new(:xpath, '//textarea')
      query_area.fill query[:query]
      @tarspect_methods.click_button('Post')
      notifications = []
      notifications << @tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)
      notifications << read_notifications
      @common_pages.close_modal
      notifications
    end

    def respond_query(answer, resolve: false)
      notifications = []
      resolve_query = QUERY_BOX(answer[:query]).find_children(:xpath, ".//button[text()='Resolve']")[0]
      open_query = QUERY_BOX(answer[:query]).find_children(:xpath, './/following-sibling::button')[0]
      open_query.click
      comment_on_query(answer[:answer])
      file_upload = Tarspect::Locator.new(:xpath, "//input[contains(@name, 'inp-file')]")
      unless answer[:file].nil?
        files = answer[:file].is_a?(Array) ? answer[:file] : [answer[:file]]
        files.each { |file| file_upload.fill_without_clear file }
      end
      @tarspect_methods.click_button('Send')
      notifications << @tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)
      sleep 1
      if resolve
        resolve_query.click
        notifications << @tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)
      end
      notifications
    end

    def comment_on_query(comment)
      reply = Tarspect::Locator.new(:name, 'comment')
      reply.fill comment
    end

    def get_query_response(answer_to_query)
      @tarspect_methods.wait_for_loader_to_disappear
      query = QUERY_BOX(answer_to_query[:query]).find_children(:xpath, './/button')[0]
      query.click
      @tarspect_methods.wait_for_loader_to_disappear
      chat_message = QUERY_BOX(answer_to_query[:query]).find_children(:xpath, ".//*[@class='chat-message']")[0]
      chat_message.text
    rescue => e
      raise "Error in getting query response #{e}"
    end

    def fetch_resolved_state(query)
      resolved_on = Tarspect::Locator.new(:xpath, "//*[text()='#{query}']/parent::div/following-sibling::div//p").text
      flag = resolved_on.include? 'Resolved'
      flag &= resolved_on.include? Date.today.strftime('%d %b, %Y')
      flag ? true : resolved_on
    end

    def select_investor(investor)
      Tarspect::Locator.new(:xpath, "//*[text()='Select an Investor']").click
      Tarspect::Locator.new(:xpath, "//*[contains(@class,'option')][text()='#{investor}']").click
    end

    def compute_score(investor_actor, params, values)
      resp = get_all_anchor_programs(investor_actor, params)
      program = resp.sample
      count = 0
      count += 1 unless program[:program_size] >= values[:p_min] && program[:program_size] <= values[:p_max]
      count += 1 unless program[:min_price_expectation].to_f >= values[:price_min] && program[:max_price_expectation].to_f <= values[:price_max]
      count += 1 unless program[:min_exposure].to_f >= values[:exp_min] && program[:max_exposure].to_f <= values[:exp_max]
      score = (9 - count) / 9.to_f * 100
    end
  end
end
