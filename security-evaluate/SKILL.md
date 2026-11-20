---
name: security-evaluate
version: 1.1.0
description: |
  Deep security evaluation of JS, TypeScript, Python, Go, and Rust codebases. Builds on
  /security-scan results (or triggers a fresh scan if none exist). Produces a
  risk-ranked evaluation with CVSS 3.1 scores for every finding, a positive/negative
  security balance scorecard, OWASP category breakdown, CVE cross-reference,
  and a prioritized remediation roadmap.
  Use when asked to "evaluate security", "score vulnerabilities", "security risk assessment",
  "prioritize security fixes", or "security report".
allowed-tools:
  - Bash
  - Read
  - Write
  - Glob
  - Grep
  - AskUserQuestion
---

## Role

You are a senior application security architect who produces actionable, evidence-based security evaluations across JS/TS, Python, Go, and Rust codebases. You score both what is broken (negative findings) and what is working (positive findings) to give developers a fair, complete picture of their security posture.

## Instructions

### Phase 1 — Load or generate scan data

1. Check for an existing scan report:
   ```bash
   ls .security-reports/scan-*.md 2>/dev/null | sort -r | head -1
   ```

2. If a scan report exists and was created today, read it.

3. If no scan report exists or it is older than today, inform the user:
   > "No scan report found. Running /security-scan first..."
   Then execute the full scan workflow from the security-scan skill before continuing.

4. Note the date for the evaluation report filename.

### Phase 2 — Parse findings

From the scan report, extract:
- All negative findings with their CVSS scores, OWASP category, file, and line
- All positive findings with their category and file
- CVE matches if present
- Total file and dependency counts

### Phase 3 — CVSS 3.1 validation and recalculation

For every negative finding, verify the CVSS score is correctly calculated. If the scan produced an approximate score, recalculate explicitly:

**CVSS 3.1 Base Score formula** (simplified):
1. Calculate ISS (Impact Sub Score): `1 - (1-C_impact)(1-I_impact)(1-A_impact)`
2. If Scope = Unchanged: Impact = 6.42 × ISS
3. If Scope = Changed: Impact = 7.52 × [ISS−0.029] − 3.25 × [ISS−0.02]^15
4. Exploitability = 8.22 × AV × AC × PR × UI
5. If Impact ≤ 0: Base Score = 0
6. Else if Scope = Unchanged: Base Score = min((Impact + Exploitability), 10), rounded up to 1 decimal
7. Else: Base Score = min(1.08 × (Impact + Exploitability), 10), rounded up to 1 decimal

**Metric numeric values:**
| Metric | Value |
|--------|-------|
| AV: Network | 0.85 |
| AV: Adjacent | 0.62 |
| AV: Local | 0.55 |
| AV: Physical | 0.20 |
| AC: Low | 0.77 |
| AC: High | 0.44 |
| PR: None | 0.85 |
| PR: Low (Scope:U) | 0.62 |
| PR: Low (Scope:C) | 0.50 |
| PR: High (Scope:U) | 0.27 |
| PR: High (Scope:C) | 0.50 |
| UI: None | 0.85 |
| UI: Required | 0.62 |
| C/I/A: None | 0.00 |
| C/I/A: Low | 0.22 |
| C/I/A: High | 0.56 |

Record the CVSS vector string for each finding (e.g., `CVSS:3.1/AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H`).

### Phase 4 — Security balance scorecard

**Negative score** (0–100, lower is better):
- Start at 0
- Add: Critical finding × 25 pts each (cap at 100)
- Add: High finding × 10 pts each
- Add: Medium finding × 4 pts each
- Add: Low finding × 1 pt each
- Final: min(sum, 100)

**Positive score** (0–100, higher is better):
Award points for each distinct secure category present in the codebase:

| Secure Pattern | Points |
|----------------|--------|
| Parameterized queries / ORM (sqlx, diesel, GORM, database/sql parameterized) | 10 |
| Input validation library (zod, joi, pydantic, validator crate, go-playground/validator) | 10 |
| Auth middleware applied to routes | 10 |
| Security headers (helmet, tower-http, Go secure middleware, CSP) | 8 |
| Secure cookie flags (httpOnly, secure, sameSite) | 8 |
| CSRF protection | 7 |
| Cryptographically secure random (secrets, crypto.randomBytes, crypto/rand, OsRng/ring) | 7 |
| Rate limiting on auth endpoints (tollbooth, governor, rateLimit) | 7 |
| Content Security Policy configured | 6 |
| Secrets from environment variables (not hardcoded) | 8 |
| TLS verification enabled / TLS 1.2+ minimum configured | 5 |
| defusedxml / secure XML parser without entity expansion | 5 |
| JWT with explicit algorithm + expiry | 7 |
| Output encoding / sanitization (DOMPurify, bleach, html.EscapeString) | 7 |
| No use of deprecated crypto (no MD5/SHA1 for secrets, use of bcrypt/argon2) | 5 |

Max positive score = 115 (normalized to 100).

**Security balance**: `positive_score - negative_score` (range: −100 to +100)
- **+50 to +100**: Strong security posture — well-defended codebase
- **0 to +49**: Adequate — some strengths, some gaps to close
- **−1 to −49**: Needs work — vulnerabilities outweigh defenses
- **−50 to −100**: Critical — immediate remediation required

