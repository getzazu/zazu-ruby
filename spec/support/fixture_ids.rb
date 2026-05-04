# frozen_string_literal: true

# Canonical mapping of fixture env vars → cassette placeholders.
#
# When recording, VCR scrubs `ENV[env_var]` to the placeholder before
# writing the cassette. When replaying, specs call `fixture_id(env_var)`
# which returns the placeholder when the env var is unset (CI) or the
# real ID when it is set (a developer recording a fresh cassette).
#
# Both halves use the same table so they can never drift.
module Zazu
  module SpecFixtures
    IDS = {
      "ZAZU_FIXTURE_ACCOUNT_ID" => "fixture-account-id",
      "ZAZU_FIXTURE_TRANSACTION_ID" => "fixture-transaction-id",
      "ZAZU_FIXTURE_CUSTOMER_ID" => "fixture-customer-id",
      "ZAZU_FIXTURE_DELETABLE_CUSTOMER_ID" => "fixture-deletable-customer-id",
      "ZAZU_FIXTURE_INVOICE_ID" => "fixture-invoice-id",
      "ZAZU_FIXTURE_DELETABLE_INVOICE_ID" => "fixture-deletable-invoice-id",
      "ZAZU_FIXTURE_PAYMENT_LINK_ID" => "fixture-payment-link-id",
      "ZAZU_FIXTURE_CANCELLABLE_PAYMENT_LINK_ID" => "fixture-cancellable-payment-link-id",
      "ZAZU_FIXTURE_WEBHOOK_ID" => "fixture-webhook-id",
      "ZAZU_FIXTURE_ENABLED_WEBHOOK_ID" => "fixture-enabled-webhook-id",
      "ZAZU_FIXTURE_DISABLED_WEBHOOK_ID" => "fixture-disabled-webhook-id",
      "ZAZU_FIXTURE_DELETABLE_WEBHOOK_ID" => "fixture-deletable-webhook-id"
    }.freeze

    def fixture_id(env_var)
      placeholder = IDS.fetch(env_var) do
        raise ArgumentError, "Unknown fixture env var: #{env_var}. Add it to Zazu::SpecFixtures::IDS."
      end

      ENV.fetch(env_var, placeholder)
    end

    module_function :fixture_id
  end
end
