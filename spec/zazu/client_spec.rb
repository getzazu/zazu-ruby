# frozen_string_literal: true

require "spec_helper"

RSpec.describe Zazu::Client do
  describe ".new" do
    it "raises ConfigurationError when api_key is missing" do
      expect { described_class.new(api_key: nil) }
        .to raise_error(Zazu::ConfigurationError, /Missing api_key/)
    end

    it "raises ConfigurationError when api_key is empty" do
      expect { described_class.new(api_key: "") }
        .to raise_error(Zazu::ConfigurationError, /Missing api_key/)
    end

    it "strips trailing slash from base_url" do
      client = described_class.new(api_key: "k", base_url: "https://api.zazu.ma/")
      expect(client.base_url).to eq("https://api.zazu.ma")
    end

    it "defaults base_url to https://zazu.ma" do
      client = described_class.new(api_key: "k")
      expect(client.base_url).to eq("https://zazu.ma")
    end

    it "reads api_key from ZAZU_API_KEY env var" do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with("ZAZU_API_KEY", nil).and_return("env-key")
      allow(ENV).to receive(:fetch).with("ZAZU_BASE_URL", anything).and_return("https://zazu.ma")
      allow(ENV).to receive(:fetch).with("ZAZU_API_VERSION", nil).and_return(nil)
      allow(ENV).to receive(:fetch).with("ZAZU_TIMEOUT", anything).and_return("30")
      client = described_class.new
      expect(client.api_key).to eq("env-key")
    end
  end

  describe "resource accessors" do
    let(:client) { described_class.new(api_key: "k") }

    it "memoizes accounts so the same instance is returned" do
      first = client.accounts
      second = client.accounts
      expect(first).to be(second)
    end

    it "exposes every resource module" do
      modules = {
        accounts: Zazu::Resources::Accounts,
        customers: Zazu::Resources::Customers,
        entity: Zazu::Resources::Entity,
        invoices: Zazu::Resources::Invoices,
        payment_links: Zazu::Resources::PaymentLinks,
        webhook_endpoints: Zazu::Resources::WebhookEndpoints
      }
      modules.each do |accessor, klass|
        expect(client.public_send(accessor)).to be_a(klass)
      end
    end
  end
end
