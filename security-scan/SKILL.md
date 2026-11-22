---
name: security-scan
version: 1.2.0
description: |
  Scans JS, TypeScript, Python, Go, and Rust code for security vulnerabilities across
  frontend, API/middleware, and backend layers. Uses OWASP Top 10 2021 rules,
  calculates CVSS 3.1 scores, tracks both insecure patterns (negatives) and
  secure patterns (positives), and cross-references dependencies against the
  local CVE database at ~/.claude/security/cve-db/. Generates a structured
  markdown report with overall project security grade.
  Use when asked to "scan for vulnerabilities", "security audit", "find vulnerabilities",
  "check for CVEs", "check security", or "run security scan".
allowed-tools:
  - Bash
  - Read
  - Write
  - Glob
  - Grep
  - AskUserQuestion
---

## Role

You are an expert application security engineer specializing in OWASP Top 10 vulnerability detection across JavaScript, TypeScript, Python, Go, and Rust codebases. You identify both security weaknesses AND security strengths, giving developers an accurate picture of their security posture.

## Instructions

Perform a complete security scan of the current project. Work through the following phases in order.

### Phase 1 — Setup

1. Check for CVE database:
   ```bash
   ls ~/.claude/security/cve-db/index/packages.json 2>/dev/null && echo "CVE_DB_FOUND" || echo "CVE_DB_MISSING"
   ```
   If missing, note: "CVE database not found. Run /security-update-cve to enable dependency CVE checks. Proceeding with OWASP static analysis."

2. Prepare output directory and date:
   ```bash
   mkdir -p .security-reports && date +%Y-%m-%d
   ```

3. Identify project name from `package.json`, `go.mod`, `Cargo.toml`, or the working directory name.

### Phase 2 — Collect target files

Find all scannable files using Glob:
- **JS/TS**: `**/*.{js,ts,jsx,tsx,mjs,cjs}` — exclude `node_modules/`, `dist/`, `build/`, `.next/`, `coverage/`
- **Python**: `**/*.py` — exclude `__pycache__/`, `.venv/`, `venv/`, `env/`, `.tox/`
- **Go**: `**/*.go` — exclude `vendor/`, `pkg/mod/`
- **Rust**: `**/*.rs` — exclude `target/`
- **Dependency manifests**: `package.json`, `package-lock.json`, `requirements.txt`, `pyproject.toml`, `Pipfile`, `Pipfile.lock`, `go.mod`, `go.sum`, `Cargo.toml`, `Cargo.lock`

Classify each source file as one of:
- **Frontend** — files under `src/components/`, `src/pages/`, `src/views/`, `src/ui/`, `public/`, `static/`, templates (`templates/`, `*.html`), or any file that imports React/Vue/Angular/Svelte or WASM/frontend frameworks (Yew, Leptos)
- **API/Middleware** — files under `src/api/`, `src/routes/`, `src/controllers/`, `src/middleware/`, `pkg/api/`, `internal/api/`, `handlers/`, or any file that imports express/fastapi/flask/django.http, Go web frameworks (gin, fiber, echo, chi, gorilla/mux, net/http), or Rust web frameworks (actix-web, axum, rocket, warp, tower)
- **Backend** — files under `src/services/`, `src/models/`, `src/db/`, `src/workers/`, `pkg/`, `internal/`, or anything not classified above

### Phase 3 — Static analysis

For each file, identify **negative findings** (vulnerabilities) and **positive findings** (secure patterns). Record the file path and line number for each.

---

#### NEGATIVE FINDINGS — What to flag as insecure

**OWASP A01 — Broken Access Control**
- Hardcoded role bypass: `isAdmin = true`, `role === "admin"`, `user.Role == "admin"` without dynamic check
- Missing auth guard before route handler (route file with no auth middleware imported / applied)
- Direct object reference without ownership check: `findById(req.params.id)` / `db.First(&user, id)` without user ownership validation
- Path traversal: unvalidated `../`, `path.join`, Go `filepath.Join(base, userInput)` without `strings.HasPrefix` check, Rust `Path::new(&base).join(user_input)` without canonicalize check
- IDOR: URL params mapped directly to DB queries without scoping to authenticated user

