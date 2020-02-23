Feature: Cleaning up

  Scenario: Cleaning up branches and worktree for a subrepo
    Given I have a remote named "barbar" with some commits
    And I have an existing git project named "foo"
    And I have cloned into "bar" from the remote "../barbar" with branch "master"
    When I create a subrepo branch and worktree
    And I clean the subrepo
    Then the subrepo branch has been removed
