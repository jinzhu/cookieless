require 'digest/sha1'
require 'uri'
require 'nokogiri'

module Rack
  class Cookieless
    def initialize app, options={}
      @app, @options = app, options
    end

    def call(env)
      # have cookies or not
      support_cookie = env['HTTP_COOKIE'].present?
      noconvert = @options[:noconvert].is_a?(Proc) ? @options[:noconvert].call(env) : false

      if support_cookie || noconvert
        @app.call env
      else
        session_id, cookies = get_cookies_by_query(env['QUERY_STRING'], env) || get_cookies_by_query((URI.parse(env['HTTP_REFERER']).query rescue nil), env)
        env['HTTP_COOKIE'] = cookies if cookies

        status, header, response = @app.call env

        if env['action_dispatch.request.path_parameters'] && %w(css js xml).exclude?(env['action_dispatch.request.path_parameters'][:format].to_s)
          session_id ||= rack_session_id env
          session_id = save_cookies_by_session_id session_id, env, header['Set-Cookie']
          ## fix 3xx redirect
          header['Location'] = convert_url(header['Location'], session_id) if header['Location'] && !external_url?(header, env)
          ## only process html page
          if session_id && !!(header['Content-Type'].to_s.downcase =~ /html/)
            response = process_response response, session_id
          end
        end

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

    def rack_session_id(env)
      env['rack.session'].try(:[], 'session_id') or env['rack.session.options'].try(:[], :id)
    end

    def process_response response, session_id
      if response.respond_to? :body
        response = process_response_body response, session_id
      elsif response.is_a?(Array) and behaves_like_string? response[0]
        response[0] = process_body_content response[0].to_s, session_id
      end
      response
    end

    def process_response_body response, session_id
      if response.body.is_a?(Array) and behaves_like_string? response.body[0]
        response.body[0] = process_body_content response.body[0].to_s, session_id
      else
        response = process_plain_body response, session_id
      end
      response
    end

    def process_plain_body response, session_id
      if response.respond_to?(:body=) and behaves_like_string? response.body
        response.body = process_body_content response.body.to_s, session_id
      elsif behaves_like_string? response.body
        response = [process_body_content(response.body.to_s, session_id)]
      end
      response
    end

    def get_cookies_by_query query, env
      session_id = Rack::Utils.parse_query(query, '&')[session_key].to_s
      return nil if session_id.blank?

      cache_id = generate_cookie_id session_id, env
      return nil unless session_id.present? and Rails.cache.exist? cache_id

      [session_id, cache_store.read(cache_id)]
    end

    def save_cookies_by_session_id session_id, env, cookie
      cache_store.write generate_cookie_id(session_id, env), cookie
      session_id
    end

    def generate_cookie_id session_id, env
      Digest::SHA1.hexdigest session_id.to_s + env['HTTP_USER_AGENT'].to_s + env['REMOTE_ADDR'].to_s
    end

    def behaves_like_string?(body)
      [ActionView::OutputBuffer,String].detect{ |klass| body.is_a? klass }
    end

    def process_body_content body, session_id
      body_doc = Nokogiri::HTML(body)
      body_doc.css('a').map { |a| a['href'] = convert_url(a['href'], session_id) if a['href'] }
      body_doc.css('form').map do |form|
        if form['action']
          form['action'] = convert_url form['action'], session_id
          form.add_child "<input type='hidden' name='#{session_key}' value='#{session_id}'>"
        end
      end
      body_doc.to_html
    end

    def convert_url u, session_id
      u = URI.parse URI.escape(u)
      if u.scheme.blank? || u.scheme.to_s =~ /http/
        u.query = Rack::Utils.build_query(Rack::Utils.parse_query(u.query).merge({session_key => session_id}))
      end
      u.to_s
    end

    def external_url?(header, env)
      location_host = URI(header['Location'].to_s).host
      current_host = env['HTTP_HOST'].to_s.split(':')[0]
      location_host != current_host
    end
  end
end
