#!/usr/bin/env bash

set -e

source test/setup

use Test::More

unset GIT_{AUTHOR,COMMITTER}_{EMAIL,NAME}

clone-foo-and-bar

# Make various changes to the repos for testing subrepo push:
(
  # In the main repo:
  cd $OWNER/foo

  # Clone the subrepo into a subdir
  git subrepo clone ../../../$UPSTREAM/bar

  # Make a series of commits:
  add-new-files bar/FooBar
  add-new-files ./FooBar
  modify-files bar/FooBar
  modify-files ./FooBar
  modify-files ./FooBar bar/FooBar
) &> /dev/null || die

(
  cd $OWNER/bar
  add-new-files bargy
  git push
) &> /dev/null || die

# Do the subrepo push and test the output:
{
  message="$(
    cd $OWNER/foo
    git config user.name 'PushUser'
    git config user.email 'push@push'
    git subrepo --quiet pull bar --squash
    git subrepo push bar
  )"

  # Test the output:
  is "$message" \
    "Subrepo 'bar' pushed to '../../../tmp/upstream/bar' (master)." \
    'push message is correct'
}

(
  cd $OWNER/bar
  git pull
) &> /dev/null || die

# Test log in main repo.
{
  fooLog="$(
    cd $OWNER/foo
    git log --graph --pretty=format:'%s' --abbrev-commit
  )"

  expectedFooLog=\
"* Push subrepo bar
* Subrepo-merge bar/master into master
* modified file: bar/FooBar
* modified file: ./FooBar
* modified file: bar/FooBar
* add new file: ./FooBar
* add new file: bar/FooBar
* Clone remote ../../../tmp/upstream/bar into bar
* Foo"
  is "$fooLog" \
    "$expectedFooLog" \
    "Main repo has the correct log"
}

# Test log in remote.
{
  barLog="$(
    cd $OWNER/bar
    git log --graph --pretty=format:'%s' --abbrev-commit
  )"

  expectedBarLog=\
"*   Subrepo-merge bar/master into master
|\  
| * add new file: bargy
* | modified file: bar/FooBar
* | modified file: bar/FooBar
* | add new file: bar/FooBar
|/  
* bard/Bard
* Bar"

  is "$barLog" \
    "$expectedBarLog" \
    "barLog"
}

{
  pullCommit="$(
    cd $OWNER/bar
    git log HEAD -1 --pretty='format:%an %ae %cn %ce'
  )"

  is "$pullCommit" \
    "PushUser push@push PushUser push@push" \
    "Pull commit has PushUser as both author and committer"
}

{
  subrepoCommit="$(
    cd $OWNER/bar
    git log HEAD^ -1 --pretty='format:%an %ae %cn %ce'
  )"

  is "$subrepoCommit" \
    "FooUser foo@foo PushUser push@push" \
    "Subrepo commit has FooUser as author but PushUser as committer"
}

# Check that all commits arrived in subrepo
test-commit-count "$OWNER/bar" HEAD 7

# Test foo/bar/.gitrepo file contents:
gitrepo=$OWNER/foo/bar/.gitrepo
{
  foo_pull_commit="$(cd $OWNER/foo; git rev-parse HEAD^)"
  bar_head_commit="$(cd $OWNER/bar; git rev-parse HEAD)"
  test-gitrepo-field "remote" "../../../$UPSTREAM/bar"
  test-gitrepo-field "branch" "master"
  test-gitrepo-field "commit" "$bar_head_commit"
  test-gitrepo-field "parent" "$foo_pull_commit"
  test-gitrepo-field "cmdver" "$VERSION"
}

(
  # In the main repo:
  cd $OWNER/foo
  add-new-files bar/FooBar2
  modify-files bar/FooBar
) &> /dev/null || die

{
  message="$(
    cd $OWNER/foo
    git subrepo push bar
  )"

  # Test the output:
  is "$message" \
    "Subrepo 'bar' pushed to '../../../tmp/upstream/bar' (master)." \
    'push message is correct'
}

# Pull the changes from UPSTREAM/bar in OWNER/bar
(
  cd $OWNER/bar
  git pull
) &> /dev/null || die

test-exists \
  "$OWNER/bar/Bar" \
  "$OWNER/bar/FooBar" \
  "$OWNER/bar/bard/" \
  "$OWNER/bar/bargy" \
  "!$OWNER/bar/.gitrepo" \

(
  # In the main repo:
  cd $OWNER/foo
  add-new-files bar/FooBar3
  modify-files bar/FooBar
  git subrepo push bar
  add-new-files bar/FooBar4
  modify-files bar/FooBar3
) &> /dev/null || die

{
  message="$(
    cd $OWNER/foo
    git subrepo push bar
  )"

  # Test the output:
  is "$message" \
    "Subrepo 'bar' pushed to '../../../tmp/upstream/bar' (master)." \
    'Seqential pushes are correct'
}

(
  # In the subrepo
  cd $OWNER/bar
  git pull
  add-new-files barBar2
  git push
) &> /dev/null || die

(
  # In the main repo:
  cd $OWNER/foo
  add-new-files bar/FooBar5
  modify-files bar/FooBar3
) &> /dev/null || die

{
  message="$(
    cd $OWNER/foo
    git subrepo push bar 2>&1 || true
  )"

  # Test the output:
  is "$message" \
    "error: There are new changes upstream, you need to pull first." \
    'Stopped by other push'
}

done_testing

teardown
