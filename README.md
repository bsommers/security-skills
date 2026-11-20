# security-skills

> Claude Code skills for security auditing, vulnerability remediation, test suite generation, and documentation — for JS, TypeScript, Python, Go, and Rust projects.

This collection adds six slash commands to Claude Code that cover the full security and quality lifecycle: scan code for vulnerabilities, evaluate and score findings against OWASP, auto-patch or suggest fixes, keep your CVE database current, generate comprehensive test suites, and produce full project documentation.

---

## Skills

| Skill | Command | What it does |
|-------|---------|--------------|
| Security Scan | `/security-scan` | Static analysis of all JS/TS/Python/Go/Rust files — OWASP Top 10, CVSS 3.1 scores, CVE cross-reference, markdown report |
| Security Evaluate | `/security-evaluate` | Deep risk scoring with security balance scorecard, OWASP coverage table, risk/effort prioritization matrix |
| Security Remediate | `/security-remediate` | Fixes vulnerabilities in three modes: auto-patch (with before/after diff), suggest, or interactive |
| Update CVE DB | `/security-update-cve` | Downloads OSV.dev (npm, PyPI, Go, crates.io) and NIST NVD API 2.0 vulnerability data into `~/.claude/security/cve-db/` and builds a package lookup index |
| Tests | `/tests` | Generates unit, integration, and E2E test suites with runners (Vitest/Playwright/pytest) and a consolidated markdown report |
| Docs | `/docs` | Writes README, ARCHITECTURE, PURPOSE, and HOWTO with ASCII diagrams and Mermaid charts |

---

## Quick Start

### Installation

Clone the repository and run the installer:

```bash
git clone https://github.com/bsommers/security-skills.git
cd security-skills

# Install for both Claude Code and Antigravity (agy)
./install.sh

# Or symlink for live development/updates
./install.sh --symlink
```

#### Installer Options:
- `./install.sh --claude` — Install for Claude Code only (`~/.claude/skills/`)
- `./install.sh --agy` — Install for Antigravity only (`~/.gemini/config/skills/`)
- `./install.sh --symlink` — Create symlinks instead of copying
- `./install.sh --project /path/to/project` — Install into a specific project workspace
- `./install.sh --list` — View installed status
- `./install.sh --uninstall` — Uninstall skills

Skills are available immediately in Claude Code and Antigravity sessions. Run:

```
/security-scan
```

---

## Usage

### `/security-scan`

Scans every JS/TS/Python/Go/Rust file in the project for OWASP Top 10 vulnerabilities. Tracks both insecure patterns (what to fix) and secure patterns (what's working). Calculates CVSS 3.1 scores for each finding, cross-references detected packages against the local CVE database, and writes a graded markdown report.

```
/security-scan
```

**Output:** `.security-reports/scan-{date}.md` — severity table, per-finding evidence and fix hints, CVE matches, security grade A–F.

---

### `/security-evaluate`

Deep evaluation that builds on scan results. Validates every CVSS 3.1 score using the full formula, computes a security balance scorecard (positive defenses vs. negative vulnerabilities, −100 to +100), classifies each finding into a risk/effort matrix (Fix Now / Plan Soon / Quick Win / Deprioritize), and maps findings to all 10 OWASP categories.

```
/security-evaluate
```

**Output:** `.security-reports/evaluate-{date}.md` — scored findings, OWASP coverage table, remediation roadmap with time estimates.

---

### `/security-remediate`

Applies OWASP-recommended fixes. Three modes:

| Mode | What happens |
|------|-------------|
| **Auto-patch** | Edits files directly. Shows before/after code diff and CVSS delta per fix. |
| **Suggest** | Outputs exact replacement code without touching files. |
| **Interactive** | Presents each fix and waits for approval before applying. |

```
/security-remediate
/security-remediate auto
/security-remediate suggest
```

**Output:** Before/after CVSS comparison, security grade change (e.g. D → B), list of new dependencies required, `.security-reports/remediate-{date}.md`.

---

### `/security-update-cve`

Downloads vulnerability data from OSV.dev bulk package feeds (npm, PyPI, Go, crates.io) and NIST NVD REST API 2.0 into `~/.claude/security/cve-db/` and builds a fast package-name lookup index. Run on demand to keep the database current.

```
/security-update-cve          # OSV feeds for npm, PyPI, Go & crates.io (recommended, fast)
/security-update-cve nvd      # NIST NVD API 2.0 (recent CVEs)
/security-update-cve full     # full multi-source sync (OSV + NVD 2.0)
```

**Output:** Terminal summary showing packages indexed, CVE count, last-update date.

---

### `/tests`

Analyzes the project stack (Node/Python, framework, existing runners), classifies every source file as Unit / Integration / E2E / Skip, presents a test plan for approval, then generates tests with Vitest, Playwright, and/or pytest. Configures runner config files, adds npm/Python scripts, and runs everything. Produces `.test-reports/summary.md` with pass rates, coverage bars, and a grade.

```
/tests
```

**Output:** `tests/unit/`, `tests/integration/`, `tests/e2e/`, `scripts/generate-test-report.js`, `.test-reports/summary.md`.

---

### `/docs`

Reads the entire codebase before writing anything. Generates four documents with ASCII system diagrams and Mermaid charts. The README links to all three supporting docs. Handles both standard software projects and Claude Code skills collections.

```
/docs
```

**Output:** `README.md`, `docs/ARCHITECTURE.md`, `docs/PURPOSE.md`, `docs/HOWTO.md`.

---

## How Skills Work

```
  You                  Claude Code             Skill
   │                        │                    │
   │   /security-scan       │                    │
   │───────────────────────►│                    │
   │                        │  read SKILL.md     │
   │                        │───────────────────►│
   │                        │◄───────────────────│
   │                        │  execute workflow  │
   │                        │─ ─ ─ ─ ─ ─ ─ ─ ─ ►│
   │                        │   [Bash, Read,     │
   │                        │    Write, Grep...] │
   │                        │◄─ ─ ─ ─ ─ ─ ─ ─ ─ │
   │  report / file edits   │                    │
   │◄───────────────────────│                    │
```

Each skill is a `SKILL.md` file declaring its name, the tools it may use, and step-by-step instructions. Claude Code reads the file, grants only the declared tools, and executes the workflow.

---

## Skill Reference

| Skill | Tools used | Writes files | Runs shell commands |
|-------|-----------|--------------|---------------------|
| `/security-scan` | Bash, Read, Write, Glob, Grep | `.security-reports/` | find, grep, jq |
| `/security-evaluate` | Bash, Read, Write, Glob, Grep | `.security-reports/` | jq |
| `/security-remediate` | Bash, Read, Write, Edit, Glob, Grep | Source files, `.security-reports/` | None |
| `/security-update-cve` | Bash, Read, Write, Glob | `~/.claude/security/cve-db/` | curl, unzip, python3 |
| `/tests` | Bash, Read, Write, Edit, Glob, Grep | `tests/`, config files, `.test-reports/` | npm/pip install, test runners |
| `/docs` | Bash, Read, Write, Edit, Glob, Grep | `README.md`, `docs/` | find, grep |

---

## Documentation

| Document | Description |
|----------|-------------|
| [Architecture](docs/ARCHITECTURE.md) | Skill execution model, component map, data flows, CVE database design |
| [Purpose](docs/PURPOSE.md) | Why this collection exists, goals, non-goals, trade-offs |
| [How-To Guide](docs/HOWTO.md) | Install skills, run a security audit end-to-end, add a new skill, update CVE DB |

---

## License

Proprietary — Bill Sommers
