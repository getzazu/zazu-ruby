# frozen_string_literal: true

module Zazu
  module Resources
    # The current entity (the tenant the API key belongs to).
    #
    #   client.entity.get  # => Zazu::Response
    class Entity < Base
      def get
        http_get("api/entity")
      end
    end
  end
end
