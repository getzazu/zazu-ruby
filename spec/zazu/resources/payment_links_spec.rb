# frozen_string_literal: true

require "spec_helper"

RSpec.describe Zazu::Resources::PaymentLinks do
  let(:client) { zazu_client }

  describe "#list", vcr: { cassette_name: "payment_links/list" } do
    it "returns a Page" do
      page = client.payment_links.list
      expect(page).to be_a(Zazu::Page)
    end
  end

  describe "#get", vcr: { cassette_name: "payment_links/get" } do
    it "returns a single payment link" do
      response = client.payment_links.get(ENV.fetch("ZAZU_FIXTURE_PAYMENT_LINK_ID", "fixture-payment-link-id"))
      expect(response.body["id"]).to be_a(String)
    end
  end

  describe "#create", vcr: { cassette_name: "payment_links/create" } do
    it "creates a payment link" do
      response = client.payment_links.create(
        account_id: ENV.fetch("ZAZU_FIXTURE_ACCOUNT_ID", "fixture-account-id"),
        amount: "100.00",
        title: "SDK fixture",
        description: "Created by zazu-ruby fixture spec",
        link_type: "single"
      )
      expect(response.status).to eq(201)
    end
  end

  describe "#cancel", vcr: { cassette_name: "payment_links/cancel" } do
    it "cancels a payment link" do
      response = client.payment_links.cancel(
        ENV.fetch("ZAZU_FIXTURE_CANCELLABLE_PAYMENT_LINK_ID", "fixture-payment-link-id")
      )
      expect(response.success?).to be true
    end
  end
end
