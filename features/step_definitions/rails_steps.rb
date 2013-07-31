Given /^I generate a new rails application$/ do
  steps %{
    When I run `bundle exec #{new_application_command} #{APP_NAME} --skip-bundle`
    And I cd to "#{APP_NAME}"
    And I turn off class caching
    And I fix the application.rb for 3.0.12
    And I write to "Gemfile" with:
      """
      source "http://rubygems.org"
      gem "rails", "#{framework_version}"
      gem "sqlite3", :platform => :ruby
      gem "activerecord-jdbcsqlite3-adapter", :platform => :jruby
      gem "jruby-openssl", :platform => :jruby
      gem "capybara"
      gem "gherkin"
      gem "aws-sdk"
      """
    And I remove turbolinks
    And I empty the application.js file
    And I configure the application to use "paperclip" from this project
    And I reset Bundler environment variable
    And I successfully run `bundle install --local`
  }
end

Given "I fix the application.rb for 3.0.12" do
  in_current_dir do
    File.open("config/application.rb", "a") do |f|
      f << "ActionController::Base.config.relative_url_root = ''"
    end
  end
end

Given "I allow the attachment to be submitted" do
  in_current_dir do
    transform_file("app/controllers/users_controller.rb") do |content|
      content.gsub("params.require(:user).permit(:name)",
                   "params.require(:user).permit!")
    end
  end
end

Given "I remove turbolinks" do
  in_current_dir do
    transform_file("app/assets/javascripts/application.js") do |content|
      content.gsub("//= require turbolinks", "")
    end
    transform_file("app/views/layouts/application.html.erb") do |content|
      content.gsub(', "data-turbolinks-track" => true', "")
    end
  end
end

Given /^I attach :attachment$/ do
  attach_attachment("attachment")
end

Given /^I attach :attachment with:$/ do |definition|
  attach_attachment("attachment", definition)
end

def attach_attachment(name, definition = nil)
  snippet = ""
  if using_protected_attributes?
    snippet += "attr_accessible :name, :#{name}\n"
  end
  snippet += "has_attached_file :#{name}"
  if definition
    snippet += ", \n"
    snippet += definition
  end
  in_current_dir do
    transform_file("app/models/user.rb") do |content|
      content.sub(/end\Z/, "#{snippet}\nend")
    end
  end
end

Given "I empty the application.js file" do
  in_current_dir do
    transform_file("app/assets/javascripts/application.js") do |content|
      ""
    end
  end
end

Given /^I run a rails generator to generate a "([^"]*)" scaffold with "([^"]*)"$/ do |model_name, attributes|
  step %[I successfully run `bundle exec #{generator_command} scaffold #{model_name} #{attributes}`]
end

Given /^I run a paperclip generator to add a paperclip "([^"]*)" to the "([^"]*)" model$/ do |attachment_name, model_name|
  step %[I successfully run `bundle exec #{generator_command} paperclip #{model_name} #{attachment_name}`]
end

Given /^I run a migration$/ do
  step %[I successfully run `bundle exec rake db:migrate --trace`]
end

When /^I rollback a migration$/ do
  step %[I successfully run `bundle exec rake db:rollback STEPS=1 --trace`]
end

Given /^I update my new user view to include the file upload field$/ do
  steps %{
    Given I overwrite "app/views/users/new.html.erb" with:
      """
      <%= form_for @user, :html => { :multipart => true } do |f| %>
        <%= f.label :name %>
        <%= f.text_field :name %>
        <%= f.label :attachment %>
        <%= f.file_field :attachment %>
        <%= submit_tag "Submit" %>
      <% end %>
      """
  }
end

Given /^I update my user view to include the attachment$/ do
  steps %{
    Given I overwrite "app/views/users/show.html.erb" with:
      """
      <p>Name: <%= @user.name %></p>
      <p>Attachment: <%= image_tag @user.attachment.url %></p>
      """
  }
end

Given /^I add this snippet to the User model:$/ do |snippet|
  file_name = "app/models/user.rb"
  in_current_dir do
    content = File.read(file_name)
    File.open(file_name, 'w') { |f| f << content.sub(/end\Z/, "#{snippet}\nend") }
  end
end

Given /^I add this snippet to config\/application.rb:$/ do |snippet|
  file_name = "config/application.rb"
  in_current_dir do
    content = File.read(file_name)
    File.open(file_name, 'w') {|f| f << content.sub(/class Application < Rails::Application.*$/, "class Application < Rails::Application\n#{snippet}\n")}
  end
end

Given /^I start the rails application$/ do
  in_current_dir do
    require "./config/environment"
    require "capybara/rails"
  end
end

Given /^I reload my application$/ do
  Rails::Application.reload!
end

When /^I turn off class caching$/ do
  in_current_dir do
    file = "config/environments/test.rb"
    config = IO.read(file)
    config.gsub!(%r{^\s*config.cache_classes.*$},
                 "config.cache_classes = false")
    File.open(file, "w"){|f| f.write(config) }
  end
end

Then /^the file at "([^"]*)" should be the same as "([^"]*)"$/ do |web_file, path|
  expected = IO.read(path)
  actual = read_from_web(web_file)
  actual.should == expected
end

When /^I configure the application to use "([^\"]+)" from this project$/ do |name|
  append_to_gemfile "gem '#{name}', :path => '#{PROJECT_ROOT}'"
  steps %{And I run `bundle install --local`}
end

When /^I configure the application to use "([^\"]+)"$/ do |gem_name|
  append_to_gemfile "gem '#{gem_name}'"
end

When /^I append gems from Appraisal Gemfile$/ do
  File.read(ENV['BUNDLE_GEMFILE']).split(/\n/).each do |line|
    if line =~ /^gem "(?!rails|appraisal)/
      append_to_gemfile line.strip
    end
  end
end

When /^I comment out the gem "([^"]*)" from the Gemfile$/ do |gemname|
  comment_out_gem_in_gemfile gemname
end

Given /^I am using Rails newer than ([\d\.]+)$/ do |version|
  if framework_version < version
    pending "Not supported in Rails < #{version}"
  end
end

def transform_file(filename)
  if File.exists?(filename)
    content = File.read(filename)
    File.open(filename, "w") do |f|
      content = yield(content)
      f.write(content)
    end
  end
end
