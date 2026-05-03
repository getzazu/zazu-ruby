# frozen_string_literal: true

# Rake tasks that seed the staging entity with the records needed to
# record VCR cassettes for the spec suite. The tasks are designed to
# be run in this order on first-time setup:
#
#   bundle exec rake fixtures:teardown   # clean any prior fixtures
#   bundle exec rake fixtures:seed       # create fresh ones; prints .env IDs
#   # paste the printed IDs into .env
#   bundle exec rake fixtures:record     # re-record cassettes
#
# All seeded records carry the FIXTURE_TAG marker in a structural
# field (`company_name` for customers, `description` for webhook
# endpoints, etc.) so teardown can find and delete them on a future
# run. Re-running `seed` with stale fixtures present will exit with
# an error pointing at teardown.
#
# Requires .env with:
#   ZAZU_STAGING_API_KEY  — must have read+write scopes for every
#                            resource we seed (customers, invoices,
#                            payment_links, webhook_endpoints).
#   ZAZU_STAGING_URL       — usually https://staging.zazu.ma.
#   ZAZU_FIXTURE_ACCOUNT_ID — must be a real account in the entity
#                              the API key belongs to. The seed
#                              cannot create accounts (that's a
#                              banking-side operation), so this one
#                              ID has to come from outside.

require 'dotenv/load'

