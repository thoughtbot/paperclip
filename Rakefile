require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'

desc 'Default: run unit tests.'
task :default => [:clean, :test]

desc 'Test the paperclip plugin.'
Rake::TestTask.new(:test) do |t|
  t.libs << 'lib' << 'profile'
  t.pattern = 'test/**/*_test.rb'
  t.verbose = true
end

desc 'Generate documentation for the paperclip plugin.'
Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'doc'
  rdoc.title    = 'Paperclip'
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

desc 'Clean up files.'
task :clean do |t|
  FileUtils.rm_rf "doc"
  FileUtils.rm_rf "repository"
  FileUtils.rm_rf "tmp"
  FileUtils.rm "test/debug.log" rescue nil
  FileUtils.rm "test/paperclip.db" rescue nil
end