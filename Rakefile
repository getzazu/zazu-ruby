# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'

RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new

task default: %i[spec rubocop]

# fixtures:seed and fixtures:teardown live in lib/tasks/fixtures.rake.
# They share the namespace with record and record_new defined below
# but are loaded from the file so the seeder code stays out of the
# Rakefile.
load File.expand_path('lib/tasks/fixtures.rake', __dir__)

namespace :fixtures do
  desc 'Re-record all VCR cassettes against the staging API. Requires .env with ZAZU_STAGING_API_KEY.'
  task :record do
    ENV['VCR_RECORD'] = 'all'
    Rake::Task['spec'].invoke
  end

  desc 'Add new cassettes only (existing ones play back as-is).'
  task :record_new do
    ENV['VCR_RECORD'] = 'new_episodes'
    Rake::Task['spec'].invoke
  end

  desc 'Pack committed cassettes into a release tarball at pkg/cassettes-vVERSION.tar.gz'
  task :pack do
    require 'fileutils'
    require_relative 'lib/zazu/version'

    out_dir = File.expand_path('pkg', __dir__)
    FileUtils.mkdir_p(out_dir)

    tarball = File.join(out_dir, "cassettes-v#{Zazu::VERSION}.tar.gz")
    cassette_dir = File.expand_path('spec/fixtures/cassettes', __dir__)

    if Dir.glob(File.join(cassette_dir, '**/*.yml')).empty?
      abort "No cassettes found in #{cassette_dir} — run `rake fixtures:record` first."
    end

    parent = File.dirname(cassette_dir).shellescape
    leaf = File.basename(cassette_dir).shellescape
    sh "tar -czf #{tarball.shellescape} -C #{parent} #{leaf}"
    puts "Packed #{tarball}"
  end
end
