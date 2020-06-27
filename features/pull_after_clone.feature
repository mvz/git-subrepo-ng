Feature: Pull after clone

  Scenario: Pull new commits from subrepo after cloning
    Given I have a remote named "bar" with some commits
    And I have an existing git project named "foo"
    And I have cloned into "bar" from the remote "../bar" with branch "master"
    And I have created and committed "foobar" in the remote
    When I pull the subrepo
    Then the subrepo and the remote should have the same contents
    And the project's log should equal:
      """
      *   Subrepo-merge bar/master into master
      |\  
      | * Add foobar
      |/  
      * Clone remote ../bar into bar
      * Initial commit
      """
    And the commit map should equal:
      """
      Subrepo-merge bar/master into master -> Add foobar
      Add foobar                           -> Add foobar
      Clone remote ../bar into bar         -> Add other_file
      Initial commit                       -> 
      """
    And the remote's log should equal:
      """
      * Add foobar
      * Add other_file
      * Add this_file
      """
