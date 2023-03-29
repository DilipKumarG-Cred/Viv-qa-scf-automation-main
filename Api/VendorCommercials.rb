module Api
  module VendorCommercials
    def delete_vendor_commercials(values)
      resp = get_vendor_commercial(values)
      return resp[:body][:error][:message].to_s if resp[:code] == 404
      return "Skipping deletion... Commercials not found for #{values['Vendor Name']}" if resp[:body] == {}

      program_limit_id = resp[:body][:program_limits][:id]
      hash = {}
      hash['headers'] = load_headers('product')
      hash['uri'] = $conf['api_url'] + construct_base_uri($endpoints['product']['delete_vendor_commercials'], program_limit_id.to_s)
      ApiMethod('delete', hash)
    end

    def get_vendor_commercial(values)
      hash = {}
      hash['headers'] = load_headers(values['actor'])
      anchor_program_id = get_anchor_program_id(values['Program'], values['Type'], values['Anchor ID'])
      vendor_details = verify_vendor_present(anchor_program_id, values['Investor ID'], values['Vendor Name'])
      hash['uri'] = $conf['api_url'] + $endpoints['vendor']['get_vendor_commercial']
      hash['headers'][:params] = { 'anchor_program_id' => anchor_program_id, 'investor_id' => values['Investor ID'], 'vendor_id' => vendor_details[:id] }
      ApiMethod('fetch', hash)
    end

    # GET /programs/list_vendors
    def verify_vendor_present(anchor_program_id, investor_id, vendor_name, actor: 'product')
      hash = {}
      hash['headers'] = load_headers(actor)
      hash['uri'] = $conf['api_url'] + $endpoints['vendor']['list_vendor']
      page = 1
      vendor = []
      loop do
        hash['headers'][:params] = { 'investor_id': investor_id, 'anchor_program_id': anchor_program_id, 'items': 30, 'page': page, vendor_name: vendor_name }
        resp = ApiMethod('fetch', hash)
        vendor << resp[:body][:vendors][0]
        break unless vendor.empty?
        break if page == resp[:body][:pagy_params][:last]

        page += 1
      end
      vendor.empty? ? [] : vendor[0]
    rescue => e
      raise e
    end

    def set_and_approve_commercials(values)
      set_resp = set_commercials(values)
      raise "Error in setting Commercials #{set_resp}" unless [200, 201].include?(set_resp[:code])

      values['Program Limit ID'] = set_resp[:body][:program_limits][:id]
      resp = upload_vendor_bd(values)
      p "Error in uploading borrowing document #{resp}" unless resp[:code] == 200

      resp = set_commercials(values, action: :submit)
      raise "Error in submitting vendor commercials #{resp}" unless resp[:code] == 200

      sleep MIN_LOADER_TIME # wait for data reflection
      r = get_vendor_commercial(values)
      raise "Commercial not moved to 'Verified' state from '#{r[:body][:program_limits][:status]}'" unless r[:body][:program_limits][:status] == 'Verified'

      resp = vendor_fee_payment(values)
      raise "Error in Fee payment #{resp}" unless resp[:code] == 200

      values['Payment Reciept ID'] = resp[:body][:program_limits][:payment_receipts][0][:id]
      resp = review_processing_fee(values)
      raise "Error in Processing Fee approval #{resp}" unless resp[:code] == 200

      [set_resp[:code], set_resp]
    rescue => e
      [e]
    end

    def set_commercials(values, action: :set)
      hash = {}
      hash['headers'] = load_headers(values['Investor'])
      hash['headers'] = add_content_type_json(hash['headers'])
      hash['uri'] = $conf['api_url'] + $endpoints['vendor']['set_limits']
      hash['payload'] = {
        vendor_id: values['Vendor ID'],
        anchor_program_id: values['Anchor Program ID'],
        tenor: values['Tenor'],
        yield: values['Yield'],
        valid_from: (Date.today - 5).strftime('%Y-%m-%d'),
        valid_till: values['Valid Till'],
        payment_strategy: values['Payment Strategy'],
        sanction_limit: values['Sanction Limit'],
        processing_fee_percentage: values['Processing Fee'],
        processing_fee_of: values['Sanction Limit'],
        investor_gstn: values['Investor GSTN'],
        days_to_raise_invoice: values['Invoice Days'],
        effective_date: Date.today.strftime('%Y-%m-%d')
      }
      hash['payload'].merge!(cc_account_identifier: values['Unique Identifier']) unless values['Unique Identifier'].nil?
      if values['Interest Type'] == 'Floating'
        hash['payload'][:roi_calculation_basis] = values['ROI Calculation Basis']
        hash['payload'][:spread_percentage] = values['Spread Percentage']
        hash['payload'].delete(:yield)
      end
      case action
      when :update
        hash['uri'] = $conf['api_url'] + $endpoints['vendor']['update_limit']
        hash['payload'].merge!(program_id: values['Program Limit ID'])
        return ApiMethod('update', hash)
      when :submit
        hash['uri'] = $conf['api_url'] + $endpoints['vendor']['update_limit']
        hash['payload'] = { submit: true, program_id: values['Program Limit ID'] }
        return ApiMethod('update', hash)
      when :admin_update
        hash['uri'] = $conf['api_url'] + construct_base_uri($endpoints['investor']['update_vendor_commercials'], values['Vendor ID'].to_s)
        hash['payload'].merge!(program_id: values['Program Limit ID'])
        return ApiMethod('update', hash)
      end
      hash['payload'] = JSON.dump(hash['payload'])
      ApiMethod('create', hash)
    rescue => e
      raise "Error in setting commercials #{e}"
    end

    def approve_vendor_commercial(values)
      hash = {}
      hash['headers'] = load_headers(values['Vendor'])
      hash['uri'] = $conf['api_url'] + $endpoints['vendor']['approve_limit']
      hash['payload'] = {
        investor_id: values['Investor ID'],
        anchor_program_id: values['Anchor Program ID']
      }
      ApiMethod('create', hash)
    rescue => e
      raise e
    end

    def upload_vendor_bd(values)
      hash = {}
      hash['headers'] = load_headers(values['Investor'])
      hash['uri'] = $conf['api_url'] + construct_base_uri($endpoints['vendor']['upload_bd'], values['Program Limit ID'].to_s)
      begin
        document = File.new(values['Borrowing Document'], 'rb')
      rescue
        document = values['Borrowing Document']
      end
      hash['payload'] = {
        multipart: true,
        document: document
      }
      ApiMethod('create', hash)
    rescue => e
      raise "Error in uploading borrowing document #{e}"
    end

    def vendor_fee_payment(values)
      hash = {}
      hash['headers'] = load_headers(values['Vendor'])
      hash['uri'] = $conf['api_url'] + $endpoints['vendor']['fee_payment']
      begin
        document = File.new(values['Payment Document'], 'rb')
      rescue
        document = values['Payment Document']
      end
      hash['payload'] = {
        multipart: true,
        document: document,
        program_id: values['Program Limit ID'],
        utr_number: values['UTR Number'],
        payment_date: values['Payment Date']
      }
      ApiMethod('update', hash)
    rescue => e
      raise "Error in processing fee payment #{e}"
    end

    def review_processing_fee(values, action: 'approve', reason: '')
      hash = {}
      hash['headers'] = load_headers(values['Investor'])
      hash['uri'] = $conf['api_url'] + construct_base_uri($endpoints['vendor']['approve_processing_fee'], values['Payment Reciept ID'].to_s)
      hash['payload'] = { type: action }
      hash['payload'].merge!(reason: reason) unless reason.empty?
      ApiMethod('patch', hash)
    rescue => e
      raise "Error in #{action} processing fee #{e}"
    end

    def fetch_fee_notifications(actor)
      hash = {}
      hash['headers'] = load_headers(actor)
      hash['uri'] = $conf['api_url'] + $endpoints['vendor']['vendor_fee_notifications']
      ApiMethod('fetch', hash)
    end

    def get_document_template(values)
      hash = {}
      hash['headers'] = load_headers(values[:actor])
      hash['uri'] = $conf['api_url'] + $endpoints['document_template']
      hash['uri'] = hash['uri'].gsub('invoice_files', 'vendor_files') if values[:which_template] == 'vendor'
      hash['headers'][:params] = { program_id: values[:program_id] }
      ApiMethod('fetch', hash)
    end

    # For Validations
    def fetch_vendor_details(response_body)
      {
        city: response_body[:vendor_details][:city],
        geography: response_body[:vendor_details][:geography],
        contact_no: response_body[:anchor_program_vendor_detail][:contact_no],
        pan: response_body[:pan],
        entity_type: response_body[:vendor_details][:entity_type]
      }
    end
  end
end
