module Rack
  class Cookieless
    def initialize(app, options={})
      @app, @options = app, options
    end

    def cache_store
      options[:cache_store] || Rails.cache
    end

    def session_id
      (options[:session_id] || :session_id).to_s
    end

    def call(env)
      if support_cookie?(env)
        @app.call(env)
      else
        _session_id = Rack::Utils.parse_query(env["QUERY_STRING"], "&")[session_id]

        cache_id = (_session_id + ip + browser + language).sha1

        session = cache_store.fetch(cache_id) { {} }

        #set env[rack.session]

        @app.call(env)
        # add session_id to links, form in body
        # read env[rack.session] & save it to cache_store
      end
    end

    def support_cookie?(env)
    end
  end
end
