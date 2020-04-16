Feature: Status of a subrepo

  Background:
    Given I have a remote named "bar" with some commits
    And I have a remote named "barbar" with some commits
    And I have an existing git project named "foo"
    And I have cloned into "bar" from the remote "../bar" with branch "master"
    And I have cloned into "barbar" from the remote "../barbar" with branch "master"
    And I have cloned into "bar/foobar" from the remote "../barbar" with branch "master"

  Scenario: Getting the status of a single subrepo
    When I get the status of the subrepo "bar"
    Then the subrepo command output should match:
      """
      Git subrepo 'bar':
        Remote URL:      \.\./bar
        Tracking Branch: master
        Pulled Commit:   .......
        Pull Parent:     .......

      """

  Scenario: Getting the status of a all subrepos
    When I get the status of all subrepos
    Then the subrepo command output should match:
      """
      2 subrepos:

      Git subrepo 'bar':
        Remote URL:      \.\./bar
        Tracking Branch: master
        Pulled Commit:   .......
        Pull Parent:     .......

      Git subrepo 'barbar':
        Remote URL:      \.\./barbar
        Tracking Branch: master
        Pulled Commit:   .......
        Pull Parent:     .......

      """

  Scenario: Getting the status of a all subrepos recursively
    When I get the status of all subrepos recursively
    Then the subrepo command output should match:
      """
      3 subrepos:

      Git subrepo 'bar':
        Remote URL:      \.\./bar
        Tracking Branch: master
        Pulled Commit:   .......
        Pull Parent:     .......

      Git subrepo 'bar/foobar':
        Remote URL:      \.\./barbar
        Tracking Branch: master
        Pulled Commit:   .......
        Pull Parent:     .......

      Git subrepo 'barbar':
        Remote URL:      \.\./barbar
        Tracking Branch: master
        Pulled Commit:   .......
        Pull Parent:     .......

      """
