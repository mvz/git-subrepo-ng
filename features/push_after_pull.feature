Feature: Pushing after pulling

  Scenario: Pushing after pulling without change
    Given I have a git project with a subrepo with a remote
    And I have initialized and pushed the subrepo
    When I add a new commit to the remote
    And I pull the subrepo without squashing
    And I push the subrepo "bar"
    Then the subrepo and the remote should have the same contents
    And the remote's log should equal:
      """
      * Add another_file in remote baz
      * Add stuff in subdir bar
      """
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

  Scenario: Pushing older commits after pulling
    Given I have a git project with a subrepo with a remote
    And I have initialized and pushed the subrepo
    When I add a new commit to the remote
    And I add a new commit to the subrepo
    And I pull the subrepo without squashing
    And I push the subrepo "bar"
    Then the subrepo and the remote should have the same contents
    And the remote's log should equal:
      """
      *   Subrepo-merge bar/master into master
      |\  
      | * Add another_file in remote baz
      * | Add more stuff in subrepo bar
      |/  
      * Add stuff in subdir bar
      """
    And the project's log should equal:
      """
      * Push subrepo bar
      *   Subrepo-merge bar/master into master
      |\  
      | * Add another_file in remote baz
      * | Add more stuff in subrepo bar
      |/  
      * Push subrepo bar
      * Initialize subrepo bar
      * Add stuff in subdir bar
      * Initial commit
      """

  Scenario: Pushing newer commits after pulling
    Given I have a git project with a subrepo with a remote
    And I have initialized and pushed the subrepo
    When I add a new commit to the remote
    And I pull the subrepo without squashing
    And I add a new commit to the subrepo
    And I push the subrepo "bar"
    Then the subrepo and the remote should have the same contents
    And the remote's log should equal:
      """
      * Add more stuff in subrepo bar
      * Add another_file in remote baz
      * Add stuff in subdir bar
      """
    And the project's log should equal:
      """
      * Push subrepo bar
      * Add more stuff in subrepo bar
      *   Subrepo-merge bar/master into master
      |\  
      | * Add another_file in remote baz
      |/  
      * Push subrepo bar
      * Initialize subrepo bar
      * Add stuff in subdir bar
      * Initial commit
      """

  Scenario: Pushing after pulling with squashing without change
    Given I have a git project with a subrepo with a remote
    And I have initialized and pushed the subrepo
    When I add a new commit to the remote
    And I pull the subrepo with squashing
    And I push the subrepo "bar"
    Then the subrepo and the remote should have the same contents
    And the remote's log should equal:
      """
      * Add another_file in remote baz
      * Add stuff in subdir bar
      """
    And the project's log should equal:
      """
      * Subrepo-merge bar/master into master
      * Push subrepo bar
      * Initialize subrepo bar
      * Add stuff in subdir bar
      * Initial commit
      """

  Scenario: Pushing older commits after pulling with squashing
    Given I have a git project with a subrepo with a remote
    And I have initialized and pushed the subrepo
    When I add a new commit to the remote
    And I add a new commit to the subrepo
    And I pull the subrepo with squashing
    And I push the subrepo "bar"
    Then the subrepo and the remote should have the same contents
    And the project's log should equal:
      """
      * Push subrepo bar
      * Subrepo-merge bar/master into master
      * Add more stuff in subrepo bar
      * Push subrepo bar
      * Initialize subrepo bar
      * Add stuff in subdir bar
      * Initial commit
      """
    And the remote's log should equal:
      """
      * Add more stuff in subrepo bar
      * Add another_file in remote baz
      * Add stuff in subdir bar
      """

  Scenario: Pushing newer commits after pulling with squashing
    Given I have a git project with a subrepo with a remote
    And I have initialized and pushed the subrepo
    When I add a new commit to the remote
    And I pull the subrepo with squashing
    And I add a new commit to the subrepo
    And I push the subrepo "bar"
    Then the subrepo and the remote should have the same contents
    And the project's log should equal:
      """
      * Push subrepo bar
      * Add more stuff in subrepo bar
      * Subrepo-merge bar/master into master
      * Push subrepo bar
      * Initialize subrepo bar
      * Add stuff in subdir bar
      * Initial commit
      """
    And the remote's log should equal:
      """
      * Add more stuff in subrepo bar
      * Add another_file in remote baz
      * Add stuff in subdir bar
      """
