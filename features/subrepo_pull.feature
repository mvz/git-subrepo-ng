Feature: Pulling a subrepo

  Background:
    Given I have an existing git project named "foo"
    And I have committed a new file "a_file" in subdirectory "bar"
    And I have an empty remote named "baz"
    And I have initialized the subrepo "bar" with that remote
    And I have pushed the subrepo "bar"

  Scenario: Pulling updates from the remote with squashing
    When I add a new commit to the remote
    And I pull the subrepo with squashing
    Then the subrepo and the remote should have the same contents
    And the project's log should equal:
      """
      * Subrepo-merge bar/master into master
      * Push subrepo bar
      * Initialize subrepo bar
      * Add bar/a_file in repo foo
      * Initial commit
      """
    And the remote's log should equal:
      """
      * Add another_file in remote baz
      * Add bar/a_file in repo foo
      """
    And the subrepo configuration should contain the latest commit and parent
    And the commit map should equal:
      """
      Subrepo-merge bar/master into master -> Add another_file in remote baz
      Push subrepo bar                     -> Add bar/a_file in repo foo
      Initialize subrepo bar               -> Add bar/a_file in repo foo
      Add bar/a_file in repo foo           -> Add bar/a_file in repo foo
      Initial commit                       -> 
      """
    And the subrepo branch has been removed

  Scenario: Pulling with squashing after committing to the main repo
    When I add a new commit to the remote
    And I add a new commit to the subrepo
    And I pull the subrepo with squashing
    Then the project's log should equal:
      """
      * Subrepo-merge bar/master into master
      * Add more stuff in subrepo bar
      * Push subrepo bar
      * Initialize subrepo bar
      * Add bar/a_file in repo foo
      * Initial commit
      """
    And the remote's log should equal:
      """
      * Add another_file in remote baz
      * Add bar/a_file in repo foo
      """
    And the commit map should equal:
      """
      Subrepo-merge bar/master into master -> Add another_file in remote baz
      Push subrepo bar                     -> Add bar/a_file in repo foo
      Initialize subrepo bar               -> Add bar/a_file in repo foo
      Add bar/a_file in repo foo           -> Add bar/a_file in repo foo
      Initial commit                       -> 
      """

  Scenario: Pulling updates from the remote
    When I add a new commit to the remote
    And I pull the subrepo
    Then the subrepo and the remote should have the same contents
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
    And the remote's log should equal:
      """
      * Add another_file in remote baz
      * Add bar/a_file in repo foo
      """
    And the subrepo configuration should contain the latest commit and parent
    And the commit map should equal:
      """
      Subrepo-merge bar/master into master -> Add another_file in remote baz
      Add another_file in remote baz       -> Add another_file in remote baz
      Push subrepo bar                     -> Add bar/a_file in repo foo
      Initialize subrepo bar               -> Add bar/a_file in repo foo
      Add bar/a_file in repo foo           -> Add bar/a_file in repo foo
      Initial commit                       -> 
      """

  Scenario: Pulling after committing to the main repo
    When I add a new commit to the remote
    And I add a new commit to the subrepo
    And I pull the subrepo
    Then the project's log should equal:
      """
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
    And the remote's log should equal:
      """
      * Add another_file in remote baz
      * Add bar/a_file in repo foo
      """
    And the commit map should equal:
      """
      Add another_file in remote baz -> Add another_file in remote baz
      Push subrepo bar               -> Add bar/a_file in repo foo
      Initialize subrepo bar         -> Add bar/a_file in repo foo
      Add bar/a_file in repo foo     -> Add bar/a_file in repo foo
      Initial commit                 -> 
      """

  Scenario: Pulling twice in a row has no extra effect
    When I add a new commit to the remote
    And I pull the subrepo
    And I pull the subrepo again
    Then the subrepo and the remote should have the same contents
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

  Scenario: Pulling all subrepos
    When I add a new commit to the remote
    And I pull all subrepos
    Then the subrepo and the remote should have the same contents
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
