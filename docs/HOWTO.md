# How-To Guide

## Contents

- [Install skills](#install-skills)
- [Run a full security audit](#run-a-full-security-audit)
- [Scan a specific project](#scan-a-specific-project)
- [Update the CVE database](#update-the-cve-database)
- [Remediate vulnerabilities](#remediate-vulnerabilities)
- [Generate a test suite](#generate-a-test-suite)
- [Generate project documentation](#generate-project-documentation)
- [Add a new skill](#add-a-new-skill)
- [Update an existing skill](#update-an-existing-skill)
- [Debug a skill that isn't working](#debug-a-skill-that-isnt-working)

---

## Install skills

**Prerequisites**: [Claude Code](https://claude.ai/code) and/or [Google Antigravity](https://github.com/google) (`agy`) installed.

Clone the repository and run `install.sh`:

```bash
git clone https://github.com/bsommers/security-skills.git
cd security-skills

# Install all skills globally for both Claude Code and Antigravity
./install.sh

# Or create symlinks for live updates during development
./install.sh --symlink
```

### Installation options

```bash
# Target-specific install
./install.sh --claude         # Claude Code only (~/.claude/skills/)
./install.sh --agy            # Antigravity only (~/.gemini/config/skills/)

# Install only specific skills
./install.sh security-scan security-evaluate

# Install into a specific project workspace
./install.sh --project /path/to/project

# Check installation status
./install.sh --list

# Uninstall
./install.sh --uninstall
```

Skills are active immediately in any Claude Code or Antigravity session — no restart needed.

---

## Run a full security audit

A complete audit follows four steps. Run these in Claude Code from inside your project directory.

**Step 1 — Initialize the CVE database** (first time only, or when refreshing)

```
/security-update-cve
```

This downloads OSV.dev and NIST NVD API 2.0 vulnerability data and builds `~/.claude/security/cve-db/index/packages.json`. Takes under 1 minute on first run.

**Step 2 — Scan**

```
/security-scan
```

Reads all `.js`, `.ts`, `.jsx`, `.tsx`, `.py`, `.go`, `.rs` files. Checks OWASP Top 10 patterns. Queries the CVE index for detected packages. Writes `.security-reports/scan-{date}.md` with a security grade. It also applies the lessons-learned checks (fail-open config parsing, untrusted data to LLMs, cleartext credentials, async blocking, log forging, missing CI gates) and, for MCP servers, an MCP checklist. Optional NIST 800-53 control tags are added when `security-controls` is available.

**Step 3 — Evaluate**

```
/security-evaluate
```

Validates every CVSS 3.1 score, computes the security balance scorecard, and classifies findings by risk/effort. Writes `.security-reports/evaluate-{date}.md`.

**Step 4 — Remediate**

```
/security-remediate
```

Presents three modes — choose based on your tolerance for automated edits:

| Mode | When to use |
|------|-------------|
| Auto-patch | You trust the fixes and want to apply them immediately |
| Suggest | You want to review code before changing anything |
| Interactive | You want to approve each fix individually |

Expected outcome: security grade improves (e.g. D → B), before/after CVSS comparison shown.

---

## Scan a specific project

Open Claude Code from the project's root directory, then:

```
/security-scan
```

The skill scans relative to the current working directory. All reports are written to `.security-reports/` inside the project. No configuration needed.

If the CVE database isn't initialized yet, the scan will complete with OWASP findings but will note that CVE cross-referencing was skipped. Run `/security-update-cve` to enable it.

---

## Update the CVE database

The CVE database at `~/.claude/security/cve-db/` is shared across all projects. Update it whenever you want current vulnerability data.

```
/security-update-cve
```

This downloads **OSV.dev package feeds** (npm, PyPI, Go, crates.io) and builds the index. Fast (<1 minute, ~250MB).

To query NIST NVD REST API 2.0 (for recently modified CVEs):

```
/security-update-cve nvd
```

To run a full multi-source sync (OSV npm, PyPI, Go, crates.io + NIST NVD 2.0):

```
/security-update-cve full
```

After updating, the terminal shows:

```
CVE Database Updated
──────────────────────────────────────
Last updated:     2026-09-14
Packages indexed: 184,210
Total CVE entries: 341,500
Sources:          OSV.dev (npm/PyPI/Go/crates.io), NIST NVD API 2.0
```

**Note on NIST NVD feeds**: NIST retired legacy JSON 1.1 feeds (`nvdcve-1.1-*.json.gz`). `/security-update-cve` now uses the official NIST NVD REST API 2.0 alongside OSV.dev open vulnerability archives.

---

## Remediate vulnerabilities

After running `/security-scan` or `/security-evaluate`:

```
/security-remediate
```

The skill asks which mode you want. You can also specify upfront:

```
/security-remediate auto        # apply all fixes automatically
/security-remediate suggest     # show code without editing
/security-remediate interactive # approve each fix
```

**Auto-patch output example:**

```
─────────────────────────────────────────────────────
FIXED: [CRITICAL 9.8] SQL Injection — src/api/orders.js:87
─────────────────────────────────────────────────────
BEFORE (CVSS 9.8 — Critical):
  const query = `SELECT * FROM orders WHERE id = ${req.params.id}`;

AFTER (CVSS 0.0 — Resolved):
  const query = "SELECT * FROM orders WHERE id = ?";
  db.query(query, [req.params.id]);

Score impact: −9.8 pts  |  Risk eliminated: SQL Injection (A03)
─────────────────────────────────────────────────────
```

If a fix requires a new package (e.g. `dompurify`, `defusedxml`, `golang.org/x/crypto`, `validator`), the skill lists all required installs at the end — it does not run `npm install`, `pip install`, `go get`, or `cargo add` automatically.

---

## Generate a test suite

Open Claude Code in the project root, then:

```
/tests
```

The skill will:
1. Detect the stack (Node/Python, framework, existing runners)
2. Classify every source file as Unit / Integration / E2E / Skip
3. Present the classification for your approval
4. Show a full test plan (file → test case list) for your approval
5. Install missing test runners (Vitest, Playwright, pytest)
6. Write the tests, run them, and report results

**Output:**

```
tests/unit/          — unit test files
tests/integration/   — integration test files
tests/e2e/           — Playwright specs
tests/helpers/       — shared factories and mocks
vitest.config.ts     — or jest.config.ts
playwright.config.ts
scripts/generate-test-report.js
.test-reports/summary.md
```

Re-run the report at any time:

```bash
npm run test:all && npm run test:report
```

---

## Generate project documentation

Open Claude Code in the project root, then:

```
/docs
```

The skill reads the entire codebase (entry points, routers, models, config, CI/CD) before writing a word. It asks two questions — audience and tone — then writes four files:

| File | What it contains |
|------|-----------------|
| `README.md` | What / Why / Quick Start / Architecture overview / Config / Dev / Deploy / links to docs |
| `docs/ARCHITECTURE.md` | Component map, ASCII data flow diagrams, Mermaid charts, key decisions |
| `docs/PURPOSE.md` | Problem statement, goals, non-goals, users, trade-offs |
| `docs/HOWTO.md` | Setup, extension patterns, debug guide, deploy instructions |

For a Claude Code skills collection (like this repo), the skill detects the `SKILL.md` pattern and switches to skills-specific templates — Usage tables, skill invocation examples, skill anatomy diagram.

---

## Add a new skill

1. **Create the directory and SKILL.md**

```bash
mkdir ~/.claude/skills/my-skill
```

Write `~/.claude/skills/my-skill/SKILL.md`:

```markdown
---
name: my-skill
version: 1.0.0
description: |
  One-line description of what this skill does.
  Use when asked to "do X", "help with Y", or "run Z".
allowed-tools:
  - Bash
  - Read
  - Write
  - Glob
  - Grep
---

## Role

You are a {relevant expert role}.

## Instructions

### Phase 1 — {First phase name}

{Step-by-step instructions...}

### Phase 2 — {Second phase name}

{Step-by-step instructions...}

## Success criteria

- [ ] {Verifiable outcome}
- [ ] {Verifiable outcome}
```

2. **Test it** — invoke the skill in Claude Code:

```
/my-skill
```

3. **Add it to the repo** (if contributing back):

```bash
cd ~/.claude/skills
git add my-skill/SKILL.md
git commit -m "feat: add my-skill — {one-line description}"
git push
```

**Frontmatter checklist:**
- `name` must match the directory name exactly
- `description` should include the trigger phrases you expect users to say
- `allowed-tools` must list every tool the skill's instructions reference; unlisted tools will be blocked at runtime

---

## Update an existing skill

Pull the latest version:

```bash
cd ~/.claude/skills
git pull origin main
```

Or edit a skill directly and push:

```bash
$EDITOR ~/.claude/skills/security-scan/SKILL.md

cd ~/.claude/skills
git add security-scan/SKILL.md
git commit -m "fix(security-scan): {what changed and why}"
git push
```

Changes take effect immediately — Claude Code reads SKILL.md fresh on each invocation.

---

## Debug a skill that isn't working

### Skill doesn't appear in /help

**Cause**: SKILL.md is at the wrong directory depth, or the frontmatter is malformed.

```bash
ls ~/.claude/skills/security-scan/SKILL.md   # must exist at this exact path
head -6 ~/.claude/skills/security-scan/SKILL.md
# Expected first line: ---
# Expected second line: name: security-scan
```

### Skill runs but a tool call is blocked

**Cause**: The tool is not listed in `allowed-tools` in the SKILL.md frontmatter.

**Fix**: Add the tool name to the `allowed-tools` list:

```yaml
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit       # ← add missing tool here
  - Glob
  - Grep
```

### Security scan finds no CVEs even though packages are outdated

**Cause**: The CVE database hasn't been initialized or is stale.

**Fix**:
```
/security-update-cve
```

Then re-run `/security-scan`. If the database still shows no matches, check that `~/.claude/security/cve-db/index/packages.json` exists and is non-empty:

```bash
ls -lh ~/.claude/security/cve-db/index/packages.json
python3 -c "import json; d=json.load(open('$HOME/.claude/security/cve-db/index/packages.json')); print(len(d), 'packages indexed')"
```

### `/security-update-cve` fails with a network error

**Cause**: NVD rate limit, API key missing, or network timeout.

**Fix**: The skill provides OSV.dev direct downloads as the recommended, rate-limit-free primary source. If you need NVD API 2.0:

1. Obtain a free NVD API key from [nvd.nist.gov/developers/request-an-api-key](https://nvd.nist.gov/developers/request-an-api-key)
2. Set `export NVD_API_KEY="your-key"` in your environment
3. Re-run `/security-update-cve nvd`
4. Or place any manual JSON/zip feeds into `~/.claude/security/cve-db/raw/` and re-run `/security-update-cve`

### `/tests` generates tests that fail to import

**Cause**: The test file's import path doesn't match the project's module layout.

**Fix**: The skill discovers the project structure before writing tests, but module aliasing (e.g. `@/` path aliases) must be configured in `vitest.config.ts`. Check that the `resolve.alias` section matches your `tsconfig.json` paths.