**OWASP A02 — Cryptographic Failures**
- Hardcoded credentials: `password = "..."`, `secret = "..."`, `api_key = "..."`, `token = "..."` (regex: `(?i)(password|secret|api_key|token|private_key|auth_token)\s*[=:]\s*["'][^"'\s]{6,}`)
- Weak algorithms: `md5(`, `sha1(`, `des.`, `rc4.`, Go `crypto/md5`, `crypto/sha1`, `crypto/des`, `crypto/rc4`, Rust `md5`, `sha1`, AES in ECB mode
- Disabled TLS: `verify=False`, `rejectUnauthorized: false`, `NODE_TLS_REJECT_UNAUTHORIZED`, Go `InsecureSkipVerify: true`, Rust `danger_accept_invalid_certs(true)`
- Insecure random for tokens: JS `Math.random()`, Python `random.random()`, Go `math/rand` (should use `crypto/rand`), Rust `rand::thread_rng()` for crypto/auth tokens (should use `rand::rngs::OsRng` or `ring`)
- HTTP (not HTTPS) in API base URLs or connection strings

**OWASP A03 — Injection**
- SQL injection: string concatenation in SQL:
  - JS/TS: `"SELECT" + `, `${userInput}` in raw SQL
  - Python: f-string in SQL query, `%s` % user_input in SQL, `.format(` in SQL string
  - Go: `fmt.Sprintf("SELECT ... %s", input)`, `db.Query("... " + input)`, `db.Raw("... " + input)`
  - Rust: `format!("SELECT ... {}", input)` in `sqlx::query` or `diesel::sql_query`
- XSS: `innerHTML =`, `outerHTML =`, `dangerouslySetInnerHTML={{`, `document.write(`, `$(el).html(userInput`, Go `template.HTML(userInput)` / `template.JS(userInput)` bypass
- eval / dynamic execution injection: `eval(`, `new Function(userInput`, `setTimeout(string,`, `setInterval(string,`
- Command injection:
  - JS/TS: `child_process.exec(`, `execSync(` with user input
  - Python: `os.system(`, `os.popen(`, `subprocess.call([..., shell=True`, `subprocess.run([..., shell=True`, `exec(userInput`
  - Go: `exec.Command("sh", "-c", userInput)`, `exec.Command(userInput)`
  - Rust: `Command::new("sh").arg("-c").arg(user_input)`, `Command::new(user_input)`
- NoSQL injection: `$where:`, `$regex:` with unsanitized user input
- Template injection: `render_template_string(userInput`, `str.format(**user_dict)`, Jinja2 `Environment(autoescape=False)`, Go SSTI in unescaped `text/template`

**OWASP A05 — Security Misconfiguration**
- CORS wildcard with credentials: `Access-Control-Allow-Origin: *` alongside `Access-Control-Allow-Credentials: true`
- Debug mode: `DEBUG = True`, `app.debug = True`, `debug: true` in production config, Go `net/http/pprof` mounted without auth
- Verbose errors to client: `res.json({ error: err.stack })`, `return str(traceback.format_exc())`, Go `http.Error(w, err.Error(), 500)`, Rust `format!("{:?}", err)` in HTTP response body
- Missing security headers: no `helmet(` in Express apps, no `Content-Security-Policy`, no `X-Frame-Options`
- Exposed admin routes without auth: `/admin`, `/debug`, `/metrics` with no guard

**OWASP A06 — Vulnerable Components**
- Flag for CVE check: any dependency in `package.json`, `requirements.txt`, `pyproject.toml`, `go.mod`, or `Cargo.toml`/`Cargo.lock` (handled in Phase 5)

**OWASP A07 — Authentication Failures**
- JWT `algorithm: "none"`, `algorithms: ["none"]`, Go `jwt.SigningMethodNone`, Rust `Validation::insecure_disable_signature_validation()`
- JWT secret hardcoded or in code
- Missing `httpOnly` on session cookies (Go `HttpOnly: false`, Rust cookie jar missing `http_only(true)`)
- Missing `secure` flag on cookies
- Missing `sameSite` on cookies
- No rate limiting on `/login`, `/auth`, `/token` endpoints
- Passwords stored as plain text or with weak hash (MD5/SHA1)

**OWASP A08 — Software and Data Integrity**
- Insecure deserialization: Python `pickle.loads(untrusted)`, `yaml.load(` without `Loader=yaml.SafeLoader`, Go unvalidated `gob.Decode(`, Rust unsafe serialization formats without bounds
- `eval(` or `exec(` on any user-supplied data
- `unserialize(` in PHP-adjacent JS
- Memory safety / bounds bypass: Go uncontrolled `unsafe.Pointer` on user input, Rust unsound `unsafe` blocks with unvalidated pointer arithmetic or user-supplied slices

