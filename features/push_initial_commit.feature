Feature: Pushing when the initial commit contains the subrepo directory

  Scenario: Pushing pushes the initial commit
    Given I have an empty git project named "foo"
    And I have an empty remote named "barbar"
    When I commit a new file "a_file" in subdirectory "bar"
    And I initialize the subrepo "bar" with the remote
    And I push the subrepo "bar"
    Then the subrepo and the remote should have the same contents
    And the remote's log should equal:
      """
      * Add bar/a_file in repo foo
      """
    And the subrepo configuration should contain the latest commit and parent
