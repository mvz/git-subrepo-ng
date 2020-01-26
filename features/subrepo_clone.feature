Feature: Cloning a subrepo

  Scenario: Cloning a remote as a subrepo
    Given I have a remote named "barbar" with some commits
    And I have an existing git project named "foo"
    When I clone into "bar" from the remote "../barbar" with branch "master"
    Then the subrepo and the remote should have the same contents
    And the remote's log should equal:
      """
      * Add other_file
      * Add this_file
      """
    And the project's log should equal:
      """
      * Clone remote ../barbar into bar
      * Initial commit
      """
    And the subrepo configuration should contain the latest commit and parent
