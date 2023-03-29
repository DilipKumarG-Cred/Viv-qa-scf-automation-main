module Pages
  class Commercials
    attr_accessor :commercials_tab, :query_tab, :submit_btn, :processing_fee_field, :skip_counterparty, :shortlist

    def initialize(driver)
      @driver = driver
      @tarspect_methods = Common::Methods.new(@driver)
      @common_pages = Pages::CommonMethods.new(@driver)
      @wait = Selenium::WebDriver::Wait.new(timeout: MIN_LOADER_TIME)

      # List page
      @add_new = Tarspect::Locator.new(:xpath, "//button[contains(text(),'Add New')]")
      @confirm_remove = Tarspect::Locator.new(:xpath, "//span[text()='Remove']")
      @modal_remove_btn = Tarspect::Locator.new(:xpath, "//button[text()='Remove']")
      @vendor_list = Tarspect::Locator.new(:xpath, "//button[text()='Filter']/../..//following-sibling::ul//ul")
      @filter_results = Tarspect::Locator.new(:xpath, "//div[contains(@class,'fade-in')]//ul//ul")
      @close_icon = Tarspect::Locator.new(:xpath, "//i[contains(@class,'nucleoinvest-close')]")

      # Bulk Import
      @bulk_import = Tarspect::Locator.new(:xpath, "//i[@class='nucleoinvest-upload']")
      @mapping_page = Tarspect::Locator.new(:xpath, "//*[text()='Back to Vendors Upload']")
      @proceed_to_mapping = @tarspect_methods.BUTTON('Proceed to File Mapping')
      @export_summary_report = Tarspect::Locator.new(:xpath, "//span[text()='Export Summary Report']")
      @program_input = @tarspect_methods.DYNAMIC_TAG(:xpath, "//*[text()='Program']/../..//input[not(contains(@type, 'hidden'))]/..")

      # Password page
      @submit_btn = Tarspect::Locator.new(:xpath, "//button[text()='Submit' and not(contains(@class, 'disabled'))]")
      @terms_and_conditions = Tarspect::Locator.new(:name, 'tnc')

      # Onboarding page
      @pan_details = Tarspect::Locator.new(:xpath, "//form//*[text()='PAN']/../..//input")
      @update_btn = Tarspect::Locator.new(:xpath, "//button[text()='Update' and not(contains(@class, 'disabled'))]")
      @account_name = Tarspect::Locator.new(:xpath, "//i[@class='nucleoinvest-account']//following-sibling::div")
      @company_info = Tarspect::Locator.new(:xpath, "//h4[text()='Company Information ']//parent::div")
      @promotor_info = Tarspect::Locator.new(:xpath, "//h4[text()='Promoter Information ']//parent::div")
      @key_managing_info = Tarspect::Locator.new(:xpath, "//h4[text()='Key Management Information ']//parent::div")
      @add_user = Tarspect::Locator.new(:xpath, "//i[@class='nucleoinvest-i-add']")
      @update_btn_add_user = Tarspect::Locator.new(:xpath, "(//button[text()='Update' and not(contains(@class, 'disabled'))])[2]")
      @update_btn_edit_user = Tarspect::Locator.new(:xpath, "(//button[text()='Update' and not(contains(@class, 'disabled'))])[3]")
      @summary_modal = Tarspect::Locator.new(:id, 'modal-root')
      @progress_info = Tarspect::Locator.new(:xpath, "//span[@class='progress-info']/..")
      @business_details_completed = Tarspect::Locator.new(:xpath, "//a[text()='Business Details']//span[@class='done']")
      @documents_completed = Tarspect::Locator.new(:xpath, "//a[text()='Documents']//span[@class='done']")
      @reject_vendor = Tarspect::Locator.new(:xpath, "//*[text()='Reject']")
      @reject_reason = Tarspect::Locator.new(:xpath, "//*[text()='Reason for rejection']/..//following-sibling::div//textarea")

      # Client profile Page
      @company_details = Tarspect::Locator.new(:class, 'tab-panel')
      @loading_text = Tarspect::Locator.new(:xpath, "//p[text()='Loading...']")

      # Vendor details page
      @commercials_tab = Tarspect::Locator.new(:xpath, "//a[text()='Commercials']")
      @query_tab = Tarspect::Locator.new(:xpath, "//a[text()='Query']")

      # Anchor Commercials
      @edit_commercials = Tarspect::Locator.new(:xpath, "//*[text()='Edit']")
      @skip_counterparty = Tarspect::Locator.new(:xpath, "//label[text()='Skip Counter Party Approval']")
      @mandatory_invoice = Tarspect::Locator.new(:xpath, "//label[text()='Mandatory Invoice File Upload']")
      @prepayment_charges = Tarspect::Locator.new(:xpath, "//*[text()='Prepayment Charges']/parent::label")
      @anchor_commercials_page = Tarspect::Locator.new(:xpath, "//*[text()='Interested Investors']")
      @anchor_commercials = Tarspect::Locator.new(:xpath, "//*[text()='Pricing']//ancestor::div[@direction='row']//div[@direction='column']")

      # Processing fee
      @rejected_payments_summary = Tarspect::Locator.new(:xpath, "//*[text()='Rejected Payments']//ancestor::section")
      @processing_fee_field = Tarspect::Locator.new(:xpath, "//input[@type = 'text' and @class = 'form-control']")

      # Pools
      @switch_hamber = Tarspect::Locator.new(:xpath, "//button[@class='switch-hamberg']/i")
      @scf_platform = Tarspect::Locator.new(:xpath, "//h6[text()='Flow']/..")
      @gstn_input = Tarspect::Locator.new(:xpath, "//input[@placeholder='GSTIN here']")
      @password_field = @tarspect_methods.DYNAMIC_LOCATOR('password', '@type')
      @fill_password_box = @tarspect_methods.DYNAMIC_LOCATOR('password protected')
      @correct_password = @tarspect_methods.DYNAMIC_LOCATOR('Password is correct!')
      @incorrect_password = @tarspect_methods.DYNAMIC_LOCATOR('Wrong password. Try again')
      @shortlist = @tarspect_methods.DYNAMIC_XPATH('span', 'text()', 'Shortlisted')
    end

    def BULK_MAPPING_LABEL(key)
      Tarspect::Locator.new(:xpath, "//label[contains(text(),'#{key}')]//parent::td//following-sibling::td")
    end

    def BULK_MAPPING_INPUT(key)
      Tarspect::Locator.new(:xpath, "//label[contains(text(),'#{key}')]//parent::td//following-sibling::td//input")
    end

    def SUMMARY(key)
      Tarspect::Locator.new(:xpath, "//p[text()='#{key}']//following-sibling::p")
    end

    def ANCHOR_SUMMARY(index, key)
      Tarspect::Locator.new(:xpath, "//h3[text()='Summary']/parent::div/div[#{index}]//p[contains(text(),'#{key}')]/preceding-sibling::p")
    end

    # Seed data
    def create_activated_channel_partner(commercials_hash)
      resp = create_channel_partner(commercials_hash)
      raise resp.to_s unless resp[:code] == 200

      result = activate_channel_partner(commercials_hash['Email'])
      clear_cookies
      result ? true : "Error while creating commercials #{result}"
    end

    def create_registered_channel_partner(testdata)
      @commercials_data = testdata['Commercials']
      @company_info = testdata['Company Info']
      @promoter_info = testdata['Promoter Info']
      @km_person_info = testdata['Key Managing Person Info']
      @bank_details = testdata['Bank Details']
      @mandatory_docs = testdata['Documents']['Mandatory Documents']
      resp = create_channel_partner(@commercials_data)
      raise "Error while creating seed vendor, #{resp}" unless resp[:code] == 200

      sleep 2 # for email
      activate_channel_partner(@commercials_data['Email'])
      vendor = @commercials_data['Email'].split('@')[0]
      sleep 5
      set_cookies_api(vendor, @commercials_data['Email'], $conf['users']['anchor']['password'])

      resp = add_company_info(vendor, @company_info)
      raise "Error while adding company info, #{resp}" unless resp[:code] == 200

      resp = add_promoter_info(vendor, @promoter_info)
      raise "Error while adding promoter info, #{resp}" unless resp[:code] == 200

      resp = add_key_manager_info({
                                    anchor_actor: 'anchor',
                                    actor: vendor,
                                    program: @commercials_data['Program'],
                                    km_person_info: @km_person_info
                                  })
      raise "Error while adding KM info, #{resp}" unless resp[:code] == 200

      resp = add_bank_details({
                                anchor_actor: 'anchor',
                                actor: vendor,
                                program: @commercials_data['Program'],
                                bank_details: @bank_details,
                                is_primary: true
                              })
      raise "Error while adding Bank details, #{resp}" unless resp[:code] == 200

      unless testdata['Commercials']['Program'] == 'Dynamic Discounting - Vendor Program'
        result = upload_onbaording_documents({
                                               actor: vendor,
                                               type: 'mandatory_docs'
                                             })
        raise 'Error while uploading documents' unless result
      end
      resp = submit_for_review(vendor)
      raise "Error while Submitting for reivew, #{resp}" unless resp[:code] == 200

      clear_cookies
      true
    rescue => e
      e
    end

    def business_details_completed?(section)
      @tarspect_methods.DYNAMIC_TAG(:xpath, "//*[@class='done']/parent::*[text()='#{section}']").is_displayed?(1)
    end

    def documents_completed?
      @documents_completed.is_displayed?(1)
    end

    def get_progress_info
      @progress_info.text
    end

    def get_account_name
      @account_name.text
    end

    def input_not_editable?(name)
      Tarspect::Locator.new(:xpath, "//form//*[text()='#{name}']/../..//input").get_attribute('disabled') == 'true'
    end

    def verify_required_field(label)
      @tarspect_methods.DYNAMIC_TAG(:xpath, "//*[contains(text(),'#{label}')]/../..//*[text()=' *']").is_displayed?(3)
    end

    def get_name(name)
      Tarspect::Locator.new(:xpath, "//h4[contains(.,'#{name}')]/../../..//button")
    end

    def get_company_info
      @company_info.text
    end

    def get_promoter_info
      @promotor_info.text
    end

    def get_key_managing_info
      @key_managing_info.text
    end

    def choose_program(anchor, program_type, bank_details = false)
      anchor_selection = Tarspect::Locator.new(:xpath, "//*[contains(@class, 'anchor-selection')]")
      program = Tarspect::Locator.new(:xpath, "//div[text()='#{anchor} - #{program_type}']")
      anchor_selection.click
      if bank_details == false
        program.click
      else
        count = program.total_count
        if [2, 1].include?(count)
          Tarspect::Locator.new(:xpath, "(//div[text()='#{anchor} - #{program_type}'])[#{count}]").click
        elsif count > 2
          (count - 1).times do |x|
            Tarspect::Locator.new(:xpath, "(//div[text()='#{anchor} - #{program_type}'])[#{x + 2}]").click
            break if @common_pages.menu_available?('Bank Details')

            anchor_selection.click
          end
        end
      end
      @tarspect_methods.wait_for_circular_to_disappear
    end

    def get_detailed_company_info
      hash = {}
      Tarspect::Locator.new(:xpath, "//form//div[contains(@class,'form-group')]").fetch_elements.each_with_index do |key, index|
        hash[key.text.split("\n")[0]] = Tarspect::Locator.new(:xpath, "(//form//div[contains(@class,'form-group')]//input)[#{index + 1}]").get_attribute('value')
      end
      hash.delete('Vendor Code')
      hash
    end

    def summary_text
      sleep 1
      @summary_modal.text
    end

    def update_onboarding_info(type, data)
      # @common_pages.click_menu(type)
      case type
      when 'Promoter Details'
        @tarspect_methods.DYNAMIC_LOCATOR('Add Promoter').click
        @tarspect_methods.wait_for_loader_to_disappear
        sleep 3
        @tarspect_methods.DYNAMIC_TAG(:name, 'dob').click
        @common_pages.choose_date_new_format(data['DOB'])
        data.delete('DOB')
        @tarspect_methods.fill_form(data, 1, 2)
        @tarspect_methods.click_button('Save')
      when 'Key Managing Person Information'
        @tarspect_methods.DYNAMIC_LOCATOR('Add Key Manager').click
        @tarspect_methods.fill_form(data, 1, 2)
        @tarspect_methods.click_button('Save')
      when 'Bank Details'
        @tarspect_methods.click_button('Add Bank Details')
        @tarspect_methods.fill_form(data, 1, 2)
        # Another way to make primary. commented as of now.
        # @tarspect_methods.DYNAMIC_LOCATOR('Make this the primary bank account for this program').click
        @tarspect_methods.click_button('Save')
      when 'Company Info'
        unless data['Incorporation Date'].nil?
          select_relationship_from_date(data['Incorporation Date'])
          data.delete('Incorporation Date')
        end
        @tarspect_methods.fill_form(data, 1, 2)
      end
      scroll_page('down')
    end

    def make_bank_detail_primary(bank_name)
      @tarspect_methods.DYNAMIC_TAG(:xpath, "//*[text()='#{bank_name}']/ancestor::li//input[@name='primaryAccount']/following-sibling::label").click
    end

    # temp patch for new date component in onboarding module
    def select_relationship_from_date(date)
      value = Date.parse(date).strftime('%B %e').gsub('  ', ' ')
      Tarspect::Locator.new(:xpath, "//*[text()='Incorporation Date']//ancestor::div[contains(@class,'date-input')]").click
      Tarspect::Locator.new(:xpath, "//*[contains(@class,'react-datepicker__day') and not(contains(@class,'disabled')) and contains(@aria-label,'#{value}')]").click
    end

    def edit_person_info(type, name, new_data)
      @common_pages.click_menu(type)
      get_name(name).click
      @tarspect_methods.click_button('Update')
      @tarspect_methods.fill_form(new_data, 1, 2)
      @tarspect_methods.click_button('Save')
    end

    def delete_person_info(type, name)
      @common_pages.click_menu(type)
      get_name(name).click
      Tarspect::Locator.new(:xpath, "//button[contains(text(),'Remove')]").click
    end

    def get_profile_page_vendor_status(status)
      @tarspect_methods.DYNAMIC_XPATH('*', 'text()', status).is_displayed?
    end

    def get_onboarding_page_list(type)
      Tarspect::Locator.new(:xpath, "//*[text()='#{type}']//ancestor::div[contains(@class,'container')]/div[2]").text
    end

    def upload_docs(doc_title_arr, file_name = nil, document_is_present = false)
      flag = true
      error_docs = []
      docs = []
      multiple_docs = ''
      doc_title_arr = doc_title_arr.is_a?(Array) ? doc_title_arr : [doc_title_arr]
      doc_name = ''
      doc_title_arr.each do |doc_title|
        doc_name = file_name ? file_name : doc_title.delete('/')
        docs << if document_is_present
                  doc_title
                else
                  create_test_doc(doc_name)
                end
      end
      docs[0..docs.size - 2].each { |d| multiple_docs += "#{d} \n " } if docs.size > 1
      multiple_docs += docs[docs.size - 1]
      ele = @tarspect_methods.DYNAMIC_TAG(:xpath, '//input')
      ele.wait_for_element
      ele.fill_without_clear multiple_docs
      sleep 10
      @common_pages.raise_if_error_notified
      @tarspect_methods.close_toaster
      delete_docs(doc_title_arr)
      true
    end

    def upload_and_map_docs(doc_title_arr, file_name = nil)
      upload_docs(doc_title_arr, file_name)
      map_docs(doc_title_arr, file_name)
    end

    def map_docs(doc_title_arr, file_name = nil)
      doc_title_arr.each do |doc_title|
        doc_name = file_name ? file_name : doc_title.delete('/')
        raise "#{doc_name} is not uploaded" unless @tarspect_methods.DYNAMIC_TAG(:xpath, "//*[text()='#{doc_name}.pdf']").is_present?

        document_type = @tarspect_methods.DYNAMIC_TAG(:xpath, "//*[text()='#{doc_name}.pdf']/ancestor::div[contains(@class, 'meta')]/following-sibling::div[contains(@class, 'document-type')]")
        document_type.click
        doc_name = doc_name.split('- ')[1] if doc_name.include? 'Promoter'
        @tarspect_methods.DYNAMIC_TAG(:xpath, "//*[contains(@class, 'menu')]//div[@id][contains(text(),'#{doc_name}')]").click
        @common_pages.raise_if_error_notified
      end
      true
    end

    def remove_docs(doc_title_arr)
      flag = true
      error_docs = []
      doc_title_arr = doc_title_arr.is_a?(Array) ? doc_title_arr : [doc_title_arr]

      doc_title_arr.each do |doc_title|
        raise "#{doc_title} is not uploaded" unless @tarspect_methods.DYNAMIC_TAG(:xpath, "//*[text()='#{doc_title}.pdf']").is_present?

        remove = @tarspect_methods.DYNAMIC_TAG(:xpath, "//*[text()='#{doc_title}.pdf']/ancestor::div[contains(@class, 'meta')]/following-sibling::div[contains(@class, 'action')]")
        remove.click
        @common_pages.raise_if_error_notified
      end
      true
    end

    def check_file_uploaded(doc_title_arr)
      check = true
      err_list = []
      doc_title_arr = doc_title_arr.is_a?(Array) ? doc_title_arr : [doc_title_arr]
      doc_title_arr.each do |doc_title|
        check &&= Tarspect::Locator.new(:xpath, "//*[text()='#{doc_title}']/ancestor::div//td[text()='Uploaded']").is_displayed?(2)
        err_list << doc_title if check != true
      end
      check ? check : err_list
    end

    def delete_docs(doc_titles)
      doc_titles = doc_titles.is_a?(Array) ? doc_titles : [doc_titles]
      doc_titles.each do |doc_title|
        doc_name = doc_title.delete('/')
        File.delete("#{Dir.pwd}/#{doc_name}.docx") if File.exist?("#{Dir.pwd}/#{doc_name}.docx")
        File.delete("#{Dir.pwd}/#{doc_name}.xlsx") if File.exist?("#{Dir.pwd}/#{doc_name}.xlsx")
      end
    end

    # Anchor Landing page
    def entity_listed?(name)
      @common_pages.search_program(name)
      Tarspect::Locator.new(:xpath, "//*[text()='#{name}']//ancestor::li").is_displayed?(3)
    end

    def entity_listed_in_current_page?(name)
      @tarspect_methods.wait_for_loader_to_disappear
      @filter_results.wait_for_element
      Tarspect::Locator.new(:xpath, "//*[text()='#{name}']//ancestor::li").is_displayed?(3)
    end

    def scroll_till_commercial(vendor_name)
      count = 1
      until entity_listed_in_current_page?(vendor_name)
        scroll_page('down')
        $driver.action.send_keys(:up).perform
        50.times do
          $driver.action.send_keys(:down).perform
        end
        sleep 2 # DOM is in partially loaded state, below wait will fail on this rare case
        begin
          @wait.until { !@vendor_list.fetch_elements[-1].text.gsub("\n", '').gsub("\u200C", '').empty? }
        rescue
          @wait.until { @vendor_list.get_texts != [] }
        end
        count += 1
        break if count > 10
      end
      @tarspect_methods.wait_for_loader_to_disappear
    end

    # Anchor programs - Vendors list page
    def scroll_till_program(vendor_name)
      count = 1
      until entity_listed_in_current_page?(vendor_name)
        scroll_page('down')
        $driver.action.send_keys(:up).perform
        50.times do
          $driver.action.send_keys(:down).perform
        end
        sleep 3 # DOM is in partially loaded state, below wait will fail on this rare case
        @tarspect_methods.wait_for_loader_to_disappear
        begin
          @wait.until { !@filter_results.fetch_elements[-1].text.gsub("\n", '').gsub("\u200C", '').empty? }
        rescue
          @tarspect_methods.wait_for_loader_to_disappear
          @filter_results.wait_for_element
        end
        count += 1
        break if count > 6
      end
    end

    def get_vendor_details(values)
      scroll_till_commercial(values[:name])
      matched_rows = @tarspect_methods.DYNAMIC_TAG(:xpath, "//*[text()='#{values[:name]}']//ancestor::li[2]")
      matched_row = nil
      matched_rows.fetch_elements.each do |row|
        matched_row = row if row.text.include?(values[:state]) && row.text.include?(values[:program])
      end
      raise "Channel partner #{values[:name]} with #{values[:state]}, #{values[:program]} not found" if matched_row.nil?

      hash = { 'Status' => 0, 'Invite Date' => 1, 'Onboarded Date' => 2 }
      index = hash[values[:field]]
      matched_row.text.split("\n")[index]
    end

    def navigate_to_entity(name, tab_name = nil)
      scroll_till_commercial(name)
      @tarspect_methods.DYNAMIC_XPATH('p', 'text()', name).click
      @tarspect_methods.wait_for_loader_to_disappear(MAX_LOADER_TIME)
      @tarspect_methods.click_link(tab_name) unless tab_name.nil?
      @wait.until { !@company_details.text.gsub("\n", '').gsub("\u200C", '').empty? }
    end

    def add_commercials(commercials_hash)
      @add_new.click
      if commercials_hash['Program'] == 'Dynamic Discounting - Vendor Program'
        bank_details = commercials_hash['Bank Details']
        commercials_hash.delete('Bank Details')
        @tarspect_methods.fill_form(commercials_hash, 1, 2)
        select_bank_details(bank_details)
      else
        @tarspect_methods.fill_form(commercials_hash, 1, 2)
      end
      @submit_btn.click
    end

    def select_bank_details(value)
      present_value = Tarspect::Locator.new(:xpath, "//div[contains(@class,'toggle-button')]//input").attribute('value')
      return true if present_value == value

      Tarspect::Locator.new(:xpath, "//div[contains(@class,'toggle-button')]//i").click
      present_value == value
    end

    def assign_vendor(name, details)
      @common_pages.search_program(name)
      Tarspect::Locator.new(:xpath, "//*[text()='#{name}']//ancestor::li//div[contains(@class,'dropdown-trigger')]").click
      Tarspect::Locator.new(:xpath, "//*[text()='#{name}']//ancestor::li//*[text()='Assign']").click
      @tarspect_methods.fill_form(details, 1, 2)
      @tarspect_methods.click_button('Assign')
    end

    def remove_vendor_from_more_options(type, name)
      @common_pages.click_menu(type)
      scroll_till_commercial(name)
      Tarspect::Locator.new(:xpath, "//*[text()='#{name}']//ancestor::li//div[contains(@class,'dropdown-trigger')]").click
      Tarspect::Locator.new(:xpath, "//*[text()='#{name}']//ancestor::li//*[text()='Remove']").click
    end

    def remove_commercials(type, name)
      @common_pages.click_menu(type)
      return unless entity_listed? name

      Tarspect::Locator.new(:xpath, "//*[text()='#{name}']//ancestor::li//button").click
      @confirm_remove.click
      sleep 2
      @modal_remove_btn.click
    end

    def vendor_removed_msg
      Tarspect::Locator.new(:xpath, "//div[contains(@class, 'success')]//p").text
    end

    def vendor_disabled?(type, name)
      @common_pages.click_menu(type)
      @common_pages.search_program(name)
      multi_select = Tarspect::Locator.new(:xpath, "//*[text()='#{name}']//ancestor::li//button")
      multi_select.element.style('pointer-events') == 'none'
    end

    # Vendor Profile page
    def get_details(menu)
      @tarspect_methods.click_link(menu)
      sleep 1
      @company_details.text
    end

    def verify_uploaded_docs(doc_title_arr)
      @loading_text.wait_until_disappear(5)
      flag = true
      err_list = []
      doc_title_arr = doc_title_arr.is_a?(Array) ? doc_title_arr : [doc_title_arr]
      doc_title_arr.each do |doc_title|
        result = Tarspect::Locator.new(:xpath, "//*[text()='#{doc_title}.pdf']").is_displayed?(1)
        err_list << doc_title unless result
        flag &&= result
      end
      flag ? flag : err_list
    end

    def click_view(view)
      Tarspect::Locator.new(:xpath, "//i[contains(@class,'#{view}')]").click
    end

    def approve_doc(doc_title_arr)
      @loading_text.wait_until_disappear(2)
      errors = []
      doc_title_arr = doc_title_arr.is_a?(Array) ? doc_title_arr : [doc_title_arr]
      doc_title_arr.each do |doc_title|
        doc = Tarspect::Locator.new(:xpath, "//*[text()='#{doc_title}.pdf']/ancestor::div[@class='item']//button[@data-tip='Accept']")
        @wait.until { Tarspect::Locator.new(:xpath, "//div//*[contains(text(), 'Loading')]").element.nil? } # Wait for document to load
        doc.scroll_to_element
        doc.click
        errors << "No success message for #{doc_title}" unless @tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME) == $notifications['DocumentsReviewed']
        @tarspect_methods.wait_for_circular_to_disappear
        Tarspect::Locator.new(:xpath, "//*[text()='#{doc_title}.pdf']/ancestor::div[@class='item']//*[@data-for]").wait_for_element
      end
      errors.empty? ? true : errors
    end

    def reject_and_verify_mail(client_name, doc_title_arr, reject_reason)
      errors = []
      doc_title_arr = doc_title_arr.is_a?(Array) ? doc_title_arr : [doc_title_arr]
      doc_title_arr.each do |doc_title|
        flag = reject_docs([doc_title], reject_reason)
        errors << flag unless flag == true
        flag = rejection_mail(client_name, doc_title)
        errors << flag unless flag == true
      end
      errors.empty? ? true : errors
    end

    def reject_docs(doc_title_arr, reject_reason)
      errors = []
      doc_title_arr = doc_title_arr.is_a?(Array) ? doc_title_arr : [doc_title_arr]
      doc_title_arr.each do |doc_title|
        Tarspect::Locator.new(:xpath, "//*[text()='#{doc_title}.pdf']/ancestor::div[@class='item']//button[@data-tip='Reject']").click
        @tarspect_methods.wait_for_loader_to_disappear
        sleep 2
        @reject_reason.wait_for_element
        @reject_reason.fill reject_reason
        @tarspect_methods.click_button('Submit')
        errors << "No reject notification for #{doc_title}" unless @tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME) == $notifications['DocumentsReviewed']
        @tarspect_methods.wait_for_circular_to_disappear
      end
      errors.empty? ? true : errors
    end

    def reject_vendor(reject_reason)
      @reject_vendor.click
      sleep 1
      @reject_reason.wait_for_element
      @reject_reason.fill reject_reason
      @tarspect_methods.click_button('Submit')
    end

    # Vendor Program list in anchor landing page
    def vendor_program_details(name)
      @common_pages.search_program(name)
      sleep 2
      @tarspect_methods.wait_for_loader_to_disappear
      scroll_till_program(name)
      sleep 3
      @common_pages.verify_vendor_present(name)
      vendor = @common_pages.VENDOR_INVESTOR_ROW(name)
      @wait.until { vendor.text != '' }
      temp = vendor.text.split("\n")
      vendor_values = temp[0] == name ? ['-'] : []
      vendor_values << temp
      vendor_values.flatten!
      {
        'Status' => vendor_values[0],
        'Name' => vendor_values[1],
        'City' => vendor_values[2],
        'Geography' => vendor_values[3],
        'Sector' => vendor_values[4],
        'Relationship Age' => vendor_values[5],
        'Turnover' => vendor_values[6],
        'Live Transaction Count' => vendor_values[7]
      }
    end

    def navigate_to_vendor(name, tab_name = nil)
      scroll_till_program(name)
      vendor = @common_pages.VENDOR_INVESTOR_ROW(name)
      vendor.wait_for_element
      vendor.click
      @tarspect_methods.DYNAMIC_LOCATOR(name).wait_for_element
      @tarspect_methods.click_link(tab_name) unless tab_name.nil?
    end

    def add_vendor_commercials(data, floating: false, edit: false, set_limit: false)
      @tarspect_methods.wait_for_loader_to_disappear(MAX_LOADER_TIME)
      unless set_limit
        @commercials_tab.click
        @tarspect_methods.click_button('Edit')
      end
      @tarspect_methods.BUTTON('Save as Draft').scroll_to_element
      @tarspect_methods.fill_form({ 'Agreement Validity ' => data['Agreement Validity'][0] }, 1, 1)
      @tarspect_methods.fill_form({ 'Agreement Validity ' => data['Agreement Validity'][1] }, 2, 1)
      data.delete('Agreement Validity')
      @tarspect_methods.fill_form({ 'Effective Date' => data['Effective Date'] }, 1, 2)
      data.delete('Effective Date')
      @processing_fee_field.fill data['Processing Fee']
      if data['Processing Fee'] != 0
        @tarspect_methods.DYNAMIC_XPATH('input', '@placeholder', 'Enter Amount').fill data['Sanction Limit']
      end
      data.delete('Processing Fee')
      depth = edit ? 2 : 1
      @tarspect_methods.fill_form(data, depth, 2)
      Tarspect::Locator.new(:id, 'mclr-radio').click if floating
      @tarspect_methods.click_button('Save as Draft')
    end

    def bulk_import_vendors(program)
      valid_vendors, expected_hash, file, menu = generate_bulk_vendor(program)
      @common_pages.click_menu(menu)
      @bulk_import.click
      sleep 1
      @tarspect_methods.DYNAMIC_TAG(:xpath, "//div[@id='modal-root']//div[@class][text()='Program']").is_displayed?(10)
      click_program_input
      sleep 0.5
      selected_program = @tarspect_methods.DYNAMIC_TAG(:xpath, "//div[contains(@class, 'menu')]//div[contains(@id, 'option')][text()='#{program}']")
      selected_program.click
      @common_pages.file_input.wait_for_element(5)
      @common_pages.file_input.fill_without_clear file
      @export_summary_report.wait_for_element
      [valid_vendors, expected_hash]
    end

    def bulk_import_by_product_user(file)
      @bulk_import.click
      sleep 1
      @tarspect_methods.DYNAMIC_TAG(:xpath, "//div[@id='modal-root']//div[@class][text()='Program']").is_displayed?(10)
      @common_pages.file_input.wait_for_element(5)
      @common_pages.file_input.fill_without_clear file
      @export_summary_report.wait_for_element
    end

    def initiate_bulk_import(file, program)
      @bulk_import.click
      sleep 1
      import_modal = @tarspect_methods.DYNAMIC_TAG(:xpath, "//div[@id='modal-root']//h1[text()='Import CSV/Excel for Adding vendors']")
      raise 'Modal is not displayed' unless import_modal.is_displayed?(MIN_LOADER_TIME)

      click_program_input
      sleep 0.5
      program = @tarspect_methods.DYNAMIC_TAG(:xpath, "//div[contains(@class, 'menu')]//div[contains(@id, 'option')][text()='#{program}']")
      program.click
      @common_pages.file_input.wait_for_element
      @common_pages.file_input.fill_without_clear file
      @export_summary_report.wait_for_element
      sleep 2 # DOM take some time to load the report links
    end

    def download_bulk_import_template(program)
      @bulk_import.click
      sleep 1
      @summary_modal.wait_for_element(MIN_LOADER_TIME)
      raise 'Program input is not displayed' unless @program_input.is_displayed?(MIN_LOADER_TIME)

      click_program_input
      sleep 0.5
      program = @tarspect_methods.DYNAMIC_TAG(:xpath, "//div[contains(@class, 'menu')]//div[contains(@id, 'option')][text()='#{program}']")
      program.click
      @common_pages.file_input.wait_for_element
      sleep 2
      @tarspect_methods.click_link('Download Template')
    end

    def click_program_input
      count = 0
      begin
        @program_input.click
      rescue
        retry if count < 5
        count += 1
      end
    end

    def download_summary_report(download_path = $download_path)
      raise 'Export Summary report is not displayed' unless @export_summary_report.is_displayed?(MIN_LOADER_TIME)

      @export_summary_report.click
      @tarspect_methods.file_downloaded?("#{download_path}/report.xlsx", MIN_LOADER_TIME)
    end

    def get_summary_report_link
      Tarspect::Locator.new(:xpath, "//*[@class='export-button'][@href]").get_attribute('href')
    end

    def verify_no_of_invitations(number)
      Tarspect::Locator.new(:xpath, "//*[contains(text(),'#{number} Invitation(s) Sent!')]").is_displayed?(2)
    end

    # Anchor investor page
    def set_counterparty_status(anchor_name, investor_name, status)
      navigate_to_anchor_commercials(anchor_name, investor_name)
      return true if get_anchor_commercial_details['Skip Counter Party Approval'] == status.capitalize

      @edit_commercials.click
      sleep 2
      @skip_counterparty.scroll_to_element
      @tarspect_methods.fill_form({ 'Skip Counter Party Approval' => status.capitalize })
      @submit_btn.click
    end

    def set_mandatory_invoice(anchor_name, investor_name, status)
      navigate_to_anchor_commercials(anchor_name, investor_name)
      return true if get_anchor_commercial_details['Mandatory Invoice File'] == status.capitalize

      @edit_commercials.click
      sleep 2
      @mandatory_invoice.scroll_to_element
      @tarspect_methods.fill_form({ 'Mandatory Invoice File Upload' => status.capitalize })
      @submit_btn.click
    end

    def navigate_to_anchor_commercials(anchor_name, investor_name)
      return if @anchor_commercials_page.is_displayed?(2)

      @common_pages.click_menu(MENU_ANCHOR_LIST)
      @common_pages.navigate_to_anchor(anchor_name)
      @common_pages.select_program('Invoice Financing', 'Vendor')
      @common_pages.click_live_investors
      @common_pages.VENDOR_INVESTOR_ROW(investor_name).click
      sleep 1
    end

    def check_anchor_commercial_cannot_be_edited
      @tarspect_methods.wait_for_loader_to_disappear
      @anchor_commercials.wait_for_element
      if @anchor_commercials.is_displayed?
        edit_button = Tarspect::Locator.new(:xpath, "//button[text()='Edit']")
        return false if edit_button.is_displayed?(2)

        true
      else
        false
      end
    rescue
      false
    end

    def get_anchor_commercial_details
      count = 0
      begin
        @tarspect_methods.wait_for_loader_to_disappear
        @anchor_commercials.wait_for_element
        @wait.until { !@anchor_commercials.text.gsub("\n", '').gsub("\u200C", '').empty? }
        @anchor_commercials.get_texts.map { |x| x.split("\n") }.to_h
      rescue
        sleep 4
        count += 1
        retry unless count > 3
      end
    end

    def add_investor_anchor_commercials(commercials_hash, edit = false)
      depth2 = {
        'Recourse' => commercials_hash['Recourse'],
        'Margin' => commercials_hash['Margin'],
        'Prepayment Charges' => commercials_hash['Prepayment Charges'],
        'Door-To-Door Tenor' => commercials_hash['Door-To-Door Tenor']
      }
      depth1 = {
        'Interest Strategy ' => commercials_hash['Interest Strategy'],
        'Liability ' => commercials_hash['Liability'],
        'Disburse By ' => commercials_hash['Disburse By'],
        'Mandatory Invoice File Upload' => commercials_hash['Mandatory Invoice File Upload'],
        'Skip Counter Party Approval' => commercials_hash['Skip Counter Party Approval'],
        'Interest Calculation Strategy' => commercials_hash['Interest Calculation Strategy'],
        'Door-To-Door Tenor' => commercials_hash['Door-To-Door Tenor']
      }
      depth1.merge!('Interest Calculation Rest' => commercials_hash['Interest Calculation Rest']) if commercials_hash['Interest Calculation Strategy'] == 'Compound Interest'
      @tarspect_methods.wait_for_loader_to_disappear
      @edit_commercials.click
      @tarspect_methods.wait_for_loader_to_disappear
      sleep 2
      fill_pricing(commercials_hash['Pricing Min'], commercials_hash['Pricing Max'])
      if edit
        @tarspect_methods.fill_form(depth2, 2, 2)
        @skip_counterparty.scroll_to_element
        hash = {
          'Penal Charges' => commercials_hash['Penal Charges'],
          'Max Sanction Limit' => commercials_hash['Max Sanction Limit'],
          'Program Code' => commercials_hash['Program Code']
        }
        @tarspect_methods.fill_form(hash, 2, 2)
        @prepayment_charges.scroll_to_element
        @tarspect_methods.fill_form({ 'Maximum Tenor ' => commercials_hash['Maximum Tenor '] }, 1, 2)
      else
        @tarspect_methods.fill_form(depth2, 1, 2, true)
        @skip_counterparty.scroll_to_element
        hash = { 'Maximum Tenor ' => commercials_hash['Maximum Tenor '] }
        @tarspect_methods.fill_form(hash, 1, 2)
        hash = {
          'Penal Charges' => commercials_hash['Penal Charges'],
          'Max Sanction Limit' => commercials_hash['Max Sanction Limit'],
          'Program Code' => commercials_hash['Program Code']
        }
        @tarspect_methods.fill_form(hash, 1, 2, true)
      end
      @tarspect_methods.fill_form(commercials_hash['date_range'][0], 1, 1)
      @tarspect_methods.fill_form(commercials_hash['date_range'][1], 2, 1)
      @skip_counterparty.scroll_to_element
      @tarspect_methods.fill_form({ 'Effective Date' => commercials_hash['Effective Date'] }, 2, 2, true)
      @tarspect_methods.fill_form(depth1, 1, 1, true)
      @tarspect_methods.click_button('Save as Draft')
    end

    def fill_pricing(min, max)
      @min_range = Tarspect::Locator.new(:xpath, "//*[contains(@class,'range-slider')]//input[1]")
      @max_range = Tarspect::Locator.new(:xpath, "//*[contains(@class,'range-slider')]//input[2]")
      @min_range.clear_by_backspace
      @min_range.send_keys min
      @max_range.clear_by_backspace
      @max_range.send_keys max
    end

    def upload_mou(file)
      @common_pages.file_input.fill_without_clear file
    end

    def edit_commercials_available?
      @edit_commercials.is_displayed?(2) && @edit_commercials.attribute('disabled') != 'true'
    end

    # Vendor Investor page
    def approve_commercials(investor = $conf['investor_name'])
      @common_pages.VENDOR_INVESTOR_ROW(investor).click
      @tarspect_methods.click_button('Accept Commercials')
    end

    def check_field_in_vendor_commercial(fields = [])
      fields.each do |field|
        loc = Tarspect::Locator.new(:xpath, "//div[text()='Commercials']/ancestor::div[2]//div[text()='#{field}']")
        validate = loc.is_displayed?(5)
        raise "#{field} present, Ideally it should not be present for other than Investor page" if validate
      end
    end

    def record_processing_fee(details, file = nil, second_payment = false)
      unless second_payment
        @tarspect_methods.click_button('Record Payment')
        @tarspect_methods.click_button('Submit & Proceed To Payment')
      end
      @common_pages.file_input.wait_for_element(MIN_LOADER_TIME)
      @common_pages.file_input.fill_without_clear file unless file.nil?
      @tarspect_methods.fill_form(details, 1, 2)
      Tarspect::Locator.new(:xpath, "(//button[@type='submit'])[2]").click
    end

    def upload_bd(file)
      @common_pages.file_input.wait_for_element(MIN_LOADER_TIME)
      @common_pages.file_input.fill_without_clear file
    end

    def rejected_processing_fee_present?(reason)
      rejected_pf = Tarspect::Locator.new(:xpath, "//*[contains(@class,'rejected')]")
      rejected_pf.text.include?('Your Payment has been rejected!') &&
        rejected_pf.text.include?(reason)
    end

    def rejected_reason_on_processing_fee_slider?(reason)
      rejected_pf = Tarspect::Locator.new(:xpath, "//div[contains(@id,'modal')]//*[contains(@class,'nucleoinvest-c-info')]//following-sibling::div")
      rejected_pf.text.include?('Your Payment has been rejected') &&
        rejected_pf.text.include?(reason)
    end

    def open_rejected_payments
      Tarspect::Locator.new(:xpath, "//*[@class='rejected-link']").click
      sleep 2
    end

    def verify_rejected_payments_summary(values)
      @wait.until { !@rejected_payments_summary.text.gsub("\n", '').gsub("\u200C", '').empty? }
      summary_text = @rejected_payments_summary.text
      errors = []
      values.each do |value|
        result = summary_text.include? value
        errors << "Unable to find #{value} in #{summary_text}" unless result
      end
      errors.empty? ? true : errors
    end

    def close_reject_summary_modal
      Tarspect::Locator.new(:xpath, "//*[text()='Rejected Payments']//following-sibling::button").click
      sleep 2
    end

    # Investor view
    def open_processing_fee_details(name)
      @tarspect_methods.wait_for_loader_to_disappear(MAX_LOADER_TIME)
      verify_now = Tarspect::Locator.new(:xpath, "//p[contains(text(),'#{name}')]//button[text()='Verify Now']")
      verify_now.scroll_to_element
      verify_now.click
    end

    def verify_processing_fee(name)
      retries = 0
      begin
        open_processing_fee_details(name)
        accept_button = Tarspect::Locator.new(:xpath, "//button[text()='Accept']")
        accept_button.wait_for_element(MIN_LOADER_TIME)
        raise 'Accept button is not displayed' unless accept_button.is_displayed?

        @tarspect_methods.click_button('Accept')
      rescue
        refresh_page
        retries += 1
        retry if retries < 2
      end
    end

    # Vendor activation
    def activate_channel_partner(email)
      email_values = { mail_box: $conf['activation_mailbox'], subject: $notifications['Mail_Welcome_Subject'], body: email }
      activation_link = $activation_mail_helper.get_activation_link(email_values)
      sleep 30 # For data reflection of new channel partners
      navigate_to(activation_link)
      @tarspect_methods.set_new_password('Think@123')
      @tarspect_methods.wait_for_loader_to_disappear
      clear_cookies
      true
    rescue => e
      raise "Error in Vendor Activation #{e}"
    end

    def capture_anchor_summary(category)
      index = category == 'General' ? 1 : 2
      hash = {}
      hash['Vendors Disbursed'] = ANCHOR_SUMMARY(index, 'Vendors Disbursed').text.to_i
      hash['First Disbursal'] = ANCHOR_SUMMARY(index, 'First Disbursal').text
      hash['Amount Outstanding as of '] = remove_comma_in_numbers(ANCHOR_SUMMARY(index, 'Amount Outstanding as of ').text)
      hash['Overdues as of '] = remove_comma_in_numbers(ANCHOR_SUMMARY(index, 'Overdues as of ').text)
      hash['Max DPD'] = ANCHOR_SUMMARY(index, 'Max DPD').text.to_i
      hash['Number of Live Transactions'] = ANCHOR_SUMMARY(index, 'Number of Live Transactions').text.to_i
      hash
    end

    def capture_program_limits
      total_limit = Tarspect::Locator.new(:xpath, "//*[text()='Total Sanction Limit']/../..//*[contains(text(),'₹')]")
      total_limit = total_limit.text.gsub(',', '').gsub(' ', '').gsub('₹', '').gsub('CR', '')
      program_limit = Tarspect::Locator.new(:xpath, "//p[text()='Total Program Limit']//following-sibling::p")
      program_limit = program_limit.text.gsub(',', '').gsub(' ', '').gsub('₹', '').gsub('CR', '')
      [total_limit, program_limit]
    end

    def create_scf_login
      @tarspect_methods.wait_for_circular_to_disappear(MAX_LOADER_TIME)
      @tarspect_methods.wait_for_loader_to_disappear
      @switch_hamber.wait_for_element
      @switch_hamber.click
      @scf_platform.wait_for_element
      @scf_platform.click
      sleep 1
      @tarspect_methods.wait_for_circular_to_disappear
      @tarspect_methods.wait_for_loader_to_disappear
    end

    def get_status_documents_in_onboarding
      docs = @tarspect_methods.DYNAMIC_TAG(:xpath, "//*[@class = 'list-sub-group-required']/parent::p").fetch_elements
      list = []
      docs.each { |doc| list << doc.text }
      list
    end

    def get_uploaded_document_size
      @tarspect_methods.DYNAMIC_TAG(:xpath, "//*[@class = 'list-sub-group-required']/parent::p/*[contains(@class,'check')]").fetch_elements
    end

    def select_checkbox(values, drop_reason)
      values.each do |value|
        @tarspect_methods.DYNAMIC_XPATH('span', 'text()', value).click
        if value == 'Other'
          drop_message = @tarspect_methods.DYNAMIC_TAG(:xpath, '//textarea')
          drop_message.fill drop_reason
        end
      end
    end

    def check_drop(value, drop_reason)
      @tarspect_methods.click_button(value)
      checkbox_values = ['CIBIL issues', 'Crime check failed', 'Other']
      @tarspect_methods.wait_for_loader_to_disappear(MAX_LOADER_TIME)
      select_checkbox(checkbox_values, drop_reason)
      @tarspect_methods.click_button('Submit')
      message = @tarspect_methods.DYNAMIC_LOCATOR('Channel Partner dropped.')
      @tarspect_methods.wait_for_loader_to_disappear(MAX_LOADER_TIME)
      drop = @tarspect_methods.DYNAMIC_XPATH('span', 'text()', 'Dropped')
      drop.mouse_hover
      drop_hover_message = @tarspect_methods.DYNAMIC_XPATH('div', 'text()', checkbox_values[0]).text
      actual_data = drop_hover_message.split("\n")
      [message, actual_data]
    end

    def check_shortlist
      click_here = @tarspect_methods.DYNAMIC_XPATH('span', 'text()', 'Click here')
      click_here.click
      @tarspect_methods.wait_for_loader_to_disappear(MAX_LOADER_TIME)
      message = @tarspect_methods.DYNAMIC_LOCATOR('Channel Partner shortlisted.')
      drop_button = @tarspect_methods.DYNAMIC_XPATH('button', 'text()', 'Drop').is_displayed?
      set_limit_button = @tarspect_methods.DYNAMIC_XPATH('button', 'text()', 'Set Limit').is_displayed?
      [message, @shortlist.text, drop_button, set_limit_button]
    end

    def fill_password(password)
      @password_field.clear_by_backspace
      @password_field.fill password
      @fill_password_box.click
      if password.eql?('Think@123')
        @correct_password.text
      else
        @incorrect_password.text
      end
    end
  end
end
