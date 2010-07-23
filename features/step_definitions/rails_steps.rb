Given %r{I generate a rails application} do
  FileUtils.rm_rf TEMP_ROOT
  FileUtils.mkdir_p TEMP_ROOT
  Dir.chdir(TEMP_ROOT) do
    `rails _2.3.8_ #{APP_NAME}`
  end
  ENV['RAILS_ENV'] = 'test'
end

When %r{I save the following as "([^"]*)"} do |path, string|
  FileUtils.mkdir_p(File.join(CUC_RAILS_ROOT, File.dirname(path)))
  File.open(File.join(CUC_RAILS_ROOT, path), 'w') { |file| file.write(string) }
end

When %r{the rails application is prepped and running$} do
  When "the rails application is prepped"
  When "the rails application is running"
end

When %r{the rails application is prepped$} do
  When %{I run "rake db:create db:migrate"}
end

When %r{the rails application is running} do
  Dir.chdir(CUC_RAILS_ROOT) do
    require "config/environment"
    require "capybara/rails"
  end
end

When %r{this plugin is available} do
  $LOAD_PATH << "#{PROJECT_ROOT}/lib"
  require 'paperclip'
  When %{I save the following as "vendor/plugins/paperclip/rails/init.rb"},
       IO.read("#{PROJECT_ROOT}/rails/init.rb") 
end

When %r{I run "([^"]*)"} do |command|
  Dir.chdir(CUC_RAILS_ROOT) do
    `#{command}`
  end
end

When %r{I have a "([^"]*)" resource with "([^"]*)"} do |resource, fields|
  When %{I run "script/generate scaffold #{resource} #{fields}"}
end
