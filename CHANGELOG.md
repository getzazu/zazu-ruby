# Changelog

All notable changes to `zazu-ruby` are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0]

Initial release.

### Added

- `Zazu::Client` — Faraday + HTTPX adapter, JSON request/response, retry middleware.
- Resource modules: `Accounts`, `Customers`, `Entity`, `Invoices`, `PaymentLinks`, `WebhookEndpoints`.
- Cursor-based pagination via `Zazu::Page` (max 100 records per page; no auto-pagination).
- Error hierarchy: `AuthenticationError`, `ForbiddenError`, `NotFoundError`,
  `ValidationError`, `RateLimitError`, `ServerError`, `ConnectionError`,
  `ConfigurationError`, `ArgumentError` — all under `Zazu::Error`.
- VCR-backed RSpec suite covering every public method.
- Cassette tarball published as a release asset for cross-language SDK reuse.
