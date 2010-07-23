Feature: Running paperclip in a Rails app using basic S3 support

  Scenario: Basic utilization
    Given I generate a rails application
    And I have a "users" resource with "name:string"
    And I run "script/generate paperclip user avatar"
    And I save the following as "app/models/user.rb"
    """
    class User < ActiveRecord::Base
    has_attached_file :avatar,
                      :storage => :s3,
                      :bucket => "jyurek",
                      :s3_credentials => "config/s3.yml"
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
    And this plugin is available
    And the rails application is prepped and running
    When I visit /users/new
    And I fill in "user_name" with "something"
    And I attach the file "test/fixtures/5k.png" to "user_avatar"
    And I press "Submit"
    Then I should see "Name: something"
    And I should see an image with a path of "http://paperclip.s3.amazonaws.com/system/avatars/1/original/5k.png"
    And the file at "http://paperclip.s3.amazonaws.com/system/avatars/1/original/5k.png" is the same as "test/fixtures/5k.png"
