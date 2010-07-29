Feature: Running paperclip in a Rails app using basic S3 support

  Scenario: Basic utilization
    Given I have a rails application
    And I save the following as "app/models/user.rb"
    """
    class User < ActiveRecord::Base
    has_attached_file :avatar,
                      :storage => :s3,
                      :path => "/:attachment/:id/:style/:filename",
                      :s3_credentials => Rails.root.join("config/s3.yml")
    end
    """
    And I validate my S3 credentials
    And I save the following as "config/s3.yml"
    """
    bucket: <%= ENV['PAPERCLIP_TEST_BUCKET'] || 'paperclip' %>
    access_key_id: <%= ENV['AWS_ACCESS_KEY_ID'] %>
    secret_access_key: <%= ENV['AWS_SECRET_ACCESS_KEY'] %>
    """
    When I visit /users/new
    And I fill in "user_name" with "something"
    And I attach the file "test/fixtures/5k.png" to "user_avatar"
    And I press "Submit"
    Then I should see "Name: something"
    And I should see an image with a path of "http://s3.amazonaws.com/paperclip/avatars/1/original/5k.png"
    And the file at "http://s3.amazonaws.com/paperclip/avatars/1/original/5k.png" is the same as "test/fixtures/5k.png"
