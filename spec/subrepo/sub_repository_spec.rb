# frozen_string_literal: true

RSpec.describe Subrepo::SubRepository do
  let(:main) { Subrepo::MainRepository.new }

  describe "#split_branch_name" do
    it "replaces initial dot in the subdir" do
      subrepo = described_class.new(main, ".foo")
      expect(subrepo.split_branch_name).to eq "subrepo/%2efoo"
    end

    it "replaces initial dot in path component" do
      subrepo = described_class.new(main, "foo/.bar")
      expect(subrepo.split_branch_name).to eq "subrepo/foo/%2ebar"
    end

    it "replaces dot in .lock" do
      subrepo = described_class.new(main, "foo.lock")
      expect(subrepo.split_branch_name).to eq "subrepo/foo%2elock"
    end

    it "does not replace dot in .locking" do
      subrepo = described_class.new(main, "foo.locking")
      expect(subrepo.split_branch_name).to eq "subrepo/foo.locking"
    end

    it "replaces two consecutive dots" do
      subrepo = described_class.new(main, "foo..bar")
      expect(subrepo.split_branch_name).to eq "subrepo/foo%2e%2ebar"
    end

    it "replaces three consecutive dots" do
      subrepo = described_class.new(main, "foo...bar")
      expect(subrepo.split_branch_name).to eq "subrepo/foo%2e%2e%2ebar"
    end

    it "replaces ascii control characters" do
      subrepo = described_class.new(main, "foo\001\037\177bar")
      expect(subrepo.split_branch_name).to eq "subrepo/foo%01%1f%7fbar"
    end

    it "replaces other disallowed single characters" do
      subrepo = described_class.new(main, " ~^:?*[\n\\")
      expect(subrepo.split_branch_name).to eq "subrepo/%20%7e%5e%3a%3f%2a%5b%0a%5c"
    end

    it "condenses extra slashes" do
      subrepo = described_class.new(main, "/foo//bar/")
      expect(subrepo.split_branch_name).to eq "subrepo/foo/bar"
    end

    it "replaces the sequence @{" do
      subrepo = described_class.new(main, "foo@{bar")
      expect(subrepo.split_branch_name).to eq "subrepo/foo%40{bar"
    end

    it "replaces final dot" do
      subrepo = described_class.new(main, "foo.bar.")
      expect(subrepo.split_branch_name).to eq "subrepo/foo.bar%2e"
    end

    it "replaces single @" do
      subrepo = described_class.new(main, "@")
      expect(subrepo.split_branch_name).to eq "subrepo/%40"
    end

    it "does not replace other case of @" do
      subrepo = described_class.new(main, "foo@")
      expect(subrepo.split_branch_name).to eq "subrepo/foo@"
    end
  end

  describe "#fetch_ref" do
    it "uses escaped subdir name" do
      subrepo = described_class.new(main, ".foo")
      expect(subrepo.fetch_ref).to eq "refs/subrepo/%2efoo/fetch"
    end
  end
end
