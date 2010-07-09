Feature: Running paperclip in a Rails app

  Scenario: Basic utilization
    Given I generate a rails application
    And I have a "users" resource with "name:string"
    And I run "script/generate paperclip user avatar"
    And I save the following as "app/models/user.rb"
    """
    class User < ActiveRecord::Base
      has_attached_file :avatar
    end
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
    And I save and open the page
