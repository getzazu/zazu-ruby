# frozen_string_literal: true

require "spec_helper"

RSpec.describe Zazu::Resources::TransferDrafts do
  let(:client) { zazu_client }

  describe "#create", vcr: { cassette_name: "transfer_drafts/create" } do
    it "creates a draft awaiting in-app approval" do
      response = client.transfer_drafts.create(
        account_id: fixture_id("ZAZU_FIXTURE_ACCOUNT_ID"),
        beneficiary_id: fixture_id("ZAZU_FIXTURE_BENEFICIARY_ID"),
        amount: "150.00",
        payment_reference: "SDK fixture"
      )

      expect(response.status).to eq(201)
      expect(response.body["status"]).to eq("requested")
      expect(response.body["transfer"]).to be_nil
    end
  end

  describe "#get", vcr: { cassette_name: "transfer_drafts/get" } do
    it "returns a single transfer draft" do
      response = client.transfer_drafts.get(fixture_id("ZAZU_FIXTURE_TRANSFER_DRAFT_ID"))

      expect(response.body["id"]).to be_a(String)
      expect(response.body).to have_key("status")
      expect(response.body).to have_key("transfer")
    end
  end
end