**Grade mapping**:
| Grade | Condition |
|-------|-----------|
| A | Balance ≥ 50, no Critical, no High |
| B | Balance ≥ 20, no Critical, ≤ 2 High |
| C | Balance ≥ 0, no Critical |
| D | Balance < 0 or has Critical findings |
| F | Balance ≤ −50 or ≥ 3 Critical findings |

### Phase 5 — Risk prioritization matrix

Create a risk/effort matrix for all negative findings. Estimate remediation effort:
- **Minutes** (< 30 min): Config change, one-line fix
- **Hours** (30 min – 4 hr): Refactor a function or module
- **Days** (> 4 hr): Architectural change required

Classify each finding on the 2×2 risk/effort matrix:
- **Fix Now** (High Risk + Low Effort): Do immediately
- **Plan Soon** (High Risk + High Effort): Schedule for next sprint
- **Quick Wins** (Lower Risk + Low Effort): Do in bulk
- **Deprioritize** (Lower Risk + High Effort): Backlog

### Phase 6 — OWASP category analysis

For each of the 10 OWASP Top 10 2021 categories, report:
- Finding count
- Worst CVSS score in this category
- Positive controls present that mitigate this category
- Net risk level for this category: Mitigated / Partial / Exposed

### Phase 7 — Generate evaluation report

Write `.security-reports/evaluate-{date}.md`:

```markdown
# Security Evaluation Report
**Date**: {date}
**Project**: {project name}
**Based on scan**: `.security-reports/scan-{date}.md`
**Security Grade**: {A/B/C/D/F}

---

## Security Balance Scorecard

```
Negative Score: {N}/100  (lower is better)
Positive Score: {N}/100  (higher is better)
─────────────────────────────────
Balance:       {+N/-N}   (range: -100 to +100)
```

**Interpretation**: {1–2 sentence plain-English summary}

---

## What Your Code Does RIGHT

> These secure patterns were found and are actively protecting the application.
> Preserve these — removing them would directly increase your attack surface.

| Category | Files | Impact |
|----------|-------|--------|
| Parameterized queries | src/db/*.js | Prevents SQL injection |
| Input validation (zod) | src/api/*.ts | Prevents injection + type confusion |
| ... | ... | ... |

**Positive score breakdown**: {N} points from {N} secure categories

---

## Vulnerabilities — Risk Ranked

### Fix Now (High Risk, Low Effort)

#### [CRITICAL 9.8] SQL Injection — `src/api/orders.js:87`
**CVSS Vector**: `CVSS:3.1/AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H`
**OWASP**: A03 — Injection | **Layer**: API/Middleware
**Effort**: Minutes | **Remediation**: Replace string concatenation with parameterized query

[evidence snippet]

---

### Plan Soon (High Risk, High Effort)

#### [HIGH 8.2] Missing Authentication on Admin Routes — `src/routes/admin.js`
...

---

### Quick Wins (Lower Risk, Low Effort)

#### [MEDIUM 5.3] Missing Secure Cookie Flags — `src/auth/session.js:34`
...

---

### Deprioritize (Lower Risk, High Effort)

[findings here]

---

## OWASP Top 10 Coverage

| Category | Findings | Worst CVSS | Controls Present | Net Risk |
|----------|----------|------------|------------------|----------|
| A01 Broken Access Control | 2 | 9.8 | Auth middleware | Partial |
| A02 Cryptographic Failures | 0 | — | Env vars, secure random | Mitigated |
| A03 Injection | 3 | 9.8 | Parameterized queries in some files | Partial |
| A04 Insecure Design | 0 | — | — | — |
| A05 Security Misconfiguration | 1 | 5.3 | Helmet.js | Partial |
| A06 Vulnerable Components | 2 CVEs | 7.5 | — | Exposed |
| A07 Auth Failures | 1 | 6.8 | Rate limiting | Partial |
| A08 Data Integrity | 0 | — | — | Mitigated |
| A09 Logging & Monitoring | 0 | — | — | Unknown |
| A10 SSRF | 0 | — | — | Mitigated |

---

## CVE Summary

| Package | Version | CVE | CVSS | Fix |
|---------|---------|-----|------|-----|
| express | 4.17.1 | CVE-2022-24999 | 7.5 | Upgrade to ≥ 4.18.2 |

---

## Remediation Roadmap

1. **Immediate** (this sprint): {N} critical/high findings — estimated {X} hours
2. **Short-term** (next sprint): {N} medium findings — estimated {X} hours
3. **Ongoing**: Keep positive patterns, add missing controls for {categories}

Run `/security-remediate` to auto-fix or get specific fix guidance for each finding.
```

After writing the report, print terminal summary:
```
Evaluation complete → .security-reports/evaluate-{date}.md
Grade: {grade}  |  Balance: {+N/-N}  (Positive: {N} | Negative: {N})
Fix Now: N findings  |  Plan Soon: N  |  Quick Wins: N
Run /security-remediate to begin fixing.
```

## Success criteria

- Every finding has a validated CVSS 3.1 score with vector string
- Both positive and negative findings are scored and balanced
- Each finding is classified into Fix Now / Plan Soon / Quick Win / Deprioritize
- OWASP Top 10 coverage table is complete
- Evaluation report is written and references the scan report
- Remediation roadmap is practical and time-estimated
