Feature: Pulling a subrepo

  Scenario: Pulling updates from the remote with squashing
    Given I have a git project with a subrepo with a remote
    And I have initialized and pushed the subrepo
    When I add a new commit to the remote
    And I pull the subrepo with squashing
    Then the subrepo and the remote should have the same contents
    And the project's log should equal:
      """
      * Subrepo-merge bar/master into master
      * Push subrepo bar
      * Initialize subrepo bar
      * Add stuff in subdir bar
      * Initial commit
      """
    And the subrepo configuration should contain the latest commit and parent

  Scenario: Pulling updates from the remote without squashing
    Given I have a git project with a subrepo with a remote
    And I have initialized and pushed the subrepo
    When I add a new commit to the remote
    And I pull the subrepo without squashing
    Then the subrepo and the remote should have the same contents
    And the project's log should equal:
      """
      *   Subrepo-merge bar/master into master
      |\  
      | * Add another_file in remote baz
      |/  
      * Push subrepo bar
      * Initialize subrepo bar
      * Add stuff in subdir bar
      * Initial commit
      """
    And the subrepo configuration should contain the latest commit and parent

  Scenario: Pulling twice in a row has no extra effect
    Given I have a git project with a subrepo with a remote
    And I have initialized and pushed the subrepo
    When I add a new commit to the remote
    And I pull the subrepo without squashing
    And I pull the subrepo without squashing again
    Then the subrepo and the remote should have the same contents
    And the project's log should equal:
      """
      *   Subrepo-merge bar/master into master
      |\  
      | * Add another_file in remote baz
      |/  
      * Push subrepo bar
      * Initialize subrepo bar
      * Add stuff in subdir bar
      * Initial commit
      """
