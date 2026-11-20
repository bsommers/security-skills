# Purpose

## Problem Statement

Security analysis, test coverage, and documentation are consistently the three things that get skipped under deadline pressure — not because engineers don't care, but because the activation energy is too high. Running a security scan means installing a tool, learning its output format, cross-referencing CVE databases, and manually translating findings into code changes. Writing tests means setting up runners, choosing patterns, and writing boilerplate. Writing docs means switching context to a different mode entirely. Each task is a multi-hour investment before any value appears.

---

## Solution

This collection gives Claude Code five skills that eliminate the setup cost. You type a slash command in the same session where you write code. Claude reads the project, does the analysis, writes the reports, and optionally edits the files — all using the tools and patterns already understood by OWASP, NVD, and the test frameworks your stack already uses. No new accounts, no separate dashboards, no configuration beyond cloning a directory.

---

## Goals

1. **Zero-friction security review** — run `/security-scan` in any JS/TS/Python/Go/Rust project and get an OWASP-mapped, CVSS-scored report in under two minutes, no tool installation required
2. **Actionable, not just informational** — every finding includes the exact code fix and the CVSS delta it removes; `/security-remediate` applies fixes directly
3. **Honest posture reporting** — track what the codebase does *right* (secure patterns) alongside what it does wrong, so teams don't accidentally remove defenses
4. **CVE coverage without an account** — the local database is downloaded from public OSV/NVD feeds (npm, PyPI, Go, crates.io) and queried with `jq`; no paid API key or SaaS dependency required
5. **Test and doc parity** — security is only part of quality; `/tests` and `/docs` bring the same zero-friction principle to test coverage and documentation

---

## Non-Goals

- **Not a CI/CD pipeline tool** — these skills run interactively in Claude Code sessions, not as automated pipeline gates; use `semgrep`, `snyk`, or `bandit` for that
- **Not a replacement for dedicated SAST tools** — pattern-matching in an LLM is not a substitute for full data-flow analysis; these skills catch common, high-signal vulnerabilities but do not provide complete coverage
- **Not a CVE scanner with automatic version pinning** — the CVE lookup identifies risks; fixing dependency versions is left to the developer
- **Not cross-language beyond JS/TS/Python/Go/Rust** — Java, Ruby, C/C++, PHP are not covered in this version
- **Not real-time** — the CVE database is a snapshot; new CVEs published after the last `/security-update-cve` run will not be detected until the database is refreshed

---

## Users and Stakeholders

| Audience | How they interact | What they need |
|----------|------------------|----------------|
| Application developers | Run `/security-scan` and `/security-remediate` in their Claude Code session while writing features | Fast, specific findings with exact fix code — not advisory PDFs |
| Tech leads / code reviewers | Run `/security-evaluate` before merging a PR | Risk-ranked findings with effort estimates to prioritize review comments |
| Security engineers | Run the full audit chain (`scan → evaluate → remediate`) on a codebase | OWASP mapping, CVSS scores, CVE cross-reference, grade before/after |
| Developers new to a codebase | Run `/docs` to get oriented | Accurate architecture diagrams, data flows, and HOWTO guides sourced from actual code |

---

## Success Criteria

- [ ] A developer with no prior knowledge of OWASP can run `/security-scan` and understand every finding
- [ ] `/security-remediate` auto-patch mode produces code that compiles and passes existing tests
- [ ] The security balance scorecard reflects real posture — a well-secured codebase scores positive
- [ ] `/security-update-cve` completes in under 10 minutes on a standard broadband connection
- [ ] `/tests` produces tests that run without modification on a fresh clone

---

## Relationship to Other Systems

```
  ╔══════════════════════════╗         ╔══════════════════════════╗
  ║  services.nvd.nist.gov   ║         ║  osv-vulnerabilities     ║
  ║  (NVD REST API 2.0)      ║         ║  .storage.googleapis.com ║
  ╚════════╤═════════════════╝         ╚═══════════╤══════════════╝
           │ REST fetch                            │ curl download
           │                                       │
           └───────────────────┬───────────────────┘
                               ▼
                    ┌──────────────────────┐
                    │ /security-update-cve │
                    │  (python3 indexer)   │
                    └──────────┬───────────┘
                               │ writes
                               ▼
                    ╔══════════════════════╗
                    ║ ~/.claude/security/  ║
                    ║ cve-db/index/        ║
                    ║ packages.json        ║
                    ╚══════════╤═══════════╝
                               │ read by
                               ▼
   Your project ──────► /security-scan ──► .security-reports/
                                 │
                                 ▼
                         /security-evaluate ──► .security-reports/
                                 │
                                 ▼
                         /security-remediate ──► source files (edits)
```

---

## Trade-offs Made

- **LLM pattern matching vs. static analysis AST tools**: Chose LLM pattern matching because it integrates into Claude Code with no installation overhead. Cost: lower precision than tools like Semgrep that parse full ASTs; some false positives are expected.

- **Local flat-file CVE index vs. online API**: Chose local flat file (packages.json built from OSV.dev feeds and NIST NVD 2.0 API) because it works offline during scans, has no scan-time rate limits, and doesn't require API keys for analysis. Cost: database becomes stale between updates; user must run `/security-update-cve` periodically.

- **Three-mode remediation vs. full automation**: Chose three modes (auto / suggest / interactive) because auto-patching production code without review creates risk. Cost: more friction than a one-click fix tool.

- **Markdown SKILL.md format vs. compiled prompts**: Chose plain Markdown because it is readable in any editor, version-controllable with meaningful diffs, and requires no build step to update. Cost: no static validation of tool names or prompt structure at write time.
