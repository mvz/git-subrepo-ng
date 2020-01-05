Feature: Pulling a subrepo

  Scenario: Pulling updates from the remote
    Given I have a git project with a subrepo with a remote
    And I have initialized and pushed the subrepo
    When I add a new commit to the remote
    And I pull the subrepo
    Then the subrepo and the remote should have the same contents
    And the project's log should equal:
      """
      Subrepo-merge bar/master into master
      Add another_file in remote baz
      Push subrepo bar
      Initialize subrepo bar
      Add stuff in subdir bar
      Initial commit
      """

  Scenario: Pulling twice in a row has no extra effect
    Given I have a git project with a subrepo with a remote
    And I have initialized and pushed the subrepo
    When I add a new commit to the remote
    And I pull the subrepo
    And I pull the subrepo again
    Then the subrepo and the remote should have the same contents
    And the project's log should equal:
      """
      Subrepo-merge bar/master into master
      Add another_file in remote baz
      Push subrepo bar
      Initialize subrepo bar
      Add stuff in subdir bar
      Initial commit
      """

