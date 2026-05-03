# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Zazu::Resources::Invoices do
  let(:client) { zazu_client }

  describe '#list', vcr: { cassette_name: 'invoices/list' } do
    it 'returns a Page' do
      page = client.invoices.list
      expect(page).to be_a(Zazu::Page)
    end
  end

  describe '#get', vcr: { cassette_name: 'invoices/get' } do
    it 'returns a single invoice' do
      response = client.invoices.get(ENV.fetch('ZAZU_FIXTURE_INVOICE_ID', 'fixture-invoice-id'))
      expect(response.body['id']).to be_a(String)
    end
  end

  describe '#create', vcr: { cassette_name: 'invoices/create' } do
    it 'creates an invoice' do
      response = client.invoices.create(
        customer_id: ENV.fetch('ZAZU_FIXTURE_CUSTOMER_ID', 'fixture-customer-id'),
        currency_code: 'MAD',
        issue_date: '2026-05-03',
        due_date: '2026-06-03',
        items: [
          { description: 'SDK fixture line', quantity: 1, unit_price: '100.00' }
        ]
      )
      expect(response.status).to eq(201)
    end
  end

  describe '#update', vcr: { cassette_name: 'invoices/update' } do
    it 'updates an invoice' do
      response = client.invoices.update(
        ENV.fetch('ZAZU_FIXTURE_INVOICE_ID', 'fixture-invoice-id'),
        notes: 'updated by SDK fixture spec'
      )
      expect(response.status).to eq(200)
    end
  end

  # The state-transition specs (send/mark_as_paid/cancel/
  # credit_note/create_payment_link) need an invoice in the
  # `approved` state. The public API does not currently expose a
  # transition into that state — the back-office UI is the only
  # path. These specs are pending and will be enabled once the API
  # surfaces an approve endpoint or we add an admin-side helper.
  describe '#send_invoice', skip: 'pending API approve endpoint' do
    it 'sends the invoice'
  end

  describe '#mark_as_paid', skip: 'pending API approve endpoint' do
    it 'marks an invoice as paid'
  end

  describe '#cancel', skip: 'pending API approve endpoint' do
    it 'cancels an invoice'
  end

  describe '#credit_note', skip: 'pending API approve endpoint' do
    it 'creates a credit note'
  end

  describe '#delete', vcr: { cassette_name: 'invoices/delete' } do
    it 'deletes an invoice' do
      response = client.invoices.delete(ENV.fetch('ZAZU_FIXTURE_DELETABLE_INVOICE_ID', 'fixture-invoice-id'))
      expect(response.status).to eq(204)
    end
  end

  describe '#create_payment_link', skip: 'pending API approve endpoint' do
    it 'creates a payment link for an invoice'
  end
end
