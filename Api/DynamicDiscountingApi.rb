module Api
  module DynamicDiscounting
    def delete_rule(actor)
      hash = {}
      program = get_anchor_program('Dynamic Discounting', actor)
      program_id = program[0][:id]
      hash['uri'] = $conf['api_url'] + construct_base_uri($endpoints['dynmaic_discount']['delete_rule'], program_id.to_s)
      hash['headers'] = load_headers(actor)
      ApiMethod('delete', hash)
    end

    def form_rules_payload(rules = [])
      payload = {
        'anchor_program_rule': {
          'rules': []
        }
      }
      rules.each do |rule|
        each_rule = {
          "logical_operator": rule['operator'].nil? ? 'and' : rule['operator'],
          "sub_rules": []
        }
        rule['sub_rules'].each do |sub_rule|
          sr = {
            "logical_operator": sub_rule['operator'].nil? ? 'and' : sub_rule['operator'],
            "lhs": sub_rule['name'],
            "expression_operator": sub_rule['condition'],
            "rhs": sub_rule['value']
          }
          each_rule[:sub_rules] << sr
        end
        payload[:anchor_program_rule][:rules] << each_rule
      end
      payload
    end

    def create_rule(actor, rules)
      hash = {}
      program = get_anchor_program('Dynamic Discounting', actor)
      program_id = program[0][:id]
      hash['uri'] = $conf['api_url'] + construct_base_uri($endpoints['dynmaic_discount']['create_rule'], program_id.to_s)
      hash['headers'] = load_headers(actor)
      hash['payload'] = form_rules_payload(rules)
      ApiMethod('create', hash)
    end

    def get_platform_fee(actor)
      resp = get_anchor_program_detail('Dynamic Discounting', actor)
      resp[:body][:anchor_program][:fee_percentage]
    end

    def add_platform_fee(fee, anchor_user, product_user)
      hash = {}
      hash['uri'] = $conf['api_url'] + $endpoints['dynmaic_discount']['add_platform_fee']
      hash['headers'] = load_headers(product_user)
      program = get_anchor_program('Dynamic Discounting', anchor_user)
      program_id = program[0][:id]
      hash['payload'] = {
        "anchor_program_id": program_id,
        "fee_percentage": fee.to_i
      }
      ApiMethod('create', hash)
    end

    def remove_platform_fee
      hash = {}
      hash['uri'] = $conf['api_url'] + $endpoints['dynmaic_discount']['add_platform_fee']
      ApiMethod('create', hash)
    end

    def get_cost_of_funds(actor)
      resp = get_anchor_program_detail('Dynamic Discounting', actor)
      resp[:body][:anchor_program][:cost_of_funds_percentage]
    end
  end
end
