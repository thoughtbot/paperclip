Feature: Migration

  Background:
    Given I generate a new rails application
    And I generate a "User" model:

  Scenario: Vintage syntax
    Given I run a paperclip migration to add a paperclip "attach" to the "User" model

    And I run a migration
    Then I should have attachment columns for "attach"

    When I rollback a migration
    Then I should not have attachment columns for "attach"

  Scenario: New syntax with create_table
    Given I run a paperclip migration to add a paperclip "attach" to the "User" model

    And I run a migration
    Then I should have attachment columns for "attach"

  Scenario: New syntax outside of create_table
    Given I run a paperclip migration to add a paperclip "attachment_sample" to the "User" model

    And I run a migration
    Then I should have attachment columns for "attachment_sample"

    When I rollback a migration
    Then I should not have attachment columns for "attachment_sample"
