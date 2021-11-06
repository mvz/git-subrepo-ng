# Subrepo

An experimental clone of git subrepo, to be extended with improvements.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'subrepo'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install subrepo

## Usage

Summary:
```
git subrepo init subdir --remote remote --branch branch
git subrepo push subdir
git subrepo fetch subdir
git subrepo pull subdir
git subrepo commit subdir
```

## What Does This Do?

This is an experimental re-implementation of
[git-subrepo](https://github.com/ingydotnet/git-subrepo), with the following goals:

* Keep as much history as reasonably possible, both when pushing and pulling.
  In particular, do not squash history when pulling subrepo changes back into
  the main repo
* Be performant
* Have nicer generated commit messages

### Initializing an Existing Directory As a Subrepo

```bash
git subrepo init subdir --remote <remote> --branch <branch>
```

Sets up configuration for handling the given subdirectory as a subrepo. A
remote repository to push to and pull from, as well as the remote branch to
use, must be provided.

This sets up a `.gitrepo` in the subdirectory with inital settings, and commits
it.

### First Push

```bash
git subrepo push subdir [--remote <remote>] [--branch <branch>]
```

Rewrites the history for the subrepo to a new branch, then pushes that
branch to the remote.

The `.gitrepo` file is not pushed to the remote.

The last commit of the pushed history and the last commit of the original
history are both recorded in the `.gitrepo` file.

### Subsequent Pushes

```bash
git subrepo push subdir [--remote <remote>] [--branch <branch>]
```

Rewrites the new part of the history of the subrepo to a new branch, then
pushes that to the remote.

The last commit of the pushed history and the last commit of the original
history are both recorded in the `.gitrepo` file.

It is highly recommended to specify a different branch to push to, so that the
pushed changes can be turned into a pull request or checked in other ways
before merging into the master branch.

### Pulling Changes From Upstream

```bash
git subrepo pull subdir [--remote <remote>]
```

Fetches commits from the remote and rewrites them as part of the history of the
subrepo.

The last fetched commit is recorded in the `.gitrepo` file.

## Status of This Project

This code is experimental. Try at your own risk. Implementation of subrepo
functionality is incomplete. In particular, it is not yet possible to clone a
remote into a new subrepo.

## Caveats

Because git-subrepo-ng stores commit shas for fetched and pushed commits in the
`.gitrepo` file, you should be careful when rebasing branches. In particular,
you should pull from the remote's main development branch, and push from the
main repository's main development branch.

## Development

After checking out the repo, run `script/setup` to install dependencies. Then,
run `rake spec` to run the tests. You can also run `script/console` for an
interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To
release a new version, update the version number in `version.rb`, and then run
`bundle exec rake release`, which will create a git tag for the version, push
git commits and tags, and push the `.gem` file to
[rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at
https://github.com/mvz/subrepo. This project is intended to be a safe,
welcoming space for collaboration, and contributors are expected to adhere to
the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

Copyright &copy; 2019-2020 [Matijs van Zuijlen](http://www.matijs.net)

This is free software, distributed under the terms of the GNU General Public
License, version 3.0 or later. See the file COPYING for more information.

The test suite in `test/` is based on the test suite of git-subrepo, which is
licensed under the MIT License and copyright &copy; 2013-2020 Ingy döt Net.

## Code of Conduct

Everyone interacting in the Subrepo project’s codebases, issue trackers, chat
rooms and mailing lists is expected to follow the
[code of conduct](https://github.com/mvz/subrepo/blob/master/CODE_OF_CONDUCT.md).
