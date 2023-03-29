module Api
  module Pages
    class Common
      def date_format?(value)
        !%r((^\d{4}[-|/]\d{1,2}[-|/]\d{1,2})|(^\d{1,2}[-|/]\w{1,3}[-|/]\d{4})|(^\d{1,2}[-|/]\d{1,2}[-|/]\d{4})).match(value.to_s).nil?
      end

      def gstn_format?(value)
        return false unless value.is_a? String

        !value.match(/\d{2}[A-Z]{5}\d{4}[A-Z]{1}[A-Z\d]{1}Z{1}[A-Z\d]{1}/).nil?
      end

      def type_of_data(field_value)
        if date_format?(field_value)
          type = 'date'
        elsif field_value.is_a? Integer
          type = 'integer'
        elsif field_value.is_a? Float
          type = 'float'
        elsif [true, false].include? field_value
          type = 'boolean'
        elsif gstn_format?(field_value)
          type = 'gstn'
        elsif File.exist? field_value
          type = 'file'
        end
        type
      end

      def perform_post_action(current_module, change_field, payload, configs)
        temp_payload = payload.dup
        temp_payload.merge!(change_field)
        case current_module
        when 'create_invoice'
          resp = create_transaction(configs['user'], temp_payload, temp_payload['Invoice file'], configs['program_id'])
        when 'create_bulk_invoice'
          resp = create_bulk_transaction(configs, temp_payload['Invoice file'])
        when 'create_po'
          values = {
            actor: configs['user'],
            po_details: temp_payload,
            po_file: temp_payload['PO file'],
            program_id: configs['program_id']
          }
          resp = create_po_transaction(values)
        when 'disburse_invoice'
          temp_payload['invoice_transaction_ids'] = change_field.key?('invoice_transaction_ids') ? temp_payload['invoice_transaction_ids'] : []
          temp_payload['amount'] = change_field.key?('amount') ? temp_payload['amount'] : 0
          temp_payload['transaction_ids'].each do |id|
            details = get_transaction_details(id)
            temp_payload['invoice_transaction_ids'] << details[:body][:id] unless change_field.key? 'invoice_transaction_ids'
            temp_payload['amount'] = rounded_half_down_value(temp_payload['amount'] + details[:body][:disbursement_amount]) unless change_field.key? 'amount'
          end
          resp = disburse_transactions_for_api(temp_payload)
        when 'disburse_dd'
          resp = disburse_transactions_for_api(temp_payload, true)
        when 'resettle_invoice'
          temp_payload.merge!('liability' => configs['liability'])
          resp = resettle_invoices_api(temp_payload)
        when 'create_cp'
          resp = create_channel_partner(temp_payload)
        when 'create_bulk_cp'
          resp = seed_bulk_vendor(temp_payload)
        end
        resp
      end

      # For disbursements
      def create_transactions_for_api(hash, count = 1)
        configs = hash[:configs]
        invoice_meta_data = hash[:invoice_meta_data]
        transation_ids = []
        count.times do
          case hash[:vendor]
          when 'Dozco'
            invoice_details = JSON.parse(ERB.new(invoice_meta_data).result(binding))['invoice']['create']
          when 'Ramkay'
            invoice_details = JSON.parse(ERB.new(invoice_meta_data).result(binding))['invoice']['create_ramkay']
          end
          transaction_id = seed_transaction(
            {
              actor: configs['actor'],
              counter_party: configs['counter_party'],
              invoice_details: invoice_details,
              invoice_file: invoice_details['Invoice file'],
              program: configs['program_name']
            }
          )
          transation_ids << transaction_id
        end
        raise "Transaction not created! #{transation_ids}" if transation_ids == []

        transation_ids
      end

      def disburse_transactions_for_api(values, dynamic_discounting = false)
        hash = {}
        hash['uri'] = $conf['api_url'] + (dynamic_discounting ? $endpoints['transactions']['dd']['disburse'] : $endpoints['disbursement']['disburse'])
        hash['headers'] = dynamic_discounting ? load_headers(values['anchor_actor']) : load_headers('investor')
        document = begin
          File.new(values['document'], 'rb')
        rescue
          values['document']
        end
        hash['payload'] = {
          document: document,
          utr_number: values['utr_number'],
          disbursement_account_number: values['disbursement_account_number'],
          payment_date: values['payment_date'],
          amount: values['amount'],
          invoice_transaction_ids: values['invoice_transaction_ids'],
          vendor_id: values['vendor_id'],
          program_id: values['program_id']
        }
        hash['payload'].merge!(anchor_id: values['anchor_id']) unless dynamic_discounting
        ApiMethod('create', hash)
      end

      def perform_get_action(action, params, actor)
        hash = {}
        hash['headers'] = load_headers(actor)
        case action
        when 'funding_history'
          hash['uri'] = $conf['api_url'] + $endpoints['disbursement']['funding_history']
        when 'transaction_associated'
          hash['uri'] = $conf['api_url'] + $endpoints['disbursement']['transactions_associated']
        when 'payment_history'
          hash['uri'] = $conf['api_url'] + $endpoints['payment']['payment_history']
          hash['uri'] = hash['uri'].gsub('anchors', 'investors') if hash['headers']['Current-Group'] == 'investor'
          hash['uri'] = hash['uri'].gsub('anchors', 'vendors') if hash['headers']['Current-Group'] == 'vendor'
        when 'transaction_history'
          hash['uri'] = $conf['api_url'] + $endpoints['payment']['transaction_history']
          hash['uri'] = hash['uri'].gsub('anchors', 'investors') if hash['headers']['Current-Group'] == 'investor'
        when 'pending_dues_invoice'
          hash['uri'] = $conf['api_url'] + $endpoints['payment']['pending_dues']['invoice_level']
        when 'pending_dues_entity'
          hash['uri'] = $conf['api_url'] + $endpoints['payment']['pending_dues']['entity_level']
        when 'vendor_pending_dues_entity'
          hash['uri'] = $conf['api_url'] + $endpoints['vendor']['pending_dues']['entity_level']
        when 'due_disbursement'
          hash['uri'] = $conf['api_url'] + $endpoints['disbursement']['due']
        end
        hash['headers'][:params] = params
        ApiMethod('fetch', hash)
      end

      # For Repayments
      # seed
      def get_reciept_for_new_resettled_transaction(hash)
        resp = create_disbursed_transaction_for_api(hash)
        p "Error in Transaction Disbursal #{resp[:code]} #{resp[:body][:error][:message]}" if resp[:code] != 200
        payload = hash[:resettle_payload].transform_keys(&:to_sym)
        payload[:overdue_amount] = payload[:amount]
        resp = repay(payload, hash[:resettle_payload]['liability'])
        p "Error in Transaction Resettlement #{resp[:code]} #{resp[:body][:error][:message]}" if resp[:code] != 200
        resp[:body][:id]
      end

      def create_disbursed_transaction_for_api(hash)
        disbursement_configs = hash[:disbursement_configs]
        invoice_meta_data = hash[:invoice_meta_data]
        disbursement_meta_data = hash[:disbursement_meta_data]
        case hash[:vendor]
        when 'Dozco'
          disbursement_payload = JSON.parse(ERB.new(disbursement_meta_data).result(binding))['disburse']
        when 'Ramkay'
          disbursement_payload = JSON.parse(ERB.new(disbursement_meta_data).result(binding))['disburse_to_ramkay']
        end
        hash[:configs] = disbursement_configs
        @transactions_ids = create_transactions_for_api(hash)
        disbursement_payload['invoice_transaction_ids'] = []
        disbursement_payload['amount'] = 0
        @transactions_ids.each do |id|
          details = get_transaction_details(id)
          disbursement_payload['invoice_transaction_ids'] << details[:body][:id]
          disbursement_payload['amount'] = rounded_half_down_value(disbursement_payload['amount'] + details[:body][:disbursement_amount])
        end
        disbursement_payload['payment_date'] = (Date.today - disbursement_configs['tenor']).strftime('%Y-%m-%d')
        disburse_transactions_for_api(disbursement_payload)
      end

      def resettle_invoices_api(values)
        hash = {}
        hash['uri'] = $conf['api_url'] + $endpoints['payment']['resettle']
        hash['headers'] = load_headers(values['liability'])
        begin
          document = File.new(values['document'], 'rb')
        rescue
          document = values['document']
        end
        hash['payload'] = {
          multipart: true,
          document: document,
          utr_number: values['utr_number'],
          payment_date: values['payment_date'],
          amount: values['amount'],
          investor_id: values['investor_id'],
          program_id: values['program_id'],
          vendor_id: values['vendor_id'],
          anchor_id: values['anchor_id']
        }
        ApiMethod('create', hash)
      end

      def get_disbursement_details_for_dd(erb_file, disbursement_erb_file, values)
        testdata = JSON.parse(ERB.new(erb_file).result(binding))['dd']
        invoice_value = testdata['create']['Invoice Value'] < testdata['create']['GRN'] ? testdata['create']['Invoice Value'] : testdata['create']['GRN']
        values[:invoice_details] = testdata['create']
        transaction_id = seed_transaction(values)
        raise "Transaction not created! #{transaction_id}" if transaction_id.include?('Error while creating transaction')

        disburse = JSON.parse(ERB.new(disbursement_erb_file).result(binding))['disburse_dd']
        disburse_config = JSON.parse(ERB.new(disbursement_erb_file).result(binding))['config_for_dd']
        tran_details = get_transaction_details(transaction_id)
        disburse['invoice_transaction_ids'] = [tran_details[:body][:id]]
        disburse['amount'] = tran_details[:body][:transaction_value]
        disburse['anchor_actor'] = disburse_config['actor']
        disburse
      end
    end
  end
end
