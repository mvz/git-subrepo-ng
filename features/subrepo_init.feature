Feature: Initializing a directory as a new subrepo

  Scenario: Initializing an existing directory as a new subrepo
    Given I have an empty remote named "barbar"
    And I have an existing git project named "foo"
    And I have committed a new file "a_file" in subdirectory "bar"
    When I init the subrepo "bar" with remote "../barbar" and branch "master"
    Then the file "foo/bar/.gitrepo" should contain:
      """
      ; DO NOT EDIT (unless you know what you are doing)
      ;
      ; This subdirectory is a git "subrepo", and this file is maintained by the
      ; git-subrepo-ng command.
      ;
      [subrepo]
      \tremote = ../barbar
      \tbranch = master
      \tcommit = ""
      \tmethod = merge
      \tcmdver = 0.1.0
      """