**OWASP A10 — SSRF**
- User-controlled URL passed directly to HTTP clients:
  - JS: `fetch(`, `axios.get(`, `http.get(`
  - Python: `requests.get(`, `urllib.request.urlopen(`
  - Go: `http.Get(userInput)`, `http.NewRequest("GET", userInput, ...)`
  - Rust: `reqwest::get(user_input)`, `reqwest::Client::new().get(user_input)`
- Open redirect: `res.redirect(req.query.url)`, Go `http.Redirect(w, r, r.URL.Query().Get("url"), ...)` without allowlist

**Additional checks**
- Prototype pollution (JS): `obj[userKey] = val` where `userKey` comes from request, no `__proto__` / `constructor` guard
- XXE (Python/Go): `lxml.etree.fromstring(`, Go `xml.NewDecoder` on untrusted XML with entity expansion
- Insecure file ops: `open(user_input)`, `fs.readFile(req.params.path)`, Go `os.Open(userInput)`, Rust `std::fs::read(user_input)` without path sanitization
- Regex DoS (ReDoS): nested quantifiers in user-supplied regex: `(a+)+`, `(.*)+`, `([a-z]+)*`

**Lessons-learned checks** (derived from a real review of an MCP/MQTT server; language-agnostic, see `CHANGELOG.md`)
- **Fail-open switch parsing (A05)**: a security toggle (`READ_ONLY`, `TLS`, `VERIFY`, `ALLOW_*`, `INSECURE`) parsed with a single literal comparison (`== "1"`, `== "true"`, `os.getenv(X) == ...`, `process.env.X === "1"`) so that `true`/`yes`/`on`/typos silently select the insecure default. Flag as Medium-High. Correct pattern: accept a documented set (`1/true/yes/on`, `0/false/no/off/""`) and raise on anything else.
- **Unmarked untrusted data reaching an LLM (A03/A08)**: tool or API results that carry attacker-settable strings (client IDs, usernames, topics, tags, file names, issue text, REST list endpoints of secondary/admin APIs) returned to a model with no `untrusted` marker, per-field length bound, or delimiter. Primary data paths are often wrapped while secondary APIs are forgotten, so check every tool return path, not only the main one. An `untrusted: true` flag is advisory; allowlists are the real control.
- **Cleartext credentials to non-loopback http (A02/A07)**: Basic/Bearer/API-key credentials sent over `http://` where the host is not `localhost`/`127.0.0.1`/`::1`. Check that every client path has the same guard, not only the primary protocol (a guard on the MQTT/DB connection does not cover the REST helper next to it).
- **Blocking sync call in an async server (A04)**: sync `requests`/`httpx.Client`/`urllib`/DB/file calls inside `async def`, or sync tool handlers on a single-event-loop framework (FastMCP, FastAPI `async` app, asyncio/tokio) that run inline. One slow upstream stalls every concurrent request. Prefer `asyncio.to_thread`, an async client, or `spawn_blocking`.
- **Truncation and size misreporting on untrusted input (A04)**: payloads cut to `limit+1` on receipt and then reported as `len(truncated)`; truncation at a byte offset that can split a UTF-8 sequence (decode then fails or falls back to base64); size caps checked after decode or after full buffering rather than before. Track the true size separately and cut on a character boundary.
- **Hand-rolled JSON logging / log forging (A09)**: JSON log lines built with `%`/f-string/format (`'{"msg": "%(message)s"}'`, `"{\"level\":\"" + x`) so quotes or newlines in logged values break the line or forge entries. Also flag logging of attacker-controlled values raw. Use a real JSON formatter (`json.dumps`, `structlog`, `tracing-subscriber` json, `zap`).
- **Exceptions that leak or leave resources open (A05/A09)**: client construction (TLS CA/key loading, file opens) outside the `try` that maps errors to a safe message, so `FileNotFoundError`/`ssl.SSLError` with filesystem paths reaches the caller; connect/timeout paths that never close the socket.
- **Unvalidated limit configuration (A05)**: size/limit settings with no relationship check (`max_message_bytes <= max_response_bytes`), no port range check, silent clamping, or no startup warning when an insecure override (`TLS_INSECURE`, `verify=False`) is enabled.
- **Missing CI gates (A06/A08)**: no workflow that runs lint, type-check, and tests on pull requests; a workflow that exists only for docs/pages; no dependency audit (`pip-audit`, `npm audit`, `cargo audit`, `govulncheck`, Dependabot); coverage or `mypy --strict`/`tsc --noEmit` thresholds documented but never enforced; workflows without `permissions:` least privilege or with actions not pinned to a commit SHA. Report as one Medium finding per repo (not per file).
- **Copy-pasted security helpers (A04)**: the same URL/auth/HTTP helper duplicated across modules (e.g. two broker adapters), so a fix to one is missed in the other. Flag as Low and cite both locations.

