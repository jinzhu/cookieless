require 'digest/sha1'

module Rack
  class Cookieless
    def initialize(app, options={})
      @app, @options = app, options
    end

    def cache_store
      @options[:cache_store] || Rails.cache
    end

    def session_key
      (@options[:session_id] || :session_id).to_s
    end

    def call(env)
      if support_cookie?(env)
        @app.call(env)
      else
        session_id = Rack::Utils.parse_query(env["QUERY_STRING"], "&")[session_key].to_s

        if session_id.present?
          cache_id = Digest::SHA1.hexdigest(session_id + env["HTTP_USER_AGENT"] + env["REMOTE_ADDR"])
          env["rack.session"].update(cache_store.fetch(cache_id) { env["rack.session"] })
        end

        status, header, response = @app.call(env)

        if session_id.blank?
          session_id = env["rack.session"]["session_id"]
          cache_id = Digest::SHA1.hexdigest(session_id + env["HTTP_USER_AGENT"] + env["REMOTE_ADDR"])
        end

        response.body = process_body(response.body, session_id)
        cache_store.write(cache_id, env["rack.session"].to_hash)

        [status, header, response]
      end
    end

    def process_body(body, session_id)
      body_doc = Nokogiri::HTML(body)
      #TODO: change hardcode "?_session_id"
      body_doc.css("a").map { |a| a["href"] += "?_session_id=#{session_id}" if a["href"] }
      body_doc.css("form").map do |form|
        session_id_input = Nokogiri::XML::Node.new "input",body_doc
        [["name","_session_id"], ["value", session_id], ["type", "hidden"]].map { |attr, value| session_id_input[attr] = value }
        form.add_child(session_id_input)
      end
      body_doc.to_html
    end

    def support_cookie?(env)
      false
    end
  end
end
