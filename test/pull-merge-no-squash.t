#!/usr/bin/env bash
#
# Squashless version of test/pull-merge.t
#

set -e

source test/setup

use Test::More

clone-foo-and-bar

subrepo-clone-bar-into-foo

note "Pull - Conflict - Merge ours/theirs without squashing - Push"

(
  cd $OWNER/bar
  add-new-files Bar2
  git push
) &> /dev/null || die

gitrepo=$OWNER/foo/bar/.gitrepo
# Test foo/bar/.gitrepo file contents:
{
  foo_pull_commit="$(cd $OWNER/foo; git rev-parse HEAD^)"
  bar_head_commit="$(cd $OWNER/bar; git rev-parse HEAD^)"
  test-gitrepo-field "commit" "$bar_head_commit"
  test-gitrepo-field "parent" "$foo_pull_commit"
}

(
  cd $OWNER/foo
  git subrepo pull bar
  modify-files-ex bar/Bar2
  git push
) &> /dev/null || die

(
  cd $OWNER/bar
  modify-files-ex Bar2
  git push
) &> /dev/null || die

(
  cd $OWNER/foo
  git subrepo pull bar || {
      cd .git/tmp/subrepo/bar
      echo "Merged Bar2" > Bar2
      git add Bar2
      git commit --file ../../../../.git/worktrees/bar/MERGE_MSG
      cd ../../../..
      git subrepo commit bar
      git subrepo clean bar
  }
) &> /dev/null || die

test-exists \
  "$OWNER/foo/bar/Bar2" \
  "$OWNER/bar/Bar2" \

is "$(cat $OWNER/foo/bar/Bar2)" \
  "Merged Bar2" \
  "The readme file in the mainrepo is merged"

# Check commit messages
{
  foo_new_commit_message="$(cd $OWNER/foo; git log --format=%B -n 1)"
  like "$foo_new_commit_message" \
      "Subrepo-merge bar/master into master" \
      "subrepo pull should have merge message"
}

# Test foo/bar/.gitrepo file contents:
{
  foo_pull_commit="$(cd $OWNER/foo; git rev-parse HEAD^2)"
  bar_head_commit="$(cd $OWNER/bar; git rev-parse HEAD)"
  test-gitrepo-field "commit" "$bar_head_commit"
  test-gitrepo-field "parent" "$foo_pull_commit"
}

(
  cd $OWNER/foo
  git subrepo push bar
) &> /dev/null || die

# Check commit messages
{
  foo_new_commit_message="$(cd $OWNER/foo; git log --format=%B -n 1)"
  like "$foo_new_commit_message" \
      "Push subrepo bar" \
      "subrepo push should not have merge message"
}

(
  cd $OWNER/bar
  git pull
) &> /dev/null || die

test-exists \
  "$OWNER/foo/bar/Bar2" \
  "$OWNER/bar/Bar2" \

is "$(cat $OWNER/foo/bar/Bar2)" \
  "Merged Bar2" \
  "The readme file in the mainrepo is merged"

is "$(cat $OWNER/bar/Bar2)" \
  "Merged Bar2" \
  "The readme file in the subrepo is merged"

done_testing

teardown