**MCP server checklist** (apply when the project imports `mcp`, `fastmcp`, `@modelcontextprotocol/sdk`, `rmcp`, or declares an MCP server; run the generic checks above plus these)
- Pattern IDs refer to `secure-design-patterns` (`mcp-serve` domain); the IDs are the stable reference, no copy of the library is needed.
- **MCP-001 Credential isolation**: tools forward the caller's `Authorization` header or token upstream (token passthrough); credentials come from the environment/secret store and are bound per upstream route, never from tool arguments.
- **MCP-003 Payload bounding**: tool results are bounded on both axes, item count and bytes, before they reach the model; truncation is reported honestly (true size, `truncated` flag); `outputSchema` is not silently stripped.
- **MCP-006 Stateless, async-safe execution**: no per-session mutable globals shared across requests; blocking work is off the event loop; lifespan-scoped clients are not reused unsafely across tasks.
- **MCP-008 Transport and sandbox hygiene**: stdio transport writes only protocol frames to stdout (logs go to stderr, as real JSON); no `eval`/`exec`/`subprocess(shell=True)` in tool bodies; filesystem/network reach is narrowed by allowlists, and a read-only mode exists and is fail-closed.
- Also flag: write/destructive tools registered without a read-only switch, wildcard allowlists, and allowlists that are optional rather than deny-by-default.

---

#### POSITIVE FINDINGS — What to flag as secure (give credit)

- Parameterized queries / ORM usage: `db.query("SELECT ... WHERE id = ?", [id])`, `Model.findById(id)`, Go `db.Query("SELECT ... WHERE id = $1", id)`, `gorm.Where("id = ?", id)`, Rust `sqlx::query!("... WHERE id = $1", id)`, `diesel` ORM
- Input validation libraries: `joi.validate(`, `zod.parse(`, `marshmallow`, `pydantic` schema validation, Go `go-playground/validator` tags (`validate:"required,email"`), Rust `validator` crate / strong typed `serde` parsing
- Auth middleware applied: `router.use(authenticate)`, `@require_login`, Go middleware `r.Use(AuthMiddleware)`, Rust `axum::middleware::from_fn(auth)`, `actix_web::guard`
- Security headers middleware: Helmet.js, Go `secure` middleware / `helmet`, Rust `tower-http` `SetResponseHeaderLayer`
- `httpOnly: true, secure: true, sameSite: 'strict'` (or SameSiteStrictMode / SameSite::Strict) on cookies
- CSRF protection: `csurf(`, `csrf_protect`, Go `gorilla/csrf`, `nosurf`
- Cryptographically secure random tokens: `secrets.token_hex(`, `crypto.randomBytes(`, Go `crypto/rand.Read(`, Rust `rand::rngs::OsRng` / `ring::rand::SystemRandom`
- Rate limiting: `rateLimit(`, `slowDown(`, `flask_limiter`, Go `tollbooth`, `golang.org/x/time/rate`, Rust `governor`, `tower` RateLimit
- Content Security Policy configured
- Environment variables for secrets: `process.env.SECRET`, `os.environ['SECRET']`, Go `os.Getenv("SECRET")`, Rust `std::env::var("SECRET")` (not hardcoded)
- TLS verification enabled (default): no `verify=False`, no `rejectUnauthorized: false`, no `InsecureSkipVerify: true`, Go `tls.Config{MinVersion: tls.VersionTLS12}`
- `defusedxml` used for XML parsing (Python) / secure XML decoding without entity expansion (Go)
- Password hashing with bcrypt/argon2: Go `golang.org/x/crypto/bcrypt`, `argon2`, Rust `argon2`, `bcrypt`
- JWT with explicit algorithm and expiry: `sign(payload, secret, { algorithm: 'HS256', expiresIn: '1h' })`, Go `jwt.NewWithClaims(jwt.SigningMethodHS256, ...)`
- Output encoding/escaping: `DOMPurify.sanitize(`, `html.EscapeString(`, `bleach.clean(`
- Strict switch parsing: a helper that accepts a documented value set and raises on unknown values (fail-closed security toggles)
- Untrusted-data handling: tool results from every API path wrapped as `{"untrusted": true, ...}` or delimited, with per-field truncation
- Loopback-only (or https-only) guard for credentialed HTTP clients on every client path
- Blocking calls offloaded from the event loop (`asyncio.to_thread`, async clients, `spawn_blocking`)
- Real JSON log formatter; CI workflow running lint, type-check, tests, and a dependency audit with `permissions: contents: read` and SHA-pinned actions
- Deny-by-default allowlists, read-only mode, payload caps checked before decode, and rate limiting in MCP servers

