Feature: Pushing after pulling

  Background:
    Given I have an existing git project named "foo"
    And I have committed a new file "a_file" in subdirectory "bar"
    And I have an empty remote named "baz"
    And I have initialized the subrepo "bar" with that remote
    And I have pushed the subrepo "bar"

  Scenario: Pushing after pulling without change
    When I add a new commit to the remote
    And I pull the subrepo without squashing
    And I push the subrepo "bar"
    Then the subrepo and the remote should have the same contents
    And the remote's log should equal:
      """
      * Add another_file in remote baz
      * Add bar/a_file in repo foo
      """
    And the project's log should equal:
      """
      *   Subrepo-merge bar/master into master
      |\  
      | * Add another_file in remote baz
      |/  
      * Push subrepo bar
      * Initialize subrepo bar
      * Add bar/a_file in repo foo
      * Initial commit
      """
    And the commit map should equal:
      """
      Subrepo-merge bar/master into master -> Add another_file in remote baz
      Add another_file in remote baz -> Add another_file in remote baz
      Push subrepo bar -> Add bar/a_file in repo foo
      Initialize subrepo bar -> Add bar/a_file in repo foo
      """

  Scenario: Pushing older commits after pulling
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
      * Add bar/a_file in repo foo
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
      * Add bar/a_file in repo foo
      * Initial commit
      """

  Scenario: Pushing newer commits after pulling
    When I add a new commit to the remote
    And I pull the subrepo without squashing
    And I add a new commit to the subrepo
    And I push the subrepo "bar"
    Then the subrepo and the remote should have the same contents
    And the remote's log should equal:
      """
      * Add more stuff in subrepo bar
      * Add another_file in remote baz
      * Add bar/a_file in repo foo
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
      * Add bar/a_file in repo foo
      * Initial commit
      """

  Scenario: Pushing after pulling with squashing without change
    When I add a new commit to the remote
    And I pull the subrepo with squashing
    And I push the subrepo "bar"
    Then the subrepo and the remote should have the same contents
    And the remote's log should equal:
      """
      * Add another_file in remote baz
      * Add bar/a_file in repo foo
      """
    And the project's log should equal:
      """
      * Subrepo-merge bar/master into master
      * Push subrepo bar
      * Initialize subrepo bar
      * Add bar/a_file in repo foo
      * Initial commit
      """

  Scenario: Pushing older commits after pulling with squashing
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
      * Add bar/a_file in repo foo
      * Initial commit
      """
    And the remote's log should equal:
      """
      * Add more stuff in subrepo bar
      * Add another_file in remote baz
      * Add bar/a_file in repo foo
      """

  Scenario: Pushing newer commits after pulling with squashing
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
      * Add bar/a_file in repo foo
      * Initial commit
      """
    And the remote's log should equal:
      """
      * Add more stuff in subrepo bar
      * Add another_file in remote baz
      * Add bar/a_file in repo foo
      """
