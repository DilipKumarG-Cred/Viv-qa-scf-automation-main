module Api
  module VendorOnboarding
    # Cleanup commercials
    def delete_channel_partner(program_type, entity_list, actor = 'anchor')
      program_id = {
        'Vendor' => 1,
        'Dealer' => 2
      }
      return true if entity_list.dup.flatten.nil?
      return true if entity_list.dup.flatten.empty?

      p "About to cleanup #{program_type}: #{entity_list}"
      delete_vendor({ program_id: program_id[program_type], program_type: program_type, vendors: entity_list, actor: actor })
    end

    def set_vendor_cookies(email)
      driver = Tarspect::Browser.new($conf['browser']).invoke
      tarspect_methods = Common::Methods.new(driver)
      navigate_to($conf['base_url'])
      tarspect_methods.login(email, $conf['users']['anchor']['password'])
      set_driver_cookie(email.split('@')[0], driver)
      driver.quit
      # to revert back the driver to initial browser
      # everytime $driver is overridden on browser invoke
      $driver = @driver
    end

    def get_anchor_programs(program, anchor_actor)
      group = program.split(' - ')[0]
      type = program.split(' - ')[1].split(' Program')[0]
      resp = resp = fetch_anchor_programs(anchor_actor)
      a_prg = resp[:body].select { |x| x[:program_group] == group && x[:program_type] == type }[0]
      a_prg[:anchor_program_id]
    end

    def fetch_list_all_vendors(program_type, actor, vendor_name = nil)
      page = 1
      vendors = []
      hash = {}
      hash['headers'] = load_headers(actor)
      hash['uri'] = $conf['api_url'] + $endpoints['anchor']['list_all_vendors']
      hash['headers'][:params] = { page: page, program_type: program_type, items: 10 }
      hash['user_defined'] = { timeout: 9000000 }
      if vendor_name.nil?
        loop do
          hash['headers'][:params].merge!(page: page)
          resp = ApiMethod('fetch', hash)[:body]
          vendors << resp[:vendors]
          break if page == resp[:pagy_params][:pages]

          page += 1
        end
      else
        hash['headers'][:params].merge!(vendor_name: vendor_name)
        resp = ApiMethod('fetch', hash)[:body]
        vendors << resp[:vendors]
      end
      vendors.flatten!
    end

    def api_get_vendor_details(actor, values = nil)
      hash = {}
      hash['headers'] = load_headers(actor)
      hash['uri'] = $conf['api_url'] + $endpoints['vendor']['vendor_details']
      hash['headers'][:params] = { anchor_program_id: values[:anchor_program_id], vendor_detail_id: values[:vendor_detail_id], id: values[:id] } unless values.nil?
      hash['user_defined'] = { timeout: 9000000 }
      ApiMethod('fetch', hash)
    end

    def bank_details_mandatory?(values)
      hash = {}
      anchor_program_id = get_anchor_programs(values[:program], values[:anchor])
      vendor_list = fetch_list_all_vendors('Vendor', values[:anchor], values[:vendor])
      vendor_details = vendor_list.select { |x| x[:name] == values[:vendor] }
      hash['headers'] = load_headers(values[:anchor])
      hash['uri'] = $conf['api_url'] + $endpoints['anchor']['document_metadata']
      hash['headers'][:params] = { 'anchor_program_id': anchor_program_id, 'vendor_id': vendor_details[0][:id] }
      resp = ApiMethod('fetch', hash)
      bank_details = resp[:body][:business_detail_metadata].select { |x| x[:business_detail] == 'bank_details' }[0]
      bank_details[:is_business_detail_required]
    end

    def create_channel_partner(vendor_hash)
      hash = {}
      hash['uri'] = $conf['api_url'] + $endpoints['anchor']['create']
      actor = vendor_hash['actor'].nil? ? 'anchor' : vendor_hash['actor']
      hash['headers'] = load_headers(actor)
      hash['headers'] = add_content_type_json(hash['headers'])
      anchor_program_id = get_anchor_programs(vendor_hash['Program'], actor)
      gst = vendor_hash['GST'].nil? ? '' : vendor_hash['GST']
      hash['payload'] = {
        anchor: {
          name: vendor_hash['Entity Name'],
          email: vendor_hash['Email'],
          gstn: vendor_hash['GSTN'],
          gst: gst,
          anchor_program_id: anchor_program_id,
          is_bank_details_mandatory: vendor_hash['Bank Details']
        }
      }
      hash['payload'] = JSON.dump(hash['payload'])
      ApiMethod('create', hash)
    end

    def seed_bulk_vendor(vendor_hash)
      hash = {}
      hash['uri'] = $conf['api_url'] + $endpoints['anchor']['create_bulk_vendor']
      actor = vendor_hash['actor'].nil? ? 'anchor' : vendor_hash['actor']
      hash['headers'] = load_headers(actor)
      anchor_program_id = if vendor_hash['Program'].nil? || !vendor_hash['Program'].include?(' - ')
                            vendor_hash['Program']
                          else
                            get_anchor_programs(vendor_hash['Program'], actor)
                          end
      document = begin
        File.new(vendor_hash['document'], 'rb')
      rescue
        vendor_hash['document']
      end
      hash['payload'] = {
        'vendor_file[document]' => document,
        'vendor_file[anchor_program_id]' => anchor_program_id
      }
      ApiMethod('create', hash)
    end

    def get_vendor_file_status(actor, id)
      hash = {}
      hash['uri'] = $conf['api_url'] + construct_base_uri($endpoints['anchor']['bulk_vendor_status'], id.to_s)
      hash['headers'] = load_headers(actor)
      ApiMethod('fetch', hash)
    end

    def wait_till_vendor_import_file_processed(values)
      status_resp = get_vendor_file_status(values[:actor], values[:id])
      count = 0
      until status_resp[:body][:state] == values[:expected_state]
        break if status_resp[:body][:state] == 'failed'

        sleep 5
        status_resp = get_vendor_file_status(values[:actor], values[:id])
        count += 1
        break if count > 5
      end
      count = 0
      while status_resp[:body][:report_url].nil?
        sleep 5
        status_resp = get_vendor_file_status(values[:actor], values[:id])
        count += 1
        break if count > 5
      end
      status_resp[:body][:state]
    end

    def add_company_info(actor, company_info)
      entity_type = {
        'Individual' => 'individual',
        'Sole Proprietorship' => 'sole_proprietorship',
        'Partnership' => 'partnership',
        'Private Limited' => 'private_limited',
        'Llp' => 'llp',
        'Limited Compay' => 'limited_compay'
      }
      hash = {}
      hash['uri'] = $conf['api_url'] + $endpoints['vendor']['add_company_info']
      hash['headers'] = load_headers(actor)
      vendor_details = api_get_vendor_details(actor)[:body]
      hash['payload'] = {
        vendor: {
          name: vendor_details[:vendor_detail][:name],
          gstn: vendor_details[:vendor_detail][:gstn],
          pan: vendor_details[:pan],
          vendor_code: vendor_details[:anchor_program_vendor_detail][:vendor_code],
          vendor_detail_id: vendor_details[:vendor_detail][:id],
          anchor_program_id: vendor_details[:anchor_program][:id],
          city: company_info['City'],
          geography: company_info['Geography'].downcase,
          sector: company_info['Sector'],
          registration_type: company_info['Registration Type'].downcase,
          address_type: company_info['Address Type'].downcase,
          zipcode: company_info['Zipcode'],
          state: company_info['State'],
          registered_address: company_info['Registered Address'],
          country: 'India'
        }
      }
      hash['payload'][:vendor][:entity_type] = entity_type[company_info['Entity Type']] unless company_info['Entity Type'].nil?
      hash['payload'][:vendor][:contact_no] = company_info['Phone Number'] unless company_info['Phone Number'].nil?
      hash['payload'][:vendor][:incorporation_date] = Date.strptime(company_info['Incorporation Date'], '%d-%b-%Y').strftime('%d,%b %Y') unless company_info['Incorporation Date'].nil?
      hash['payload'][:vendor][:uam] = company_info['UAM'] unless company_info['UAM'].nil?
      ApiMethod('create', hash)
    end

    def add_promoter_info(actor, promoter_hash)
      hash = {}
      hash['uri'] = $conf['api_url'] + $endpoints['vendor']['add_promoter']
      hash['headers'] = load_headers(actor)
      hash['payload'] = {
        "vendor": {
          "promoter_info": [
            {
              "name": promoter_hash['Full Name'],
              "contact": promoter_hash['Phone Number'],
              "shareholding_percentage": promoter_hash['Shareholding'].to_i,
              "salutation": promoter_hash['Salutation'].downcase,
              "pan": promoter_hash['PAN'],
              "email": promoter_hash['Email Id'],
              "address": promoter_hash['Address'],
              "state": promoter_hash['State'],
              "city": promoter_hash['City'],
              "zipcode": promoter_hash['Zipcode'],
              "address_type": promoter_hash['Address Type'].downcase,
              "gender": promoter_hash['Gender'].downcase,
              "dob": promoter_hash['DOB'],
              "marital_status": promoter_hash['Marital Status'].downcase
            }
          ]
        }
      }
      ApiMethod('create', hash)
    end

    def add_key_manager_info(values)
      hash = {}
      hash['uri'] = $conf['api_url'] + $endpoints['vendor']['add_km_person']
      hash['headers'] = load_headers(values[:actor])
      anchor_program_id = get_anchor_programs(values[:program], values[:anchor_actor])
      vendor_detail_id = api_get_vendor_details(values[:actor])[:body][:vendor_detail][:id]
      kms = values[:km_person_info].is_a?(Array) ? values[:km_person_info] : [values[:km_person_info]]
      hash['payload'] = {
        vendor: {
          vendor_detail_id: vendor_detail_id,
          anchor_program_id: anchor_program_id,
          key_managing_persons_info: nil
        }
      }
      km_infos = []
      kms.each do |km|
        km_infos << {
          name: km['Full Name'],
          contact: km['Phone Number'],
          designation: km['Designation'],
          email: km['Email Id']
        }
      end
      hash['payload'][:vendor][:key_managing_persons_info] = km_infos
      ApiMethod('create', hash)
    end

    def add_bank_details(values)
      hash = {}
      hash['uri'] = $conf['api_url'] + $endpoints['vendor']['add_bank_details']
      hash['headers'] = load_headers(values[:actor])
      anchor_program_id = get_anchor_programs(values[:program], values[:anchor_actor])
      vendor_detail_id = api_get_vendor_details(values[:actor])[:body][:vendor_detail][:id]
      hash['payload'] = {
        "vendor": {
          "vendor_detail_id": vendor_detail_id,
          "anchor_program_id": anchor_program_id,
          "account_number": values[:bank_details]['Account Number'],
          'bank_name': values[:bank_details]['Bank Name'],
          'ifsc_code': values[:bank_details]['IFSC Code']
        }
      }
      hash['payload'][:vendor].merge!('is_primary': true) unless values[:is_primary].nil?
      ApiMethod('update', hash)
    end

    def get_required_docs(type = nil, sub_type = nil)
      documents = {
        'mandatory_docs' => {
          'gst_certificate' => 'GST Certificate',
          'entity_pan' => 'Entity PAN',
          'promoter_pan' => 'Promoter 1 - Promoter PAN',
          'promoter_aadhar' => 'Promoter 1 - Promoter Aadhaar'
        },
        'company_kyc' => {
          'utility_bill' => 'Utility Bill',
          'gst_certificate' => 'GST Certificate',
          'entity_pan' => 'Entity PAN',
          'lease_rent_agreement' => 'Lease Rent Agreement',
          'certificate_of_incorporation' => 'Certificate Of Incorporation',
          'aoa' => 'AOA',
          'moa' => 'MOA',
          'partnership_deed' => 'Partnership Deed',
          'other_documents' => 'Other Documents'
        },
        'promoter_kyc' => {
          'promoter_aadhar' => 'Promoter 1 - Promoter Aadhaar',
          'promoter_pan' => 'Promoter 1 - Promoter PAN',
          'promoter_photograph' => 'Promoter 1 - Promoter Photograph'
        },
        'financials' => {
          'it_returns' => 'IT returns (Last 1 Year)',
          'audited_balance_sheet' => 'Audited Balance Sheet (Last 1 Year)',
          'audited_profit_and_loss_statement' => 'Audited Profit And Loss Statement (Last 1 Year)'
        },
        'bank_statements' => {
          'current_bank_account' => 'Current Bank Account (Last 6 Months)',
          'cc_bank_account' => 'CC Bank Account (Last 6 Months)'
        },
        'gst_returns' => {
          'gst_return' => 'GST Return (Last 12 Months)'
        }
      }
      # return all docs if no input
      return documents if type.nil?
      # return all docs of particular type is given and no sub_type provided
      return { type => documents[type] } if sub_type.nil?

      # return only the exact type and sub_type document if both are provided
      { type => { sub_type => documents[type][sub_type] } }
    end

    def upload_onbaording_documents(values)
      doc_hash = get_required_docs(values[:type], values[:sub_type])
      doc_hash.each do |e_type, e_sub_type|
        e_sub_type.each do |doc_sub_type, doc_title|
          file = create_test_doc(doc_title)
          hash = {}
          hash['uri'] = $conf['api_url'] + $endpoints['vendor']['upload_docs']
          hash['headers'] = load_headers(values[:actor])
          hash['payload'] = { multipart: true, "doc_date": Date.today.strftime('%Y-%m-%d'), "document[]": File.new(file, 'rb') }
          resp = ApiMethod('create', hash)
          raise "Document not uploaded for #{e_type} - #{doc_sub_type} - #{doc_title} [Error: #{resp}]" unless resp[:code] == 201

          # Set type to the documents uploaded
          resp = list_all_onboarding_documents(values[:actor])
          matched_doc = resp[:body][:onboarding_documents].select { |doc| doc[:file_name].include? doc_title }
          document_id = matched_doc[0][:id]
          found_key = ''
          full_docs = get_required_docs
          full_docs.each do |k, v|
            v.each_key { |v_k| found_key = k if v_k == doc_sub_type && k != 'mandatory_docs' }
          end
          update_values = { document_id: document_id, doc_date: Date.today.strftime('%Y-%m-%d'),
                            doc_type: found_key, doc_sub_type: doc_sub_type, actor: values[:actor] }
          update_values.merge!(promoter_id: api_get_vendor_details(values[:actor])[:body][:promoters][0][:id]) if found_key == 'promoter_kyc'
          resp = update_doc_type(update_values)
          raise resp.to_s unless resp[:code] == 200
        end
      end
      true
    rescue => e
      e
    end

    def list_all_onboarding_documents(actor)
      hash = {}
      hash['uri'] = $conf['api_url'] + $endpoints['vendor']['list_onboarding_documents']
      hash['headers'] = load_headers(actor)
      ApiMethod('fetch', hash)
    end

    def update_doc_type(values)
      hash = {}
      hash['uri'] = $conf['api_url'] + construct_base_uri($endpoints['vendor']['update_document_type'], values[:document_id].to_s)
      hash['headers'] = load_headers(values[:actor])
      hash['payload'] = {
        multipart: true,
        doc_date: values[:doc_date],
        doc_sub_type: values[:doc_sub_type],
        doc_type: values[:doc_type]
      }
      hash['payload'].merge!(promoter_id: values[:promoter_id]) unless values[:promoter_id].nil?
      ApiMethod('update', hash)
    end

    def create_test_doc(doc_title)
      doc_name = doc_title.delete('/')
      ext = '.pdf'
      file = File.new("#{Dir.pwd}/tmp/#{doc_name}#{ext}", 'w+').path
      if File.exist?("#{Dir.pwd}/tmp/#{doc_name}#{ext}")
        file_open = File.open(file, 'w+')
        file_open.write('Test Document')
        file_open.close
      end
      file
    end

    def submit_for_review(actor)
      hash = {}
      hash['uri'] = $conf['api_url'] + $endpoints['vendor']['submit_for_review']
      hash['headers'] = load_headers(actor)
      hash['headers'] = add_content_type_json(hash['headers'])
      resp = api_get_vendor_details(actor)
      hash['payload'] = {
        vendor_detail_id: resp[:body][:vendor_detail][:id].to_s,
        anchor_program_id: resp[:body][:anchor_program][:id].to_s
      }
      hash['payload'] = JSON.dump(hash['payload'])
      ApiMethod('create', hash)
    end

    def delete_vendor(values)
      errors = []
      values[:vendors].each do |vendor|
        vendor_has_program_group = vendor.is_a?(Array)
        details = if vendor_has_program_group
                    vendor_list = fetch_list_all_vendors(values[:program_type], values[:actor], vendor[0])
                    vendor_list.select { |x| x[:name] == vendor[0] && x[:program][:program_group] == vendor[1] }
                  else
                    vendor_list = fetch_list_all_vendors(values[:program_type], values[:actor], vendor)
                    vendor_list.select { |x| x[:name] == vendor }
                  end
        next if details.empty?

        p "Vendor found #{vendor}"
        details = details[0]
        hash = {}
        hash['uri'] = $conf['api_url'] + $endpoints['anchor']['delete']
        hash['headers'] = load_headers(values[:actor])
        hash['payload'] = {
          "anchor": [
            {
              "anchor_program_id": details[:anchor_program_id],
              "vendor_detail_id": [
                details[:vendor_detail_id]
              ]
            }
          ]
        }
        resp = ApiMethod('create', hash)
        errors << "Error cleaning up #{vendor} #{resp[:code]} #{resp[:body][:error][:message]}" unless resp[:code] == 200
      end
      p errors unless errors.empty?

      errors.empty? ? true : errors
    end

    def get_verification_doc(values)
      vendor_details = api_get_vendor_details(values[:actor])[:body]
      hash = {}
      hash['headers'] = load_headers('product')
      hash['uri'] = $conf['api_url'] + $endpoints['product']['get_document']
      hash['headers'][:params] = { 'doc_type': values[:doc_type], "doc_sub_type": values[:doc_sub_type], 'vendor_id': vendor_details[:id] }
      if values[:doc_type] == 'promoter_kyc'
        promoter_id = vendor_details[:promoters][0][:id]
        hash['headers'][:params].merge!('promoter_id': promoter_id)
      end
      hash['user_defined'] = { timeout: 9000000 }
      ApiMethod('fetch', hash)
    end

    def review_all_docs(values, action: :verify)
      doc_hash = get_required_docs(values[:doc_type], values[:doc_sub_type])
      doc_hash.each do |doc_type, sub_type|
        sub_type.each_key do |doc_sub_type|
          found_key = ''
          full_docs = get_required_docs
          full_docs.each do |k, v|
            v.each_key { |v_k| found_key = k if v_k == doc_sub_type && k != 'mandatory_docs' }
          end
          resp = get_verification_doc({ actor: values[:actor], doc_type: found_key, doc_sub_type: doc_sub_type })
          raise "Error in retrieving document #{resp}" unless resp[:code] == 200

          document_id = resp[:body][:verification_documents][0][:documents][0][:id]
          case action
          when :verify
            url = resp[:body][:verification_documents][0][:documents][0][:file_url]
            resp = request_url(url)
            raise "URL returned #{resp}" unless resp.code == 200
            raise "Document file name not matched #{resp.headers}" unless URI.decode_www_form_component(resp.headers[:content_disposition]).include?(doc_hash[doc_type][doc_sub_type])
          when :approve
            next if resp[:body][:verification_documents][0][:documents][0][:document_status] == 'platform_approved'

            resp = review_document({ review: true, comment: '', document_id: document_id })
            raise "Error approving document #{found_key} :: #{doc_sub_type}, #{resp}" unless resp[:code] == 200
          when :reject
            resp = review_document({ review: false, comment: values[:reject_reason], document_id: document_id })
            raise "Error approving document #{found_key} :: #{doc_sub_type}, #{resp}" unless resp[:code] == 200
          when :remove
            result = remove_uploaded_document(document_id, values[:actor])
            raise result unless result
          end
        end
      end
      true
    rescue => e
      e
    end

    def review_document(values)
      hash = {}
      hash['uri'] = $conf['api_url'] + construct_base_uri($endpoints['product']['verify_doc'], values[:document_id].to_s)
      hash['headers'] = load_headers('product')
      hash['payload'] = {
        is_verified: values[:review],
        comment: values[:comment]
      }
      ApiMethod('update', hash)
    end

    def remove_uploaded_document(documents, actor)
      hash = {}
      hash['headers'] = load_headers(actor)
      uploaded_documents = documents.is_a?(Array) ? documents : [documents]
      uploaded_documents.each do |document_id|
        hash['uri'] = $conf['api_url'] + construct_base_uri($endpoints['product']['verify_doc'], document_id.to_s)
        resp = ApiMethod('delete', hash)
        raise resp.to_s unless resp[:code] == 200
      end
      true
    rescue => e
      e
    end

    def review_vendor(actor, review = 'approved', comment = '')
      hash = {}
      hash['uri'] = $conf['api_url'] + $endpoints['product']['modify_vendor_state']
      hash['headers'] = load_headers('product')
      vendor_details = api_get_vendor_details(actor)[:body]
      hash['payload'] = {
        "product": {
          "vendor_detail_id": vendor_details[:anchor_program_vendor_detail][:vendor_detail_id],
          "anchor_program_id": vendor_details[:anchor_program_vendor_detail][:anchor_program_id],
          "state": review,
          "comment": comment
        }
      }
      ApiMethod('create', hash)
    end

    # POST /users/{user_id}/activate
    def api_set_new_password(activation_link)
      params = activation_link.split('?')[1].split('&')
      token = params[1].split('=')[1]
      user_id = params[2].split('=')[1]

      hash = {}
      hash['uri'] = $conf['auth_api_url'] + construct_base_uri($endpoints['auth']['activate_user'], user_id.to_s)
      hash['payload'] = {
        password: 'Think@123',
        token: token,
        terms_and_conditions_accepted: true
      }
      ApiMethod('update', hash)
    end

    # POST /programs/map_program
    def map_program(values)
      hash = {}
      hash['uri'] = $conf['api_url'] + $endpoints['programs']['map_program']
      hash['headers'] = load_headers(values[:actor])
      hash['payload'] = {
        program_id: values[:program_id],
        vendor_detail_id: values[:vendor_detail_id]
      }
      ApiMethod('create', hash)
    end

    # GET /vendors/get_invitation_details
    def get_invitation_details(actor, email)
      hash = {}
      hash['uri'] = $conf['api_url'] + $endpoints['vendor']['get_invitation_details']
      hash['headers'] = load_headers(actor)
      hash['headers'][:params] = { email: email }
      ApiMethod('fetch', hash)
    end

    # PUT /vendors/update_promoter_information
    def update_promoter_information(values)
      hash = {}
      hash['uri'] = $conf['api_url'] + $endpoints['vendor']['update_promoter_information']
      hash['headers'] = load_headers(values[:actor])
      hash['payload'] = {
        vendor: {
          promoter_info: {
            name: values[:name],
            contact: values[:contact],
            shareholding_percentage: values[:shareholding_percentage],
            salutation: values[:salutation],
            pan: values[:pan],
            email: values[:email],
            address: values[:address],
            state: values[:state],
            city: values[:city],
            zipcode: values[:zipcode],
            address_type: values[:address_type],
            gender: values[:gender],
            dob: values[:dob],
            marital_status: values[:marital_status]
          },
          promoter_id: values[:promoter_id]
        }
      }
      ApiMethod('update', hash)
    end

    def api_create_registered_channel_partner(testdata)
      commercials_data = testdata['Commercials']
      company_info = testdata['Company Info']
      promoter_info = testdata['Promoter Info']
      km_person_info = testdata['Key Managing Person Info']
      bank_details = testdata['Bank Details']

      resp = create_channel_partner(commercials_data)
      raise "Error while creating vendor, #{resp}" unless resp[:code] == 200

      sleep 2 # for email
      resp = api_activate_channel_partner(commercials_data['Email'])
      raise "Error in Channel Partner activation #{resp}" unless resp[:code] == 200

      p "Vendor '#{commercials_data['Entity Name']}' is activated"
      sleep 10
      vendor = commercials_data['Email'].split('@')[0]
      set_cookies_api(vendor, commercials_data['Email'], $conf['users']['anchor']['password'])
      resp = add_promoter_info(vendor, promoter_info)
      raise "Error while adding promoter info, #{resp}" unless resp[:code] == 200

      values = { anchor_actor: 'anchor', actor: vendor, program: commercials_data['Program'], km_person_info: km_person_info }
      resp = add_key_manager_info(values)
      raise "Error while adding KM info, #{resp}" unless resp[:code] == 200

      values.merge!(program: commercials_data['Program'], bank_details: bank_details, is_primary: true)
      resp = add_bank_details(values)
      raise "Error while adding Bank details, #{resp}" unless resp[:code] == 200

      resp = add_company_info(vendor, company_info)
      raise "Error while adding company info, #{resp}" unless resp[:code] == 200

      unless testdata['Commercials']['Program'] == 'Dynamic Discounting - Vendor Program'
        p 'Documents are being uploaded..'
        result = upload_onbaording_documents({ actor: vendor, type: 'mandatory_docs' })
        raise 'Error while uploading documents' unless result
      end
      resp = submit_for_review(vendor)
      raise "Error while Submitting for reivew, #{resp}" unless resp[:code] == 200

      true
    rescue => e
      e
    end

    # Vendor activation
    def api_activate_channel_partner(email)
      email_values = { mail_box: $conf['activation_mailbox'], subject: $notifications['Mail_Welcome_Subject'], body: email }
      activation_link = $activation_mail_helper.get_activation_link(email_values, 25)
      sleep 30 # For data reflection of new channel partners
      api_set_new_password(activation_link)
    rescue => e
      raise "Error in Vendor Activation #{e}"
    end

    def api_approve_all_docs_and_vendor(testdata, type = nil)
      errors = []
      vendor = testdata['Commercials']['Email'].split('@')[0]
      result = review_all_docs({ actor: vendor, doc_type: type }, action: :approve)
      errors << 'Error while approving docs' unless result
      resp = review_vendor(vendor, 'approved')
      errors << "Error while approving vendor #{resp}" unless resp[:code] == 200
      clear_cookies
      errors.empty? ? true : errors
    end
  end
end