---

### Phase 4 — CVSS 3.1 Scoring

For every negative finding, calculate a CVSS 3.1 Base Score using this table. Be explicit about each metric.

| Metric | Options |
|--------|---------|
| Attack Vector (AV) | Network (N) = 0.85, Adjacent (A) = 0.62, Local (L) = 0.55, Physical (P) = 0.2 |
| Attack Complexity (AC) | Low (L) = 0.77, High (H) = 0.44 |
| Privileges Required (PR) | None (N) = 0.85, Low (L) = 0.62/0.50, High (H) = 0.27/0.50 |
| User Interaction (UI) | None (N) = 0.85, Required (R) = 0.62 |
| Scope (S) | Unchanged (U), Changed (C) |
| Confidentiality (C) | None (N), Low (L), High (H) |
| Integrity (I) | None (N), Low (L), High (H) |
| Availability (A) | None (N), Low (L), High (H) |

Score ranges: **Critical** 9.0–10.0 | **High** 7.0–8.9 | **Medium** 4.0–6.9 | **Low** 0.1–3.9

Use these reference scores for common vulnerability types (adjust ±1 based on context):
- SQL Injection (network-accessible): **9.8** (AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H)
- XSS Stored: **8.8** (AV:N/AC:L/PR:L/UI:R/S:C/C:H/I:L/A:N)
- XSS Reflected: **6.1** (AV:N/AC:L/PR:N/UI:R/S:C/C:L/I:L/A:N)
- Command Injection: **9.8** (AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H)
- Hardcoded Credential: **7.5** (AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:N/A:N)
- SSRF: **8.6** (AV:N/AC:L/PR:N/UI:N/S:C/C:H/I:N/A:N)
- Open Redirect: **6.1** (AV:N/AC:L/PR:N/UI:R/S:C/C:L/I:L/A:N)
- Insecure Deserialization: **9.8**
- Path Traversal: **7.5**
- Missing Auth: **9.8** (for admin endpoints), **7.5** (for user data)

### Phase 5 — Dependency CVE check

If CVE database exists and dependency files were found:

1. Extract package / dependency names and versions from:
   - JS/TS: `package.json` (`.dependencies` + `.devDependencies`), `package-lock.json`
   - Python: `requirements.txt`, `pyproject.toml`, `Pipfile`
   - Go: `go.mod`, `go.sum`
   - Rust: `Cargo.toml`, `Cargo.lock`

2. For each package, query the index:
   ```bash
   jq --arg pkg "PACKAGE_NAME" 'to_entries | map(select(.key | ascii_downcase | contains($pkg))) | from_entries' \
     ~/.claude/security/cve-db/index/packages.json 2>/dev/null
   ```

3. Include any CVE where the installed version falls within the vulnerable version range. Report the CVE ID, CVSS score, severity, and a one-line description.

### Phase 6 — Calculate project security score

**Negative score**: Sum of all finding CVSS scores, weighted by count
**Positive score**: 1 point per distinct positive category found (max 15 points)
**Overall grade**:
- **A** (90–100): No Critical/High findings, 10+ positive patterns
- **B** (75–89): No Critical findings, ≤2 High findings, 7+ positive patterns
- **C** (60–74): No Critical findings, several Medium/High findings
- **D** (40–59): Has Critical or many High findings
- **F** (<40): Multiple Critical findings or systemic security failures

### Optional — Control mapping and evidence hand-off

This step is optional and has no hard dependency. Skip it silently if the tools below are not present; never download anything to perform it.

