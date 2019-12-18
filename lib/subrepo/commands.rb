# frozen_string_literal: true

require "rugged"
require "subrepo/version"
require "subrepo/config"

module Subrepo
  module Commands
    module_function

    def command_fetch(subdir, remote: nil)
      config = Config.new(subdir)
      remote ||= config.remote
      branch = config.branch
      last_merged_commit = config.commit

      remote_commit = `git ls-remote --no-tags \"#{remote}\" \"#{branch}\"`
      if remote_commit.empty?
        puts "Branch #{branch} not on remote yet"
        return false
      end
      system "git fetch --no-tags \"#{remote}\" \"#{branch}\""
      new_commit = `git rev-parse FETCH_HEAD`.chomp
      puts "Fetched #{new_commit}"
      puts "No change" if new_commit == last_merged_commit
      refs_subrepo_fetch = "refs/subrepo/#{subdir}/fetch"
      system "git update-ref #{refs_subrepo_fetch} #{new_commit}"
      true
    end

    def command_merge(subdir, remote: nil)
      current_branch = `git rev-parse --abbrev-ref HEAD`.chomp
      config = Config.new(subdir)
      remote ||= config.remote
      branch = config.branch
      last_merged_commit = config.commit

      config_name = config.file_name

      last_local_commit = `git log -n 1 --pretty=format:%H -- "#{config_name}"`
      refs_subrepo_fetch = "refs/subrepo/#{subdir}/fetch"
      last_fetched_commit = `git rev-parse #{refs_subrepo_fetch}`.chomp

      if last_fetched_commit == last_merged_commit
        warn "Nothing to do"
        return
      end

      command = "git rebase" \
        " --onto #{last_local_commit} #{last_merged_commit} #{last_fetched_commit}" \
        " --rebase-merges" \
        " -X subtree=#{subdir}"

      system command

      rebased_head = `git rev-parse HEAD`.chomp
      system "git checkout #{current_branch}"
      system "git merge #{rebased_head} --no-ff --no-edit" \
        " -m \"Subrepo-merge #{subdir}/#{branch} into #{current_branch}\""

      config.commit = last_fetched_commit
      system "git add \"#{config_name}\""
      system "git commit --amend --no-edit"
    end

    def command_pull(subdir, remote: nil)
      command_fetch(subdir, remote: remote)
      command_merge(subdir, remote: remote)
    end

    def command_push(subdir, remote: nil, branch: nil)
      fetched = command_fetch(subdir, remote: remote)

      repo = Rugged::Repository.new(".")

      current_branch = `git rev-parse --abbrev-ref HEAD`.chomp

      config = Config.new(subdir)

      remote ||= config.remote
      branch ||= config.branch
      last_merged_commit = config.commit
      last_pushed_commit = config.parent

      upstream = Rugged::Repository.new(remote)

      if fetched
        refs_subrepo_fetch = "refs/subrepo/#{subdir}/fetch"
        last_fetched_commit = repo.ref(refs_subrepo_fetch).target_id
        last_fetched_commit == last_merged_commit or
          raise "There are new changes upstream, you need to pull first."

        split_branch_name = "subrepo-#{subdir}"
        if repo.branches.exist? split_branch_name
          raise "It seems #{split_branch_name} already exists. Remove it first"
        end

        # Walk all commits that haven't been pushed yet
        walker = Rugged::Walker.new(repo)
        walker.push repo.head.target_id
        walker.hide last_pushed_commit
        commits = walker.to_a

        commit_map = { last_pushed_commit => last_merged_commit }

        last_commit = nil

        commits.reverse_each do |commit|
          # Fetch subrepo's tree
          subtree = repo.lookup commit.tree[subdir][:oid]

          # Filter out .gitrepo
          builder = Rugged::Tree::Builder.new(repo)
          subtree.filter { |it| it[:name] != ".gitrepo" }.each { |it| builder << it }
          rewritten_tree_sha = builder.write
          rewritten_tree = repo.lookup rewritten_tree_sha

          # Map parent commits
          parent_shas = commit.parents.map(&:oid)
          target_parent_shas = parent_shas.map do |sha|
            # TODO: Improve upon last_merged_commit as best guess
            commit_map.fetch sha, last_merged_commit
          end.uniq
          target_parents = target_parent_shas.map { |sha| repo.lookup sha }

          if target_parents.one?
            target_parent = target_parents.first
            diff = target_parent.tree.diff rewritten_tree
            # If commit tree is no different from the target parent, map this
            # commit to the target parent and skip to the next commit.
            if diff.none?
              commit_map[commit.oid] = target_parent.oid
              next
            end
          end

          # Commit has multiple mapped parents or is non-empty: We should
          # create it in the target branch too.
          options = {}
          options[:tree] = rewritten_tree
          options[:author] = commit.author
          options[:committer] = commit.committer
          options[:parents] = target_parents
          options[:message] = commit.message

          puts "Committing #{commit.summary}"

          new_commit_sha = Rugged::Commit.create(repo, options)
          commit_map[commit.oid] = new_commit_sha
          last_commit = new_commit_sha
        end

        unless last_commit
          puts "No changes to push"
          return
        end

        split_branch = repo.branches.create split_branch_name, last_commit

        puts "git push \"#{remote}\" #{split_branch_name}:#{branch}"
        system "git push \"#{remote}\" #{split_branch_name}:#{branch}"
        pushed_commit = last_commit

        system "git branch -D #{split_branch_name}"

        parent_commit = `git rev-parse HEAD`.chomp

        unless last_pushed_commit == pushed_commit
          config.commit = pushed_commit
          config.parent = parent_commit
          system "git add -f -- #{config.file_name}"
          system "git commit -m \"Push subrepo #{subdir}\""
        end
      else
        split_branch = "subrepo-#{subdir}"
        unless `git show-ref #{split_branch}`.chomp.empty?
          raise "It seems #{split_branch} already exists. Remove it first"
        end

        system "git co -b #{split_branch}"
        puts "Filtering #{subdir}"
        ENV["FILTER_BRANCH_SQUELCH_WARNING"] = "1"
        system "git filter-branch" \
          " --subdirectory-filter #{subdir}" \
          " --index-filter 'git rm --cached --ignore-unmatch .gitrepo'" \
          " --prune-empty"
        system "git push \"#{remote}\" #{split_branch}:#{branch}"
        pushed_commit = `git rev-parse HEAD`.chomp

        system "git co #{current_branch}"

        system "git branch -D #{split_branch}"

        parent_commit = `git rev-parse HEAD`.chomp

        config.commit = pushed_commit
        config.parent = parent_commit
        system "git add -f -- #{config.file_name}"
        system "git commit -m \"Push subrepo #{subdir}\""
      end
    end

    def command_init(subdir, remote:, branch:)
      repo = Rugged::Repository.new(".")

      File.exist? subdir or raise "The subdir '#{subdir} does not exist."
      config = Config.new(subdir)
      config_name = config.file_name
      File.exist? config_name and
        raise "The subdir '#{subdir}' is already a subrepo."
      last_subdir_commit = `git log -n 1 --pretty=format:%H -- "#{subdir}"`.chomp
      last_subdir_commit.empty? and
        raise "The subdir '#{subdir}' is not part of this repo."

      config.create(remote, branch)

      index = repo.index
      index.add config_name
      index.write
      Rugged::Commit.create(repo, tree: index.write_tree,
                            message: "Initialize subrepo #{subdir}",
                            parents: [repo.head.target], update_ref: "HEAD")
    end
  end
end
