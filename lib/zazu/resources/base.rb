# frozen_string_literal: true

module Zazu
  module Resources
    # Shared scaffolding for every resource module. Carries a back-
    # reference to the client and exposes thin `get/post/patch/delete`
    # helpers that delegate to {Zazu::Client#request}.
    #
    # Pagination:
    #
    #   Every resource that has a list endpoint exposes `#list` which
    #   returns a {Zazu::Page}. Callers can walk pages explicitly via
    #   `page.next` or use `each_page` for capped iteration.
    class Base
      MAX_PER_PAGE = Page::MAX_PER_PAGE

      attr_reader :client

      def initialize(client)
        @client = client
      end

      private

      def get(path, params: nil)
        client.request(:get, path, params: params)
      end

      def post(path, body: nil)
        client.request(:post, path, body: body)
      end

      def patch(path, body: nil)
        client.request(:patch, path, body: body)
      end

      def delete(path)
        client.request(:delete, path)
      end

      # Builds a paginated list. `path` is the collection endpoint;
      # `params` is everything else (filters, etc.). `limit` is enforced
      # at MAX_PER_PAGE; the caller can pass `cursor:` to fetch a
      # specific page.
      def list_page(path, limit: MAX_PER_PAGE, cursor: nil, **params)
        validated_limit = validate_limit!(limit)

        fetcher = lambda { |next_cursor|
          query = params.merge(limit: validated_limit, cursor: next_cursor).compact
          response = get(path, params: query)
          Page.new(response, fetcher: fetcher)
        }

        initial_query = params.merge(limit: validated_limit, cursor: cursor).compact
        response = get(path, params: initial_query)
        Page.new(response, fetcher: fetcher)
      end

      # Iterates list-endpoint records up to `max_items`, fetching
      # additional pages on demand. Caps ensure callers never
      # accidentally pull a full table.
      #
      # Pass either a block or get an Enumerator back.
      def each_page_record(path, max_items:, **params, &block)
        return enum_for(:each_page_record, path, max_items: max_items, **params) unless block

        unless max_items.is_a?(Integer) && max_items.positive?
          raise ArgumentError,
                'max_items must be a positive integer'
        end

        seen = 0
        page = list_page(path, **params)

        loop do
          page.data.each do |record|
            return seen if seen >= max_items

            yield record
            seen += 1
          end

          break unless page.has_more && seen < max_items

          page = page.next
          break if page.nil?
        end

        seen
      end

      def validate_limit!(limit)
        return MAX_PER_PAGE if limit.nil?

        unless limit.is_a?(Integer) && limit.positive?
          raise Zazu::ArgumentError, "limit must be a positive integer (got #{limit.inspect})"
        end

        raise Zazu::ArgumentError, "limit cannot exceed #{MAX_PER_PAGE} (got #{limit})" if limit > MAX_PER_PAGE

        limit
      end

      def encode_path(*segments)
        segments.map { |s| ERB::Util.url_encode(s.to_s) }.join('/')
      end
    end
  end
end
