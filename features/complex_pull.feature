Feature: Complex pull

  Background:
    Given I have a remote named "bar" with some commits
    And I have an existing git project named "foo"
    And I have cloned into "bar" from the remote "../bar" with branch "master"
    And I have created and committed "baz" in the remote
    And I have created a branch with commits for "qux" in the remote
    And I have created and committed "quuz" in the remote
    And I have created a branch with commits for "zyxxy" in the remote
    And I have updated and committed "quuz" in the remote

  Scenario: Pulling new changes with intermediate branch points
    When I pull the subrepo
    And I merge the branch for "qux" in the remote
    And I merge the branch for "zyxxy" in the remote
    And I pull the subrepo again
    Then the subrepo and the remote should have the same contents
