#!/usr/bin/env bash
#
# Squashless version of test/pull-new-branch.t
#

source test/setup

use Test::More

clone-foo-and-bar

subrepo-clone-bar-into-foo

(
  cd "$OWNER/bar"
  git checkout -b branch1
  git push --set-upstream origin branch1
) &> /dev/null || die

# Test subrepo file content:
gitrepo=$OWNER/foo/bar/.gitrepo

{
  foo_pull_commit=$(cd "$OWNER/foo"; git rev-parse HEAD^)
  bar_head_commit=$(cd "$OWNER/bar"; git rev-parse HEAD)
  test-gitrepo-comment-block
  test-gitrepo-field remote "../../../$UPSTREAM/bar"
  test-gitrepo-field branch master
  test-gitrepo-field commit "$bar_head_commit"
  test-gitrepo-field parent "$foo_pull_commit"
  test-gitrepo-field cmdver "$VERSION"
}

{
  is "$(
    cd $OWNER/foo
    git subrepo pull bar -b branch1 -u
  )" \
    "Subrepo 'bar' pulled from '../../../tmp/upstream/bar' (branch1)." \
    'subrepo pull commits config even when we dont need to pull'
}

{
  foo_pull_commit=$(cd "$OWNER/foo"; git rev-parse HEAD^)
  bar_head_commit=$(cd "$OWNER/bar"; git rev-parse HEAD)
  test-gitrepo-comment-block
  test-gitrepo-field remote "../../../$UPSTREAM/bar"
  test-gitrepo-field branch branch1
  test-gitrepo-field commit "$bar_head_commit"
  test-gitrepo-field parent "$foo_pull_commit"
  test-gitrepo-field cmdver "$VERSION"
}

{
  is "$(
    cd $OWNER/foo
    git subrepo pull bar
  )" \
    "Subrepo 'bar' is up to date." \
    'subrepo detects that we dont need to pull'
}

done_testing

teardown
