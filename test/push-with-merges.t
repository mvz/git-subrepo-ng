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
  git branch flub
  git branch flab
  git checkout flub
  add-new-files bar/FooBar
  modify-files bar/FooBar
  git checkout flab
  add-new-files ./FooBar
  modify-files ./FooBar
  git checkout master
  git merge flab --no-ff -m "Merge branch without subrepo changes"
  git merge flub --no-ff -m "Merge branch with subrepo changes"
  modify-files ./FooBar bar/FooBar
) &> /dev/null || die

# Check that all commits were created in main repo
test-commit-count "$OWNER/foo" HEAD 9

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

# Check that all commits were created in main repo
test-commit-count "$OWNER/foo" HEAD 11

# Check that all commits arrived in subrepo
test-commit-count "$OWNER/bar" HEAD 8

# Check full log in main repo
{
  fooLog="$(
    cd $OWNER/foo
    git log --graph --pretty=format:'%s' --abbrev-commit
  )"

  expectedFooLog=\
"* Push subrepo bar
* Subrepo-merge bar/master into master
* modified file: bar/FooBar
*   Merge branch with subrepo changes
|\  
| * modified file: bar/FooBar
| * add new file: bar/FooBar
* |   Merge branch without subrepo changes
|\ \  
| |/  
|/|   
| * modified file: ./FooBar
| * add new file: ./FooBar
|/  
* Clone remote ../../../tmp/upstream/bar into bar
* Foo"
  is "$fooLog" \
    "$expectedFooLog" \
    "Main repo has the correct log"
}

# Check full log in subrepo
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
* |   Merge branch with subrepo changes
|\ \  
| |/  
|/|   
| * modified file: bar/FooBar
| * add new file: bar/FooBar
|/  
* bard/Bard
* Bar"

  is "$barLog" \
    "$expectedBarLog" \
    "barLog"
}

done_testing

teardown
