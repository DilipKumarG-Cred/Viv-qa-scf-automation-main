require 'bigdecimal/util'
module Pages
  class Payment
    def initialize(driver)
      @driver = driver
      @tarspect_methods = Common::Methods.new(@driver)
      @common_pages = Pages::CommonMethods.new(@driver)
      @disbursement_page = Pages::Disbursement.new(@driver)
      @wait = Selenium::WebDriver::Wait.new(timeout: MIN_LOADER_TIME)
      @extra_wait = Selenium::WebDriver::Wait.new(timeout: MAX_LOADER_TIME)
      @overdue_list = Tarspect::Locator.new(:xpath, "//ul[contains(@class,'list-item-wrapper')]//ul")
      @payment_history = Tarspect::Locator.new(:xpath, "//li//a[text()='Payment History']")
      @payment_list = Tarspect::Locator.new(:xpath, "//div[contains(@class,'fade-in')]//ul//ul")
      @payment_details = Tarspect::Locator.new(:xpath, "//*[text()='Payment Details']//parent::div")
      @summary_modal = Tarspect::Locator.new(:xpath, "//h4[text()='Summary']//preceding-sibling::p")
      @no_invoices = Tarspect::Locator.new(:xpath, "//div[text()='No Due For Payment Invoices found!'] | //div[text()='Transactions Not Available!']")
      @record_payment_icon = Tarspect::Locator.new(:xpath, "//*[text()='Record Payment']")
      @recorded_payment_details = Tarspect::Locator.new(:xpath, "//h2[contains(text(),'Due for')]//parent::div//parent::div//*[text()='Payment Details']/..//following-sibling::div")
      @transaction_summary = Tarspect::Locator.new(:xpath, '//section')

      @file_input = Tarspect::Locator.new(:xpath, "//input[@type='file']")
      @submit_btn = Tarspect::Locator.new(:xpath, "//button[text()='Submit' and not(contains(@class, 'disabled'))]")
      @record_payment_btn = Tarspect::Locator.new(:xpath, "//button[text()='Record Payment' and not(contains(@class, 'disabled'))]")

      class << self
        attr_accessor :record_payment_icon
      end
    end

    def no_invoices_to_payment?
      @tarspect_methods.wait_for_loader_to_disappear
      @no_invoices.is_displayed?(5)
    end

    def record_payment_available?
      @record_payment_icon.is_displayed?(5)
    end

    def overdue_available(actor)
      @overdue_list.fetch_elements.each do |x|
        return true if x.text.include?(actor)
      end
      false
    end

    def get_matching_row(actor)
      @wait.until { !@overdue_list.text.gsub("\n", '').gsub("\u200C", '').empty? }
      @overdue_list.fetch_elements.each do |x|
        next unless x.text.include?(actor)

        return x
      end
    end

    def get_total_demanded_interest(actor)
      x = get_matching_row(actor)
      x.element.find_element(:xpath, './/li[7]/div/p').text
    end

    def select_overdue_details(actor)
      row = get_matching_row(actor)
      row.element.find_element(:xpath, './/button').click
    rescue Selenium::WebDriver::Error::NoSuchElementError
      raise 'Error in selecting overdue details, Due for Payment details are not loaded properly'
    end

    def get_refund_details(actor)
      @common_pages.wait_for_transactions_to_load
      return [] unless Tarspect::Locator.new(:xpath, "//ul//ul/li/*[text()='#{actor}']").is_displayed?(2)

      Tarspect::Locator.new(:xpath, "//*[text()='#{actor}']/../..//li").get_texts
    end

    def select_payment_history_tab
      @payment_history.click
      @common_pages.wait_for_transactions_to_load
      sleep 3 # added sleep to make sure DOM loaded properly
    end

    def toggle_investor_payments(value)
      investor_toggle = Tarspect::Locator.new(:xpath, "//input[@name='investorPayments']")
      investor_toggle.wait_for_element
      return if investor_toggle.get_attribute('value') == value.to_s

      Tarspect::Locator.new(:xpath, "//*[text()='Disbursements']").click
      @common_pages.wait_for_transactions_to_load
      sleep 5 # added sleep to make sure DOM loaded properly
    end

    def view_detailed_breakup(utr_number)
      @payment_list.fetch_elements.each do |x|
        next unless x.text.include? utr_number

        x.element.find_element(:xpath, ".//*[text()='View Detail']").click
        break
      end
      count = 1
      begin
        @wait.until { @payment_list.text.delete("\n").delete('‌‌‌‌‌‌‌‌').strip != '' }
      rescue
        count += 1
        sleep 1
        retry if count <= 5
      end
    end

    def verify_transaction_in_payment_history(values, known_index = 0)
      return false if known_index > 100

      values.flatten!
      result = ''
      errors = []
      errors << "[List page error] Finding #{values} ::: in :::"
      @payment_list.wait_for_element
      initial_count = @payment_list.total_count
      @wait.until { @payment_list.text.delete("\n").delete('‌‌‌‌‌‌‌‌').strip != '' }
      # First call after 25 items loads entire page including the previously loaded
      # SO loading all the elements in the before hand
      if @payment_list.total_count <= 25
        last_element = @payment_list.fetch_elements[-1].element
        # first scroll to check everything to load
        scroll_page('down')
        $driver.action.send_keys(:up).perform
        $driver.action.send_keys(:down).perform
        sleep 1
        @wait.until { @payment_list.text.delete("\n").delete('‌‌‌‌‌‌‌‌').strip != '' }
      end
      @payment_list.fetch_elements.each_with_index do |x, index|
        # Temporarily create an index based element
        index_based_element = Tarspect::Locator.new(:xpath, "(//div[contains(@class,'fade-in')]//ul//ul)[#{index + 1}]")
        # element list loads all the loading elements as well. So waiting for the element vased in the index
        next if known_index > index

        @wait.until { index_based_element.is_displayed? }
        @wait.until { index_based_element.text.delete("\n").delete('‌‌‌‌‌‌‌‌').strip != '' }
        begin
          raise unless x.is_displayed?(2)

          # rare case scenario. x will be true, still element is empty, so assign index based element always
          x = index_based_element
        rescue
          # if x is not displayed means, page is loading. So wait till the page/element loads and call the method with current index
          @wait.until { index_based_element.is_displayed? }
          @wait.until { index_based_element.text.delete("\n").delete('‌‌‌‌‌‌‌‌').strip != '' }
          return verify_transaction_in_payment_history(values, index)
        end
        @wait.until { x.text.delete("‌\n").strip != '' }
        result = true
        values.each do |y|
          y.gsub!(' LAC', '')
          result &= x.text.include?(y)
        end
        unless result
          errors << x.text.to_s unless result
          next
        end
        return true
      end
      # Scroll is happening.... wait till the last element of the previously loaded list
      @wait.until { Tarspect::Locator.new(:xpath, "(//div[contains(@class,'fade-in')]//ul//ul)[#{initial_count}]").text.delete("\n").delete('‌‌‌‌‌‌‌‌').strip != '' }
      # if count is not matching means, new items loaded, recall the methods with initial index - 10, sometimes previously loaded last 5-10 list is getting skipped
      return verify_transaction_in_payment_history(values, initial_count - 10) unless @payment_list.total_count == initial_count

      errors.size == 1 ? true : errors
    end

    def verify_transaction_in_due_for_payments(*values)
      values.flatten! if values[0].is_a?(Array)
      result = ''
      errors = []
      due_list = Tarspect::Locator.new(:xpath, '//ul//ul')
      count = 0
      # to handle stale element on DOM refresh
      begin
        due_list.wait_for_element
        @wait.until { due_list.text.delete("\n").delete('‌‌‌‌‌‌‌‌').strip != '' }
      rescue
        count += 1
        sleep 1
        retry if count <= 10
      end
      due_list.get_texts.each do |x|
        result = true
        values.each do |y|
          result &= x.include?(y)
        end
        unless result
          errors << "[List page error] Finding #{values} ::: in ::: #{x}" unless result
          next
        end
        return true
      end
      errors.empty? ? true : errors
    end

    def record_refund(actor, payment_details, file = nil)
      open_refund(actor)
      @wait.until { @file_input.is_present? }
      @file_input.fill_without_clear file unless file.nil?
      @tarspect_methods.fill_form(payment_details, 1, 2)
      @submit_btn.click
    end

    def open_refund(actor)
      Tarspect::Locator.new(:xpath, "//p[text()='#{actor}']").mouse_hover
      Tarspect::Locator.new(:xpath, "//p[text()='#{actor}']/../..//*[text()='Record Payment']").click
      sleep 2
    end

    def record_payment(payment_details, file = nil)
      @record_payment_icon.click
      @wait.until { @file_input.is_present? }
      @file_input.fill_without_clear file unless file.nil?
      @tarspect_methods.fill_form(payment_details, 1, 2)
      if @submit_btn.is_displayed?(1)
        @submit_btn.click
      elsif @record_payment_btn.is_displayed?(1)
        @record_payment_btn.click
      end
      sleep 1
      raise 'Still submitting' unless Tarspect::Locator.new(:xpath, "//*[text()='Submitting']").wait_until_disappear(MAX_LOADER_TIME)
    end

    def get_recorded_payment_details
      @wait.until { @recorded_payment_details.text != '' }
      temp = @recorded_payment_details.text
      temp = temp.split("\n")
      if temp.include? 'LAC'
        temp[temp.index('LAC') - 1] = temp[temp.index('LAC') - 1] + ' ' + 'LAC'
        temp.delete 'LAC'
      end
      temp = temp[0..(temp.count / 2) - 1].zip(temp[(temp.count / 2)..-1])
      Hash[*temp.flatten]
    end

    def clear_all_overdue_payments(actor, _investor)
      navigate_to($conf['base_url'])
      @tarspect_methods.login($conf['users'][actor]['email'], $conf['users'][actor]['password'])
      @common_pages.transactions_list.wait_for_element
      @common_pages.click_transactions_tab(DUE_FOR_REPAYMENT)
      return @common_pages.logout if no_invoices_to_payment?

      counter_party = ''
      case actor
      when 'anchor'
        counter_party = 'dealer'
      when 'grn_anchor'
        counter_party = 'grn_dealer'
      when 'vendor'
        counter_party = 'anchor'
      when 'grn_vendor'
        counter_party = 'grn_anchor'
      end
      overdue_amount = get_total_overdue($conf['investor_name'], $conf['users'][counter_party]['name'])
      return @common_pages.logout unless overdue_amount

      payment_details = {
        'UTR Number' => "UTR#{DateTime.now.to_time.to_i}#{rand(1..999)}",
        'Date of Payment' => Date.today.strftime('%d-%b-%Y'),
        'Payment Amount' => overdue_amount,
        'Payment Account Number' => Faker::Number.number(digits: 10)
      }
      record_payment(payment_details)
      @tarspect_methods.close_toaster
      sleep 2 # to ensure summary modal pops out
      @transaction_summary.wait_for_element
      @tarspect_methods.click_button('close')
      @common_pages.logout
    end

    def get_total_overdue(investor, counter_party)
      overdue_amount = 0
      Tarspect::Locator.new(:xpath, "//ul[contains(@class,'list-item-wrapper')]//ul").fetch_elements.each do |x|
        next unless x.text.include?(counter_party) && x.text.include?(investor)

        overdue_amount = x.text.split("\n")[-3] == 'LAC' ? x.element.text.split("\n")[-4..-3].join(' ') : x.element.text.split("\n")[-3]
      end
      return false if overdue_amount.zero?

      overdue_amount.gsub!('₹', '')
      overdue_amount.gsub!(',', '')
      if overdue_amount.include? 'LAC'
        overdue_amount.gsub!('LAC', '')
        overdue_amount = (overdue_amount.to_f * 100000).to_i + 5000
      end
      overdue_amount
    end

    def get_total_count_of_invoices_in_due_for_payments
      @common_pages.payment_list.fetch_elements[-1].text.split("\n")[-4].to_s.to_i
    end

    def create_test_data_for_bulk_repayment(amount, file)
      excel = RubyXL::Parser.parse(file)
      sheet = excel['Repayment']
      utrs = []
      count = 0
      for row in 1..14
        unless [11, 12, 13, 14].include? row # No UTR, UTR already in system
          utr = "UTR#{DateTime.now.to_time.to_i}#{rand(1..999)}#{count}"
          sheet.add_cell(row, 8, utr)
          utrs << utr
        end
        sheet.add_cell(row, 7, Date.today.strftime('%d/%m/%Y'))
      end
      sheet.add_cell(1, 6, amount / 2.to_f) # Amount seperated to partial payments
      sheet.add_cell(2, 6, (amount / 2.to_f) - 2500) # Amount seperated
      excel.save
      utrs
    end

    def create_test_data_for_repayment(amount, file)
      excel = RubyXL::Parser.parse(file)
      sheet = excel['Repayment']
      utrs = []
      count = 0
      for row in 1..2
        utr = "UTR#{DateTime.now.to_time.to_i}#{rand(1..999)}#{count}"
        sheet.add_cell(row, 8, utr)
        utrs << utr
        sheet.add_cell(row, 7, Date.today.strftime('%d/%m/%Y'))
      end
      sheet.add_cell(1, 6, amount / 2.to_f) # Amount seperated to partial payments
      sheet.add_cell(2, 6, amount / 2.to_f) # Amount seperated
      excel.save
      utrs
    end

    def repay_amount(amount, file, cp_pan, program, anchor_pan)
      excel = RubyXL::Parser.parse(file)
      sheet = excel['Repayment']
      count = 0
      utr = "UTR#{DateTime.now.to_time.to_i}#{rand(1..999)}#{count}"
      sheet.add_cell(1, 8, utr)
      sheet.add_cell(1, 7, Date.today.strftime('%d/%m/%Y'))
      sheet.add_cell(1, 6, amount.to_f) # Amount seperated to partial payments
      sheet.add_cell(1, 5, cp_pan)
      sheet.add_cell(1, 3, anchor_pan)
      sheet.add_cell(1, 9, program)
      excel.save
      utr
    end

    def create_expected_data_for_bulk_repay(utrs)
      {
        utrs[0] => ['uploaded', ''],
        utrs[1] => ['uploaded', ''],
        utrs[2] => ['uploaded', ''],
        utrs[3] => ['uploaded', ''],
        utrs[4] => ['uploaded', ''],
        utrs[5] => ['failed', 'Invalid Repayment received (INR)'],
        utrs[6] => ['failed', 'Validation failed: Amount should be in max 2 decimal places, Amount should be >0'],
        utrs[7] => ['failed', 'Repayment Transactions are not present in the system'],
        utrs[8] => ['uploaded', ''],
        utrs[9] => ['failed', 'Repayment Transactions are not present in the system'],
        '' => ['failed', 'Invalid UTR Number'],
        'UTR16642009904960' => ['failed', 'UTR number is already in the system'], # UTR Validation when Anchor/CP and Investor details are provided
        'UTR1664200990770' => ['failed', 'UTR number is already in the system'], # UTR Validation when only Anchor PAN is provided
        'UTR16642009908460' => ['failed', 'UTR number is already in the system'] # UTR Validation when only CP PAN is provided
      }
    end

    def create_expected_data_for_repayment(utr)
      {
        utr => ['uploaded', '']
      }
    end

    def check_transaction_status(expected_values, column_value, amount_repay = true)
      @wait.until { @common_pages.payment_list.is_displayed? } if amount_repay
      @tarspect_methods.wait_for_loader_to_disappear(MAX_LOADER_TIME)
      @common_pages.payment_list.fetch_elements.each do |row|
        return true if row.text.split("\n")[column_value].eql?(expected_values)
      end
      false
    end
  end
end
