Feature: Pushing a subrepo

  Background:
    Given I have an existing git project named "foo"
    And I have committed a new file "a_file" in subdirectory "bar"
    And I have an empty remote named "barbar"
    And I have initialized the subrepo "bar" with that remote

  Scenario: Pushing a freshly initialized subrepo
    When I push the subrepo "bar"
    Then the subrepo and the remote should have the same contents
    And the remote's log should equal:
      """
      * Add bar/a_file in repo foo
      """

  Scenario: Pushing again to an existing subrepo
    When I push the subrepo "bar"
    And I commit a new file "other_file" in subdirectory "bar"
    And I push the subrepo "bar" again
    Then the subrepo and the remote should have the same contents
    And the remote's log should equal:
      """
      * Add bar/other_file in repo foo
      * Add bar/a_file in repo foo
      """

  Scenario: Pushing with unrelated merge commits
    Given I have pushed the subrepo "bar"
    When I create a branch with some commits in the main project
    And I commit a new file "other_file" in subdirectory "bar"
    And I merge in the main project branch
    And I push the subrepo "bar"
    Then the subrepo and the remote should have the same contents
    And the remote's log should equal:
      """
      * Add bar/other_file in repo foo
      * Add bar/a_file in repo foo
      """
