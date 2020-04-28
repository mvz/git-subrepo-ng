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
    And the project's log should equal:
      """
      * Push subrepo bar
      *   Subrepo-merge bar/master into master
      |\  
      | * Add foobar
      * | Add bar/smurf in repo foo
      * |   Merge branch 'subrepo-branch'
      |\ \  
      | |/  
      |/|   
      | * Update bar/barfoo in repo foo
      | * Add bar/barfoo in repo foo
      * |   Merge branch 'unrelated-branch'
      |\ \  
      | |/  
      |/|   
      | * Update zyxxy
      | * Add zyxxy
      |/  
      * Clone remote ../bar into bar
      * Initial commit
      """
    And the commit map should equal:
      """
      Push subrepo bar                     -> Subrepo-merge bar/master into master
      Subrepo-merge bar/master into master -> Subrepo-merge bar/master into master
      Merge branch 'subrepo-branch'        -> Update bar/barfoo in repo foo
      Update bar/barfoo in repo foo        -> Update bar/barfoo in repo foo
      Add bar/barfoo in repo foo           -> Add bar/barfoo in repo foo
      Add foobar                           -> Add foobar
      Merge branch 'unrelated-branch'      -> Add other_file
      Update zyxxy                         -> Add other_file
      Add zyxxy                            -> Add other_file
      Clone remote ../bar into bar         -> Add other_file
      """
    And the remote's log should equal:
      """
      *   Subrepo-merge bar/master into master
      |\  
      | * Add foobar
      * | Add bar/smurf in repo foo
      * |   Merge branch 'subrepo-branch'
      |\ \  
      | |/  
      |/|   
      | * Update bar/barfoo in repo foo
      | * Add bar/barfoo in repo foo
      |/  
      * Add other_file
      * Add this_file
      """
