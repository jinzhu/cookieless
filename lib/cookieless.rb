require 'digest/sha1'
require 'uri'

module Rack
  class Cookieless
    def initialize(app, options={})
      @app, @options = app, options
    end

    def call(env)
      # have cookies or not
      support_cookie = env["action_dispatch.cookies"].present?

      if support_cookie
        @app.call(env)
      else
        ## get session_id from uri
        session_id, cache_id = set_session_id(Rack::Utils.parse_query(env["QUERY_STRING"], "&")[session_key].to_s, env)

        ## get session_id from referer
        session_id, cache_id = set_session_id(Rack::Utils.parse_query((URI.parse(env['HTTP_REFERER']).query rescue nil))[session_key].to_s, env) if session_id.blank?

        env["rack.session"].update(cache_store.fetch(cache_id) { env["rack.session"] }) if cache_id

        status, header, response = @app.call(env)

        session_id, cache_id = set_session_id(env["rack.session"]["session_id"], env) if session_id.blank?
        cache_store.write(cache_id, env["rack.session"].to_hash)

        ## for 3xx redirect
        header["Location"] = convert_url(header["Location"], session_id) if header["Location"]

        ## only process html page
        response.body = process_body(response.body, session_id) if env['action_dispatch.request.path_parameters'][:format].to_s =~ /\A(html)?\Z/ && response.respond_to?(:body)

        [status, header, response]
      end
    end

    private
    def cache_store
      @options[:cache_store] || Rails.cache
    end

    def session_key
      (@options[:session_id] || :session_id).to_s
    end

    def set_session_id(session_id, env)
      [session_id, (session_id.present? ? Digest::SHA1.hexdigest(session_id + env["HTTP_USER_AGENT"] + env["REMOTE_ADDR"]) : nil)]
    end

    def process_body(body, session_id)
      body_doc = Nokogiri::HTML(body)
      body_doc.css("a").map { |a| a["href"] = convert_url(a['href'], session_id) if a["href"] }
      body_doc.css("form").map { |form| form["action"] = convert_url(form["action"], session_id) if form["action"] }
      body_doc.to_html
    end

    def convert_url(u, session_id)
      u = URI.parse(u)
      u.query = Rack::Utils.build_query(Rack::Utils.parse_query(u.query).merge({session_key => session_id})) unless u.scheme =~ /javascript/
      u.to_s
    end
  end
end
