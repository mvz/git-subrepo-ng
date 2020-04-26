Feature: Complex pull

  Scenario: Pulling new changes with intermediate branch points
    Given I have a remote named "bar" with some commits
    And I have an existing git project named "foo"
    And I have cloned into "bar" from the remote "../bar" with branch "master"
    When I create and commit "baz" in the remote
    And I create a branch with commits for "qux" in the remote
    And I create and commit "quuz" in the remote
    And I create a branch with commits for "zyxxy" in the remote
    And I update and commit "quuz" in the remote
    And I pull the subrepo
    And I merge the branch for "qux" in the remote
    And I merge the branch for "zyxxy" in the remote
    And I pull the subrepo again
    Then the subrepo and the remote should have the same contents
