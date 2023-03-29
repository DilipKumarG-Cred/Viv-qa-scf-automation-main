module Pages
  class Disbursement
    def initialize(driver)
      @driver = driver
      @tarspect_methods = Common::Methods.new(@driver)
      @common_pages = Pages::CommonMethods.new(@driver)
      @investor_page = Pages::Investor.new(@driver)
      @wait = Selenium::WebDriver::Wait.new(timeout: MIN_LOADER_TIME)
      @extra_wait = Selenium::WebDriver::Wait.new(timeout: MAX_LOADER_TIME)

      @disburse = Tarspect::Locator.new(:xpath, "//span[text()='Disburse']")
      @decline = Tarspect::Locator.new(:xpath, "//span[text()='Decline']")
      @disbursement_amount = Tarspect::Locator.new(:xpath, "//span[text()='Disbursement Amount']//parent::p//following-sibling::p")
      @acc_number = Tarspect::Locator.new(:xpath, "//span[text()='Account No.']//parent::p//following-sibling::p")
      @payment_details = Tarspect::Locator.new(:xpath, "//*[text()='Funding Details']/..//*[text()='Payment Details']//parent::div")
      @summary_modal = Tarspect::Locator.new(:xpath, "//*[text()='Summary']//preceding-sibling::p")
      @discrepancy_file = Tarspect::Locator.new(:xpath, "(//input[@type='file'])[1]")
      @payment_file = Tarspect::Locator.new(:xpath, "(//input[@type='file'])[2]")

      @total_invoice_value = Tarspect::Locator.new(:xpath, "//*[contains(text(),'Instrument Value:')]//parent::div")
      @due_for = Tarspect::Locator.new(:xpath, "//h2[contains(text(),'Due for')]//parent::div//parent::div")
      @due_for_repayment = Tarspect::Locator.new(:xpath, "//h2[text()='Due for Re-payment']//parent::div//parent::div")
      @due_for_payment = Tarspect::Locator.new(:xpath, "//h2[text()='Due for Payment']//parent::div//parent::div")
      @discrepancy_link = Tarspect::Locator.new(:xpath, "//span[text()='Click here ']")

      @resettlement_banner = Tarspect::Locator.new(:xpath, "//*[text()='Record Payment']//ancestor::div[@direction='row']")

      class << self
        attr_accessor :resettlement_banner, :decline
      end
    end

    # DYNAMIC LOCATORS
    def SUMMARY(key)
      Tarspect::Locator.new(:xpath, "//p[text()='#{key}']//following-sibling::p")
    end

    def DISCREPANCY_REASON(text)
      Tarspect::Locator.new(:xpath, "//span[@data-for='#{text}']")
    end

    def TOOLTIP_REASON(text)
      $driver.find_element(:xpath, "//div[text()='#{text}']")
    end

    def HOVER_STATUS(vendor)
      Tarspect::Locator.new(:xpath, "//p[text()='#{vendor}']/ancestor::ul[1]//span[@data-tip='true']")
    end

    def REVIEW_AT_ROOT(date, action)
      invoice_date = Date.parse(date, 'dd-mmm-yyyy').strftime('%d %b, %Y')
      Tarspect::Locator.new(:xpath, "//li[text()='#{invoice_date}']/parent::ul//button[text()='#{action}']")
    end

    def click_disbursement
      @disburse.click
    end

    def decline_disbursement(reason)
      @decline.click
      sleep 1
      reason_box = Tarspect::Locator.new(:xpath, '//textarea')
      reason_box.fill(reason)
      @tarspect_methods.click_button('Decline')
      sleep 2
      @tarspect_methods.click_button('Done')
    end

    def verify_summary_details(summary)
      errors = []
      @tarspect_methods.wait_for_loader_to_disappear
      summary.each do |key, value|
        SUMMARY(key).wait_for_element
        @wait.until { SUMMARY(key).text != '' }
        @wait.until { SUMMARY(key).text != '-' }
        result = (SUMMARY(key).text == value)
        errors << "[Wrong data] #{key} : Expected => #{value} ::: Got : #{SUMMARY(key).text}" unless result
      end
      errors.empty? ? true : errors
    end

    def disburse(file, details, discrepancy_details = nil)
      @payment_file.wait_for_element
      @payment_file.fill_without_clear file
      @tarspect_methods.fill_form(details, 1, 2)
      add_discrepancy(discrepancy_details) unless discrepancy_details.nil?
      @tarspect_methods.click_button('Submit')
    end

    def add_discrepancy(discrepancy_details)
      @discrepancy_file.fill_without_clear discrepancy_details['discrepancy file']
      @tarspect_methods.fill_form({ 'Discrepancy Reason (Optional)' => discrepancy_details['discrepancy reason'] }, 1, 2)
    end

    def disbursement_amount
      @wait.until { @disbursement_amount.text != '' }
      @disbursement_amount.text
    end

    def account_number
      @wait.until { @acc_number.text != '' }
      @acc_number.text
    end

    def get_payment_details
      temp = @payment_details.text
      temp = temp.split("\n")[1..-1]
      if temp.include? 'LAC'
        temp[temp.index('LAC') - 1] = "#{temp[temp.index('LAC') - 1]} LAC"
        temp.delete 'LAC'
      end
      temp.delete('More')
      temp = temp[0..(temp.count / 2) - 1].zip(temp[(temp.count / 2)..-1])
      Hash[*temp.flatten]
    end

    def validate_discrepancy_reason(reason)
      actual_value = get_payment_details['Discrepancy Reason'].delete('.')
      result = reason.include?(actual_value) && DISCREPANCY_REASON(reason).is_displayed?(2)
      result &= wait_for_mouse_hover(reason)
      result
    end

    def wait_for_mouse_hover(reason)
      i = 0
      while i < 5
        $driver.action.move_to(DISCREPANCY_REASON(reason).element).perform
        return true if TOOLTIP_REASON(reason).displayed?

        i += 1
      end
      false
    end

    def get_due_for_payment_details
      @wait.until { @due_for.text != '' }
      temp = if @due_for_repayment.is_displayed?(2)
               @due_for_repayment.text.split("\n")
             else
               @due_for_payment.text.split("\n")
             end
      temp.each { |x| temp.delete(x) if x.include? 'Payment Overdue' }
      temp = temp[1..10]
      Hash[*temp.flatten]
    end

    def select_vendor(name)
      @tarspect_methods.DYNAMIC_XPATH('p', 'text()', name).click
      @common_pages.transactions_list.wait_for_element
    end

    def select_vendor_in_up_for_disbursement(name)
      @tarspect_methods.wait_for_loader_to_disappear(MAX_LOADER_TIME)
      vendor = Tarspect::Locator.new(:xpath, "//p[text()='#{name}']/ancestor::ul[1]//button[text()='View Details']")
      vendor.click
    end

    def select_clubbed_group(date)
      @tarspect_methods.wait_for_loader_to_disappear(MAX_LOADER_TIME)
      invoice_date = Date.parse(date, 'dd-mmm-yyyy').strftime('%d %b, %Y')
      @tarspect_methods.DYNAMIC_XPATH('li', 'text()', invoice_date).click
    end

    def select_vendor_in_disbursement(name, date)
      select_vendor_in_up_for_disbursement(name)
      @tarspect_methods.wait_for_loader_to_disappear(MIN_LOADER_TIME)
      invoice_date = Date.parse(date, 'dd-mmm-yyyy').strftime('%d %b, %y')
      clubbed_group = @tarspect_methods.DYNAMIC_XPATH('li', 'text()', invoice_date)
      count = 1
      Tarspect::Locator.new(:xpath, "//p[text()='Terms & Conditions']").scroll_to_element
      until clubbed_group.is_displayed?(2)
        last_element = @common_pages.payment_list.fetch_elements[-1]
        last_element.scroll_to_element
        10.times { $driver.action.send_keys(:up).perform }
        10.times { $driver.action.send_keys(:down).perform }
        scroll_page('down')
        count += 1
        break if count > 10

        scroll_page('down')
        $driver.action.send_keys(:up).perform
        50.times do
          $driver.action.send_keys(:down).perform
        end
      end
      raise 'Clubbed transaction group not found' if clubbed_group.is_displayed?(2)

      clubbed_group.click
    end

    def get_list_details_in_up_for_disbursement(date)
      invoice_date = Date.parse(date, 'dd-mmm-yyyy').strftime('%d %b, %Y')
      invoice = Tarspect::Locator.new(:xpath, "//li[text()='#{invoice_date}']/parent::ul")
      invoice.wait_for_element(MAX_LOADER_TIME)
      invoice.text.split("\n")
    end

    def get_group_id(transaction_id)
      resp = get_po_details(transaction_id)
      anchor_id = resp[:body][:anchor][:id]
      vendor_id = resp[:body][:vendor][:id]
      investor_id = resp[:body][:investor][:id]
      program_id = resp[:body][:program][:id]
      date = Date.parse(resp[:body][:po_date]).strftime('%d%m%Y')
      "#{anchor_id}-#{program_id}-#{investor_id}-#{vendor_id}-#{date}"
    end

    def review_at_root_level(date, action)
      case action
      when :disburse
        REVIEW_AT_ROOT(date, 'Disburse').click
      when :decline
        REVIEW_AT_ROOT(date, 'Decline').click
        sleep 1
        @investor_page.decline('Declining at root level')
        @tarspect_methods.BUTTON('Done').wait_for_element
        sleep 1
        notifications = @investor_page.read_notifications
        @tarspect_methods.click_button('Done')
        notifications
      end
    end

    def scroll_till_transaction(vendor_name, id)
      count = 1
      vendor_details = Tarspect::Locator.new(:xpath, "//p[text()='#{vendor_name}']//ancestor::a").text
      total_invoices = if vendor_details[-1] == 'LAC'
                         vendor_details[-3]
                       else
                         vendor_details[-2]
                       end
      until @common_pages.TRANSACTION(id).is_displayed?(3)
        last_element = @common_pages.transactions_list.fetch_elements[-1]
        last_element.element.location_once_scrolled_into_view
        break if @common_pages.transactions_list.fetch_elements.size == total_invoices.to_i

        count += 1
        return if count > 15
      end
      @common_pages.TRANSACTION(id).element.location_once_scrolled_into_view
    end

    def select_transactions(transactions_ids)
      transactions_ids = transactions_ids.is_a?(Array) ? transactions_ids : [transactions_ids]
      transactions_ids.each do |id|
        Tarspect::Locator.new(:xpath, "#{@common_pages.TRANSACTION(id).get_what}//i[@class='nucleoinvest-checkbox-select']").click
      end
    end

    def select_transaction_and_get_tooltip_text(transaction_id)
      count = 0
      begin
        tooltip = Tarspect::Locator.new(:xpath, "#{@common_pages.TRANSACTION(transaction_id).get_what}//i[@data-tip]")
        tooltip.mouse_hover
        sleep 1
        tooltip_text = Tarspect::Locator.new(:xpath, "#{@common_pages.TRANSACTION(transaction_id).get_what}//div[@data-id='tooltip' and contains(@class,'show')]")
        raise unless tooltip_text.is_displayed?

        @wait.until { !tooltip_text.text.gsub("\n", '').gsub("\u200C", '').empty? }
        tooltip_text.text
      rescue
        count += 1
        retry if count < 5
      end
    end

    def verify_disbursement_details(no_of_transactions, invoice_value, disbursement_value)
      @wait.until { @total_invoice_value.text != '' }
      actual_value = @total_invoice_value.text
      errors = []
      result = actual_value.include? "#{no_of_transactions} Transactions selected!"
      errors << ["[Mismatch of number of transactions] Expected : #{no_of_transactions}, in the banner : #{actual_value.split("\n")}"] unless result
      result = actual_value.include? "Instrument Value:  ₹ #{invoice_value}"
      errors << ["[Wrong Instrument Value] Expected : ₹ #{invoice_value}, in the banner : #{actual_value.split("\n")}"] unless result
      result = actual_value.include? "Total Disbursement Value:  ₹ #{disbursement_value}"
      errors << ["[Wrong total disbursement value] Expected : ₹ #{disbursement_value}, :: in the banner : #{actual_value.split("\n")}"] unless result
      errors.empty? ? true : errors
    end

    def calculate_total_value_in_words(values)
      values = values.is_a?(Array) ? values : [values]
      total = 0
      values.each do |x|
        x.gsub!('₹', '')
        x.gsub!(',', '')
        total += if x.include? '.'
                   x.to_f
                 else
                   x.to_i
                 end
      end
      if total < 100000
        [comma_seperated_value(total), comma_seperated_value(total)]
      else
        [comma_seperated_value(total), "#{format('%g', rounded_half_down_value(total.to_f / 100000))} LAC"]
      end
    end

    def no_of_transactions_in_summary(no_of_transactions)
      @summary_modal.text == "#{no_of_transactions} Transactions Moved To Settled!"
    end

    # Helper method to convert Amount values to 2 decimal strings
    # 16900.79 => "16900.79"
    # 16900.70 => "16900.7"
    # 16900.09 => "16900.09"
    # 16900 => "16900"
    def decimal_converted(value)
      if value.instance_of?(Integer)
        format('%.2f', value)
      elsif value.instance_of?(Float)
        format('%.2f', value).sub(/\.?0+$/, '')
      end
    end

    def generate_bulk_disbursement(values, file)
      excel = RubyXL::Parser.parse(file)
      sheet = excel['Disbursement']
      count = 0
      for row in 1..18
        sheet.add_cell(row, 4, values[count][:invoice_id])
        sheet.add_cell(row, 5, values[count][:disbursement_amount]) unless row == 17 # Invalid Amount
        sheet.add_cell(row, 6, values[count][:disbursement_date])
        sheet.add_cell(row, 7, "UTR#{DateTime.now.to_time.to_i}#{rand(1..999)}#{count}") unless row == 16 # Duplicate UTR
        count += 1
      end
      sheet.add_cell(5, 6, Date.today.strftime('%d/%m/%Y')) # Current date
      sheet.add_cell(6, 6, (Date.today + 2).strftime('%d/%m/%Y')) # Future date
      sheet.add_cell(7, 5, 999) # Wrong disbursement amount
      sheet.add_cell(8, 5, 999) # Wrong disbursement amount with discrepancy
      sum_amount = values[8][:disbursement_amount] + values[9][:disbursement_amount]
      sheet.add_cell(9, 5, sum_amount) # Multiple invoices, Same UTR
      sheet.add_cell(10, 5, sum_amount) # Multiple invoices, Same UTR, Same SUM Amount
      sheet.add_cell(10, 7, sheet[9][7].value)
      sheet.add_cell(11, 5, 1000.0) # Multiple invoices, Same UTR
      sheet.add_cell(12, 5, 1000.0) # Multiple invoices, Same UTR, Same SUM Amount with Discrepancy
      sheet.add_cell(12, 7, sheet[11][7].value)
      sheet.add_cell(13, 5, 1000.0) # Multiple invoices, Same UTR
      sheet.add_cell(14, 5, 1500.0) # Multiple invoices, Same UTR Different amount case
      sheet.add_cell(14, 7, sheet[13][7].value)
      excel.save
    end

    def create_test_data_for_bulk_disbursement(po_transactions, invoice_transactions)
      total_test_data = []
      po_transactions.each do |tran_id|
        test_data = {}
        resp = get_po_details(tran_id)
        test_data[:invoice_id] = resp[:body][:po_number]
        test_data[:disbursement_amount] = resp[:body][:disbursement_amount]
        test_data[:disbursement_date] = Date.parse(resp[:body][:po_date]).strftime('%d/%m/%Y')
        total_test_data << test_data
      end
      total_disbursements = total_test_data[0][:disbursement_amount] + total_test_data[1][:disbursement_amount]
      total_disbursements += 999.0 + 1000.0 + total_test_data[4][:disbursement_amount]
      for i in 8..9 do total_disbursements += total_test_data[i][:disbursement_amount] end

      invoice_transactions.each do |tran_id|
        test_data = {}
        resp = get_transaction_details(tran_id)
        test_data[:invoice_id] = resp[:body][:invoice_number]
        test_data[:disbursement_amount] = resp[:body][:disbursement_amount]
        test_data[:disbursement_date] = Date.parse(resp[:body][:invoice_date]).strftime('%d/%m/%Y')
        total_test_data << test_data
      end
      total_disbursements += total_test_data[total_test_data.length - 1][:disbursement_amount]
      [total_test_data, total_disbursements]
    end

    def create_expected_data_for_bulk_disburse(values)
      {
        values[0][:invoice_id] => ['uploaded', ''],
        values[1][:invoice_id] => ['uploaded', ''],
        values[2][:invoice_id] => ['failed',	'Invoice/Purchase Order is already disbursed or does not exist in the system'],
        values[3][:invoice_id] => ['failed',	'Invoice/Purchase Order is already disbursed or does not exist in the system'],
        values[4][:invoice_id] => ['uploaded', ''],
        values[5][:invoice_id] => ['failed', 'Disbursement cant be done for a future date'],
        values[6][:invoice_id] => ['failed', "The disbursement amount provided is not matching the system's calculated amount. Please provide a valid reason/proof for the mismatch."],
        values[7][:invoice_id] => ['uploaded', ''],
        "#{values[8][:invoice_id]},#{values[9][:invoice_id]}" => ['uploaded', ''],
        "#{values[10][:invoice_id]},#{values[11][:invoice_id]}" => ['uploaded', ''],
        "#{values[12][:invoice_id]},#{values[13][:invoice_id]}" => ['failed', 'Disbursement amount, date & UTR cant be different for different records'],
        values[14][:invoice_id] => ['failed', 'Validation failed: Disbursement account number is invalid'],
        values[15][:invoice_id] => ['failed', 'UTR number is already in the system'],
        values[16][:invoice_id] => ['failed', 'Invalid Disbursement amount (INR)'],
        values[17][:invoice_id] => ['uploaded', ''],
        ',INVNOTEXIST' => ['failed',	'Invalid Instrument Number'],
        'INVCUM2199799922' => ['failed', 'Invoice/Purchase Order is already disbursed or does not exist in the system'],
        'INVALIDANCHORPAN' => ['failed',	'Unable to find anchor with PAN - INVAL0940E'],
        'INVALIDVENDORPAN' => ['failed',	'Unable to find vendor with PAN - INVAL8936R'],
        'INVRATIONE7430150254' => ['failed', 'Invalid Disbursement Date (DD/MM/YYYY)']
      }
    end

    def upload_bulk_disbursement(file, type = 'Disbursement')
      @tarspect_methods.wait_for_loader_to_disappear
      @tarspect_methods.click_button('Upload')
      Tarspect::Locator.new(:xpath, "//h4[text()='Upload settlement details']").wait_for_element
      values = { 'Data Upload Type' => type }
      @tarspect_methods.fill_form(values, 1, 2)
      @common_pages.file_input.fill_without_clear file
      sleep 5
      Tarspect::Locator.new(:xpath, "//*[text()='Upload successful!']").wait_for_element(120)
      summary = Tarspect::Locator.new(:xpath, "//*[text()='Summary']/following-sibling::div[1]/div")
      summary_texts = []
      upload_wait = Selenium::WebDriver::Wait.new(timeout: 300)
      begin
        upload_wait.until { summary.fetch_elements[1].text.split("\n")[1] != '-' }
      rescue
        raise 'Could not fetch summary details'
      end
      summary.fetch_elements.each { |sumry| summary_texts << sumry.text.split("\n") }
      report = Tarspect::Locator.new(:xpath, "//*[text()='Summary']/following-sibling::div[2]/a")
      report.click
      report_link = report.get_attribute('href')
      actual_summary = if type == 'Disbursement'
                         {
                           'Total Disbursement Value' => summary_texts[0][1],
                           'Invoices disbursed' => summary_texts[1][1],
                           'Payment accepted' => summary_texts[2][1],
                           'Payment rejected' => summary_texts[3][1]
                         }
                       else
                         {
                           'Total Repayment Value' => summary_texts[0][1],
                           'Payment accepted' => summary_texts[1][1],
                           'Payment rejected' => summary_texts[2][1]
                         }
                       end
      @tarspect_methods.click_button('Close')
      [actual_summary, report_link]
    end

    def verify_bulk_disbursment_summary_report(file = "#{$download_path}/report.xlsx", type = 'disbursement')
      invoice_file = Roo::Spreadsheet.open(file)
      invoice_sheet = invoice_file.sheet('Sheet1')
      actual_results = {}
      index = type == 'disbursement' ? [2, 3] : [1, 2]
      invoice_sheet.entries[1..-1].each do |x|
        actual_results[x[0]] = [x[index[0]], x[index[1]]]
      end
      actual_results
    end
  end
end
