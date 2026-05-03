# frozen_string_literal: true

module Zazu
  module Resources
    # Standalone payment links (not attached to an invoice).
    class PaymentLinks < Base
      # GET /api/payment_links
      def list(status: nil, link_type: nil, limit: MAX_PER_PAGE, cursor: nil)
        list_page(
          'api/payment_links',
          status: status,
          link_type: link_type,
          limit: limit,
          cursor: cursor
        )
      end

      # GET /api/payment_links/:id
      def get(id)
        super(encode_path('api/payment_links', id))
      end

      # POST /api/payment_links
      def create(**attributes)
        post('api/payment_links', body: attributes)
      end

      # POST /api/payment_links/:id/cancel
      def cancel(id)
        post(encode_path('api/payment_links', id, 'cancel'))
      end
    end
  end
end
