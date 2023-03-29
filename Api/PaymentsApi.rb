module Api
  module Payments
    def over_due_payments(values)
      page = 1
      anchor_vendors = []
      investor_id = ''
      loop do
        hash = {}
        hash['uri'] = $conf['api_url'] + $endpoints['payment']['investor_overdue']
        hash['headers'] = load_headers(values[:investor_actor])
        hash['headers'][:params] = { page: page, items: 50, program_group: values[:program_group], anchor_id: values[:anchor_id] }
        resp = ApiMethod('fetch', hash)
        anchor_vendors << resp[:body][:anchor_vendors].select { |x| x[:state] == 'approved' && x[:vendor][:name] == values[:vendor] }
        anchor_vendors.flatten!
        investor_id = resp[:body][:investor][:id] if page == 1
        break if anchor_vendors.size.positive? || page == resp[:body][:pagy_params][:pages]

        page += 1
      end
      [investor_id, anchor_vendors]
    rescue => e
      puts "Exception in fetching overdue payments #{e}"
    end

    def get_complete_overdue_payments(anchor, vendor, investor)
      anchors_list = retrieve_anchor_list(investor, anchor_name: anchor)
      anchor_vendors = []
      values = {
        anchor_id: anchors_list[0][:id],
        investor_actor: investor,
        vendor: vendor,
        program_group: 'invoice'
      }
      investor_id, invoice_overdue = over_due_payments(values)
      anchor_vendors << invoice_overdue
      values[:program_group] = 'po'
      invoice_overdue = over_due_payments(values)[1]
      anchor_vendors << invoice_overdue
      anchor_vendors.flatten!
      [investor_id, anchor_vendors]
    end

    def clear_all_overdues(values)
      investor = values[:investor].nil? ? 'investor' : values[:investor]
      investor_id, program_details = get_complete_overdue_payments(values[:anchor], values[:vendor], investor)
      configs = "#{values[:anchor]} and #{values[:vendor]} with #{$conf['users'][investor]['name']}"
      if program_details.empty?
        p "No dues present for #{configs}"
        return "No dues present for #{configs}"
      end
      program_details = program_details[0]
      raise program_details.to_s if program_details[:total_amount_due].nil?

      overdue_amount = program_details[:total_amount_due]
      return "No dues present for #{configs}" if overdue_amount.zero?

      # NO Overdue and program exists refers Upcoming payments for Dealer programs
      # Including Pre-payment charges for Upcoming dues(Pre-Payments), Additional payments move to refunds.
      overdue_amount += 10_000 if program_details[:overdue_invoices_count].zero?
      repay_hash = {
        overdue_amount: overdue_amount,
        investor_id: investor_id,
        program_id: program_details[:program][:id],
        vendor_id: program_details[:vendor][:id],
        anchor_id: program_details[:anchor][:id],
        payment_date: values[:payment_date]
      }
      resp = repay(repay_hash, investor)
      p resp.to_s unless resp[:code] == 200
      p "Cleared overdues for #{configs} with #{overdue_amount}" if resp[:code] == 200
      resp
    rescue => e
      p "Error in Clearing overdues #{e}"
    end

    def repay(values, liability)
      hash = {}
      hash['uri'] = $conf['api_url'] + $endpoints['payment']['resettle']
      hash['headers'] = load_headers(liability)
      payment_date = values[:payment_date].nil? ? Date.today.strftime('%Y-%m-%d') : values[:payment_date]
      hash['payload'] = {
        multipart: true,
        utr_number: "UTR#{DateTime.now.to_time.to_i}#{rand(1..999)}",
        payment_date: payment_date,
        amount: values[:overdue_amount],
        investor_id: values[:investor_id],
        program_id: values[:program_id],
        vendor_id: values[:vendor_id],
        anchor_id: values[:anchor_id]
      }
      ApiMethod('create', hash)
    end

    def get_all_refunds(entity_name = nil, actor = 'investor')
      hash = {}
      hash['uri'] = $conf['api_url'] + $endpoints['payment']['list_refunds']
      hash['headers'] = load_headers(actor)
      hash['headers'][:params] = { refund_entity: entity_name } unless entity_name.nil?
      ApiMethod('fetch', hash)
    end

    def clear_refunds(liability)
      resp = get_all_refunds
      program_details = resp[:body][:refund_entities].select { |x| x[:user_name] == liability }[0]
      return true if program_details.nil?

      hash = {}
      hash['uri'] = $conf['api_url'] + $endpoints['payment']['refund_entity']
      hash['headers'] = load_headers('investor')
      hash['payload'] = {
        multipart: true,
        "utr_number": "UTR#{DateTime.now.to_time.to_i}#{rand(1..999)}",
        "payment_date": Date.today.strftime('%Y-%m-%d'),
        "amount": program_details[:refund_amount],
        "entity_id": program_details[:id],
        "entity_group": program_details[:entity_group],
        'program_id': program_details[:program_id]
      }
      resp = ApiMethod('create', hash)
      return true if resp[:code] == 200
    end
  end
end
