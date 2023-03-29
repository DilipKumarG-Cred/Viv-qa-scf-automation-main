module Pages
  class Trasactions
    attr_accessor :tenor, :tenor_computed, :due_date, :due_date_computed

    def initialize(driver)
      @driver = driver
      @tarspect_methods = Common::Methods.new(@driver)
      @common_pages = Pages::CommonMethods.new(@driver)

      @commercials = Tarspect::Locator.new(:xpath, "//h3[text()='Commercials']//parent::div//following-sibling::div")

      @initiate_transaction_page = Tarspect::Locator.new(:xpath, "//h4[text()='Initiate Transaction']")
      @map_fields_page = Tarspect::Locator.new(:xpath, "//h4[text()='Map Invoice Fields']")

      @invoice_preview = Tarspect::Locator.new(:xpath, "//div[@class='react-pdf__Document']")
      @invoice_preview_error = Tarspect::Locator.new(:xpath, "//div[contains(@class,'react-pdf__message--error')]")

      @status_timeline = Tarspect::Locator.new(:xpath, "//div[contains(@class, 'status-timeline')]//li")

      @accept_invoice = Tarspect::Locator.new(:xpath, "//*[text()='Accept']")
      @reject_invoice = Tarspect::Locator.new(:xpath, "//*[text()='Reject'] | //*[text()='Decline']")
      @reason = Tarspect::Locator.new(:xpath, "//*[text()='Reason for rejection']/..//following-sibling::div//textarea")
      @rejected_status = @tarspect_methods.DYNAMIC_TAG(:xpath, "//div[contains(@class,'rejected-reason')]/preceding-sibling::*[text()='Rejected']")
      @re_initiate_status = @tarspect_methods.DYNAMIC_TAG(:xpath, "//div[contains(@class,'rejected-reason')]/preceding-sibling::*[text()='Re-Initiate']")
      @rejected_reason = Tarspect::Locator.new(:xpath, "//div[contains(@class,'rejected-reason')]")
      @alert_icon = Tarspect::Locator.new(:xpath, "//*[contains(@class,'alert-icon')]//following-sibling::p")

      @save_and_re_initiate = Tarspect::Locator.new(:xpath, "//span[contains(text(),'Save and Re-Initiate')]")

      @table_of_contents = Tarspect::Locator.new(:xpath, "//div[@class='sheet-selection-list']//table")
      @mapping_table = Tarspect::Locator.new(:xpath, "//div[@class='sheet-selection-list']//table")
      @transaction_summary = Tarspect::Locator.new(:xpath, '//section')
      @summary_report = Tarspect::Locator.new(:xpath, "//div[@data-testid='file-card-container']//a")
      @download_icon = Tarspect::Locator.new(:xpath, "//a[@data-testid='file-card-download-button']")

      @tenor = @tarspect_methods.DYNAMIC_TAG(:name, 'tenor')
      @tenor_computed = @tarspect_methods.DYNAMIC_TAG(:name, 'tenorComputed')
      @due_date = @tarspect_methods.DYNAMIC_TAG(:name, 'requestedDueDate')
      @due_date_computed = @tarspect_methods.DYNAMIC_TAG(:name, 'requestedDueDateComputed')

      # PO Invoices
      @reject_po_invoice_reason = Tarspect::Locator.new(:xpath, "//*[text()='Reason of Rejection']//following-sibling::textarea")
      @reject_alert_icon = Tarspect::Locator.new(:xpath, "//*[@class='nucleoinvest-c-warning']")
      @rejected_tooltip_icon = Tarspect::Locator.new(:xpath, "//*[@data-testid='file-card-edit-button']")
      @close_icon = Tarspect::Locator.new(:xpath, "//i[@class='icon nucleoinvest-close']")

      @wait = Selenium::WebDriver::Wait.new(timeout: MIN_LOADER_TIME)
      @extra_wait = Selenium::WebDriver::Wait.new(timeout: MAX_LOADER_TIME)
      @file_input = Tarspect::Locator.new(:xpath, "//input[@type='file']")
      @file_input2 = Tarspect::Locator.new(:xpath, "(//input[@type='file'])[2]")
      @uploading_btn = Tarspect::Locator.new(:xpath, "//*[text()='Uploading']")
    end

    # DYNAMIC LOCATORS
    def TRANSACTION_DETAILS(key)
      Tarspect::Locator.new(:xpath, "//p[text()='#{key}']//following-sibling::p")
    end

    def HOVER_STATUS(transaction_id)
      Tarspect::Locator.new(:xpath, "#{@common_pages.TRANSACTION(transaction_id).get_what}//li//span[@data-tip='true']")
    end

    def HOVER_ACTIONS(transaction_id)
      Tarspect::Locator.new(:xpath, "#{@common_pages.TRANSACTION(transaction_id).get_what}//span[@data-for='action-tooltip']")
    end

    def OVERDUE_TOOLTIP(transaction_id)
      "#{@common_pages.TRANSACTION(transaction_id).get_what}//div[contains(@class,'show') and @data-id='tooltip']"
    end

    def HOVER_STATUS_TIMELINE!
      "//div[contains(@id, 'statusTooltip') and contains(@class, 'show')]"
    end

    def REJECT_REASON_TOOLTIP(_transaction_id)
      $driver.find_element(:xpath, "//div[contains(@class,'show')]//div[contains(@class,'rejected-reason')]")
    end

    def BULK_MAPPING_LABEL(key)
      Tarspect::Locator.new(:xpath, "//label[contains(text(),'#{key}')]//parent::td//following-sibling::td")
    end

    def BULK_MAPPING_INPUT(key)
      Tarspect::Locator.new(:xpath, "//label[contains(text(),'#{key}')]//parent::td//following-sibling::td//input")
    end

    # Invoice Assignemnt
    def deselect_checkbox_in_unassigned_investor
      check_deselect = Tarspect::Locator.new(:xpath, "//i[@class='nucleoinvest-checkbox-deselct']")
      @wait.until { check_deselect.is_displayed? }
      check_deselect.click
    end

    def assign_investor
      @tarspect_methods.click_button('Assign')
      sleep 1
      confirm_button = Tarspect::Locator.new(:xpath, "//button[text()='Confirm']")
      @wait.until { confirm_button.is_displayed? }
      @tarspect_methods.click_button('Confirm')
      sleep 1
      message = Tarspect::Locator.new(:xpath, "//div[@id='modal-root']//h4")
      @wait.until { message.is_displayed? }
      @wait.until { message.text != '' }
      message.text
    end

    def verify_investor_commercials_in_investor_page(investor_hash)
      @commercials.wait_for_element
      @wait.until { !@commercials.text.gsub("\n", '').gsub("\u200C", '').empty? }
      investor_details = @commercials.text.split("\n")
      investor_details = Hash[*investor_details.flatten]
      investor_hash.delete('investor')
      result = true
      investor_hash.each_value { |x| result &= investor_details.values.include?(x) }
      result
    end

    def select_vendor(vendor_name)
      @common_pages.verify_vendor_present(vendor_name)
      @common_pages.VENDOR_INVESTOR_ROW(vendor_name).click
    end

    def verify_vendor_approved?(vendor_name)
      @common_pages.verify_vendor_present(vendor_name)
      vendor_details = @common_pages.VENDOR_INVESTOR_ROW(vendor_name).text
      vendor_details.include?(vendor_name) && vendor_details.include?('Verified')
    end

    def get_available_limit(program:, vendor:, investor:)
      @tarspect_methods.click_button('Check available limit')
      sleep 1
      hash = {
        'Select Program' => program,
        'Select Channel Partner' => vendor,
        'Select Investor' => investor
      }
      @tarspect_methods.fill_form(hash, 1, 2)
      sanction_limit = Tarspect::Locator.new(:xpath, "//*[contains(text(),'Sanction Limit for')]/preceding-sibling::p")
      sanction_limit.wait_for_element
      available_limit = Tarspect::Locator.new(:xpath, "//*[contains(text(),'Available Limit for')]/preceding-sibling::p")
      available_limit.wait_for_element
      @common_pages.close_modal
      [sanction_limit.text, available_limit.text]
    end

    def add_transaction(file, invoice_details, program = 'Vendor Financing', instrument_type = 'invoice')
      @tarspect_methods.click_button('Add Transaction')
      select_transaction_program(program, 1)
      select_transaction_program(instrument_type, 2)
      if file == 'No File'
        @tarspect_methods.click_button('Add Instrument Details')
        @map_fields_page.wait_for_element
        @tarspect_methods.fill_form(invoice_details, 1, 1)
      else
        upload_invoice(file, invoice_details)
        @wait.until { invoice_preview_available? }
      end
      @tarspect_methods.click_button('Submit')
    end

    def select_transaction_program(program, index = 1)
      @tarspect_methods.wait_for_circular_to_disappear
      @tarspect_methods.wait_for_loader_to_disappear
      Tarspect::Locator.new(:xpath, "(//div[contains(@class, 'program-select')])[#{index}]").click
      scroll_page('up')
      # @common_pages.raise_if_error_notified
      Tarspect::Locator.new(:xpath, "//*[text()= '#{program}']").click
      sleep 1
    end

    def upload_invoice(file, invoice_details)
      @initiate_transaction_page.wait_for_element
      @file_input.fill_without_clear file
      @map_fields_page.wait_for_element
      @tarspect_methods.fill_form(invoice_details, 1, 1)
    end

    def create_seed_transaction(actor, counter_party, invoice_file, invoice_details, transaction_details)
      navigate_to($conf['base_url'])
      @tarspect_methods.login($conf['users'][actor]['email'], $conf['users'][actor]['password'])
      @common_pages.click_transactions_tab(SHOW_ALL)
      add_transaction(invoice_file, invoice_details)
      @tarspect_methods.close_toaster
      @transaction_id = @common_pages.get_transaction_id(transaction_details)
      @common_pages.logout
      release_transaction(counter_party, @transaction_id)
      @transaction_id
    rescue
      raise 'Error while creating transaction'
    end

    def release_transaction(counterparty, transaction_id)
      navigate_to($conf['base_url'])
      @tarspect_methods.login($conf['users']['product']['email'], $conf['users']['product']['password'])
      @common_pages.navigate_to_transaction(transaction_id)
      approve_transaction
      @tarspect_methods.close_toaster
      @common_pages.logout
      navigate_to($conf['base_url'])
      @tarspect_methods.login($conf['users'][counterparty]['email'], $conf['users'][counterparty]['password'])
      @common_pages.navigate_to_transaction(transaction_id)
      approve_transaction
      @tarspect_methods.close_toaster
      @common_pages.logout
      navigate_to($conf['base_url'])
      @tarspect_methods.login($conf['users']['product']['email'], $conf['users']['product']['password'])
      @common_pages.navigate_to_transaction(transaction_id)
      approve_transaction
      @tarspect_methods.close_toaster
      @common_pages.logout
      true
    rescue
      raise 'Error while releasing transaction'
    end

    def upload_page_available?
      @initiate_transaction_page.is_displayed?
    end

    def invoice_preview_available?
      @invoice_preview.is_displayed? && !@invoice_preview.text.nil?
    end

    def error_thrown?(label)
      @common_pages.ERROR_MESSAGE(label).is_displayed?(5)
    end

    def get_transactions_in_list_page(page:)
      @tarspect_methods.wait_for_circular_to_disappear
      @tarspect_methods.wait_for_loader_to_disappear
      @common_pages.transactions_list.wait_for_element(60)
      @wait.until { !@common_pages.transactions_list.text.gsub("\n", '').gsub("\u200C", '').empty? }
      investor = []
      not_investor = []
      instrument_date = []
      initiation_date = []
      transaction_value = []
      anchor = []
      due_date = []
      scroll_page('down')
      5.times { $driver.action.send_keys(:up).perform }
      50.times { $driver.action.send_keys(:down).perform }
      array_index = case page
                    when :investor
                      [2, 4, 5, 6, 7]
                    when :product
                      [2, 5, 6, 7, 9, 4]
                    else
                      [3, 4, 5, 6, 7]
                    end
      @common_pages.transactions_list.fetch_elements.each do |transaction|
        transaction_text = transaction.text.split("\n")
        not_investor << transaction_text[array_index[0]]
        investor << transaction_text[array_index[1]]
        instrument_date << transaction_text[array_index[2]]
        initiation_date << transaction_text[array_index[3]]
        transaction_value << transaction_text[array_index[4]]
        due_date << transaction_text[8]
        anchor << transaction_text[array_index[5]] if page == :product
      end
      { investor: investor, not_investor: not_investor, instrument_date: instrument_date, transaction_value: transaction_value, anchor: anchor, initiation_date: initiation_date, due_date: due_date }
    end

    def verify_transaction_in_list_page(values, page:, apply_filter: true)
      @tarspect_methods.wait_for_circular_to_disappear
      @tarspect_methods.wait_for_loader_to_disappear
      @common_pages.transactions_list.wait_for_element(60)
      @wait.until { !@common_pages.transactions_list.text.gsub("\n", '').gsub("\u200C", '').empty? }
      if apply_filter
        hash = { 'date_range' => [{ 'Date Of Initiation' => values['Date of Initiation'] }, { 'Date Of Initiation' => values['Date of Initiation'] }], 'With Documents?' => true }
        @common_pages.apply_list_filter(hash)
      end
      @tarspect_methods.wait_for_loader_to_disappear
      case page
      when :anchor
        values.delete('Anchor Name')
      when :investor
        values.delete('Investor Name')
      when :vendor
        values.delete('Vendor Name')
      end
      errors = []
      errors << "[List page error] Finding #{values.values}"
      found = ''
      @common_pages.transactions_list.fetch_elements.each do |x|
        found = x.text if x.text.include?(values['Number'])
      end
      result = true
      values.each_value do |y|
        result &= found.gsub('\n', ' ').downcase.include?(y.downcase)
        unless result
          errors << found unless result
          next
        end
        return true
      end
      errors.empty? ? true : errors
    end

    def verify_transaction_status(status)
      @tarspect_methods.wait_for_loader_to_disappear(MIN_LOADER_TIME)
      @tarspect_methods.DYNAMIC_XPATH('span', 'text()', status).is_displayed?
    end

    def verify_transaction_in_detail_page(values)
      errors = []
      values.each do |key, value|
        TRANSACTION_DETAILS(key).wait_for_element
        @wait.until { TRANSACTION_DETAILS(key).text != '' }
        temp = TRANSACTION_DETAILS(key).text
        result = temp == value
        errors << "[Data mismatch] Expected:: #{value} ::::: Got : #{temp}" unless result
      end
      errors.empty? ? true : errors
    end

    def invoice_exists?(file_name, tab = 'Invoices')
      @tarspect_methods.click_link('Invoices & Documents')
      @tarspect_methods.click_link(tab)
      Tarspect::Locator.new(:xpath, "//*[contains(text(),'#{file_name}')]").is_displayed?(10)
    end

    def approve_transaction
      @accept_invoice.click
    end

    def reject_transaction(type, reason)
      @reject_checkbox = Tarspect::Locator.new(:xpath, "//*[text()='#{type}']/..//preceding-sibling::input")
      @reject_invoice.click
      @reason.wait_for_element
      retry_count = 1
      begin
        count = 1
        until @reject_checkbox.get_attribute('checked') == 'true'
          @wait.until { @reject_checkbox.is_displayed? }
          @reject_checkbox.click
          count += 1
          break if count > 5
        end
      rescue
        retry_count += 1
        retry if retry_count <= 3
      end
      @reason.fill reason
      @tarspect_methods.BUTTON('Submit').wait_for_element
      @tarspect_methods.click_button('Submit')
    end

    def upload_invoice_to_po(invoice_details, invoice_file)
      @tarspect_methods.DYNAMIC_XPATH('span', 'text()', 'Upload').click
      upload_invoice(invoice_file, invoice_details)
      @tarspect_methods.click_button('Submit')
    end

    def submit_invoice_for_review
      @tarspect_methods.DYNAMIC_XPATH('span', 'text()', 'Submit for Invoice Review').click
    end

    def approve_invoice_message_available?
      Tarspect::Locator.new(:xpath, "//*[text()='Approve Invoices']").is_displayed?(5)
    end

    def open_invoice_document
      Tarspect::Locator.new(:xpath, "//span[@class='file-full-name']").click
      sleep 2
    end

    def verify_invoice_review_modal(values)
      sleep 2 # to ensure modal loads
      errors = []
      values.each do |key, value|
        modal_value = Tarspect::Locator.new(:xpath, "//div[contains(@id,'modal')]//div[contains(@class,'vc-grid') and @direction='row' and text()='#{key}']//following-sibling::div").text
        @wait.until { !modal_value.gsub("\n", '').gsub("\u200C", '').empty? }
        result = modal_value == value
        errors << "Expected value for #{key} :: #{value} ::::: Got :: #{modal_value}" unless result
      end
      errors.empty? ? true : errors
    rescue
      errors.empty? ? true : errors
    end

    def verify_discrepancies_in_review_modal(value)
      discrepancy_values = Tarspect::Locator.new(:xpath, "//div[contains(@id,'modal')]//*[contains(@class,'nucleoinvest-c-info')]//following-sibling::p").get_texts
      discrepancy_values.include? value
    end

    def reject_processing_fee_invoice(reason)
      @reject_invoice.click
      sleep 2
      @reject_po_invoice_reason.wait_for_element
      @reject_po_invoice_reason.fill reason
      @common_pages.UNDER_MODAL_ROOT('Submit').click
    end

    def reject_invoice_for_po(reason)
      open_invoice_document
      @reject_invoice.click
      @reject_po_invoice_reason.wait_for_element
      @reject_po_invoice_reason.fill reason
      @tarspect_methods.click_button('Submit')
    end

    def reject_reason_present?(reason)
      @rejected_tooltip_icon.mouse_hover
      Tarspect::Locator.new(:xpath, "//div[contains(@class,'show') and @data-id='tooltip' and text()='#{reason}']").is_displayed?(3) && @reject_alert_icon.is_displayed?(3)
    end

    def actions_present?(transaction_id)
      HOVER_ACTIONS(transaction_id).is_displayed?(3)
    end

    def actions_needed(transaction_id)
      HOVER_ACTIONS(transaction_id).text
    end

    def hover_dd_transaction(transaction_id)
      tooltip = Tarspect::Locator.new(:xpath, "#{@common_pages.TRANSACTION(transaction_id).get_what}//i[@data-tip]")
      count = 0
      begin
        @wait.until { @common_pages.transaction_listed?(transaction_id) }
        tooltip.mouse_hover
        sleep 1
        @data = $driver.find_element(:xpath, "#{@common_pages.TRANSACTION(transaction_id).get_what}//div[@data-id]").text
      rescue
        count += 1
        retry if count < 5
      end
      datas = @data.split("\n")
      hash = {}
      datas.each_slice(2) do |x|
        hash[x[1]] = x[0]
      end
      hash
    end

    def hover_actions_for_transactions(transaction_id)
      count = 0
      begin
        @wait.until { HOVER_ACTIONS(transaction_id).is_displayed? }
        HOVER_ACTIONS(transaction_id).mouse_hover
      rescue
        count += 1
        retry if count < 3
      end
    end

    def overdue_tooltip(transaction_id)
      count = 0
      begin
        @wait.until { $driver.find_element(:xpath, OVERDUE_TOOLTIP(transaction_id)).displayed? }
        $driver.find_element(:xpath, OVERDUE_TOOLTIP(transaction_id)).text
      rescue
        hover_actions_for_transactions(transaction_id)
        count += 1
        retry if count < 3
      end
    end

    def invoice_discrepancies_present?
      Tarspect::Locator.new(:xpath, "//*[contains(text(),'Some invoices have discrepancies')]").is_displayed?(3)
    end

    def status_timeline_present?(date, approval_level, status = '')
      @tarspect_methods.wait_for_loader_to_disappear
      @status_timeline.fetch_elements.each do |x|
        flag = x.text.include?(date.upcase) && x.text.include?(approval_level)
        flag &= x.text.include?(status) unless status.empty?
        return true if flag
      end
      "#{date}, #{approval_level}, #{status} not found in #{@status_timeline.text}"
    end

    def rejected_status(type, user, reason)
      case type
      when 'Discard'
        raise 'Rejected Status is not displayed' unless @rejected_status.is_displayed?
      when 'Re-Initiate Transaction'
        raise 'Re-initiate Status is not displayed' unless @re_initiate_status.is_displayed?
      end
      raise "#{@rejected_reason.text} does not have #{user}" unless @rejected_reason.text.include?(user.downcase)
      raise "#{@rejected_reason.text} does not have #{reason}" unless @rejected_reason.text.include?(reason)

      true
    end

    def status_timeline_on_hover(transaction_id, date, approval_level)
      count = 0
      begin
        sleep 1
        mouse_hover_status(transaction_id)
        hover_element = $driver.find_element(:xpath, HOVER_STATUS_TIMELINE!)
        raise unless hover_element.displayed?

        if hover_element.text.strip.include?(date.upcase) && hover_element.text.strip.include?(approval_level)
          true
        else
          "Could not find #{transaction_id}, #{date}, #{approval_level}, got: #{hover_element.text}"
        end
      rescue => e
        p "status_timeline_on_hover - exception #{e}"
        count += 1
        retry if count < 5
        "Could not find #{transaction_id}, #{date}, #{approval_level}"
      end
    end

    def rejected_reason_on_hover(transaction_id, user, reason)
      count = 0
      begin
        sleep 1
        mouse_hover_status(transaction_id)
        raise 'tool tip not found' unless REJECT_REASON_TOOLTIP(transaction_id).displayed?

        if REJECT_REASON_TOOLTIP(transaction_id).text.include?(user.downcase) && REJECT_REASON_TOOLTIP(transaction_id).text.include?(reason)
          true
        else
          "Expected: #{user} with #{reason}\nGot: #{REJECT_REASON_TOOLTIP(transaction_id).text}"
        end
      rescue => e
        p "rejected_reason_on_hover - exception #{e}"
        count += 1
        retry if count < 2
        false
      end
    end

    def get_message_on_hover_element(vendor, location = 'UpForDisbursement')
      count = 0
      begin
        sleep 1
        tooltip = Tarspect::Locator.new(:xpath, "//p[text()='#{vendor}']/ancestor::ul[1]//span[contains(@data-for,'statusTooltip')]")
        tooltip = Tarspect::Locator.new(:xpath, "//span[contains(@data-for,'statusTooltip')]") if location == 'BorrowerList'
        tooltip.wait_for_element
        tooltip.mouse_hover
        tooltip_text = tooltip.element.find_element(:xpath, './/following-sibling::div')
        raise unless tooltip_text.displayed?

        tooltip_text.text
      rescue
        count += 1
        retry if count < 3
        nil
      end
    end

    def mouse_hover_status(transaction_id)
      count = 1
      begin
        @common_pages.filter.wait_for_element
        @wait.until { @common_pages.transaction_listed?(transaction_id) }
        $driver.action.move_to(HOVER_STATUS(transaction_id).element).perform
        hover_element = $driver.find_element(:xpath, HOVER_STATUS_TIMELINE!)
        raise unless hover_element.displayed?

        true
      rescue => e
        p "mouse_hover_status #{e}"
        count += 1
        $driver.navigate.refresh
        @tarspect_methods.wait_for_circular_to_disappear
        @tarspect_methods.wait_for_loader_to_disappear
        retry if count < 2
        false
      end
    end

    def alert_message
      if @alert_icon.is_displayed?(5)
        @alert_icon.text
      else
        false
      end
    end

    def re_initiate_transaction(file, details, changes = false)
      @alert_icon.wait_for_element
      unless changes
        @tarspect_methods.fill_form(details, 1, 1)
        @file_input.fill_without_clear file
      end
      @save_and_re_initiate.click
    end

    def change_po_value(value)
      po_eligible = Tarspect::Locator.new(:xpath, "//input[@name='poEligibleValue']")
      po_eligible.fill(value)
    end

    # Invoice bulk transctions
    def add_bulk_transaction(type, program = 'Vendor Financing', instrument = 'Invoice')
      file = ''
      case type
      when 'anchor', 'grn_anchor', 'vendor', 'grn_vendor'
        file = "#{Dir.pwd}/test-data/attachments/invoice_vendor_transaction_bulk_upload.xlsx"
      when 'dealer'
        file = "#{Dir.pwd}/test-data/attachments/invoice_dealer_transaction_bulk_upload.xlsx"
      end
      generate_bulk_invoice(type, file)
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @tarspect_methods.click_button('Add Transaction')
      @initiate_transaction_page.wait_for_element
      select_transaction_program(program, 1)
      select_transaction_program(instrument, 2)
      @file_input2.fill_without_clear file
      sleep 5
      @extra_wait.until { @uploading_btn.element.nil? == true }
      @tarspect_methods.BUTTON('close').wait_for_element
      invoice_file = Roo::Spreadsheet.open(file)
      invoice_sheet = if type == 'dealer'
                        invoice_file.sheet('Invoice - Dealer Program')
                      else
                        invoice_file.sheet('Invoice - Vendor Program')
                      end
      create_bulk_invoice_expected_hash(invoice_sheet, type)
    end

    def create_bulk_invoice_expected_hash(invoice_sheet, type)
      expected_hash = {
        invoice_sheet.entries[1][0] => ['uploaded', '', ''],
        invoice_sheet.entries[2][0] => ['uploaded', '', 'Failed to upload Invoice Image'],
        invoice_sheet.entries[3][0] => ['uploaded', '', ''],
        invoice_sheet.entries[4][0] => ['uploaded', '', ''],
        invoice_sheet.entries[5][0] => ['uploaded', '', ''],
        invoice_sheet.entries[6][0] => ['failed', 'Invalid invoice_number', ''],
        invoice_sheet.entries[7][0] => ['failed', 'Invalid invoice_value', ''],
        invoice_sheet.entries[8][0] => ['failed', 'Invalid invoice_date', ''],
        invoice_sheet.entries[9][0] => ['failed', 'Unable to find Anchor from the GSTN provided', ''],
        invoice_sheet.entries[10][0] => ['failed', 'Unable to find Vendor from the GSTN provided', '']
      }

      if type != 'dealer'
        expected_hash.merge!(
          invoice_sheet.entries[11][0] => ['failed', 'Requested Disbursement Value cannot be greater than the entered Invoice/GRN value', ''],
          invoice_sheet.entries[12][0] => ['failed', 'GRN Value cannot be greater than the Invoice value', ''],
          invoice_sheet.entries[13][0] => ['failed', 'Requested Disbursement Value cannot be greater than the entered Invoice/GRN value', ''],
          invoice_sheet.entries[14][0] => ['uploaded', '', '']
        )
      end
      expected_hash
    end

    def initiate_bulk_import_transaction(file, program, instrument)
      @common_pages.click_menu(MENU_PO_FINANCING)
      @tarspect_methods.wait_for_circular_to_disappear
      @tarspect_methods.wait_for_loader_to_disappear
      @tarspect_methods.click_button('Add Transaction')
      @initiate_transaction_page.wait_for_element
      select_transaction_program(program, 1)
      select_transaction_program(instrument, 2)
      @file_input2.fill_without_clear file
      sleep 5
      @uploading_btn.wait_until_disappear(MAX_LOADER_TIME)
      raise "Document is still uploading after #{MAX_LOADER_TIME} seconds" if @uploading_btn.is_displayed?(0)

      @tarspect_methods.BUTTON('close').wait_for_element
    end

    def transaction_summary_present?
      @transaction_summary.is_displayed?
    end

    def verify_summary(key)
      Tarspect::Locator.new(:xpath, "//p[text()='#{key}']//following-sibling::p").text
    end

    def download_summary_report(download_path = $download_path)
      report_link = @summary_report.get_attribute('href')
      navigate_to(report_link)
      @wait.until { @tarspect_methods.file_downloaded?("#{download_path}/report.xlsx") }
      @wait.until { File.exist?("#{download_path}/report.xlsx") }
      @tarspect_methods.file_downloaded?("#{download_path}/report.xlsx")
    end

    def get_summary_report_link
      Tarspect::Locator.new(:xpath, "//div[@data-testid='file-card-container']//a[@href]").get_attribute('href')
    end
  end
end
