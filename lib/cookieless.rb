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
        session_id, session = get_session_by_query(env["QUERY_STRING"], env) || get_session_by_query((URI.parse(env['HTTP_REFERER']).query rescue nil), env)
        env["rack.session"].update(session) if session

        status, header, response = @app.call(env)

        session_id = save_session_by_id(session_id || env["rack.session"]["session_id"], env)

        ## fix 3xx redirect
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

    def get_session_by_query(query, env)
      session_id = Rack::Utils.parse_query(query, "&")[session_key].to_s
      return nil if session_id.blank?

      cache_id = Digest::SHA1.hexdigest(session_id + env["HTTP_USER_AGENT"] + env["REMOTE_ADDR"])
      return nil unless Rails.cache.exist?(cache_id)
      return [session_id, cache_store.read(cache_id)]
    end

    def save_session_by_id(session_id, env)
      cache_id = Digest::SHA1.hexdigest(session_id + env["HTTP_USER_AGENT"] + env["REMOTE_ADDR"])
      cache_store.write(cache_id, env["rack.session"].to_hash)
      session_id
    end

    def process_body(body, session_id)
      body_doc = Nokogiri::HTML(body)
      body_doc.css("a").map { |a| a["href"] = convert_url(a['href'], session_id) if a["href"] }
      body_doc.css("form").map { |form| form["action"] = convert_url(form["action"], session_id) if form["action"] }
      body_doc.to_html
    end

    def convert_url(u, session_id)
      u = URI.parse(u)
      u.query = Rack::Utils.build_query(Rack::Utils.parse_query(u.query).merge({session_key => session_id})) if u.scheme.blank? || u.scheme.to_s =~ /http/
      u.to_s
    end
  end
end
