# frozen_string_literal: true

require "rspec/core/rake_task"
require "rubocop/rake_task"

RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new

task default: %i[spec rubocop]

desc "Build gem and verify contents"
task :build do
  sh("gem build zazu-ruby.gemspec --strict")
  gem_file = Dir["zazu-ruby-*.gem"].first
  abort "Gem file not found after build" unless gem_file

  sh("gem unpack #{gem_file} --target /tmp/gem-verify")
  puts "\n=== Gem contents ==="
  sh("find /tmp/gem-verify -type f | sort")
  sh("rm -rf /tmp/gem-verify #{gem_file}")
end

def info(msg)    = puts "\e[34m→\e[0m #{msg}"
def success(msg) = puts "\e[32m✓\e[0m #{msg}"
def skip(msg)    = puts "\e[33m⊘\e[0m #{msg} \e[33m(skipped)\e[0m"
def header(msg)  = puts "\n\e[1;36m#{msg}\e[0m\n#{"─" * msg.length}"

desc "Release a new version (rake release[1.2.3] or rake release[pre] or rake release[1.2.3,force])"
task :release, %i[version force] do |_t, args|
  require_relative "lib/zazu/version"

  new_version = args[:version]
  abort "\e[31mUsage: rake release[X.Y.Z] or rake release[X.Y.Z,force]\e[0m" unless new_version

  # Strict-ish semver: X.Y.Z with optional -alpha.N / -beta.N / -rc.N / -pre.N.
  # We don't need full semver coverage — we control the inputs and only ship
  # clean numeric versions. The regex is permissive enough for pre-release
  # suffixes but rejects anything that would silently corrupt version.rb.
  semver_re = /\A\d+\.\d+\.\d+(?:-(?:alpha|beta|rc|pre)(?:\.\d+)?)?\z/
  unless new_version == "pre" || new_version.match?(semver_re)
    abort "\e[31mInvalid version \"#{new_version}\". " \
          "Expected X.Y.Z (optionally suffixed with -alpha.N / " \
          "-beta.N / -rc.N / -pre.N), or the literal \"pre\".\e[0m"
  end

  force = args[:force]&.to_s&.downcase == "force"

  dirty = `git status --porcelain`.strip
  abort "\e[31mAborting: working directory is not clean.\e[0m\n#{dirty}" unless dirty.empty?

  current = Zazu::VERSION
  prerelease = new_version.match?(/alpha|beta|rc|pre/) || new_version == "pre"

  if new_version == "pre"
    new_version = current
    prerelease = true
  end

  tag = "v#{new_version}"
  version_file = "lib/zazu/version.rb"

  title = "Release #{tag}"
  title += " (force)" if force
  header title
  info "Current version: #{current}"
  info "New version:     #{new_version}"
  info "Pre-release:     #{prerelease}"

  # Bail out before any repo mutation if the release already exists
  # and we're not in force mode. Without this guard, a re-run on an
  # already-shipped version would still rewrite version.rb, build the
  # gem, commit, and push origin/main — landing a noise commit on
  # main with no release dispatched.
  if !force && system("gh release view #{tag} >/dev/null 2>&1")
    header "Release"
    skip "Release #{tag} already exists (use force to re-create)"
    puts ""
    puts "Release #{tag} was not dispatched. To re-cut, run with `force` or pick a higher version."
    next
  end

  # Step 0: Force cleanup — delete existing release and tag
  if force
    header "Force cleanup"
    if system("gh release view #{tag} >/dev/null 2>&1")
      sh("gh release delete #{tag} --yes --cleanup-tag")
      success "Deleted release and remote tag #{tag}"
    else
      skip "No release #{tag} to delete"
    end

    # Even when no release existed, a stray remote tag may still be
    # there (e.g. from a previous half-finished release attempt).
    # gh release delete --cleanup-tag only runs when the release
    # object existed, so we have to handle the orphaned-tag case
    # ourselves — otherwise gh release create --target main below
    # fails with "tag already exists" and the user can't recover
    # without manual git push --delete.
    if system("git ls-remote --exit-code origin refs/tags/#{tag} >/dev/null 2>&1")
      sh("git push origin --delete #{tag}")
      success "Deleted remote tag #{tag}"
    else
      skip "No remote tag #{tag} to delete"
    end

    if system("git rev-parse #{tag} >/dev/null 2>&1")
      sh("git tag -d #{tag}")
      success "Deleted local tag #{tag}"
    else
      skip "No local tag #{tag} to delete"
    end
  end

  # Step 1: Update version file
  header "Version"
  if new_version == current
    skip "Version already #{new_version}"
  else
    content = File.read(version_file)
    content.sub!(/VERSION = ".*"/, "VERSION = \"#{new_version}\"")
    File.write(version_file, content)
    success "Updated #{version_file}"
  end

  # Step 2: Verify gem builds cleanly
  header "Build verification"
  sh("gem build zazu-ruby.gemspec --strict")
  sh("rm -f zazu-ruby-*.gem")
  success "Gem builds cleanly"

  # Step 3: Commit version bump
  header "Git commit"
  version_changed = !`git diff #{version_file}`.strip.empty? || !`git diff --cached #{version_file}`.strip.empty?
  if version_changed
    sh("git add #{version_file}")
    sh("git commit -m 'chore: bump version to #{new_version}'")
    success "Committed version bump"
  else
    skip "No version change to commit"
  end

  # Step 4: Push to origin
  header "Git push"
  # Refuse to push from anywhere other than main — release.yml triggers
  # on pushes to main and tags off main, so a release driven from a
  # feature branch would land tags pointing at the wrong commit.
  branch = `git rev-parse --abbrev-ref HEAD`.strip
  abort "\e[31mAborting: must release from main, currently on #{branch}.\e[0m" unless branch == "main"

  # Refresh origin/main so the local-vs-remote comparison below is
  # meaningful — without this fetch, an out-of-date tracking ref will
  # either skip a needed push or trigger a redundant one.
  sh("git fetch origin main")

  local_sha = `git rev-parse HEAD`.strip
  remote_sha = `git rev-parse origin/main 2>/dev/null`.strip
  if local_sha == remote_sha
    skip "origin/main already at #{local_sha[0..6]}"
  else
    sh("git push origin main")
    success "Pushed to origin/main"
  end

  # Step 5: Create release
  header "Release"
  tag_exists = system("git rev-parse #{tag} >/dev/null 2>&1")

  if tag_exists
    info "Tag #{tag} exists, creating release from it"
    pre_flag = prerelease ? "--prerelease" : ""
    sh("gh release create #{tag} --generate-notes #{pre_flag}".strip)
    success "Release #{tag} created from existing tag"
  else
    pre_flag = prerelease ? "--prerelease" : ""
    sh("gh release create #{tag} --generate-notes --target main #{pre_flag}".strip)
    success "Release #{tag} created"
  end

  puts ""
  success "\e[1mRelease #{tag} complete!\e[0m CI will handle the rest:"
  puts "    • Run tests"
  puts "    • Build + verify gem"
  puts "    • Sign with Sigstore"
  puts "    • Publish to RubyGems"
  puts "    • Upload assets to the release"
