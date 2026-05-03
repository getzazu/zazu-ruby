# frozen_string_literal: true

module Zazu
  module Resources
    # Invoices and their lifecycle actions.
    class Invoices < Base
      # GET /api/invoices
      def list(status: nil, customer_id: nil, limit: MAX_PER_PAGE, cursor: nil)
        list_page(
          'api/invoices',
          status: status,
          customer_id: customer_id,
          limit: limit,
          cursor: cursor
        )
      end

      # GET /api/invoices/:id
      def get(id)
        super(encode_path('api/invoices', id))
      end

      # POST /api/invoices
      def create(**attributes)
        post('api/invoices', body: attributes)
      end

      # PATCH /api/invoices/:id
      def update(id, **attributes)
        patch(encode_path('api/invoices', id), body: attributes)
      end

      # POST /api/invoices/:id/send
      def send_invoice(id)
        post(encode_path('api/invoices', id, 'send'))
      end

      # POST /api/invoices/:id/mark_as_paid
      def mark_as_paid(id)
        post(encode_path('api/invoices', id, 'mark_as_paid'))
      end

      # POST /api/invoices/:id/cancel
      def cancel(id)
        post(encode_path('api/invoices', id, 'cancel'))
      end

      # POST /api/invoices/:id/credit_note
      def credit_note(id)
        post(encode_path('api/invoices', id, 'credit_note'))
      end

      # DELETE /api/invoices/:id
      def delete(id)
        super(encode_path('api/invoices', id))
      end

      # POST /api/invoices/:invoice_id/payment_link
      #
      # @param account_id [String] the funding account for the link
      def create_payment_link(invoice_id, account_id:)
        post(
          encode_path('api/invoices', invoice_id, 'payment_link'),
          body: { account_id: account_id }
        )
      end
    end
  end
end
