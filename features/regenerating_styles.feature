Feature: Regenerating styles

  Scenario: Adding a new style
    Given I generate a new rails application
    And I have made a simple avatar on the user model
    And I start the rails application
    And I upload an avatar to the user model
    When I add the following style to the user avatar:
    """
    large: '124x124#'
    """
    And I change the user show page to show the large avatar
    Then I see a missing large avatar on the user show page
    When I generate the "add_large_thumbnail_to_user_avatar" migration as follows:
    """
    def up
      add_style :users, :avatar, large: '124x124#'
    end

    def down
      remove_style :users, :avatar, :large
    end
    """
    And I run the up database migration
    Then I see the large avatar on the user show page
    When I run the down database migration
    Then I see a missing large avatar on the user show page
