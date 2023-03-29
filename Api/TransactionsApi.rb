module Api
  module Trasactions
    def get_transaction_details(transaction_id, actor: 'product')
      hash = {}
      hash['uri'] = $conf['api_url'] + $endpoints['transactions']['invoice']['get'] + transaction_id.to_s
      hash['headers'] = load_headers(actor)
      ApiMethod('fetch', hash)
    end

    def get_po_details(transaction_id, actor: 'product')
      hash = {}
      hash['uri'] = $conf['api_url'] + $endpoints['transactions']['po']['get'] + transaction_id.to_s
      hash['headers'] = load_headers(actor)
      ApiMethod('fetch', hash)
    end

    def fetch_transaction_list(queries)
      party_hash = {
        'product' => '/products',
        'anchor' => '/anchors',
        'investor' => '/investors',
        'vendor' => '/vendors'
      }
      hash = {}
      hash['headers'] = load_headers(queries[:actor])
      party = case queries[:category]
              when 'invoices'
                ''
              when 'pending_assignments'
                '/purchase_orders' if queries[:program_group] == 'po'
              else
                hash['headers']['Current-Group'] == 'customer' ? party_hash[hash['headers']['Current-Sub-Group']] : party_hash[hash['headers']['Current-Group']]
              end
      hash['uri'] = "#{$conf['api_url']}#{party}/#{queries[:category]}"
      hash['headers'][:params] = { page: 1, items: 30, program_group: queries[:program_group] }
      ApiMethod('fetch', hash)
    end

    def disburse_transaction(values)
      program_mapping = {
        'Invoice Financing - Vendor' => 1,
        'Invoice Financing - Dealer' => 2,
        'PO Financing - Vendor' => 4,
        'PO Financing - Dealer' => 3
      }
      values[:program_id] = program_mapping[values[:program]]
      tenor = if !values[:tenor].nil?
                values[:tenor]
              elsif values[:type] == 'frontend'
                $conf['vendor_tenor']
              else
                $conf['dealer_tenor']
              end
      yield_value = values[:yield].nil? ? $conf['yield'] : values[:yield]
      margin_value = values[:margin].nil? ? $conf['margin'] : values[:margin]
      transaction_values = calculate_transaction_values(
        {
          invoice_value: values[:invoice_value],
          margin: margin_value,
          yield: yield_value,
          tenor: tenor,
          type: values[:type],
          strategy: values[:strategy],
          rest: values[:rest]
        }
      )
      values[:disbursement_details] = {
        'UTR Number' => "UTR#{DateTime.now.to_time.to_i}#{rand(1..999)}",
        'Date of Payment' => values[:date_of_payment],
        'Disbursement Amount' => transaction_values[1],
        'Disbursement Account Number' => Faker::Number.number(digits: 10)
      }
      disburse_hash = {
        transaction_id: values[:transaction_id],
        payment_proof: values[:payment_proof],
        disbursement_details: values[:disbursement_details],
        program_id: values[:program_id]
      }
      disburse_hash.merge!(investor_actor: values[:investor_actor]) unless values[:investor_actor].nil?
      resp = disburse_transaction_api(disburse_hash)
      raise resp.to_s if resp.is_a?(String)
      raise resp.to_s unless resp[:code] == 200

      [transaction_values, values[:disbursement_details]]
    rescue => e
      p "Exception in disbursing transaction - Exception: #{e}"
      "Error while disbursements #{e}"
    end

    def disburse_transaction_api(values)
      resp = if [1, 2].include? values[:program_id]
               get_transaction_details(values[:transaction_id])
             else
               get_po_details(values[:transaction_id])
             end
      if values[:disbursement_details].nil?
        @utr_number = "UTR#{DateTime.now.to_time.to_i}#{rand(1..999)}"
        @account_number = Faker::Number.number(digits: 10)
        @amount = resp[:body][:disbursement_amount]
        @disbursement_date = Date.today.strftime('%Y-%m-%d')
      else
        p 'setting here'
        @utr_number = values[:disbursement_details]['UTR Number'].nil? ? "UTR#{DateTime.now.to_time.to_i}#{rand(1..999)}" : values[:disbursement_details]['UTR Number']
        @account_number = values[:disbursement_details]['Disbursement Account Number'].nil? ? Faker::Number.number(digits: 10) : values[:disbursement_details]['Disbursement Account Number']
        @amount = values[:disbursement_details]['Disbursement Amount'].nil? ? resp[:body][:disbursement_amount] : values[:disbursement_details]['Disbursement Amount']
        @disbursement_date = values[:disbursement_details]['Date of Payment'].nil? ? Date.today.strftime('%Y-%m-%d') : Date.strptime(values[:disbursement_details]['Date of Payment'], '%d-%b-%Y').strftime('%Y-%m-%d')
      end
      disburse_hash = {
        utr_number: @utr_number,
        account_number: @account_number,
        disbursement_date: @disbursement_date,
        amount: @amount,
        invoice_transaction_ids: resp[:body][:id]
      }
      disburse_hash.merge!(investor_actor: values[:investor_actor]) unless values[:investor_actor].nil?
      disburse_multiple_transactions(disburse_hash)
    rescue => e
      "Error while disbursements #{e}"
    end

    def disburse_multiple_transactions(values)
      hash = {}
      investor_actor = values[:investor_actor].nil? ? 'investor' : values[:investor_actor]
      hash['uri'] = $conf['api_url'] + $endpoints['disbursement']['disburse']
      hash['headers'] = load_headers(investor_actor)
      hash['payload'] = {
        multipart: true,
        utr_number: values[:utr_number],
        disbursement_account_number: values[:account_number],
        payment_date: values[:disbursement_date],
        amount: values[:amount],
        invoice_transaction_ids: values[:invoice_transaction_ids],
        discrepancy_reason: values[:discrepancy_reason]
      }
      hash['payload']['document'] = File.new(values[:payment_proof], 'rb') unless values[:payment_proof].nil?
      hash['payload']['discrepancy_documents[]'] = File.new(values[:discrepancy_proof], 'rb') unless values[:discrepancy_proof].nil?
      ApiMethod('create', hash)
    end

    def calculate_transaction_values(values, formatted: true)
      margin_amount = (values[:invoice_value] * values[:margin]) / 100.to_f
      principal_outstanding = (values[:invoice_value] - margin_amount).to_f
      ir = values[:yield].to_f / 100
      values[:strategy] = 'compound_interest' if values[:strategy].nil?
      values[:rest] = 'daily' if values[:rest].nil?
      case values[:strategy]
      when 'simple_interest'
        interest_value = principal_outstanding * (ir / 365.0) * values[:tenor]
      when 'compound_interest'
        case values[:rest]
        when 'daily'
          t_interest = (1 + (ir / 365.0))**values[:tenor]
        when 'monthly'
          t_interest = (1 + (ir / 12.0))**(values[:tenor] / 30.0)
        when 'quarterly'
          t_interest = (1 + ir / 4.0)**(4.0 * (values[:tenor] / 365.0))
        end
        interest_value = (principal_outstanding * t_interest) - principal_outstanding
      end
      disbursement_value = if values[:type] == 'frontend'
                             rounded_half_down_value(principal_outstanding - interest_value)
                           else
                             principal_outstanding
                           end
      interest = formatted ? rounded_half_down_value(interest_value) : interest_value
      [principal_outstanding, disbursement_value, interest]
    end

    # /investors/reject_invoices
    def decline_multiple_transactions(values)
      hash = {}
      hash['uri'] = $conf['api_url'] + $endpoints['disbursement']['decline']
      hash['headers'] = load_headers(values[:actor])
      hash['payload'] = {
        comment: values[:comment],
        invoice_transaction_ids: values[:invoice_transaction_ids]
      }
      ApiMethod('create', hash)
    end

    def create_transaction(actor, invoice_details, invoicefile = nil, program_id = nil)
      invoice_details = invoice_details.dup
      vendor_gstn = invoice_details['GSTN of Channel Partner']
      hash = {}
      hash['uri'] = $conf['api_url'] + $endpoints['transactions']['invoice']['create']
      hash['headers'] = load_headers(actor)
      begin
        invoice_file = File.new(invoicefile, 'rb')
      rescue
        invoice_file = invoicefile
      end
      begin
        invoice_date = Date.strptime(invoice_details['Invoice Date'], '%d-%b-%Y').strftime('%Y-%m-%d')
      rescue
        invoice_date = invoice_details['Invoice Date']
      end
      hash['payload'] = {
        multipart: true,
        "invoice[document]": invoice_file,
        "invoice[invoice_number]": invoice_details['Invoice Number'],
        "invoice[invoice_value]": invoice_details['Invoice Value'],
        "invoice[invoice_date]": invoice_date,
        "invoice[anchor_gstn]": invoice_details['GSTN of Anchor'],
        "invoice[vendor_gstn]": vendor_gstn,
        "invoice[program_id]": program_id
      }
      unless invoice_details['EWB No'].nil?
        begin
          ewb_date = Date.strptime(invoice_details['EWB Date'], '%d-%b-%Y').strftime('%Y-%m-%d')
        rescue
          ewb_date = invoice_details['EWB Date']
        end
        hash['payload'].merge!(
          'invoice[ewb_no]': invoice_details['EWB No'],
          'invoice[ewb_date]': ewb_date
        )
      end
      unless invoice_details['GRN'].nil?
        begin
          grn_date = Date.strptime(invoice_details['GRN Date'], '%d-%b-%Y').strftime('%Y-%m-%d')
        rescue
          grn_date = invoice_details['GRN Date']
        end
        hash['payload']['invoice[grn]'] = invoice_details['GRN']
        hash['payload']['invoice[grn_date]'] = grn_date
      end
      if program_id == 5 # Dynamic discounting
        desired_date = begin
          Date.strptime(invoice_details['Desired Date'], '%d-%b-%Y').strftime('%Y-%m-%d')
        rescue
          invoice_details['Desired Date']
        end
        hash['payload'].merge!(
          'invoice[desired_date]' => desired_date,
          'invoice[discount]' => invoice_details['Discount'],
          'invoice[tds]' => invoice_details['TDS']
        )
        due_date = begin
          Date.strptime(invoice_details['Due Date'], '%d-%b-%Y').strftime('%Y-%m-%d')
        rescue
          invoice_details['Due Date']
        end
        hash['payload'][:'invoice[due_date]'] = due_date
      end
      requested_due_date_computed = begin
        Date.strptime(invoice_details['Due Date Computed'], '%d-%b-%Y').strftime('%Y-%m-%d')
      rescue
        invoice_details['Due Date Computed']
      end
      hash['payload'][:'invoice[requested_due_date_computed]'] = requested_due_date_computed
      hash['payload'].merge!('invoice[tenor]': invoice_details['tenor']) unless invoice_details['tenor'].nil?
      hash['payload'].merge!('invoice[requested_disbursement_value]': invoice_details['requested_disbursement_value']) unless invoice_details['requested_disbursement_value'].nil?
      ApiMethod('create', hash)
    end

    def create_bulk_transaction(configs, invoicefile = nil)
      actor = configs['user']
      program_id = configs['program_id']
      hash = {}
      document = begin
        File.new(invoicefile, 'rb')
      rescue
        invoicefile
      end
      case configs['program_type'].split(' - ')[0]
      when 'Dynamic Discounting'
        hash['uri'] = $conf['api_url'] + $endpoints['transactions']['dd']['create_bulk']
        hash['payload'] = {
          'invoice_file[program_id]' => program_id,
          'invoice_file[document]' => document
        }
      when 'PO Financing'
        hash['uri'] = $conf['api_url'] + $endpoints['transactions']['po']['create_bulk']
        hash['payload'] = {
          'purchase_order_file[program_id]' => program_id,
          'purchase_order_file[document]' => document
        }
      when 'Invoice Financing'
        hash['uri'] = $conf['api_url'] + $endpoints['transactions']['invoice']['create_bulk']
        hash['payload'] = {
          'invoice_file[program_id]' => program_id,
          'invoice_file[document]' => document
        }
      end
      hash['headers'] = load_headers(actor)
      ApiMethod('create', hash)
    end

    def create_po_transaction(values)
      po_details = values[:po_details].dup
      vendor_gstn = po_details['GSTN of Channel Partner']
      hash = {}
      hash['uri'] = $conf['api_url'] + $endpoints['transactions']['po']['create']
      hash['headers'] = load_headers(values[:actor])
      po_file = begin
        File.new(values[:po_file], 'rb')
      rescue
        values[:po_file]
      end
      po_date = begin
        Date.strptime(po_details['PO Date'], '%d-%b-%Y').strftime('%Y-%m-%d')
      rescue
        po_details['PO Date']
      end
      hash['payload'] = {
        multipart: true,
        "purchase_order[document]": po_file,
        "purchase_order[po_number]": po_details['PO Number'],
        "purchase_order[po_value]": po_details['PO Value'],
        "purchase_order[po_eligible_value]": po_details['Requested Disbursement Value'],
        "purchase_order[po_date]": po_date,
        "purchase_order[anchor_gstn]": po_details['GSTN of Anchor'],
        "purchase_order[vendor_gstn]": vendor_gstn,
        "purchase_order[program_id]": values[:program_id]
      }
      hash['payload'].merge!('purchase_order[tenor]' => po_details['tenor']) unless po_details['tenor'].nil?
      ApiMethod('create', hash)
    end

    def approve_transcation(values)
      hash = {}
      hash['headers'] = load_headers(values[:actor])
      hash['headers'] = add_content_type_json(hash['headers'])
      hash['uri'] = $conf['api_url'] + $endpoints['transactions']['invoice']['verify']
      transacion_ids = values[:transaction_id].is_a?(Array) ? values[:transaction_id] : [values[:transaction_id]]
      hash['payload'] = {
        products: [
          { program_group: values[:program_group], ids: transacion_ids }
        ],
        status: values[:todo],
        can_reinitiate: values[:can_reinitiate],
        comment: values[:comment]
      }
      hash['payload'] = JSON.dump(hash['payload'])
      ApiMethod('update', hash)
    end

    def release_transaction(values)
      bulk_upload = values[:bulk_upload].nil? ? false : values[:bulk_upload]
      skip_counterparty_approval = values[:skip_counterparty_approval].nil? ? false : values[:skip_counterparty_approval]
      rel_values = {
        actor: '',
        program_group: values[:program_group],
        transaction_id: values[:transaction_id],
        todo: 'approved',
        can_reinitiate: false,
        comment: ''
      }
      unless bulk_upload
        rel_values.merge!(actor: 'product')
        resp = approve_transcation(rel_values)
        raise resp.to_s unless resp[:code] == 200
      end
      unless skip_counterparty_approval
        rel_values.merge!(actor: values[:counter_party])
        resp = approve_transcation(rel_values)
        raise resp.to_s unless resp[:code] == 200

        rel_values.merge!(actor: 'product')
        resp = approve_transcation(rel_values)
        raise resp.to_s unless resp[:code] == 200
      end
      resp = [1].include?(values[:program_id]) ? get_transaction_details(values[:transaction_id]) : get_po_details(values[:transaction_id])
      unless resp[:body][:status] == 'investor_approved'
        rel_values.merge!(actor: values[:investor_actor])
        resp = approve_transcation(rel_values)
        raise resp.to_s unless resp[:code] == 200
      end

      true
    rescue => e
      e
    end

    def seed_transaction(values)
      program_mapping = {
        'Invoice Financing - Vendor' => 1,
        'Invoice Financing - Dealer' => 2,
        'PO Financing - Vendor' => 4,
        'PO Financing - Dealer' => 3,
        'Dynamic Discounting - Vendor' => 5
      }
      unless $conf['env'] == 'staging' # program id for PO is different in qa and demo env
        program_mapping.merge!(
          'PO Financing - Vendor' => 3,
          'PO Financing - Dealer' => 4
        )
      end
      values[:program_id] = program_mapping[values[:program]]
      resp = if [1, 2, 5].include? values[:program_id]
               create_transaction(values[:actor], values[:invoice_details], values[:invoice_file], values[:program_id])
             else
               create_po_transaction(values)
             end
      raise "Transaction not created! #{resp}" unless [200, 201].include? resp[:code]

      transaction_id = resp[:body][:id].to_s

      if resp[:body][:status] == 'pending_investor_assignment'
        values[:program_id] = 2 if values[:program_id] == 3
        transaction_type = resp[:body][:invoice_name].nil? ? 'po' : 'invoice'
        assign_values = {
          ids: [transaction_id],
          program_id: values[:program_id],
          actor: values[:actor],
          investor_id: values[:investor_id],
          type: transaction_type
        }
        assign_values.merge!(vendor_id: resp[:body][:vendor][:id]) if resp[:body][:initiator] == 'anchor'
        assign_values.merge!(anchor_id: resp[:body][:anchor][:id]) if resp[:body][:initiator] == 'vendor'
        resp = assign_investor(assign_values)
        raise "Investor cannot be assigned! #{resp}" unless resp[:code] == 200

        values[:program_id] = 3
      end
      if values[:program] == 'Dynamic Discounting - Vendor'
        approve_values = {
          actor: values[:counter_party],
          investor_actor: 'investor',
          program_group: values[:program_group],
          transaction_id: transaction_id,
          todo: 'approved',
          can_reinitiate: false,
          comment: ''
        }
        approve_values.merge!(investor_actor: values[:investor_actor]) unless values[:investor_actor].nil?
        resp = approve_transcation(approve_values)
        flag = resp[:code] == 200
      else
        values[:transaction_id] = transaction_id
        values[:investor_actor] = 'investor' if values[:investor_actor].nil? # Default, Kotak
        values[:program_id] = values[:program_group].eql?('invoice') ? 1 : 2
        flag = release_transaction(values)
      end
      raise "Error in Approval of transaction #{flag}" unless flag == true

      transaction_id
    rescue => e
      p "Error while creating transaction - Exception: #{e}"
    end

    def assign_investor(values)
      hash = {}
      hash['headers'] = load_headers(values[:actor])
      hash['uri'] = $conf['api_url'] + $endpoints['transactions'][values[:type]]['assign_investor']
      hash['payload'] = { program_id: values[:program_id] }
      hash['payload'].merge!(investor_id: values[:investor_id]) unless values[:investor_id].nil?
      hash['payload'].merge!(invoice_ids: values[:ids]) if values[:type] == 'invoice'
      hash['payload'].merge!(po_ids: values[:ids]) if values[:type] == 'po'
      hash['payload'].merge!(anchor_id: values[:anchor_id]) unless values[:anchor_id].nil?
      hash['payload'].merge!(vendor_id: values[:vendor_id]) unless values[:vendor_id].nil?
      ApiMethod('patch', hash)
    end

    def fetch_assign_investors(values)
      hash = {}
      hash['headers'] = load_headers(values[:actor])
      hash['uri'] = $conf['api_url'] + $endpoints['transactions'][values[:type]]['get_assign_investors']
      hash['headers'][:params] = { program_id: values[:program_id], vendor_id: values[:vendor_id] }
      hash['headers'][:params].merge!(anchor_id: values[:anchor_id]) unless values[:anchor_id].nil?
      hash['headers'][:params].merge!(vendor_id: values[:vendor_id]) unless values[:vendor_id].nil?
      hash['headers'][:params].merge!('invoice_ids[]': values[:ids])
      hash['headers'][:params].merge!('po_ids[]': values[:ids]) if values[:type] == 'po'
      ApiMethod('fetch', hash)
    end

    def re_initiate_transaction(values)
      hash = {}
      hash['uri'] = $conf['api_url'] + construct_base_uri($endpoints['transactions'][values[:type]]['re_initiate'], values[:id].to_s)
      hash['headers'] = load_headers(values[:actor])
      payload = {}
      if values[:type] == 'po'
        payload = {
          'purchase_order[po_value]': values[:instrument_value],
          'purchase_order[po_eligible_value]': values[:required_disbursement_value],
          'purchase_order[po_date]': values[:instrument_date],
          'purchase_order[investor_id]': values[:investor_id]
        }
        payload.merge!('purchase_order[document]': File.new(values[:document])) unless values[:document].nil?
      else
        payload = {
          'invoice[invoice_value]': values[:invoice_value],
          'invoice[invoice_date]': values[:invoice_date],
          'invoice[grn]': values[:grn],
          'invoice[requested_disbursement_value]': values[:requested_disbursement_value],
          'invoice[ewb_no]': values[:ewb_no],
          'invoice[ewb_date]': values[:ewb_date],
          'invoice[investor_id]': values[:investor_id]
        }
        payload.merge!('invoice[document]': File.new(values[:document])) unless values[:document].nil?
      end
      hash['payload'] = payload
      ApiMethod('update', hash)
    end

    def get_invoice_file_status(program_type, actor, id)
      hash = {}
      type = if program_type.include?('Dynamic')
               'dd'
             else
               program_type.include?('PO') ? 'po' : 'invoice'
             end
      hash['uri'] = $conf['api_url'] +
                    construct_base_uri($endpoints['transactions'][type]['bulk_invoice_status'], id.to_s)
      hash['headers'] = load_headers(actor)
      ApiMethod('fetch', hash)
    end

    # GET /investors/list_anchor_vendor_invoices
    def get_up_for_disbursement(values)
      hash = {}
      hash['headers'] = load_headers(values[:actor])
      hash['uri'] = $conf['api_url'] + $endpoints['disbursement']['up_for_disbursal']
      hash['headers'][:params] = {
        program_group: values[:program_group],
        anchor_id: values[:anchor_id],
        vendor_id: values[:vendor_id],
        group_id: values[:group_id]
      }
      ApiMethod('fetch', hash)
    end

    # GET /investors/to_disburse_group_invoices
    def get_disburse_group_invoices(values)
      hash = {}
      hash['headers'] = load_headers(values[:actor])
      hash['uri'] = $conf['api_url'] + $endpoints['disbursement']['get_disburse_group_invoices']
      page = 1
      group_ids = []
      hash['headers'][:params] = {
        program_group: values[:program_group],
        anchor_id: values[:anchor_id],
        vendor_id: values[:vendor_id],
        by_group_id: values[:by_group_id],
        items: 20,
        page: page
      }
      resp = ApiMethod('fetch', hash)
      resp[:body][:anchor_vendors].each { |anchor_vendor| group_ids << anchor_vendor[:group_id] }
      until page == resp[:body][:pagy_params][:last]
        page += 1
        hash['headers'][:params][:page] = page
        resp = ApiMethod('fetch', hash)
        resp[:body][:anchor_vendors].each { |anchor_vendor| group_ids << anchor_vendor[:group_id] }
      end
      group_ids
    end

    # Declines all up for disbursement transactions, used in before each
    def decline_all_up_for_disbursements(values)
      group_ids = get_disburse_group_invoices(values)
      transactions = []
      group_ids.each do |group_id|
        values[:group_id] = group_id
        resp = get_up_for_disbursement(values)
        resp[:body][:invoices].each { |invoice| transactions << invoice[:id] }
      end
      return if transactions.empty?

      values.merge!(
        comment: values[:comment],
        invoice_transaction_ids: transactions
      )
      resp = decline_multiple_transactions(values)
      raise "Could not clear all up for disbursment transactions #{resp}" unless resp[:code] == 200

      true
    end

    # Validations

    def api_transaction_listed?(queries, transaction_ids)
      resp = fetch_transaction_list(queries)
      raise resp.to_s if resp[:body][:invoices].nil?
      raise resp.to_s if resp[:code] != 200 && resp[:body][:invoices].empty?

      ids = transaction_ids.is_a?(Array) ? transaction_ids : [transaction_ids]
      list = resp[:body][:invoices]
      property = queries[:category] == 'live_invoices' ? :invoice_id : :id
      found = []
      ids.each do |id|
        found << list.select { |transaction| transaction[property] == id.to_i }
      end
      found.flatten!
      found.empty? ? ["#{transaction_ids} not present in #{queries}"] : [true, found]
    end

    def status_present_in_timeline?(status_timeline, details_to_verify)
      is_passed = details_to_verify[:is_passed].nil? ? true : details_to_verify[:is_passed]
      details_to_verify[:invoice_state].each do |state|
        status_timeline.each do |status|
          flag = state == status[:invoice_state]
          change_date = Date.parse(status[:change_date])
          flag &= change_date == details_to_verify[:change_date]
          flag &= status[:is_passed] == is_passed
          return true if flag
        end
      end
      [status_timeline, details_to_verify]
    end

    def api_verify_transaction_in_list_page(response_body, test_data)
      values = test_data.dup
      hash = {
        status: response_body[:display_status],
        channel_partner_name: response_body[:vendor][:name].capitalize,
        anchor_name: response_body[:anchor][:name].capitalize,
        investor_name: response_body[:investor][:name].capitalize,
        date_of_initiation: Date.parse(response_body[:created_at]).strftime('%d %b, %Y').capitalize,
        transaction_value: response_body[:transaction_value].to_i.to_s.capitalize
      }
      hash.merge!(instrument_value: response_body[:po_eligible_value].to_i.to_s.capitalize) unless response_body[:po_eligible_value].nil?
      hash.merge!(po_number: response_body[:po_number].capitalize) unless response_body[:po_number].nil?
      hash.merge!(po_value: "#{(response_body[:po_value] / 100000.to_f).round(2)}LAC".capitalize) unless response_body[:po_value].nil?
      hash.merge!(invoice_value: response_body[:invoice_value].to_i.to_s.capitalize) unless response_body[:invoice_value].nil?
      hash.merge!(po_eligible_value: response_body[:po_eligible_value]) unless response_body[:po_eligible_value].nil?
      not_matched = []
      ['Transaction Value', 'Instrument Value'].each do |key|
        if !values[key].nil? && ![Integer, Float].include?(values[key].class)
          values[key] = remove_comma_in_numbers(values[key])
        end
      end

      values.each_key do |key|
        not_matched << values[key] unless hash.value? values[key].capitalize
      end
      not_matched.empty? ? true : "#{not_matched} not found in #{hash}"
    end

    def api_verify_transaction_details_page(response_body, values)
      hash = {
        status: response_body[:display_status],
        anchor_name: response_body[:anchor][:name],
        date_of_initiation: Date.parse(response_body[:created_at]).strftime('%d %b, %Y'),
        invoice_value: response_body[:invoice_value].to_i.to_s
      }
      hash.merge!(channel_partner_name: response_body[:vendor][:name]) unless response_body[:vendor].nil?
      hash.merge!(channel_partner_name: response_body[:dealer][:name]) unless response_body[:dealer].nil?
      not_matched = []
      values.each_key do |key|
        not_matched << values[key] unless hash.value? values[key]
      end
      not_matched.empty? ? true : "#{not_matched} not found in #{hash}"
    end

    def validate_comments(response, values)
      comment = response[:comments][0]
      flag = comment[:comment_type] == values[:comment_type]
      flag &= comment[:name] == values[:name]
      flag &= comment[:comment] == values[:comment]
      return true if flag

      "#{values} not found in #{response[:comments]}"
    end

    def verify_document_is_uploaded_and_valid(response_body, values, search_in_array: false)
      raise 'documents in response body is empty' if response_body[:documents].empty?

      index = 0
      if search_in_array
        response_body[:documents].each_with_index { |doc, count| index = count if doc[:file_name] == values[:file_name] }
      end
      raise "expected #{values[:document_type]} got: #{response_body[:documents][index][:document_type]}" unless response_body[:documents][index][:document_type] == values[:document_type]
      raise "expected: #{values[:file_name]}, got: #{response_body[:documents][index][:file_name]}" unless response_body[:documents][index][:file_name] == values[:file_name]
      raise 'file_url is empty' unless response_body[:documents][index][:file_url].empty? == false

      resp = request_url(@tran_resp[:body][:documents][index][:file_url])
      raise resp.to_s unless resp.code == 200
      raise "expected: 'application/pdf', got: #{resp.headers[:content_type]}" unless resp.headers[:content_type] == 'application/pdf'

      true
    end

    def fetch_status_of_transaction(response_body)
      { status: response_body[:status], display_status: response_body[:display_status], action_label: response_body[:action_label] }
    end

    def wait_till_doc_processed(values)
      status_resp = get_invoice_file_status(values[:program_type], values[:actor], values[:id])
      count = 0
      until status_resp[:body][:state] == values[:expected_state]
        break if status_resp[:body][:state] == 'failed'

        sleep 5
        status_resp = get_invoice_file_status(values[:program_type], values[:actor], values[:id])
        count += 1
        break if count > 5
      end
      count = 0
      while status_resp[:body][:report_url].nil?
        sleep 5
        status_resp = get_invoice_file_status(values[:program_type], values[:actor], values[:id])
        count += 1
        break if count > 5
      end
      status_resp[:body][:state]
    end

    def fetch_sample_date_and_their_count(values)
      created_at = []
      due_date = []
      instrument_date = []
      group_ids = get_disburse_group_invoices(values)
      group_ids.each do |group_id|
        values[:group_id] = group_id
        resp = get_up_for_disbursement(values)
        invoices = resp[:body][:invoices]
        invoices.each do |invoice|
          created_at << invoice[:created_at]
          instrument_date << invoice[:po_date]
          due_date << invoice[:settlement_date]
        end
      end
      hash = {
        to_validate_created_at: created_at.sample,
        to_validate_instrument_date: instrument_date.sample,
        to_validate_due_date: due_date.sample
      }
      hash.merge!(
        count_of_created_at: created_at.count(hash[:to_validate_created_at]),
        count_of_instrument_date: instrument_date.count(hash[:to_validate_instrument_date]),
        count_of_due_date: due_date.count(hash[:to_validate_due_date])
      )
      hash
    end

    def wait_till_checker1_approval(investor_actor, investor_id, program_id)
      count = 0
      until count == 15

        sleep 2
        count += 1
        resp = get_anchor_commercials(investor_actor: investor_actor, investor_id: investor_id, anchor_program_id: program_id)
        break if resp[:body][:result][:status] == 'pending_checker_1_approval'
      end
      resp[:body][:result][:status]
    end
  end
end
