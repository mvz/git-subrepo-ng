Feature: Pushing after pulling

  Scenario: Pushing after pulling without change
    Given I have a git project with a subrepo with a remote
    And I have initialized and pushed the subrepo
    When I add a new commit to the remote
    And I pull the subrepo
    And I push the subrepo "bar"
    Then the subrepo and the remote should have the same contents
    And the remote's log should equal:
      """
      Add another_file in baz
      Add stuff in bar
      """
    And the project's log should equal:
      """
      Subrepo-merge bar/master into master
      Add another_file in baz
      Push subrepo bar
      Initialize subrepo bar
      Add stuff in bar
      Initial commit
      """

  Scenario: Pushing older commits after pulling
    Given I have a git project with a subrepo with a remote
    And I have initialized and pushed the subrepo
    When I add a new commit to the remote
    And I add a new commit to the subrepo
    And I pull the subrepo
    And I push the subrepo "bar"
    Then the subrepo and the remote should have the same contents
    And the remote's log should equal:
      """
      Subrepo-merge bar/master into master
      Add more stuff in bar
      Add another_file in baz
      Add stuff in bar
      """
    And the project's log should equal:
      """
      Push subrepo bar
      Subrepo-merge bar/master into master
      Add another_file in baz
      Add more stuff in bar
      Push subrepo bar
      Initialize subrepo bar
      Add stuff in bar
      Initial commit
      """
