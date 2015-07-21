require 'rubygems'
require 'bundler/setup'
require 'bundler'

require 'bundler/gem_tasks'
Bundler.with_clean_env do
  require 'appraisal'
end

require 'rspec/core'
require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:test) do |test|
  test.pattern = FileList['test/**/*_test.rb']
end

task :default => :test
