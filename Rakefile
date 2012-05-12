require 'bundler/gem_tasks'
require 'appraisal'
require 'rake/testtask'
require 'cucumber/rake/task'

desc 'Default: run unit tests.'
task :default => [:clean, :all]

desc 'Test the paperclip plugin under all supported Rails versions.'
task :all do |t|
  if ENV['BUNDLE_GEMFILE']
    exec('rake test cucumber')
  else
    Rake::Task["appraisal:install"].execute
    exec('rake appraisal test cucumber')
  end
end

desc 'Test the paperclip plugin.'
Rake::TestTask.new(:test) do |t|
  t.libs << 'lib' << 'profile'
  t.pattern = 'test/**/*_test.rb'
  t.verbose = true
end

desc 'Run integration test'
Cucumber::Rake::Task.new do |t|
  t.cucumber_opts = %w{--format progress}
end

desc 'Start an IRB session with all necessary files required.'
task :shell do |t|
  chdir File.dirname(__FILE__)
  exec 'irb -I lib/ -I lib/paperclip -r rubygems -r active_record -r tempfile -r init'
end

desc 'Clean up files.'
task :clean do |t|
  FileUtils.rm_rf "doc"
  FileUtils.rm_rf "tmp"
  FileUtils.rm_rf "pkg"
  FileUtils.rm_rf "public"
  FileUtils.rm "test/debug.log" rescue nil
  FileUtils.rm "test/paperclip.db" rescue nil
  Dir.glob("paperclip-*.gem").each{|f| FileUtils.rm f }
end
