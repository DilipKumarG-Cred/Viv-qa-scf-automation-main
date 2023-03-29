require './spec_helper'
describe 'Pre-requisite validations', :smoke do
  it 'Smoke Test: Users Login Validations' do |e|
    e.run_step 'Verify whether cookies can be set' do
      could_not_load = []
      # $conf['users'].each_key do |user|
      ['product', 'anchor', 'investor'].each do |user|
        load_headers(user)
      rescue
        could_not_load << user
      end
      could_not_load.flatten!
      expect(could_not_load.empty?).to eq(true)
    end
  end

  it 'Smoke Test: GET : /invoices' do |e|
    ['investor', 'anchor', 'vendor', 'dealer', 'product', 'grn_anchor'].each do |actor|
      e.run_step "/invoices for user #{$conf['users'][actor]['email']}" do
        url = $conf['api_url'] + $endpoints['transactions']['invoice']['get']
        params = { page: 1, items: 30, program_group: 'invoice' }
        resp = request_url_with_actor(url, params, actor)
        expect(resp[:code]).to eq(200), resp.to_s
      end
    end
  end

  it 'Smoke Test: GET : /list_all_vendors' do |e|
    ['anchor', 'product', 'grn_anchor'].each do |actor|
      e.run_step "/list_all_vendors for user #{$conf['users'][actor]['email']}" do
        url = $conf['api_url'] + $endpoints['anchor']['list_all_vendors']
        params = { page: 1, program_type: 'Vendor', items: 10 }
        resp = request_url_with_actor(url, params, actor)
        expect(resp[:code]).to eq(200), resp.to_s
      end
      e.run_step "/list_all_vendors for user #{$conf['users'][actor]['email']}" do
        url = $conf['api_url'] + $endpoints['anchor']['list_all_vendors']
        params = { page: 1, program_type: 'Dealer', items: 10 }
        resp = request_url_with_actor(url, params, actor)
        expect(resp[:code]).to eq(200), resp.to_s
      end
    end
  end
end
