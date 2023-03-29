module Api
  # APIs called with group: investor
  module InvestorApi
    def get_anchor_program_by_investor(id, investor_actor)
      programs = get_all_anchor_programs(investor_actor)
      programs.select { |program| program[:id] == id }
    end

    # /anchor_programs/interested_programs
    def get_interested_programs(investor_actor, interest_type)
      hash = {}
      hash['headers'] = load_headers(investor_actor)
      hash['uri'] = $conf['api_url'] + $endpoints['programs']['interested_programs']
      hash['headers'][:params] = { interest_type: interest_type }
      page = 1
      anchor_programs = []
      iresp = ApiMethod('fetch', hash)
      anchor_programs << iresp[:body][:anchor_programs]
      until page == iresp[:body][:pagy_params][:last]
        page += 1
        hash['headers'][:params].merge!(page: page)
        iresp = ApiMethod('fetch', hash)
        anchor_programs << iresp[:body][:anchor_programs]
      end
      anchor_programs.flatten!
      anchor_programs
    end

    def get_interested_program(investor_actor, interest_type, id)
      programs = get_interested_programs(investor_actor, interest_type)
      programs.select { |program| program[:id] == id }
    end

    # /investors/list_borrowers_data
    def single_view_data(investor_actor, params)
      hash = {}
      hash['headers'] = load_headers(investor_actor)
      hash['headers'][:params] = params
      hash['uri'] = $conf['api_url'] + $endpoints['investor']['borrowers_list']
      ApiMethod('fetch', hash)
    end

    # /investors/borrowers_aggregation
    def single_view_data_aggregation(investor_actor, params)
      hash = {}
      hash['headers'] = load_headers(investor_actor)
      hash['uri'] = $conf['api_url'] + $endpoints['investor']['borrowers_list_aggregation'] + params
      ApiMethod('fetch', hash)
    end

    def retrieve_anchor_list(investor_actor, anchor_name: false)
      hash = {}
      hash['uri'] = $conf['api_url'] + $endpoints['anchor']['list_anchors']
      hash['headers'] = load_headers(investor_actor)
      page = 1
      anchors = []
      hash['headers'][:params] = { page: page, items: 30 }
      hash['headers'][:params].merge!(name: anchor_name) unless anchor_name == false
      resp = ApiMethod('fetch', hash)
      anchors << resp[:body][:anchors]
      until resp[:body][:pagy_params][:pages] == page
        page += 1
        hash['headers'][:params] = { page: page, items: 30 }
        hash['headers'][:params].merge!(name: anchor_name) unless anchor_name == false
        resp = ApiMethod('fetch', hash)
        anchors << resp[:body][:anchors]
      end
      anchors.flatten!
      anchors
    end

    def retrieve_anchors_without_published_programs(investor_actor)
      anchors_list = retrieve_anchor_list(investor_actor)
      anchors = []
      anchors_list.select do |anchor|
        if anchor[:anchor_programs] == []
          anchors << anchor[:name]
          next
        end
        anchors << anchor[:name] if anchor[:anchor_programs].count == 1 && anchor[:anchor_programs][0][:program_group] == 'DYNAMIC DISCOUNTING'
      end
      anchors
    rescue => e
      p "Error in retrieving anchor list #{e}"
    end

    def verify_whether_anchor_present_in_anchor_list(investor_actor, anchor_name)
      anchors_list = retrieve_anchor_list(investor_actor)
      return true unless anchors_list.select { |anchor| anchor[:name] == anchor_name } == []

      false
    rescue => e
      p "Error in retrieving anchor list #{e}"
    end

    def get_anchor_commercials(investor_actor:, investor_id:, anchor_program_id:)
      hash = {}
      hash['headers'] = load_headers(investor_actor)
      hash['uri'] = $conf['api_url'] + $endpoints['product']['get_anchor_details']
      hash['headers'][:params] = { 'investor_id': investor_id, 'anchor_program_id': anchor_program_id }
      ApiMethod('fetch', hash)
    end

    # GET /investors/detail
    def get_investor_profile(investor_actor)
      hash = {}
      hash['uri'] = $conf['api_url'] + $endpoints['investor']['get_investor_preferences']
      hash['headers'] = load_headers(investor_actor)
      ApiMethod('fetch', hash)
    end

    # PUT /investors/{id}/update_investor
    def update_investor_profile(values)
      hash = {}
      hash['uri'] = $conf['api_url'] + construct_base_uri($endpoints['investor']['update_investor_preferences'], values[:investor_id].to_s)
      hash['headers'] = load_headers(values[:investor_actor])
      hash['headers'] = add_content_type_json(hash['headers'])
      hash['payload'] = if values[:preferences_type] == 'approval_mechanism'
                          {
                            vendor_commercial: values[:vendor_commercial],
                            anchor_commercial: values[:anchor_commercial],
                            is_maker_checker_enabled: values[:is_maker_checker_enabled],
                            checker_type: values[:checker_type],
                            preferences_type: 'approval_mechanism'
                          }
                        else
                          {
                            interest_calculation_rest: values[:interest_calculation_rest],
                            interest_calculation_strategy: values[:interest_calculation_strategy],
                            interest_type: values[:interest_type],
                            mclr: values[:mclr],
                            rllr: values[:rllr],
                            mclr_effective_from: values[:mclr_effective_from],
                            rllr_effective_from: values[:rllr_effective_from],
                            preferences_type: 'program_terms'
                          }
                        end
      hash['payload'] = JSON.dump(hash['payload'])
      ApiMethod('update', hash)
    end

    # DELETE /investors/{id}/investor_profiles
    def delete_investor_floating_rates(investor_actor, investor_id)
      hash = {}
      hash['uri'] = $conf['api_url'] + construct_base_uri($endpoints['product']['delete_investor_floating_rates'], investor_id.to_s)
      hash['headers'] = load_headers(investor_actor)
      hash['headers'].merge!('product-request-type' => 'regression')
      ApiMethod('delete', hash)
    end

    def fetch_interested_investors(actor, anchor_program_id)
      hash = {}
      hash['uri'] = $conf['api_url'] + $endpoints['investor']['interested_investors']
      hash['headers'] = load_headers(actor)
      hash['headers'][:params] = { anchor_program_id: anchor_program_id }
      ApiMethod('fetch', hash)
    end

    # program_preferences/set_program_preferences
    def set_program_preferences(values, investor_actor)
      hash = {}
      hash['uri'] = $conf['api_url'] + $endpoints['investor']['program_prefs']
      hash['headers'] = load_headers(investor_actor)
      hash['payload'] = {
        attributes: {
          is_auto_ei: { is_enabled: false },
          expected_pricing: { is_enabled: false, min: 5, max: 100 },
          program_size: { is_enabled: false, min: 0, max: 2500000000 },
          tenure: { is_enabled: false, min: 30, max: 120 },
          industry: { is_enabled: false, values: ['airlines'] },
          ebitda: { is_enabled: false, min: 0, max: 25000000000 },
          min_credit_rating: { is_enabled: false, values: ['AA+'] },
          program_type: { is_enabled: false, values: ['Invoice Financing - Vendor'] },
          revenue: { is_enabled: false, min: -58863636000, max: 57272727000 },
          exposure_per_channel_partner: { is_enabled: false, min: 0, max: 2500000000 }
        }
      }
      hash['payload'][:attributes].merge!(values) unless values.empty?
      ApiMethod('create', hash)
    end

    def fetch_program_preferences(investor_actor)
      hash = {}
      hash['uri'] = $conf['api_url'] + $endpoints['investor']['get_program_preferences']
      hash['headers'] = load_headers(investor_actor)
      ApiMethod('fetch', hash)
    end

    def fetch_up_for_renewal_cards(investor_actor, itype)
      hash = {}
      hash['uri'] = $conf['api_url'] + $endpoints['investor']['up_for_renewal']
      hash['headers'] = load_headers(investor_actor)
      type = itype == 'pgmlimit' ? 'iap' : 'ivap'
      hash['headers'][:params] = { commercial_type: type }
      resp = ApiMethod('fetch', hash)
      raise resp.to_s unless resp[:code] == 200

      commercials = []
      resp[:body][:commercials].select { |commercial| commercials << commercial if Date.parse(commercial[:expiry_date]) >= Date.parse(get_todays_date) }
      [commercials, resp[:body][:commercials].count]
    end
  end
end
