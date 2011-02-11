Feature: Running paperclip in a Rails app using MongoDB's GridFS

  Scenario: Basic utilization
    Given I have a rails application
    And I save the following as "app/models/user.rb"
    """
    class User < ActiveRecord::Base
    has_attached_file :avatar,
                      :storage => :mongo,
                      :path => "/:attachment/:id/:style/:filename",
                      :mongo_frontend_host => 'somehost.com',
					  :mongo_frontend_path => '/paperclip',
					  :mongo_database => 'paperclip-test'
    end
    """
    And I have a MongoDB server
    When I visit /users/new
    And I fill in "user_name" with "something"
    And I attach the file "test/fixtures/5k.png" to "user_avatar"
    And I press "Submit"
    Then I should see "Name: something"
    And I should see an image with a path of "http://somehost.com/paperclip/avatars/1/original/5k.png"
    And the file at "http://somehost.com/paperclip/avatars/1/original/5k.png" is the same as "test/fixtures/5k.png"
