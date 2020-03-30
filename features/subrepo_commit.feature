Feature: Commiting merge conflict resolutions in a subrepo

  Background:
    Given I have an existing git project named "foo"
    And I have committed a new file "a_file" in subdirectory "bar"
    And I have an empty remote named "baz"
    And I have initialized the subrepo "bar" with that remote
    And I have pushed the subrepo "bar"

  Scenario: Pulling conflicting updates from the remote
    Given I have updated and committed "a_file" in the remote
    And I have updated and committed "a_file" in the subrepo
    When I attempt to pull the subrepo
    And I resolve the merge conflict with merged content
    And I finalize the pull using the subrepo commit subcommand
    And I push the subrepo
    Then the subrepo and the remote should have the same contents