# All seeding logic lives in the namespace below. Kept inline rather
# than pulled into lib/zazu/* because this is purely a development
# tool — it has no place in the gem itself.
module Fixtures
  # rubocop:disable Metrics/ClassLength
  class Seeder
    # Marker baked into every seeded record so teardown can find them.
    FIXTURE_TAG = 'zazu-ruby-fixture'
    FIXTURE_VERSION = '1' # bump when seed shape changes meaningfully

    REQUIRED_ENV = %w[ZAZU_STAGING_API_KEY ZAZU_STAGING_URL ZAZU_FIXTURE_ACCOUNT_ID].freeze

    # Keys we will print to stdout, in .env-paste-ready order.
    #
    # Note: invoice state-transition fixtures (sendable, payable,
    # cancellable, creditable) are not seeded here because the
    # public API does not expose the `pending_approval → approved`
    # transition. Without that, send/mark_as_paid/cancel/credit_note
    # cannot be exercised in v0.1.0. Cassettes for those land in a
    # later release once the API surfaces an approve endpoint or we
    # build a Rails-side helper that approves fixture invoices.
    EMITTED_KEYS = %w[
      ZAZU_FIXTURE_CUSTOMER_ID
      ZAZU_FIXTURE_DELETABLE_CUSTOMER_ID
      ZAZU_FIXTURE_INVOICE_ID
      ZAZU_FIXTURE_DELETABLE_INVOICE_ID
      ZAZU_FIXTURE_PAYMENT_LINK_ID
      ZAZU_FIXTURE_CANCELLABLE_PAYMENT_LINK_ID
      ZAZU_FIXTURE_WEBHOOK_ID
      ZAZU_FIXTURE_ENABLED_WEBHOOK_ID
      ZAZU_FIXTURE_DISABLED_WEBHOOK_ID
      ZAZU_FIXTURE_DELETABLE_WEBHOOK_ID
    ].freeze

    def initialize
      check_env!
      $LOAD_PATH.unshift(File.expand_path('../..', __dir__))
      require 'zazu'
      @client = Zazu::Client.new(
        api_key: ENV.fetch('ZAZU_STAGING_API_KEY'),
        base_url: ENV.fetch('ZAZU_STAGING_URL')
      )
      @account_id = ENV.fetch('ZAZU_FIXTURE_ACCOUNT_ID')
      @ids = {}
    end

    def run!
      log 'Checking for stale fixtures…'
      stale = find_stale_fixtures
      total_stale = stale.values.sum(&:size)
      if total_stale.positive?
        warn '!! Existing fixture records found on staging. Run `rake fixtures:teardown` first:'
        stale.each { |kind, items| warn "    #{kind}: #{items.size} record(s)" if items.any? }
        exit 1
      end

      log 'Seeding customers…'
      seed_customers!

      log 'Seeding invoices…'
      seed_invoices!

      log 'Seeding payment links…'
      seed_payment_links!

      log 'Seeding webhook endpoints…'
      seed_webhook_endpoints!

      emit_env_block
    end

    def teardown!
      log 'Looking up existing fixtures to delete…'
      stale = find_stale_fixtures
      total = stale.values.sum(&:size)

      if total.zero?
        log 'No fixtures to delete. Nothing to do.'
        return
      end

      log "Deleting #{total} fixture record(s)…"

      # Delete in dependency order: webhook endpoints, payment links,
      # invoices (which deletes invoice items), then customers.
      delete_each(stale[:webhook_endpoints]) { |id| @client.webhook_endpoints.delete(id) }
      delete_each(stale[:payment_links])     { |id| try_cancel_payment_link(id) }
      delete_each(stale[:invoices])          { |id| try_delete_invoice(id) }
      delete_each(stale[:customers])         { |id| try_delete_customer(id) }

      log 'Teardown complete.'
    end

    private

    def check_env!
      missing = REQUIRED_ENV.select { |k| ENV.fetch(k, '').empty? }
      return if missing.empty?

      warn "Missing required env vars: #{missing.join(', ')}"
      warn 'Copy .env.example to .env and fill in the values.'
      exit 1
    end

    def log(msg)
      warn "[fixtures] #{msg}"
    end

    def fixture_marker(suffix = nil)
      [FIXTURE_TAG, "v#{FIXTURE_VERSION}", suffix].compact.join('-')
    end

    # --- Seed steps ---------------------------------------------------------

    def seed_customers!
      @ids['ZAZU_FIXTURE_CUSTOMER_ID'] = create_customer!('primary').body['id']
      @ids['ZAZU_FIXTURE_DELETABLE_CUSTOMER_ID'] = create_customer!('deletable').body['id']
    end

    def create_customer!(suffix)
      @client.customers.create(
        customer_type: 'business',
        company_name: "Zazu Fixture Co — #{suffix} (#{fixture_marker})",
        email: "fixture-#{suffix}-#{SecureRandom.hex(4)}@example.com",
        ice_number: random_ice_number
      )
    end

    def seed_invoices!
      customer_id = @ids.fetch('ZAZU_FIXTURE_CUSTOMER_ID')

      # Two invoices in the API's default starting state
      # (`pending_approval`): one for read-only specs (list/get/
      # update), one earmarked for the delete spec.
      #
      # The send/mark_as_paid/cancel/credit_note specs need invoices
      # in the `approved` and `sent` states, which the public API
      # cannot transition into. Those specs are skipped in v0.1.0.
      drafts = Array.new(2) { |i| create_draft_invoice!(customer_id, i) }

      @ids['ZAZU_FIXTURE_INVOICE_ID'] = drafts[0]
      @ids['ZAZU_FIXTURE_DELETABLE_INVOICE_ID'] = drafts[1]
    end

    def create_draft_invoice!(customer_id, idx)
      response = @client.invoices.create(
        customer_id: customer_id,
        currency_code: 'MAD',
        issue_date: Date.today.iso8601,
        due_date: (Date.today + 30).iso8601,
        reference: fixture_marker("inv-#{idx}"),
        notes: "[#{FIXTURE_TAG}] draft #{idx}",
        items: [
          { description: 'Zazu fixture line item', quantity: 1, unit_price: '100.00' }
        ]
      )
      response.body['id']
    end

    def seed_payment_links!
      @ids['ZAZU_FIXTURE_PAYMENT_LINK_ID'] = create_payment_link!('primary')
      @ids['ZAZU_FIXTURE_CANCELLABLE_PAYMENT_LINK_ID'] = create_payment_link!('cancellable')
    end

    def create_payment_link!(suffix)
      response = @client.payment_links.create(
        account_id: @account_id,
        amount: '100.00',
        title: "Zazu Fixture — #{suffix}",
        description: "[#{FIXTURE_TAG}] #{suffix}",
        payment_reference: "fixture-#{suffix}-#{SecureRandom.hex(4)}",
        link_type: 'single'
      )
      response.body['id']
    end

    def seed_webhook_endpoints!
      @ids['ZAZU_FIXTURE_WEBHOOK_ID'] = create_webhook_endpoint!('primary')
      @ids['ZAZU_FIXTURE_ENABLED_WEBHOOK_ID'] = create_webhook_endpoint!('enabled')

      # disabled: create then disable.
      disabled_id = create_webhook_endpoint!('disabled')
      @client.webhook_endpoints.disable(disabled_id)
      @ids['ZAZU_FIXTURE_DISABLED_WEBHOOK_ID'] = disabled_id

      @ids['ZAZU_FIXTURE_DELETABLE_WEBHOOK_ID'] = create_webhook_endpoint!('deletable')
    end

    def create_webhook_endpoint!(suffix)
      response = @client.webhook_endpoints.create(
        url: "https://example.com/zazu-fixture-#{suffix}-#{SecureRandom.hex(4)}",
        events: ['payment_link.paid'],
        description: "[#{FIXTURE_TAG}] #{suffix}"
      )
      response.body['id']
    end

    # --- Teardown steps -----------------------------------------------------

    # Returns { customers: [ids], invoices: [ids], ... } of fixture-tagged records.
    def find_stale_fixtures
      {
        customers: stale_customers,
        invoices: stale_invoices,
        payment_links: stale_payment_links,
        webhook_endpoints: stale_webhook_endpoints
      }
    end

    def stale_customers
      stale_records(@client.customers) { |c| fixture_record?(c['company_name']) }
    end

    def stale_invoices
      stale_records(@client.invoices) do |i|
        fixture_record?(i['reference']) || fixture_record?(i.dig('customer', 'name'))
      end
    end

    def stale_payment_links
      stale_records(@client.payment_links) do |pl|
        fixture_record?(pl['title']) || fixture_record?(pl['description'])
      end
    end

    def stale_webhook_endpoints
      stale_records(@client.webhook_endpoints) do |w|
        fixture_record?(w['description']) || fixture_record?(w['url'])
      end
    end

    def stale_records(resource, &)
      matching = list_all(resource).select(&)
      matching.map { |r| r['id'] }
    end

    def fixture_record?(value)
      value.to_s.include?(FIXTURE_TAG)
    end

    # Walks every page of a list endpoint up to a sane safety cap.
    # Stops at 10 pages (1000 records) so a runaway entity never
    # blocks the seed forever.
    def list_all(resource)
      results = []
      page = resource.list(limit: 100)
      pages_seen = 0
      while page && pages_seen < 10
        results.concat(page.data)
        pages_seen += 1
        page = page.next
      end
      results
    end

    def delete_each(ids)
      return if ids.nil? || ids.empty?

      ids.each do |id|
        yield(id)
        log "  ✓ deleted #{id}"
      rescue Zazu::Error => e
        log "  ! failed to delete #{id}: #{e.class.name.split('::').last}: #{e.message}"
      end
    end

    def try_delete_customer(id)
      @client.customers.delete(id)
    rescue Zazu::ValidationError => e
      # Customers with invoices cannot be hard-deleted. Surface the
      # constraint and move on.
      log "  - customer #{id}: #{e.message}"
    end

    def try_delete_invoice(id)
      # Only draft invoices can be deleted via the API. Sent/paid
      # ones stay around — the next seed run will create fresh drafts
      # and the lingering sent/paid ones will be rediscovered as
      # "stale" on the next teardown.
      @client.invoices.delete(id)
    rescue Zazu::ValidationError, Zazu::ForbiddenError => e
      log "  - invoice #{id}: #{e.message} (cancelling instead)"
      @client.invoices.cancel(id)
    end

    def try_cancel_payment_link(id)
      @client.payment_links.cancel(id)
    rescue Zazu::Error => e
      log "  - payment link #{id}: #{e.message}"
    end

    # --- Output -------------------------------------------------------------

    def emit_env_block
      missing = EMITTED_KEYS.reject { |k| @ids.key?(k) }
      unless missing.empty?
        warn "::error:: Seed completed but #{missing.size} ID(s) missing: #{missing.join(', ')}"
        exit 1
      end

      puts
      puts '# Paste the lines below into .env (or copy from above with values intact).'
      puts '# These IDs are stable until you run `rake fixtures:teardown`.'
      puts
      EMITTED_KEYS.each do |k|
        puts "#{k}=#{@ids.fetch(k)}"
      end
      puts
    end

    def random_ice_number
      # MA market requires 15 digits when business + ice_number is
      # present. We always send exactly 15 digits to keep validation
      # happy across markets.
      Array.new(15) { rand(10) }.join
    end
  end
  # rubocop:enable Metrics/ClassLength
end

namespace :fixtures do
  desc 'Create fixture records on staging and print .env-paste-ready IDs'
  task :seed do
    Fixtures::Seeder.new.run!
  end

  desc 'Delete every fixture record previously created on staging by this seed'
  task :teardown do
    Fixtures::Seeder.new.teardown!
  end
end
