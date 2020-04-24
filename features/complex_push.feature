Feature: Complex push

  Scenario: Pushing with unrelated merge commits
    Given I have a remote named "bar" with some commits
    And I have an existing git project named "foo"
    And I have cloned into "bar" from the remote "../bar" with branch "master"
    And I have created and committed "foobar" in the remote
    When I create a branch with commits for "zyxxy" in the main project
    And I create a branch with commits for "barfoo" in the subrepo
    And I merge in the main project branch
    And I merge in the subrepo branch
    And I commit a new file "smurf" in the subrepo
    And I pull the subrepo
    And I push the subrepo
    Then the subrepo and the remote should have the same contents
