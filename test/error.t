#!/usr/bin/env bash

set -e

source test/setup

use Test::More
export GIT_SUBREPO_TEST_ERRORS=true

note "Test all error message conditions in git-subrepo"

clone-foo-and-bar

{
  is "$(
      cd $OWNER/bar
      git subrepo --quiet clone ../../../$UPSTREAM/foo
      add-new-files foo/file
      git subrepo --quiet branch foo
      catch git subrepo branch foo
    )" \
    "error: Branch 'subrepo/foo' already exists. Use '--force' to override." \
    "Error OK: can't create a branch that exists"

  (
    cd $OWNER/bar
    git subrepo --quiet clean foo
    git reset --quiet --hard HEAD^
  )
}

{
  like "$(catch git subrepo clone --foo)" \
    "error: Unknown option --foo" \
    "Error OK: unknown command option"
}

{
  is "$(catch git subrepo main 1 2 3)" \
    "error: Unknown command 'main'" \
    "Error OK: unknown command"
}

{
  is "$(catch git subrepo pull --update)" \
    "error: Can't use '--update' without '--branch' or '--remote'." \
    "Error OK: --update requires --branch or --remote options"
}

{
  is "$(catch git subrepo clone --all)" \
    "error: Unknown option --all" \
    "Error OK: Invalid option '--all' for 'clone'"
}

{
  like "$(
      cd $OWNER/bar
      catch git subrepo pull /home/user/bar/foo
    )" \
    "error: The subdir '.*/home/user/bar/foo' should not be absolute path." \
    "Error OK: check subdir is not absolute path"
}

{
  # XXX add 'commit' to cmds here when implemented:
  for cmd in pull push fetch branch commit clean; do
    is "$(
        cd $OWNER/bar
        catch git subrepo $cmd
      )" \
      "error: Command '$cmd' requires arg 'subdir'." \
      "Error OK: check that '$cmd' requires subdir"
  done
}

{
  is "$(
      cd $OWNER/bar
      catch git subrepo clone foo bar baz quux
    )" \
    "error: Unknown argument(s) 'baz quux' for 'clone' command." \
    "Error OK: extra arguments for clone"
}

{
  is "$(
      cd $OWNER/bar
      catch git subrepo clone .git
    )" \
    "error: Can't determine subdir from '.git'." \
    "Error OK: check error in subdir guess"
}

{
  is "$(
      cd $OWNER/bar
      catch git subrepo pull lala
    )" \
    "error: No 'lala/.gitrepo' file." \
    "Error OK: check for valid subrepo subdir"
}

{
  is "$(
      cd $OWNER/bar
      git checkout --quiet $(git rev-parse master)
      catch git subrepo status
    )" \
    "error: Must be on a branch to run this command." \
    "Error OK: check repo is on a branch"
  (
    cd $OWNER/bar
    git checkout --quiet master
  )
}

{
  is "$(
      cd .git
      catch git subrepo status
    )" \
    "error: Can't 'subrepo status' outside a working tree." \
    "Error OK: check inside working tree"
}

{
  like "$(
      cd $OWNER/bar
      touch me
      git add me
      catch git subrepo clone ../../../$UPSTREAM/foo
    )" \
    "error: Can't clone subrepo. Working tree has changes." \
    "Error OK: check no working tree changes"
  (
    cd $OWNER/bar
    git reset --quiet --hard
  )
}

{
  is "$(
      cd lib
      catch git subrepo status
    )" \
    "error: Need to run subrepo command from top level directory of the repo." \
    "Error OK: check cwd is at top level"
}

{
  is "$(
      cd $OWNER/bar
      catch git subrepo clone dummy bard
    )" \
    "error: The subdir 'bard' exists and is not empty." \
    "Error OK: non-empty clone subdir target"
}

{
  is "$(
      cd $OWNER/bar
      catch git subrepo clone dummy-repo
    )" \
    "error: Command failed: 'git ls-remote --no-tags dummy-repo master'." \
    "Error OK: clone non-repo"
}

done_testing

teardown
