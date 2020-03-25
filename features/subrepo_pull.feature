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
    And the subrepo configuration should contain the latest commit and parent

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

  Scenario: Pulling updates from the remote without squashing
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
      * Add bar/a_file in repo foo
      * Initial commit
      """
    And the subrepo configuration should contain the latest commit and parent

  Scenario: Pulling without squashing after committing to the main repo
    When I add a new commit to the remote
    And I add a new commit to the subrepo
    And I pull the subrepo without squashing
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

  Scenario: Pulling twice in a row has no extra effect
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
      * Add bar/a_file in repo foo
      * Initial commit
      """
