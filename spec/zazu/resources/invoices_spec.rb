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

  describe '#send_invoice', vcr: { cassette_name: 'invoices/send' } do
    it 'sends the invoice' do
      response = client.invoices.send_invoice(ENV.fetch('ZAZU_FIXTURE_SENDABLE_INVOICE_ID', 'fixture-invoice-id'))
      expect(response.success?).to be true
    end
  end

  describe '#mark_as_paid', vcr: { cassette_name: 'invoices/mark_as_paid' } do
    it 'marks an invoice as paid' do
      response = client.invoices.mark_as_paid(ENV.fetch('ZAZU_FIXTURE_PAYABLE_INVOICE_ID', 'fixture-invoice-id'))
      expect(response.success?).to be true
    end
  end

  describe '#cancel', vcr: { cassette_name: 'invoices/cancel' } do
    it 'cancels an invoice' do
      response = client.invoices.cancel(ENV.fetch('ZAZU_FIXTURE_CANCELLABLE_INVOICE_ID', 'fixture-invoice-id'))
      expect(response.success?).to be true
    end
  end

  describe '#credit_note', vcr: { cassette_name: 'invoices/credit_note' } do
    it 'creates a credit note' do
      response = client.invoices.credit_note(ENV.fetch('ZAZU_FIXTURE_CREDITABLE_INVOICE_ID', 'fixture-invoice-id'))
      expect(response.success?).to be true
    end
  end

  describe '#delete', vcr: { cassette_name: 'invoices/delete' } do
    it 'deletes an invoice' do
      response = client.invoices.delete(ENV.fetch('ZAZU_FIXTURE_DELETABLE_INVOICE_ID', 'fixture-invoice-id'))
      expect(response.status).to eq(204)
    end
  end

  describe '#create_payment_link', vcr: { cassette_name: 'invoices/create_payment_link' } do
    it 'creates a payment link for an invoice' do
      response = client.invoices.create_payment_link(
        ENV.fetch('ZAZU_FIXTURE_INVOICE_ID', 'fixture-invoice-id'),
        account_id: ENV.fetch('ZAZU_FIXTURE_ACCOUNT_ID', 'fixture-account-id')
      )
      expect(response.status).to eq(201)
    end
  end
end
