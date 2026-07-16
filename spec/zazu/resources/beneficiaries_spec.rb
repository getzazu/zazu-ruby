# frozen_string_literal: true

require "spec_helper"

RSpec.describe Zazu::Resources::Beneficiaries do
  let(:client) { zazu_client }

  describe "#list", vcr: { cassette_name: "beneficiaries/list" } do
    it "returns a Page of beneficiaries with their bank accounts" do
      page = client.beneficiaries.list

      expect(page).to be_a(Zazu::Page)
      expect(page.data.first["external_accounts"]).to be_an(Array)
    end
  end

  describe "#get", vcr: { cassette_name: "beneficiaries/get" } do
    it "returns a single beneficiary" do
      response = client.beneficiaries.get(fixture_id("ZAZU_FIXTURE_BENEFICIARY_ID"))

      expect(response.body["id"]).to be_a(String)
      expect(response.body["external_accounts"]).to be_an(Array)
    end
  end
end
