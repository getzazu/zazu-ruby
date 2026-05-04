# frozen_string_literal: true

require "rspec/core/rake_task"
require "rubocop/rake_task"

RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new

task default: %i[spec rubocop]

desc "Build gem and verify contents"
task :build do
  sh("gem build zazu.gemspec --strict")
  gem_file = Dir["zazu-*.gem"].first
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

  # Step 0: Force cleanup — delete existing release and tag
  if force
    header "Force cleanup"
    if system("gh release view #{tag} >/dev/null 2>&1")
      sh("gh release delete #{tag} --yes --cleanup-tag")
      success "Deleted release and remote tag #{tag}"
    else
      skip "No release #{tag} to delete"
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
  sh("gem build zazu.gemspec --strict")
  sh("rm -f zazu-*.gem")
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
  release_exists = system("gh release view #{tag} >/dev/null 2>&1")

  if release_exists
    skip "Release #{tag} already exists (use force to re-create)"
  elsif tag_exists
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
