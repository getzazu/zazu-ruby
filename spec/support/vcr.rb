# frozen_string_literal: true

# VCR configuration. Cassettes live in spec/fixtures/cassettes/
# and are committed to the repo. Each release ships them as a
# tarball release asset so other-language SDKs can reuse the same
# canonical interaction record.
#
# Recording:
#   - Default mode is :none — CI and local runs play back cassettes
#     and fail loudly on any unexpected HTTP request.
#   - Set VCR_RECORD=all or VCR_RECORD=new_episodes to refresh.
#     Common usage: `bundle exec rake fixtures:record` which sets
#     VCR_RECORD=all and runs the entire spec suite.
#
# Sensitive data is filtered before cassettes hit disk:
#   - Authorization bearer tokens → "<ZAZU_API_KEY>"
#   - X-Request-Id response headers → "<REQUEST_ID>"
#   - Zazu-Version response headers → "<ZAZU_VERSION>"
# Even if a developer pastes a real key into a test or pulls one
# from .env, the committed cassette is scrubbed.

VCR.configure do |config|
  config.cassette_library_dir = File.expand_path("../fixtures/cassettes", __dir__)
  config.hook_into :webmock
  config.configure_rspec_metadata!

  config.default_cassette_options = {
    record: :none,
    match_requests_on: %i[method uri body],
    serialize_with: :yaml
  }

  if ENV["VCR_RECORD"]
    record_mode = ENV["VCR_RECORD"].to_sym
    config.default_cassette_options[:record] = record_mode

    # When recording, allow real HTTP through WebMock.
    WebMock.allow_net_connect!
  end

  # Scrubbers — run on every interaction before write.
  config.filter_sensitive_data("<ZAZU_API_KEY>") do |interaction|
    auth = interaction.request.headers["Authorization"]
    next nil unless auth.is_a?(Array) && auth.first

    auth.first.delete_prefix("Bearer ")
  end

  config.filter_sensitive_data("<REQUEST_ID>") do |interaction|
    interaction.response.headers["X-Request-Id"]&.first
  end

  config.filter_sensitive_data("<ZAZU_VERSION>") do |interaction|
    interaction.response.headers["Zazu-Version"]&.first
  end
end