- **NIST SP 800-53 tags**: if the `security-controls` library (https://github.com/bsommers/security-controls) is installed or cloned locally, or you already know the control IDs, add a `**Controls**:` line to each finding. Without it, use the common mapping below as plain text.

| Finding class | Typical 800-53 r5 IDs |
|---------------|----------------------|
| Fail-open security switch / insecure default | CM-6, CM-7, SI-10 |
| Unmarked untrusted data to an LLM, injection | SI-10, SI-15, SC-18 |
| Cleartext credentials, missing TLS | SC-8, SC-13, IA-5 |
| Blocking call / unbounded resource use | SC-5, SC-6 |
| Truncation / size misreport, input bounds | SI-10 |
| Log forging, missing audit fields | AU-3, AU-9, SI-11 |
| Missing CI gates, no dependency audit | SA-11, SA-15, RA-5, SR-3 |
| Wildcard allowlist, no deny-by-default | AC-3, AC-6 |

- **Evidence hand-off**: if `security-assurance` (https://github.com/bsommers/security-assurance) is available, the report's finding table (ID, severity, file:line, control IDs, status) is suitable input for an OSCAL POA&M item. This skill does not generate OSCAL; it only keeps the fields stable so another tool can.

### Phase 7 — Generate report

Write `.security-reports/scan-{date}.md`:

```markdown
# Security Scan Report
**Date**: {date}
**Project**: {project name}
**Scanned**: {N} files ({JS/TS count} JS/TS, {Python count} Python, {Go count} Go, {Rust count} Rust)
**CVE Database**: {last-updated date or "not available — run /security-update-cve"}
**Security Grade**: {A/B/C/D/F}

---

## Executive Summary

| Category | Count |
|----------|-------|
| Critical findings | N |
| High findings | N |
| Medium findings | N |
| Low findings | N |
| Secure patterns found | N |
| CVE matches | N |

**Risk Assessment**: {1-2 sentence summary of overall posture}

---

## What Your Code Does RIGHT

> Security strengths found in this codebase. These are good practices to preserve and extend.

### Parameterized Queries — `src/db/users.js:23`
Using `db.query("SELECT * FROM users WHERE id = ?", [id])` — correct defense against SQL injection.

### Input Validation — `src/api/auth.js:15`
`zod.parse(req.body)` validates all incoming request bodies before processing.

[... all positive findings ...]

---

## Vulnerabilities Found

> Issues ordered by CVSS severity (highest first). Each finding includes OWASP category, CVSS score, evidence, and fix guidance.

### [CRITICAL 9.8] SQL Injection — `src/api/orders.js:87`
**OWASP**: A03 — Injection
**Layer**: API/Middleware
**CVSS**: 9.8 (AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H)
**Controls** *(optional)*: SI-10

**Evidence** (insecure):
```js
const query = `SELECT * FROM orders WHERE user_id = ${req.params.id}`;
```

**Risk**: Attacker can inject arbitrary SQL to read, modify, or delete any database record, or execute admin commands.

**Fix**: Use parameterized queries:
```js
const query = "SELECT * FROM orders WHERE user_id = ?";
db.query(query, [req.params.id]);
```

**References**: [OWASP SQL Injection](https://owasp.org/www-community/attacks/SQL_Injection)

---

[... additional findings in descending CVSS order ...]

---

## CVE Findings

| Package | Installed | CVE | CVSS | Severity | Summary |
|---------|-----------|-----|------|----------|---------|
| express | 4.17.1 | CVE-2022-24999 | 7.5 | High | qs prototype pollution |

---

## Files Scanned

<details>
<summary>{N} files scanned</summary>

| File | Layer | Findings |
|------|-------|----------|
| src/api/orders.js | API | 2 |
| src/components/Form.tsx | Frontend | 1 |
| pkg/handlers/auth.go | API | 0 |
| src/main.rs | Backend | 1 |
| ... | ... | ... |

</details>

---

## Next Steps

Run `/security-evaluate` for risk-ranked remediation priorities.
Run `/security-remediate` to apply fixes with before/after scoring.
```

After writing the report, print a terminal summary:
```
Security scan complete → .security-reports/scan-{date}.md
Grade: {grade}  |  Critical: N  |  High: N  |  Medium: N  |  Low: N
Secure patterns found: N
Run /security-evaluate for scoring detail, /security-remediate to fix.
```

## Success criteria

- Every JS/TS/Python/Go/Rust file in the project has been analyzed
- Both negative findings (vulnerabilities) and positive findings (secure patterns) are recorded
- Every negative finding has a CVSS 3.1 score with metric breakdown
- Every finding has a file path + line number, OWASP category, evidence snippet, risk explanation, and fix example
- CVE cross-reference was performed if database is available
- Report is written to `.security-reports/scan-{date}.md`
- Project security grade is calculated and displayed
- Lessons-learned checks and, for MCP projects, the MCP checklist were applied
- Optional NIST control tags are present only when available; the scan never requires network or extra tools
