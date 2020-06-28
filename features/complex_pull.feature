Feature: Complex pull

  Background:
    Given I have a remote named "bar" with some commits
    And I have an existing git project named "foo"
    And I have cloned into "bar" from the remote "../bar" with branch "master"
    And I have created and committed "baz" in the remote
    And I have created a branch with commits for "qux" in the remote
    And I have created and committed "quuz" in the remote
    And I have created a branch with commits for "zyxxy" in the remote
    And I have updated and committed "quuz" in the remote

  Scenario: Commit map after pulling changes with several commits
    When I pull the subrepo
    Then the commit map should equal:
      """
      Subrepo-merge bar/master into master -> Update quuz in remote bar
      Update quuz in remote bar            -> Update quuz in remote bar
      Add quuz                             -> Add quuz
      Add baz                              -> Add baz
      Clone remote ../bar into bar         -> Add other_file
      Initial commit                       -> 
      """

  Scenario: Squash-pulling before and after changes with intermediate branch points
    When I pull the subrepo with squashing
    And I merge the branch for "qux" in the remote
    And I merge the branch for "zyxxy" in the remote
    And I pull the subrepo with squashing again
    Then the subrepo and the remote should have the same contents

  Scenario: Squash-pulling new changes with intermediate branch points
    When I pull the subrepo
    And I merge the branch for "qux" in the remote
    And I merge the branch for "zyxxy" in the remote
    And I pull the subrepo with squashing
    Then the subrepo and the remote should have the same contents

  Scenario: Squash-pulling first commits, then pulling new changes without squashing
    When I pull the subrepo with squashing
    And I merge the branch for "qux" in the remote
    And I merge the branch for "zyxxy" in the remote
    And I pull the subrepo
    Then the subrepo and the remote should have the same contents

  Scenario: Pulling new changes with intermediate branch points
    When I pull the subrepo
    And I merge the branch for "qux" in the remote
    And I merge the branch for "zyxxy" in the remote
    And I pull the subrepo again
    Then the subrepo and the remote should have the same contents
