require 'cookieless'

ENV['RACK_ENV'] = 'test'
ENV['RAILS_ENV'] = 'test'

require 'rails'
case Rails::VERSION::MAJOR
when 4
  require File.expand_path("../dummy/rails4", __FILE__)
when 3
  require File.expand_path("../dummy/rails3", __FILE__)
end