end

# fixtures:seed and fixtures:teardown live in lib/tasks/fixtures.rake.
# They share the namespace with record and record_new defined below
# but are loaded from the file so the seeder code stays out of the
# Rakefile.
load File.expand_path("lib/tasks/fixtures.rake", __dir__)

namespace :fixtures do
  desc "Re-record all VCR cassettes against the staging API. Requires .env with ZAZU_STAGING_API_KEY."
  task record: %i[teardown seed] do
    # `seed` writes fresh IDs into .env. Re-load them here so the
    # spec child process picks up the new values, in case anything
    # in this Rake process already cached the old ones.
    require "dotenv"
    Dotenv.overload

    ENV["VCR_RECORD"] = "all"
    Rake::Task["spec"].invoke
  end

  desc "Add new cassettes only (existing ones play back as-is)."
  task :record_new do
    ENV["VCR_RECORD"] = "new_episodes"
    Rake::Task["spec"].invoke
  end

  desc "Pack committed cassettes into a release tarball at pkg/cassettes-vVERSION.tar.gz"
  task :pack do
    require "fileutils"
    require_relative "lib/zazu/version"

    out_dir = File.expand_path("pkg", __dir__)
    FileUtils.mkdir_p(out_dir)

    tarball = File.join(out_dir, "cassettes-v#{Zazu::VERSION}.tar.gz")
    cassette_dir = File.expand_path("spec/fixtures/cassettes", __dir__)

    if Dir.glob(File.join(cassette_dir, "**/*.yml")).empty?
      abort "No cassettes found in #{cassette_dir} — run `rake fixtures:record` first."
    end

    parent = File.dirname(cassette_dir).shellescape
    leaf = File.basename(cassette_dir).shellescape
    sh "tar -czf #{tarball.shellescape} -C #{parent} #{leaf}"
    puts "Packed #{tarball}"
  end
end
