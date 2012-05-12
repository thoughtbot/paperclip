Feature: Rails integration

  Background:
    Given I generate a new rails application
    And I run a rails generator to generate a "User" scaffold with "name:string"
    And I run a paperclip generator to add a paperclip "attachment" to the "User" model
    And I run a migration
    And I update my new user view to include the file upload field
    And I update my user view to include the attachment

  Scenario: Filesystem integration test
    Given I add this snippet to the User model:
      """
      attr_accessible :name, :attachment
      has_attached_file :attachment, :url => "/system/:attachment/:style/:filename",
                                     :styles => { :square => "100x100#" }
      """
    And I start the rails application
    When I go to the new user page
    And I fill in "Name" with "something"
    And I attach the file "test/fixtures/5k.png" to "Attachment"
    And I press "Submit"
    Then I should see "Name: something"
    And I should see an image with a path of "/system/attachments/original/5k.png"
    And the file at "/system/attachments/original/5k.png" should be the same as "test/fixtures/5k.png"

  Scenario: S3 Integration test
    Given I add this snippet to the User model:
      """
      attr_accessible :name, :attachment
      has_attached_file :attachment,
                        :storage => :s3,
                        :path => "/:attachment/:style/:filename",
                        :s3_credentials => Rails.root.join("config/s3.yml"),
                        :styles => { :square => "100x100#" }
      """
    And I write to "config/s3.yml" with:
      """
      bucket: paperclip
      access_key_id: access_key
      secret_access_key: secret_key
      """
    And I start the rails application
    When I go to the new user page
    And I fill in "Name" with "something"
    And I attach the file "test/fixtures/5k.png" to "Attachment" on S3
    And I press "Submit"
    Then I should see "Name: something"
    And I should see an image with a path of "http://s3.amazonaws.com/paperclip/attachments/original/5k.png"
    And the file at "http://s3.amazonaws.com/paperclip/attachments/original/5k.png" should be uploaded to S3
