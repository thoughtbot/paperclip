Given /^I have made a simple avatar on the user model$/ do
  run_simple(%{bundle exec #{generator_command} scaffold user})
  run_simple(%{bundle exec #{generator_command} paperclip user avatar})
  run_simple(%{bundle exec rake db:migrate})
  write_file('app/views/users/new.html.erb', <<-VIEW)
    <%= form_for @user, :html => { :multipart => true } do |f| %>
      <%= f.label :avatar %>
      <%= f.file_field :avatar %>
      <%= submit_tag 'Submit' %>
    <% end %>
  VIEW
  write_file('app/views/users/show.html.erb', <<-VIEW)
    <p>Attachment: <%= image_tag @user.avatar.url(:thumbnail) %></p>
  VIEW
  write_file('app/models/user.rb', <<-MODEL)
    class User < ActiveRecord::Base
      has_attached_file :avatar, styles: { thumbnail: '8x8#' }
      attr_accessible :avatar
    end
  MODEL
end

Given /^I upload an avatar to the user model$/ do
  visit '/users/new'
  attach_file('Avatar', File.expand_path('test/fixtures/5k.png'))
  click_button 'Submit'
end

When /^I add the following style to the user avatar:$/ do |string|
  write_file('app/models/user.rb', <<-MODEL)
    class User < ActiveRecord::Base
      has_attached_file :avatar, styles: { thumbnail: '8x8#', #{string} }
      attr_accessible :avatar
    end
  MODEL
end

When /^I change the user show page to show the large avatar$/ do
  write_file('app/views/users/show.html.erb', <<-VIEW)
    <p>Attachment: <%= image_tag @user.avatar.url(:large) %></p>
  VIEW
end

Then /^I see a missing large avatar on the user show page$/ do
  user = User.last
  user.should_not be_nil
  visit "/users/#{user.to_param}"

  page.source =~ %r{img alt="5k" src="/([^"]+)\?.*"}
  image_path = $1
  image_path.should_not be_blank

  File.should_not be_exist(Rails.root.join('public',image_path))
end

When /^I generate the "(.*?)" migration as follows:$/ do |migration_name, code|
  run_simple(%{bundle exec ./script/rails generate migration #{migration_name}})
  migration_filename = Dir[Rails.root.join('db', 'migrate', "*#{migration_name}.rb")].first
  write_file(migration_filename, <<-MIGRATION)
    class #{migration_name.classify} < ActiveRecord::Migration
      #{code}
    end
  MIGRATION
end

When /^I run the up database migration$/ do
  run_simple('bundle exec rake db:migrate')
end

When /^I run the down database migration$/ do
  migration_filename = Dir[Rails.root.join('db', 'migrate', '*')].sort.last
  migration_filename =~ %r{.*/(\d+)_[^/]+.rb}
  version = $1
  version.should_not be_blank
  run_simple("bundle exec rake db:migrate:down VERSION=#{version}")
end

Then /^I see the large avatar on the user show page$/ do
  user = User.last
  user.should_not be_nil
  visit "/users/#{user.to_param}"

  page.source =~ %r{img alt="5k" src="/([^"]+)\?.*"}
  image_path = $1
  image_path.should_not be_blank

  File.should be_exist(Rails.root.join('public',image_path))
end
