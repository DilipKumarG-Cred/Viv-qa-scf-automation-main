require 'httpclient'
module Pages
  class CommonMethods
    attr_accessor :transactions_list, :payment_list, :export, :file_input,
                  :alert_message, :download_button, :filter, :clear_filter, :close_icon, :vendor_details, :explore_container_col_names, :investor_drp_down, :investor, :company_information, :select_investor, :recommonded_message, :shortlisted_by, :yubi_team

    def initialize(driver)
      @driver = driver
      @driver.manage.timeouts.implicit_wait = 0.2 unless @driver.nil?
      @tarspect_methods = Common::Methods.new(@driver)
      @close_toaster = Tarspect::Locator.new(:xpath, "//*[contains(@class, 'close-toastr')]")
      @toaster_title = Tarspect::Locator.new(:xpath, "//div[@class='rrt-title' and text()='Success!']")
      @payment_list = Tarspect::Locator.new(:xpath, "//div[contains(@class,'fade-in')]//ul//ul")
      @error_toastr = Tarspect::Locator.new(:xpath, "//div[contains(@class, 'rrt-error') and contains(@class, 'toastr')]")

      @transactions_list = Tarspect::Locator.new(:xpath, "//a[contains(@href,'/transactions/') and not(@tab) and not(contains(@class,'has-child-menu'))]")
      @details_tab = Tarspect::Locator.new(:xpath, "//a[text()='Details']")

      @interested_investors = Tarspect::Locator.new(:xpath, "//h4[text()='Investors']//following-sibling::div//ul")

      @avatar_btn = Tarspect::Locator.new(:xpath, "//div[@class='profile-info-container']")
      @logout_btn = Tarspect::Locator.new(:xpath, "//*[text()='Logout']")
      @back_button = Tarspect::Locator.new(:xpath, "//i[contains(@class, 'nucleoinvest-small-left')]")

      @close_icon = Tarspect::Locator.new(:xpath, "//*[@id='modal-root']//i[contains(@class,'nucleoinvest-close')]")
      @wait = Selenium::WebDriver::Wait.new(timeout: MIN_LOADER_TIME)

      @filter = Tarspect::Locator.new(:xpath, "//button[text()='Filter'] | //button/*[text()='Filter'] | //button/*[text()='Filter List']")
      @clear_filter = Tarspect::Locator.new(:xpath, "//button/*[text()='Clear Filters']")
      @assign_list = Tarspect::Locator.new(:xpath, "//ul[@class='assign-list']//div[@class='list-label']")
      @switcher_menu = Tarspect::Locator.new(:xpath, "//*[contains(@class,'Menu-Icon')]")

      @export = Tarspect::Locator.new(:xpath, "//span[text()='Export']")
      @file_input = Tarspect::Locator.new(:xpath, "//input[@type='file']")
      @alert_message = Tarspect::Locator.new(:xpath, "//*[contains(@class,'alert-message')]//p")
      @download_button = Tarspect::Locator.new(:xpath, "//*[contains(@class,'nucleoinvest-download')]")
      @vendor_details = @tarspect_methods.DYNAMIC_TAG(:xpath, '//tbody')
      @explore_container_col_names = @tarspect_methods.DYNAMIC_TAG(:xpath, '//thead')
      @investor_drp_down = @tarspect_methods.DYNAMIC_LOCATOR('investor-select', '@class')
      @investor = @tarspect_methods.DYNAMIC_LOCATOR($conf['users']['investor']['name'])
      @company_information = @tarspect_methods.DYNAMIC_XPATH('h3', 'text()', 'Company Information')
      @select_investor = @tarspect_methods.DYNAMIC_LOCATOR('investor-form-field', '@class')
      @recommonded_message = @tarspect_methods.DYNAMIC_LOCATOR('You have successfully recommended')
      @shortlisted_by = @tarspect_methods.DYNAMIC_LOCATOR('Shortlisted by')
      @yubi_team = @tarspect_methods.DYNAMIC_LOCATOR('Yubi team')
      @otp_box = Tarspect::Locator.new(:xpath, "//*[text() = 'Enter your OTP']/..//input")
      @is_document_present = @tarspect_methods.DYNAMIC_LOCATOR('With Documents?')
    end

    # DYNAMIC LOCATORS
    def INVESTOR_LIST(investor)
      Tarspect::Locator.new(:xpath, "//*[contains(text(),'#{investor}')]")
    end

    def ANCHOR(name)
      Tarspect::Locator.new(:xpath, "//p[text()='#{name}']//parent::li")
    end

    def TRANSACTION_MENU(menu)
      Tarspect::Locator.new(:xpath, "//button[contains(text(),'#{menu} (')]")
    end

    def TRANSACTION(id)
      Tarspect::Locator.new(:xpath, "//*[starts-with(@href,'/transactions') and contains(@href,'#{id}')]")
    end

    def UNDER_MODAL_ROOT(text)
      Tarspect::Locator.new(:xpath, "//*[@id='modal-root']//*[text()='#{text}']")
    end

    def LABEL(type)
      Tarspect::Locator.new(:xpath, "//div/label[@for='#{type}']/following-sibling::div")
    end

    def ASSIGNEE_LIST(investor)
      Tarspect::Locator.new(:xpath, "//ul[@class='assign-list']//div[@class='list-label']/h4[text()='#{investor}']")
    end

    def ASSIGNEE_CATEGORY(investor, category)
      Tarspect::Locator.new(:xpath, "#{ASSIGNEE_LIST(investor).get_what}/following-sibling::P//*[text()='#{category}']")
    end

    def VENDOR_INVESTOR_ROW(name)
      Tarspect::Locator.new(:xpath, "//li[text()='#{name}']//parent::ul")
    end

    def ERROR_MESSAGE(label)
      Tarspect::Locator.new(:xpath, "//*[text()='#{label}']/../..//span[@class='error-text']")
    end

    def raise_if_error_notified
      raise 'Error displayed in Notification' if @error_toastr.is_displayed?(2)
    end

    def SIMPLE_XPATH(label)
      @tarspect_methods.DYNAMIC_XPATH('*', 'text()', label)
    end

    def generate_report(hash, name, report_name, postive_case: true)
      dup_hash = hash.dup
      dup_hash.delete('date_range')
      @tarspect_methods.fill_form(dup_hash, 1, 2)
      unless hash['date_range'].nil?
        fill_date(hash['date_range'][0], hash['date_range'][1])
      end
      @tarspect_methods.click_button('View Report')
      if postive_case
        @tarspect_methods.close_tab if $driver.window_handles.count > 1
        @wait.until { (@tarspect_methods.BUTTON('Send Email').is_displayed? && @tarspect_methods.BUTTON('Send Email').get_attribute('disabled').nil?) }
        @tarspect_methods.click_button('Send Email')
        @tarspect_methods.wait_for_circular_to_disappear(MIN_LOADER_TIME)
        @tarspect_methods.click_button('Excel')
        @tarspect_methods.DYNAMIC_TAG(:xpath, "//*[text()= 'We sent the #{report_name} to your email #{name}']").is_displayed?
      else
        @tarspect_methods.DYNAMIC_TAG(:xpath, "//*[text()='Maximum duration is 180 days']").text
      end
    end

    def select_report_menu(key, value)
      @tarspect_methods.DYNAMIC_TAG(:xpath, "//div[@class='control-label'][text()='#{key}']/ancestor::div[1]//div[contains(@class, 'container')]")
      @tarspect_methods.DYNAMIC_TAG(:xpath, "//div[@class='control-label'][text()='#{key}']/ancestor::div[1]//div[contains(@class, 'container')]//div//input").fill value
      sleep 1
      @tarspect_methods.DYNAMIC_TAG(:xpath, "//div[contains(@class, 'form-group')]//div[contains(@class, 'menu')]//div[contains(@class, 'option')][text()='#{value}']").click
    end

    def get_link_from_mail(email_values, email = '', new_tab: true)
      activation_link = $mail_helper.get_activation_link(email_values)
      unless activation_link.is_a?(Array)
        @tarspect_methods.open_new_tab if new_tab
        navigate_to(activation_link)
        if @otp_box.is_displayed?
          @tarspect_methods.fill_otp_and_verify(email, false)
          navigate_to(activation_link)
        end
        sleep 1
        @tarspect_methods.wait_for_circular_to_disappear
        @tarspect_methods.close_tab if new_tab && $driver.window_handles.count > 1
      end
      activation_link
    rescue => e
      raise "Invalid URI #{e} URL: #{activation_link}"
    end

    def check_for_file(filename, download_path = $download_path)
      count = 0
      begin
        @downloadedfile = ''
        files = Dir["#{download_path}/*.csv"]
        files.each do |x|
          @downloadedfile = File.basename(x, '.csv')
          break if @downloadedfile.include? filename
        end
        raise "File name not matching #{@downloadedfile} <> #{filename}" unless @downloadedfile.include? filename

        @downloadedfile.empty? ? 'File not downloaded' : @downloadedfile
      rescue => e
        count += 1
        sleep 1
        retry if count < 3
        puts "Exception #{e}"
      end
    end

    def download_summary_report
      @tarspect_methods.file_downloaded?("#{$download_path}/report.xlsx", MIN_LOADER_TIME)
    end

    def get_max_limit
      @tarspect_methods.wait_for_loader_to_disappear
      sleep 1
      max_limit = Tarspect::Locator.new(:xpath, "//span[text()='Max Sanction Limit']/following-sibling::span")
      @wait.until { max_limit.is_displayed? }
      limit = max_limit.text
      limit.gsub(',', '').gsub(' ', '').gsub('₹', '').gsub('CR', '')
    end

    def validate_csv(csv_data, expected_data)
      disburse_data = expected_data['disburse_data']
      repayment_data = expected_data['repayment_data']
      disburse_flag = false
      for row in 0...csv_data.length do
        if csv_data[row][0] == disburse_data[0] && !disburse_flag
          disburse_flag = csv_data[row][2] == disburse_data[1].to_s
        elsif csv_data[row][0] == repayment_data[0]
          repay_flag = csv_data[row][4] == repayment_data[1].to_s
        end
        return true if disburse_flag && repay_flag
      end
      "#{expected_data} not found in #{csv_data}"
    end

    def user_action(action:)
      @tarspect_methods.wait_for_loader_to_disappear
      scroll_page('up')
      profile_icon = @tarspect_methods.DYNAMIC_TAG(:xpath, "//*[text()='Need Help?']/following-sibling::div")
      if profile_icon.element.nil?
        Tarspect::Locator.new(:xpath, "//header//div[@class='container']").scroll_to_element
        @avatar_btn.scroll_to_element
        sleep 1
        @avatar_btn.click
      else
        profile_icon.click
      end
      Tarspect::Locator.new(:xpath, "//*[text()='#{action}']").click
      @tarspect_methods.wait_for_circular_to_disappear(MAX_LOADER_TIME)
    end

    def switch_role(entity_name, role)
      user_action(action: 'Switch Role')
      role = Tarspect::Locator.new(:xpath, "//*[text()='#{entity_name}']//following-sibling::*[text()='#{role}']")
      role.mouse_hover
      role.click
      @tarspect_methods.wait_for_circular_to_disappear
    end

    def apply_filter(hash)
      clear = Tarspect::Locator.new(:xpath, "//button/*[text()='Clear Filters']")
      clear.click unless clear.element.nil?
      remove_filter = @tarspect_methods.DYNAMIC_LOCATOR('Remove Filter')
      remove_filter.click unless remove_filter.element.nil?
      @tarspect_methods.wait_for_loader_to_disappear
      @filter.click
      @tarspect_methods.wait_for_loader_to_disappear
      sleep 1
      unless hash['date_range'].nil?
        @tarspect_methods.fill_form(hash['date_range'][0], 1)
        @tarspect_methods.fill_form(hash['date_range'][1], 2)
        hash.delete('date_range')
      end
      @tarspect_methods.fill_form(hash, 1, 2)
      sleep 0.5
      @is_document_present.click unless hash['With Documents?'].nil?
      if @tarspect_methods.BUTTON('Submit').is_displayed?(3)
        @tarspect_methods.click_button('Submit')
      else
        @tarspect_methods.click_button('Apply')
      end
      sleep 2 # to handle stale element reference for filter results DOM
      @tarspect_methods.wait_for_loader_to_disappear
    end

    def apply_list_filter(hash)
      wait_for_transactions_to_load
      apply_filter(hash)
      wait_for_transactions_to_load
      @tarspect_methods.wait_for_loader_to_disappear
    end

    def check_for_error_notification?
      @error_toaster.wait_for_element(3)
      # @close_toaster.click
      true
    rescue
      false
    end

    def navigate_to_investor(investor_name)
      count = 0
      begin
        @wait.until { INVESTOR_LIST(investor_name).is_displayed? }
        INVESTOR_LIST(investor_name).click
      rescue
        count += 1
        retry if count < 2
      end
    end

    def verify_interested_investors_details(investor_hash)
      result = true
      @interested_investors.wait_for_element
      @interested_investors.fetch_elements[1..-1].each do |x|
        investor_hash.each_value { |y| result &= x.text.include?(y) }
        return true if result
      end
      false
    end

    def anchor_available?(anchor_name)
      ANCHOR(anchor_name).is_displayed?(5)
    end

    def navigate_to_anchor(anchor_name)
      @wait.until { ANCHOR(anchor_name).is_displayed? }
      ANCHOR(anchor_name).click
    end

    def select_program(type)
      @tarspect_methods.wait_for_loader_to_disappear(MAX_LOADER_TIME)
      Tarspect::Locator.new(:xpath, "//*[contains(text(), '#{type}')]").click
      @tarspect_methods.wait_for_loader_to_disappear(MAX_LOADER_TIME)
    end

    def search_program(entity)
      @tarspect_methods.wait_for_loader_to_disappear(MAX_LOADER_TIME)
      search = Tarspect::Locator.new(:xpath, "//input[contains(@class, 'search-icon')]")
      search.clear_by_backspace
      search.fill(entity)
      sleep 1
      @tarspect_methods.wait_for_loader_to_disappear(MAX_LOADER_TIME)
    end

    def click_live_investors
      Tarspect::Locator.new(:xpath, "//*[contains(text(),'Live Investors')]").click
    end

    def click_interested_investors
      Tarspect::Locator.new(:xpath, "//*[contains(text(),'Interested Investors')]").click
    end

    def click_back_button
      @back_button.click
    end

    def wait_for_transactions_to_load
      count = 0
      begin
        @wait.until { @payment_list.text.delete("‌\n") != '' }
      rescue
        count += 1
        retry if count < 2
        false
      end
      true
    end

    def menu_available?(menu)
      @tarspect_methods.wait_for_circular_to_disappear
      @tarspect_methods.wait_for_loader_to_disappear(MAX_LOADER_TIME)
      @tarspect_methods.LINK(menu).is_displayed?(2)
    end

    def click_menu(menu)
      count = 1
      @tarspect_methods.wait_for_circular_to_disappear
      # raise_if_error_notified
      @tarspect_methods.wait_for_loader_to_disappear(MAX_LOADER_TIME)
      if [MENU_INOICE_FINANCING, MENU_PO_FINANCING].include? menu
        @tarspect_methods.click_link('Transactions')
        @tarspect_methods.wait_for_loader_to_disappear(MAX_LOADER_TIME)
      end
      @tarspect_methods.click_link(menu)
      @tarspect_methods.wait_for_loader_to_disappear(MAX_LOADER_TIME)
      until @tarspect_methods.LINK(menu).get_attribute('class').include? 'active'
        @tarspect_methods.click_link(menu)
        @tarspect_methods.wait_for_loader_to_disappear(MAX_LOADER_TIME)
        count += 1
        break if count > 3
      end
      wait_for_transactions_to_load if ['Payment History', 'Refund'].include? menu
    end

    def click_transactions_tab(menu)
      count = 1
      # raise_if_error_notified
      @tarspect_methods.wait_for_loader_to_disappear(MAX_LOADER_TIME)
      scroll_page('up')
      TRANSACTION_MENU(menu).click
      @tarspect_methods.wait_for_loader_to_disappear(MAX_LOADER_TIME)
      until TRANSACTION_MENU(menu).get_attribute('class').include? 'active'
        scroll_page('up')
        TRANSACTION_MENU(menu).click
        count += 1
        break if count > 3
      end
      @tarspect_methods.wait_for_loader_to_disappear(MAX_LOADER_TIME)
      @transactions_list.is_displayed?(5)
    end

    def get_transaction_id(values)
      @transactions_list.wait_for_element(MAX_LOADER_TIME)
      @wait.until { !@transactions_list.text.gsub("\n", '').gsub("\u200C", '').empty? }
      result = ''
      transaction_id = ''
      @transactions_list.fetch_elements.each do |x|
        result = true
        values.each_value { |y| result &= x.text.gsub("\n", ' ').include?(y) }
        next unless result

        transaction_id = x.attribute('href').split('/')[-1]
        break
      end
      transaction_id.to_i
    end

    def transaction_listed?(transaction_id)
      @tarspect_methods.wait_for_loader_to_disappear
      TRANSACTION(transaction_id).is_displayed?
    end

    def navigate_to_transaction(transaction_id)
      transaction_listed?(transaction_id)
      TRANSACTION(transaction_id).click
      @tarspect_methods.wait_for_loader_to_disappear(MAX_LOADER_TIME)
      @details_tab.wait_for_element
    end

    def get_investor_in_details
      investor = Tarspect::Locator.new(:xpath, "//div/p[text()='Name of the Investor']//following-sibling::p")
      investor.wait_for_element
      investor.text
    rescue
      false
    end

    def verify_assignment_dialog(investor, category)
      assign_investor = Tarspect::Locator.new(:xpath, "//h4[text()='Assign Investor']")
      assign_investor.wait_for_element
      return ASSIGNEE_LIST(investor).text if category == 'status'

      ASSIGNEE_CATEGORY(investor, category).text
    end

    def reassign_investor(investor, reinitiation = false)
      @wait.until { @assign_list.is_displayed? }
      @assign_list.fetch_elements.each do |assignee|
        assignee.click if assignee.text.include? investor
      end
      sleep 1
      unless reinitiation
        @tarspect_methods.BUTTON('Assign Investor').wait_for_element(MIN_LOADER_TIME)
        @tarspect_methods.click_button('Assign Investor')
        sleep 1
        @tarspect_methods.BUTTON('Confirm').wait_for_element(MIN_LOADER_TIME)
        @tarspect_methods.click_button('Confirm')
        sleep 2
      end
      @tarspect_methods.BUTTON('Done').wait_for_element(MIN_LOADER_TIME)
      @tarspect_methods.click_button('Done')
      true
    end

    def verify_vendor_present(vendor_name)
      count = 0
      begin
        raise if @common_pages.VENDOR_INVESTOR_ROW(vendor_name).element.nil?

        return true
      rescue
        50.times do
          $driver.action.send_keys(:down).perform
        end
        count += 1
        retry if count < 5
      end
      false
    end

    def close_modal
      sleep 2
      @close_icon.click
      sleep 2
    end

    def logout
      user_action(action: 'Logout')
      Tarspect::Locator.new(:id, 'username').wait_for_element
    end

    def calculate_relationship_age(diff_in_days)
      return "#{diff_in_days} Days" if diff_in_days < 61
      return "#{diff_in_days / 30} Months" if diff_in_days / 30 < 25
      return "#{diff_in_days / 365} Years" if diff_in_days / 365 < 25
    end

    def switch_to_credit_platform
      @tarspect_methods.wait_for_circular_to_disappear
      @tarspect_methods.wait_for_loader_to_disappear
      @switcher_menu.click
      credit_login = Tarspect::Locator.new(:xpath, "//div[text()='Home']")
      credit_login.wait_for_element
      credit_login.click
      @tarspect_methods.wait_for_circular_to_disappear
      @tarspect_methods.wait_for_loader_to_disappear
      $driver.current_url
    end

    def unzip_file(zip_file)
      files = []
      Zip::File.open(zip_file) do |file|
        file.each do |entry|
          files << entry.name
        end
      end
      files
    end

    def get_zip_file(download_path = $download_path)
      files = Dir["#{download_path}/*.zip"]
      downloadedfile = ''
      files.each do |x|
        downloadedfile = File.basename(x, '.csv')
      end
      downloadedfile
    end

    def PROGRAM_VALUES(field)
      [
        @tarspect_methods.DYNAMIC_TAG(:xpath, "//*[text()='#{field}']//parent::div//*[contains(@class,'text-value')]"),
        @tarspect_methods.DYNAMIC_TAG(:xpath, "//*[text()='#{field}']//parent::div//input")
      ]
    end

    def set_slider_values(element, input_element, value)
      $driver.execute_script('arguments[0].click();', element)
      ele = input_element.fetch_elements[0]
      ele.wait_for_element
      ele.clear_by_backspace
      ele.fill_and_press(value, :tab)
    end

    def configure_slider_in_filter(values)
      values.each_key do |key|
        elements = PROGRAM_VALUES(key)
        set_slider_values(elements[0].fetch_elements[0].element, elements[1], values[key][0])
        set_slider_values(elements[0].fetch_elements[1].element, elements[1], values[key][1]) if values[key].size > 1
      end
    end

    # Onboarding page details
    def select_onboarding_anchor_program(anchor_name, status = nil)
      sleep 2 # DOM is in partially loaded state
      @tarspect_methods.wait_for_loader_to_disappear(MIN_LOADER_TIME)
      anchor = Tarspect::Locator.new(:xpath, "//p[contains(text(),'#{anchor_name}')]")
      anchor.wait_for_element
      if status.nil?
        anchor.click
      else
        status = anchor.element.find_element(:xpath, "//ancestor::button//*[contains(text(),'#{status}')]")
        status.click
      end
    end

    def choose_date_new_format(date)
      year_month = @tarspect_methods.DYNAMIC_TAG(:xpath, "//button[text()='<']/following-sibling::select").fetch_elements
      l_date = Date.parse(date)
      get_selected_value(year_month[0].element, l_date.year.to_s)
      get_selected_value(year_month[1].element, l_date.strftime('%B'))
      @tarspect_methods.DYNAMIC_TAG(:xpath, "//*[contains(@aria-label, '#{l_date.strftime('%B')} #{format('%g', l_date.strftime('%d'))}')]").click
    end

    def get_selected_value(ele, text)
      select_list = Selenium::WebDriver::Support::Select.new(ele)
      select_list.select_by(:text, text)
    end

    def get_each_page_datas(row_number)
      datas = []
      page_datas = @tarspect_methods.DYNAMIC_TAG(:xpath, "//table/tbody/tr/td[#{row_number}]").fetch_elements
      page_datas.each do |row|
        datas << row.text
      end
      datas
    end

    def get_all_page_datas(row_number)
      pages = @tarspect_methods.DYNAMIC_LOCATOR('Page').text.split(' ')
      first_page = []
      for i in (1..pages[3].to_i)
        @tarspect_methods.wait_for_loader_to_disappear(MAX_LOADER_TIME)
        first_page += get_each_page_datas(row_number)
        @tarspect_methods.click_button('Next')
      end
      first_page
    end

    def vendor_present(actor)
      @vendor_details.fetch_elements.each do |x|
        return true if x.text.include?(actor.capitalize)
      end
      false
    end

    def verify_actor_present_in_all_pages(actor, row_number)
      investor_details = get_all_page_datas(row_number).uniq
      flag = true
      investor_details.each do |x|
        flag &= x.include?(actor.capitalize)
      end
      flag
    end

    def fill_date(value1, value2)
      from_month = value1.split(/[-,\s]+/)[1]
      to_month = value2.split(/[-,\s]+/)[1]
      date_value1 = value1.split(/[-,\s]+/)[0]
      date_value2 = value2.split(/[-,\s]+/)[0]
      from_year = value1.split(/[-,\s]+/)[2]
      to_year = value2.split(/[-,\s]+/)[2]
      [[date_value1, from_month, from_year, 1], [date_value2, to_month, to_year, 2]].each do |date|
        @tarspect_methods.DYNAMIC_TAG(:xpath, "(//input[contains(@class, 'react-daterange-picker__inputGroup__day')])[#{date[3]}]").fill_without_clear date[0]
        @tarspect_methods.DYNAMIC_TAG(:xpath, "(//input[contains(@class, 'react-daterange-picker__inputGroup__month')])[#{date[3]}]").fill_without_clear date[1]
        @tarspect_methods.DYNAMIC_TAG(:xpath, "(//input[contains(@class, 'react-daterange-picker__inputGroup__year')])[#{date[3]}]").fill_without_clear date[2]
      end
      @tarspect_methods.DYNAMIC_TAG(:xpath, "(//*[contains(@class,'react-daterange-picker__button')])[1]").click
    end
  end
end
