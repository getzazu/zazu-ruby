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
#   - List endpoints: non-fixture entries dropped from the response
#     so we don't ship real customer PII / live webhook URLs from the
#     staging entity into a public repo.
#   - Webhook signing_secret → "<WEBHOOK_SIGNING_SECRET>"
# Even if a developer pastes a real key into a test or pulls one
# from .env, the committed cassette is scrubbed.

require "json"

# Real fixture IDs from the developer's .env, used to identify which
# entries in a list-endpoint response are ours (i.e. seeded by
# `rake fixtures:seed`) vs anything else on the staging entity.
# Only ours survive cassette recording — everything else is real
# customer / invoice / webhook data and would leak PII to a public
# repo if committed.
FIXTURE_REAL_IDS = Zazu::SpecFixtures::IDS.keys.filter_map { |k| ENV.fetch(k, nil) }.reject(&:empty?).to_set

# VCR scrubber that removes non-fixture records from list-endpoint
# response bodies and strips `signing_secret` from webhook responses.
# Runs in a `before_record` hook (before the filter_sensitive_data
# replacements), so IDs are still real UUIDs at this point — that's
# why we compare against FIXTURE_REAL_IDS instead of placeholders.
def scrub_response_body!(interaction)
  body = interaction.response.body
  return unless body.is_a?(String) && !body.empty?

  parsed =
    begin
      JSON.parse(body)
    rescue JSON::ParserError
      nil
    end
  return if parsed.nil?

  changed = false

  if parsed.is_a?(Hash) && parsed["data"].is_a?(Array)
    kept = parsed["data"].select do |entry|
      next false unless entry.is_a?(Hash) && entry["id"].is_a?(String)

      FIXTURE_REAL_IDS.include?(entry["id"])
    end
    if kept.size != parsed["data"].size
      parsed["data"] = kept
      changed = true
    end
  end

  changed = true if scrub_signing_secret!(parsed)

  interaction.response.body = JSON.generate(parsed) if changed
end

# Recursively replace any `signing_secret` value with a placeholder.
# Returns true if anything was changed.
def scrub_signing_secret!(value)
  case value
  when Hash
    changed = false
    value.each do |k, v|
      if k == "signing_secret" && v.is_a?(String) && v != "<WEBHOOK_SIGNING_SECRET>"
        value[k] = "<WEBHOOK_SIGNING_SECRET>"
        changed = true
      elsif scrub_signing_secret!(v)
        changed = true
      end
    end
    changed
  when Array
    value.any? { |v| scrub_signing_secret!(v) }
  else
    false
  end
end

VCR.configure do |config|
  config.cassette_library_dir = File.expand_path("../fixtures/cassettes", __dir__)
  config.hook_into :webmock
  config.configure_rspec_metadata!

  # Drop non-fixture records from list responses + redact webhook
  # signing secrets before VCR writes the cassette to disk.
  config.before_record do |interaction|
    scrub_response_body!(interaction)
  end

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

  # Scrub fixture IDs out of URLs and bodies so cassettes replay
  # deterministically on machines without an .env (CI, contributors).
  # The placeholder must match the spec's `ENV.fetch` fallback exactly
  # — see spec/support/fixture_ids.rb for the canonical table.
  Zazu::SpecFixtures::IDS.each do |env_var, placeholder|
    real = ENV.fetch(env_var, nil)
    next if real.nil? || real.empty?

    config.filter_sensitive_data(placeholder) { real }
  end
end
