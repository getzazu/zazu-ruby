# frozen_string_literal: true

require "spec_helper"

RSpec.describe Zazu::Resources::Customers do
  let(:client) { zazu_client }

  describe "#list", vcr: { cassette_name: "customers/list" } do
    it "returns a Page of customers" do
      page = client.customers.list
      expect(page).to be_a(Zazu::Page)
    end
  end

  describe "#list with q filter", vcr: { cassette_name: "customers/list_q_filtered" } do
    it "passes q through" do
      page = client.customers.list(q: "Acme")
      expect(page).to be_a(Zazu::Page)
    end
  end

  describe "#get", vcr: { cassette_name: "customers/get" } do
    it "returns a single customer" do
      response = client.customers.get(ENV.fetch("ZAZU_FIXTURE_CUSTOMER_ID", "fixture-customer-id"))
      expect(response.body["id"]).to be_a(String)
    end
  end

  describe "#create", vcr: { cassette_name: "customers/create" } do
    it "creates a customer" do
      response = client.customers.create(
        customer_type: "business",
        company_name: "Zazu SDK Fixture Co (zazu-ruby-fixture-v1-spec)",
        email: "create-spec@zazu-ruby-fixture.example.com",
        ice_number: "000000000000000"
      )
      expect(response.status).to eq(201)
      expect(response.body["id"]).to be_a(String)
    end
  end

  describe "#update", vcr: { cassette_name: "customers/update" } do
    it "updates a customer" do
      response = client.customers.update(
        ENV.fetch("ZAZU_FIXTURE_CUSTOMER_ID", "fixture-customer-id"),
        email: "updated@example.com"
      )
      expect(response.status).to eq(200)
    end
  end

  describe "#delete", vcr: { cassette_name: "customers/delete" } do
    it "deletes a customer" do
      response = client.customers.delete(ENV.fetch("ZAZU_FIXTURE_DELETABLE_CUSTOMER_ID", "fixture-customer-id"))
      expect(response.status).to eq(204)
    end
  end
end
