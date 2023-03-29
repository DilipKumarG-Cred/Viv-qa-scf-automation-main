module Api
  module CommonApi
    def load_headers(actor)
      raise 'Given actor to load headers is nil' if actor.to_s.empty?

      set_cookies([actor])
      hash = set_headers(actor)
      hash['mfa-token'] = hash['mfa_token']
      hash.delete('mfa_token')
      hash.delete('Current-Sub-Group') if hash['Current-Group'] == 'product'
      hash['Authorization'] = hash['access_token']
      hash.delete('access_token')
      hash
    rescue => e
      p e.backtrace_locations[0..10]
      raise "Error in loading headers for #{actor}, #{e}"
    end

    def add_content_type_json(hash)
      hash['Content-Type'] = 'application/json'
      hash
    end

    def get_params_from_uri(url)
      params = {}
      return {} if !url.include?('?') && !url.include?('&')

      url.split('?')[1].split('&').each do |param|
        key, value = param.split('=')
        params[key] = value
      end
      params
    end

    def request_url(url)
      RestClient::Request.execute(url: url, method: :get)
    end

    def modify_url_with_actor(hash)
      party_hash = { 'product' => 'products', 'anchor' => 'anchors', 'investor' => 'investors', 'vendor' => 'vendors' }
      actor = hash['headers']['Current-Group'] == 'customer' ? party_hash[hash['headers']['Current-Sub-Group']] : party_hash[hash['headers']['Current-Group']]
      hash['uri'].gsub('{actor}', actor)
      hash
    end

    def request_url_with_actor(url, params, actor)
      hash = {}
      hash['uri'] = url
      hash['headers'] = load_headers(actor)
      hash['headers'][:params] = params
      ApiMethod('fetch', hash)
    end
  end
end
