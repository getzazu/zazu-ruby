# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Zazu::Resources::WebhookEndpoints do
  let(:client) { zazu_client }

  describe '#list', vcr: { cassette_name: 'webhook_endpoints/list' } do
    it 'returns a Page' do
      page = client.webhook_endpoints.list
      expect(page).to be_a(Zazu::Page)
    end
  end

  describe '#get', vcr: { cassette_name: 'webhook_endpoints/get' } do
    it 'returns a single webhook endpoint' do
      response = client.webhook_endpoints.get(
        ENV.fetch('ZAZU_FIXTURE_WEBHOOK_ID', 'fixture-webhook-id')
      )
      expect(response.body['id']).to be_a(String)
    end
  end

  describe '#create', vcr: { cassette_name: 'webhook_endpoints/create' } do
    it 'creates a webhook endpoint' do
      response = client.webhook_endpoints.create(
        url: 'https://example.com/zazu-webhooks',
        events: ['payment_link.paid'],
        description: 'SDK fixture endpoint'
      )
      expect(response.status).to eq(201)
    end
  end

  describe '#update', vcr: { cassette_name: 'webhook_endpoints/update' } do
    it 'updates a webhook endpoint' do
      response = client.webhook_endpoints.update(
        ENV.fetch('ZAZU_FIXTURE_WEBHOOK_ID', 'fixture-webhook-id'),
        description: 'Updated description'
      )
      expect(response.success?).to be true
    end
  end

  describe '#delete', vcr: { cassette_name: 'webhook_endpoints/delete' } do
    it 'deletes a webhook endpoint' do
      response = client.webhook_endpoints.delete(
        ENV.fetch('ZAZU_FIXTURE_DELETABLE_WEBHOOK_ID', 'fixture-webhook-id')
      )
      expect(response.status).to eq(204)
    end
  end

  describe '#test_endpoint', vcr: { cassette_name: 'webhook_endpoints/test' } do
    it 'fires a test event' do
      response = client.webhook_endpoints.test_endpoint(
        ENV.fetch('ZAZU_FIXTURE_WEBHOOK_ID', 'fixture-webhook-id')
      )
      expect(response.success?).to be true
    end
  end

  describe '#regenerate_secret', vcr: { cassette_name: 'webhook_endpoints/regenerate_secret' } do
    it 'rotates the webhook secret' do
      response = client.webhook_endpoints.regenerate_secret(
        ENV.fetch('ZAZU_FIXTURE_WEBHOOK_ID', 'fixture-webhook-id')
      )
      expect(response.success?).to be true
    end
  end

  describe '#enable', vcr: { cassette_name: 'webhook_endpoints/enable' } do
    it 'enables an endpoint' do
      response = client.webhook_endpoints.enable(
        ENV.fetch('ZAZU_FIXTURE_DISABLED_WEBHOOK_ID', 'fixture-webhook-id')
      )
      expect(response.success?).to be true
    end
  end

  describe '#disable', vcr: { cassette_name: 'webhook_endpoints/disable' } do
    it 'disables an endpoint' do
      response = client.webhook_endpoints.disable(
        ENV.fetch('ZAZU_FIXTURE_ENABLED_WEBHOOK_ID', 'fixture-webhook-id')
      )
      expect(response.success?).to be true
    end
  end
end
