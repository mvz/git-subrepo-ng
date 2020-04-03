Feature: Commiting merge conflict resolutions in a subrepo

  Background:
    Given I have an existing git project named "foo"
    And I have committed a new file "a_file" in subdirectory "bar"
    And I have an empty remote named "baz"
    And I have initialized the subrepo "bar" with that remote
    And I have pushed the subrepo "bar"

  Scenario: Resolving conflicting update from the remote with merged content
    Given I have updated and committed "a_file" in the remote
    And I have updated and committed "a_file" in the subrepo
    When I attempt to pull the subrepo
    And I resolve the merge conflict with merged content
    And I finalize the pull using the subrepo commit subcommand
    And I push the subrepo
    Then the subrepo and the remote should have the same contents

  Scenario: Resolving conflicting update from the remote with local content
    Given I have updated and committed "a_file" in the remote
    And I have updated and committed "a_file" in the subrepo
    When I attempt to pull the subrepo
    And I resolve the merge conflict with local content
    And I finalize the pull using the subrepo commit subcommand
    And I push the subrepo
    Then the subrepo and the remote should have the same contents

  Scenario: Resolving conflicting update from the remote with remote content
    Given I have updated and committed "a_file" in the remote
    And I have updated and committed "a_file" in the subrepo
    When I attempt to pull the subrepo
    And I resolve the merge conflict with remote content
    And I finalize the pull using the subrepo commit subcommand
    And I push the subrepo
    Then the subrepo and the remote should have the same contents

  Scenario: Attempting commit without an available merge commit
    Given I have updated and committed "a_file" in the remote
    And I have updated and committed "a_file" in the subrepo
    When I fetch new commits for the subrepo from the remote
    When I attempt to commit
    Then I see that no existing merge commit is available

  Scenario: Attempting commit without resolving the conflict
    Given I have updated and committed "a_file" in the remote
    And I have updated and committed "a_file" in the subrepo
    When I attempt to pull the subrepo
    And I attempt to commit without resolving the conflict
    Then I see that I need to resolve the conflict first
