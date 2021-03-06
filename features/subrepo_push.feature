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
    And the subrepo configuration should contain the latest commit and parent
    And the subrepo branch has been removed

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
    And the subrepo configuration should contain the latest commit and parent

  Scenario: Squash-pushing to an existing subrepo
    When I push the subrepo "bar"
    And I commit a new file "other_file" in subdirectory "bar"
    And I commit a new file "third_file" in subdirectory "bar"
    And I push the subrepo "bar" again, squashing the commits
    Then the subrepo and the remote should have the same contents
    And the remote's log should equal:
      """
      * Push subrepo bar
      * Add bar/a_file in repo foo
      """
    And the subrepo configuration should contain the latest commit and parent

  Scenario: Pushing after squash-pushing to an existing subrepo
    When I push the subrepo "bar"
    And I commit a new file "other_file" in subdirectory "bar"
    And I push the subrepo "bar" again, squashing the commits
    And I commit a new file "third_file" in subdirectory "bar"
    And I push the subrepo "bar" again
    Then the subrepo and the remote should have the same contents
    And the remote's log should equal:
      """
      * Add bar/third_file in repo foo
      * Push subrepo bar
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
