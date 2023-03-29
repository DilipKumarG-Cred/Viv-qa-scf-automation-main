module Api
  module AnchorCommercials
    def delete_anchor_commercials(values)
      resp = get_anchor_commercials(
        investor_actor: values[:investor_actor], investor_id: values[:investor_id], anchor_program_id: values[:anchor_program_id]
      )
      return resp if resp[:code] == 422 && resp[:body][:error][:message] == "Couldn't find InvestorAnchorProgram" # empty commericals
      return resp if resp[:code] == 200 && resp[:body] == {} # empty commericals

      investor_program_id = resp[:body][:result][:id]
      hash = {}
      hash['headers'] = load_headers('product')
      hash['uri'] = $conf['api_url'] + construct_base_uri($endpoints['product']['delete_commercials'], investor_program_id.to_s)
      ApiMethod('delete', hash)
    end

    def force_delete_anchor_commercials(values)
      anchor_details = fetch_anchor_details(values[:investor_actor], values[:anchor_id])
      anchor_program = anchor_details[:body][:anchor_programs].select { |programs| programs[:id] == values[:program_id] }
      anchor_program_id = anchor_program[0][:anchor_program_id]
      values.merge!(anchor_program_id: anchor_program_id)

      resp = delete_anchor_commercials(values)
      return resp[:code] if resp[:code] == 200
      return 200 if resp[:code] == 500 && resp[:body][:error][:message].include?("Couldn't find InvestorAnchorProgram")

      # Approving Anchor Commercials
      investor_program = get_anchor_commercials(investor_actor: values[:investor_actor], investor_id: values[:investor_id], anchor_program_id: anchor_program_id)
      investor_details = {
        investor_program: investor_program[:body][:result][:id],
        actor: values[:investor_actor]
      }
      resp = review_anchor_commercials(investor_details: investor_details, status: 'approved', comment: 'before_each clearing commercials')
      sleep 15
      # raise "Could not approve commercials as status is #{resp[:body][:status]}" unless resp[:body][:status] == 'pending_effective_date'

      delete_anchor_commercials(values)
    end

    def review_anchor_commercials(investor_details:, status:, comment:)
      hash = {}
      hash['uri'] = $conf['api_url'] + construct_base_uri($endpoints['investor']['verify_mou'], investor_details[:investor_program].to_s)
      hash['headers'] = load_headers(investor_details[:actor])
      hash['payload'] = {
        investor_anchor_program: {
          status: status,
          comment: comment
        }
      }
      ApiMethod('update', hash)
    end

    # investor_anchor_programs/{commercial_id}/update_deal_mou
    def set_anchor_commercials(values, action: :set)
      p "Setting anchor commercials - Action #{action} for #{values[:actor]}, Anchor program id: #{values[:anchor_program_id]}, Investor ID: #{values[:investor_id]}"
      hash = {}
      case action
      when :set
        hash['headers'] = load_headers(values[:actor])
        hash['headers'] = add_content_type_json(hash['headers'])
        hash['uri'] = $conf['api_url'] + $endpoints['investor']['set_anchor_commercial']
        hash['payload'] = create_anchor_commercial_payload(values)
      when :update
        resp = get_anchor_program(values[:program_name], values[:anchor_actor])
        resp = get_anchor_commercials(investor_actor: values[:investor_actor], investor_id: values[:investor_id], anchor_program_id: resp[0][:id])
        commercial = resp[:body][:result]
        investor_program_id = commercial[:id]
        values[:update_fields].each do |key, value|
          commercial[key] = value
        end
        commercial.delete(:interest_calculation_rest) if commercial[:interest_calculation_strategy] == 'simple_interest'
        hash['headers'] = load_headers('product')
        hash['headers'] = add_content_type_json(hash['headers'])
        hash['uri'] = $conf['api_url'] + construct_base_uri($endpoints['product']['update_anchor_commerical'], investor_program_id.to_s)
        hash['payload'] = create_anchor_commercial_payload(commercial)
        hash['payload'][:investor_anchor_program].delete(:valid_from)
        hash['payload'][:investor_anchor_program].delete(:interest_calculation_rest)
        hash['payload'][:investor_anchor_program].delete(:investor_id)
        hash['payload'][:investor_anchor_program][:valid_till] = Date.parse(commercial[:valid_till], 'yyyy-mm-dd').strftime('%Y-%m-%d')
        hash['payload'][:investor_anchor_program][:max_days_to_raise_invoice] = commercial[:max_days_to_raise_invoice]
        hash['payload'][:investor_anchor_program].merge!(interest_calculation_rest: commercial[:interest_calculation_rest]) unless commercial[:interest_calculation_rest].nil?
      when :edit
        hash['headers'] = load_headers(values[:actor])
        hash['headers'] = add_content_type_json(hash['headers'])
        resp = get_anchor_commercials(investor_actor: values[:actor], investor_id: values[:investor_id], anchor_program_id: values[:anchor_program_id])
        hash['uri'] = $conf['api_url'] + construct_base_uri($endpoints['investor']['edit_anchor_commercial'], resp[:body][:result][:id].to_s)
        hash['payload'] = create_anchor_commercial_payload(values)
      when :submit
        hash['headers'] = load_headers(values[:actor])
        hash['headers'] = add_content_type_json(hash['headers'])
        resp = get_anchor_commercials(investor_actor: values[:actor], investor_id: values[:investor_id], anchor_program_id: values[:anchor_program_id])
        hash['uri'] = $conf['api_url'] + construct_base_uri($endpoints['investor']['edit_anchor_commercial'], resp[:body][:result][:id].to_s)
        hash['payload'] = { investor_anchor_program: { submit: true } }
      end
      hash['payload'] = JSON.dump(hash['payload'])
      ApiMethod('update', hash)
    end

    def create_anchor_commercial_payload(values)
      investor_anchor_program = {
        investor_anchor_program_instrument: {
          instrument_ids: [values[:instrument_ids]]
        },
        investor_anchor_program: {
          recourse_percentage: values[:recourse_percentage],
          discount_percentage: values[:discount_percentage],
          prepayment_charges: values[:prepayment_charges],
          max_tenor: values[:max_tenor],
          penal_rate: values[:penal_rate],
          valid_till: values[:valid_till],
          valid_from: values[:valid_from],
          interest_strategy: values[:interest_strategy],
          liability: values[:liability],
          disburse_by: values[:disburse_by],
          is_invoice_file_mandatory: values[:is_invoice_file_mandatory],
          skip_counter_party_approval: values[:skip_counter_party_approval],
          max_sanction_limit: values[:max_sanction_limit],
          door_to_door_tenor: values[:door_to_door_tenor],
          invoice_ageing_threshold: values[:invoice_ageing_threshold],
          interest_calculation_strategy: values[:interest_calculation_strategy],
          interest_calculation_rest: values[:interest_calculation_rest],
          investor_id: values[:investor_id],
          anchor_program_id: values[:anchor_program_id],
          min_yield: values[:min_yield],
          max_yield: values[:max_yield],
          effective_date: values[:effective_date]
        }
      }
      investor_anchor_program[:investor_anchor_program].merge!(max_days_to_raise_invoice: values[:max_days_to_raise_invoice]) unless values[:max_days_to_raise_invoice].nil?
      investor_anchor_program
    end

    def upload_anchor_mou(values)
      hash = {}
      hash['headers'] = load_headers(values[:actor])
      hash['uri'] = $conf['api_url'] + construct_base_uri($endpoints['investor']['upload_mou'], values[:id].to_s)
      begin
        document = File.new(values[:borr_doc], 'rb')
      rescue
        document = values[:borr_doc]
      end
      hash['payload'] = {
        multipart: true,
        'investor_anchor_program[document]' => document
      }
      ApiMethod('update', hash)
    end

    # /investors/list_borrowers_data
    def single_view_data(investor_actor, params)
      hash = {}
      hash['headers'] = load_headers(investor_actor)
      hash['headers'][:params] = { 'anchor_ids[]' => params['anchor_ids[]'] }
      hash['uri'] = $conf['api_url'] + $endpoints['investor']['borrowers_list']
      ApiMethod('fetch', hash)
    end

    # Validations

    def api_form_vendor_program_details(response_body)
      {
        status: response_body[:status],
        name: response_body[:name],
        city: response_body[:city],
        geography: response_body[:geography],
        incorporation_date: Date.parse(response_body[:incorporation_date]),
        turnover: response_body[:turnover],
        live_transaction_count: response_body[:live_transaction_count]
      }
    end
  end
end
