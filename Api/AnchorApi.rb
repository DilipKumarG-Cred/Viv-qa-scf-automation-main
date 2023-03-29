module Api
  # Anchor Onboarding APIs
  module AnchorApi
    # GET /anchors/{id}
    def fetch_anchor_details(actor, anchor_id)
      hash = {}
      hash['headers'] = load_headers(actor)
      hash['uri'] = $conf['api_url'] + construct_base_uri($endpoints['anchor']['detail'], anchor_id.to_s)
      ApiMethod('fetch', hash)
    end

    # GET /anchors/profile
    def fetch_anchor_profile(actor, anchor_id)
      hash = {}
      hash['headers'] = load_headers(actor)
      hash['uri'] = $conf['api_url'] + $endpoints['anchor']['profile']
      hash['headers'][:params] = { id: anchor_id }
      ApiMethod('fetch', hash)
    end

    def create_anchor_program(values)
      hash = {}
      hash['headers'] = load_headers(values[:actor])
      hash['uri'] = $conf['api_url'] + $endpoints['programs']['all_anchor_program']
      hash['payload'] = {
        anchor_programs: [
          {
            max_tranche: values[:max_tranche],
            program_id: $conf['programs'][values[:type]],
            program_size: values[:program_size],
            min_exposure: values[:exposure][0],
            max_exposure: values[:exposure][1],
            min_price_expectation: values[:price_expectation][0],
            max_price_expectation: values[:price_expectation][1]
          }
        ]
      }
      ApiMethod('create', hash)
    end

    def publish_anchor_program(actor, ids)
      hash = {}
      hash['headers'] = load_headers(actor)
      hash['uri'] = $conf['api_url'] + $endpoints['programs']['publish_program']
      hash['payload'] = {
        anchor_programs: ids
      }
      ApiMethod('create', hash)
    end

    def delete_live_program(program_group, program_type, anchor_id)
      hash = {}
      program_id = get_anchor_program_id(program_group, program_type, anchor_id)
      return true if program_id.nil?

      hash['headers'] = load_headers('product')
      hash['uri'] = $conf['api_url'] + construct_base_uri($endpoints['programs']['delete_live_program'], program_id.to_s)
      resp = ApiMethod('delete', hash)
      resp[:code] == 200
    end

    def delete_draft_program(name, actor)
      hash = form_payload_anchor_program_detail(name, actor, 'draft')
      resp = ApiMethod('delete', hash)
      return resp[:code] == 200
    rescue IOError => e
      p e.message
    else
      raise
    end

    def get_draft_program(name, actor)
      resp = get_all_anchor_programs(actor)
      return nil if resp[:body][:available_programs][:draft_programs].empty?

      program = resp[:body][:available_programs][:draft_programs].select { |x| x[:name] == name }
      return nil if program.empty?

      program[0][:id]
    end

    # /anchor_programs
    def get_all_anchor_programs(actor, params = nil)
      page = 1
      hash = {}
      hash['uri'] = $conf['api_url'] + $endpoints['programs']['all_anchor_program']
      hash['headers'] = load_headers(actor)
      hash['headers'][:params] = { page: page }
      hash['headers'][:params].merge!(params) unless params.nil?
      resp = ApiMethod('fetch', hash)
      return resp if hash['headers']['Current-Sub-Group'] == 'anchor'

      programs = []
      programs << resp[:body][:anchor_programs]
      last_page = resp[:body][:pagy_params][:last]
      until last_page == page
        page += 1
        hash['headers'][:params] = { page: page }
        hash['headers'][:params].merge!(params) unless params.nil?
        resp = ApiMethod('fetch', hash)
        programs << resp[:body][:anchor_programs]
      end
      programs.flatten!
      programs
    end

    def get_anchor_program(program_name, actor, type = 'published')
      resp = get_all_anchor_programs(actor)
      raise resp.to_s unless resp[:code] == 200
      return [] if resp[:body][:available_programs].empty?

      if type == 'published'
        resp[:body][:available_programs][:published_programs].select { |x| x[:name] == program_name }
      else
        return [] if resp[:body][:available_programs][:draft_programs].empty?

        resp[:body][:available_programs][:draft_programs].select { |x| x[:name] == program_name }
      end
    rescue => e
      raise e
    end

    def form_payload_anchor_program_detail(program_name, actor, type)
      hash = {}
      program = get_anchor_program(program_name, actor, type)
      raise IOError, "Program #{program_name} not present" if program.empty?

      program_id = program[0][:id]
      raise IOError, "Program #{program_name} not present" if program_id.nil?

      hash['headers'] = load_headers(actor)
      hash['uri'] = $conf['api_url'] + construct_base_uri($endpoints['programs']['anchor_program_detail'], program_id.to_s)
      hash
    rescue => e
      raise e
    end

    def fetch_anchor_detail(actor, program_id)
      hash = {}
      hash['headers'] = load_headers(actor)
      hash['uri'] = $conf['api_url'] + construct_base_uri($endpoints['programs']['anchor_program_detail'], program_id.to_s)
      ApiMethod('fetch', hash)
    end

    def get_anchor_program_detail(name, actor)
      hash = form_payload_anchor_program_detail(name, actor, 'published')
      ApiMethod('fetch', hash)
    end

    def fetch_anchor_programs(actor, anchor_id: '', vendor_id: '')
      hash = {}
      hash['headers'] = load_headers(actor)
      hash['uri'] = $conf['api_url'] + $endpoints['anchor']['anchor_programs']
      hash['headers'][:params] = { 'anchor_id': anchor_id.to_s } unless anchor_id.to_s.empty?
      hash['headers'][:params] = { 'vendor_id': vendor_id.to_s } unless vendor_id.to_s.empty?
      ApiMethod('fetch', hash)
    end

    def get_anchor_program_id(program_group, program_type, anchor_id)
      resp = fetch_anchor_programs('product', anchor_id: anchor_id.to_s)
      raise resp.to_s unless resp[:code] == 200

      program = resp[:body].select { |x| x[:program_group] == program_group and x[:program_type] == program_type }[0]
      program[:anchor_program_id]
    end

    # GET invoices/available_limits
    def get_available_limits(values)
      hash = {}
      hash['headers'] = load_headers(values[:actor])
      hash['uri'] = $conf['api_url'] + $endpoints['anchor']['available_limits']
      hash['headers'][:params] = { investor_id: values[:investor_id], program_id: values[:program_id] }
      hash['headers'][:params].merge!(vendor_id: values[:vendor_id]) unless values[:vendor_id].nil?
      hash['headers'][:params].merge!(anchor_id: values[:anchor_id]) unless values[:anchor_id].nil?
      ApiMethod('fetch', hash)
    end

    def fetch_report_types(actor)
      hash = {}
      hash['headers'] = load_headers('product')
      hash['uri'] = $conf['api_url'] + $endpoints['reports']['report_types']
      hash['headers'][:params] = { current_user: actor, current_group: actor }
      resp = ApiMethod('fetch', hash)
      raise resp.to_s unless resp[:code] == 200

      resp[:body][:report_types]
    end

    def validate_associated_actors_present(values)
      hash = {}
      hash['headers'] = load_headers('product')
      hash['uri'] = $conf['api_url'] + $endpoints['associated'][values[:type_of_actor]]
      hash['headers'][:params] = case values[:type_of_actor]
                                 when 'vendors'
                                   param = :vendors
                                   { program_id: values[:program_id], anchor_id: values[:anchor_id] }
                                 when 'investors'
                                   param = :investors
                                   { program_id: values[:program_id], anchor_id: values[:anchor_id], vendor_id: values[:vendor_id] }
                                 else
                                   param = :anchors
                                   nil
                                 end
      resp = ApiMethod('fetch', hash)
      raise resp.to_s unless resp[:code] == 200

      all_actors = resp[:body][param]
      all_actors.flatten!
      not_present = []
      values[:actors].each do |actor|
        found = all_actors.select { |each_actor| each_actor[:name] == actor }
        not_present << actor if found == []
      end
      not_present.empty? ? true : not_present
    end

    # Credit APIs

    # /cra/customers
    def get_customer_info
      hash = {}
      hash['uri'] = $conf['credit_api_url'] + $endpoints['credit']['get_customers']
      hash['headers'] = load_headers('client_acquisition_group')
      page = 1
      matching_clients = []
      hash['headers'][:params] = {
        state: 'onboarded',
        subgroup: nil,
        page_size: 100
      }
      resp = ApiMethod('fetch', hash)
      matching_clients << resp[:body][:customers].select { |x| x[:subgroups] == [] && !x[:company_name].match(/\w+-\d+/).nil? && x[:company_type] == 'enterprise_finance' }
      loop do
        page += 1
        hash['headers'][:params].merge!(page: page)
        resp = ApiMethod('fetch', hash)
        matching_clients << resp[:body][:customers].select { |x| x[:subgroups] == [] && !x[:company_name].match(/\w+-\d+/).nil? && x[:company_type] == 'enterprise_finance' }
        matching_clients.flatten!
        break if matching_clients.count > 5
      end
      matched_client = matching_clients.sample
      p "Primary Contact email #{matched_client[:contact_email]}"
      return matched_client[:contact_email] unless matched_client[:contact_email].nil?

      resp = fetch_detailed_customer_info(matched_client[:entity_id])
      raise resp.to_s unless resp[:code] == 200

      unless resp[:body][:secondary_contacts].nil?
        return resp[:body][:secondary_contacts][0][:contact_email] unless resp[:body][:secondary_contacts][0][:contact_email].nil?
      end
      nil
    end

    # /cra/entities/{entity_id}/customer
    def fetch_detailed_customer_info(entity_id)
      hash = {}
      hash['uri'] = $conf['credit_api_url'] + construct_base_uri($endpoints['credit']['get_detailed_customer'], entity_id.to_s)
      hash['headers'] = load_headers('product')
      ApiMethod('fetch', hash)
    end

    # Customer relation data for particular deal id
    # GET /cra/customer_interest_relations
    def retrieve_customer_relation_data(deal_id, anchor_actor)
      hash = {}
      hash['uri'] = $conf['mp_base_uri'] + $endpoints['credit']['customer_interest_relation']
      hash['headers'] = load_headers(anchor_actor)
      hash['headers'][:params] = { deal_id: deal_id, product_category: 'scf' }
      ApiMethod('fetch', hash)
    end

    # /cra/customer_interest_relations/{id}
    def act_on_express_interest(values)
      data = retrieve_customer_relation_data(values[:id], values[:actor])
      cir_id = data[:body][:customer_interest_relation][0][:id]
      hash = {}
      hash['headers'] = load_headers(values[:actor])
      hash['uri'] = $conf['mp_base_uri'] + construct_base_uri($endpoints['credit']['update_customer_interest_relation'], cir_id.to_s)
      hash['payload'] = {
        customer_interest_relation: {
          relation_name: 'profile_interest',
          interest_relation_type: 'deal',
          dest_relation_id: values[:id].to_s,
          product_category: 'scf',
          remarks: values[:remarks],
          request_action: values[:action],
          selective_release_option: false
        }
      }
      ApiMethod('patch', hash)
    end

    # /cra/deals
    def retrieve_deals_from_credit(investor_actor, program_name, borrower)
      hash = {}
      hash['uri'] = $conf['mp_base_uri'] + $endpoints['credit']['get_deals']
      hash['headers'] = load_headers(investor_actor)
      page = 1
      hash['headers'][:params] = { deal_category: 'scf', page_size: 20, page: page }
      resp = ApiMethod('fetch', hash)
      found_deal = []
      until page == resp[:body][:total_pages]
        page += 1
        hash['headers'][:params] = { deal_category: 'scf', page_size: 20, page: page }
        found_deal = resp[:body][:deals].select { |deal| deal[:name] == program_name && deal[:borrower_name] == borrower }
        break unless found_deal == []
      end
      found_deal
    end

    # POST /cra/customer_interest_relations
    def express_interest_on_deal(deal_id, investor_actor)
      hash = {}
      hash['uri'] = $conf['mp_base_uri'] + $endpoints['credit']['customer_interest_relation']
      hash['headers'] = load_headers(investor_actor)
      hash['payload'] = {
        customer_interest_relation: {
          dest_relation_id: {
            scf: [deal_id]
          },
          interest_relation_type: 'deal',
          relation_name: 'profile_interest'
        }
      }
      ApiMethod('create', hash)
    end

    def fetch_document(actor, params)
      hash = {}
      hash['uri'] = $conf['api_url'] + $endpoints['download_documents']
      hash['headers'] = load_headers(actor)
      hash['headers'][:params] = params
      ApiMethod('fetch', hash)
    end
  end
end
