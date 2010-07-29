Given "I have a rails application" do
  steps %{
    Given I generate a rails application
    And this plugin is available
    And I have a "users" resource with "name:string"
    And I turn off class caching
    Given I save the following as "app/models/user.rb"
      """
      class User < ActiveRecord::Base
      end
      """
    And I save the following as "config/s3.yml"
      """
      access_key_id: <%= ENV['AWS_ACCESS_KEY_ID'] %>
      secret_access_key: <%= ENV['AWS_SECRET_ACCESS_KEY'] %>
      bucket: paperclip
      """
    And I save the following as "app/views/users/new.html.erb"
      """
      <% form_for @user, :html => { :multipart => true } do |f| %>
        <%= f.text_field :name %>
        <%= f.file_field :avatar %>
        <%= submit_tag "Submit" %>
      <% end %>
      """
    And I save the following as "app/views/users/show.html.erb"
      """
      <p>Name: <%= @user.name %></p>
      <p>Avatar: <%= image_tag @user.avatar.url %></p>
      """
    And I run "script/generate paperclip user avatar"
    And the rails application is prepped and running
  }
end

Given %r{I generate a rails application} do
  FileUtils.rm_rf TEMP_ROOT
  FileUtils.mkdir_p TEMP_ROOT
  Dir.chdir(TEMP_ROOT) do
    `rails _2.3.8_ #{APP_NAME}`
  end
end

When %r{I save the following as "([^"]*)"} do |path, string|
  FileUtils.mkdir_p(File.join(CUC_RAILS_ROOT, File.dirname(path)))
  File.open(File.join(CUC_RAILS_ROOT, path), 'w') { |file| file.write(string) }
end

When %r{I turn off class caching} do
  Dir.chdir(CUC_RAILS_ROOT) do
    file = "config/environments/test.rb"
    config = IO.read(file)
    config.gsub!(%r{^\s*config.cache_classes.*$},
                 "config.cache_classes = false")
    File.open(file, "w"){|f| f.write(config) }
  end
end

When %r{the rails application is prepped and running$} do
  When "I reset the database"
  When "the rails application is running"
end

When %r{I reset the database} do
  When %{I run "rake db:drop db:create db:migrate"}
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
