Feature: Pushing a subrepo

  Scenario: Pushing a freshly initialized subrepo
    Given I have an empty remote named "barbar"
    And I have an existing git project named "foo"
    And I have a subdirectory "bar" with commits
    When I init the subrepo "bar" with remote "../barbar" and branch "master"
    And I push the subrepo "bar"
    Then the remote should contain the contents of "bar"
    And the remote's log should equal:
      """
      Add stuff in bar
      """

  Scenario: Pushing again to an existing subrepo
    Given I have a git project "foo" with subrepo "bar" with remote "baz"
    And I have initialized and pushed the subrepo
    When I add a new commit to the subrepo
    And I push the subrepo "bar"
    Then the remote should contain the contents of "bar"
    And the remote's log should equal:
      """
      Add more stuff in bar
      Add stuff in bar
      """
