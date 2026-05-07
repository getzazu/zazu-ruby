# frozen_string_literal: true

module Zazu
  module Resources
    # One-off hosted checkout sessions. Pre-API there's no list,
    # update, or delete — sessions are created and inspected by id.
    # State (`open`, `processing`, `complete`, `expired`) transitions
    # are read-only from the SDK's perspective.
    class CheckoutSessions < Base
      # GET /api/checkout_sessions/:id
      def get(id)
        http_get(encode_path("api/checkout_sessions", id))
      end

      # POST /api/checkout_sessions
      #
      # @param attributes [Hash] checkout-session attributes — see API docs.
      #   Required: account_id, amount, success_url.
      #   Optional: metadata, customer_email, cancel_url, description, expires_at.
      def create(**attributes)
        http_post("api/checkout_sessions", body: attributes)
      end
    end
  end
end
