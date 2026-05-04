# frozen_string_literal: true

# Tiny test-side helper. Wires a Zazu::Client up to the staging
# base URL with whatever API key is in ENV. During cassette playback
# the key value doesn't matter (it's scrubbed in cassettes anyway);
# during recording, it has to be a real staging key.
module ClientHelpers
  STAGING_BASE_URL = "https://staging.zazu.ma"

  def zazu_client(**overrides)
    Zazu::Client.new(
      api_key: ENV.fetch("ZAZU_STAGING_API_KEY", "test-key-only-used-during-recording"),
      base_url: ENV.fetch("ZAZU_STAGING_URL", STAGING_BASE_URL),
      **overrides
    )
  end
end
