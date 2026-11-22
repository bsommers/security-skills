# Changelog

## Unreleased

### Added
- `security-scan` 1.2.0: lessons-learned checks (fail-open switch parsing, unmarked untrusted data reaching an LLM, cleartext credentials over non-loopback http, sync calls blocking an async loop, truncation and size misreporting, hand-rolled JSON logging, error/resource leaks, unvalidated limits, missing CI gates, duplicated security helpers), matching positive findings, and an MCP server checklist (secure-design-patterns MCP-001/003/006/008).
- `security-evaluate` 1.2.0: class-level checks phase and MCP pattern coverage; positive credit only for enforced controls.
- `security-remediate` 1.2.0: fix library for the new classes (strict env bool, untrusted wrapper, URL guard, `to_thread`, true-size truncation, JSON formatter, CI gate template).
- Optional, loosely coupled pointers to `security-controls` (NIST SP 800-53 r5 IDs) and `security-assurance` (OSCAL POA&M). Written as "if available"; no vendored copies, no network required.
- Origin: findings R-01 to R-20 of an MCP/MQTT server review.
