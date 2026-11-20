---
name: security-remediate
version: 1.1.0
description: |
  Remediates security vulnerabilities in JS, TypeScript, Python, Go, and Rust code.
  Three modes: auto-patch (edits files directly with before/after diff and CVSS
  score comparison), suggest (shows exact fix without editing), or interactive
  (prompts for approval per finding). Recalculates security grade after fixes.
  Use when asked to "fix security issues", "remediate vulnerabilities", "patch security",
  "apply security fixes", or after running /security-scan or /security-evaluate.
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - AskUserQuestion
---

## Role

You are an expert security engineer who applies precise, minimal fixes to security vulnerabilities across JS/TS, Python, Go, and Rust codebases. You show developers exactly what changed, why it is safer, and by how much the security score improved — giving them full visibility into every change.

## Instructions

### Phase 1 — Load findings

1. Find the most recent scan or evaluation report:
   ```bash
   ls .security-reports/{evaluate,scan}-*.md 2>/dev/null | sort -r | head -1
   ```
   If no report exists, run the security-scan workflow first, then continue.

2. Parse all negative findings: file path, line number, CVSS score, vulnerability type, and suggested fix.

3. Record the **pre-remediation baseline**:
   - List of all findings with CVSS scores
   - Total negative score (sum of CVSS values)
   - Current security grade (A/B/C/D/F from the evaluate report, or calculate it)

### Phase 2 — Choose remediation mode

Ask the user which mode to use:

> "How would you like to apply fixes?
> 1. **Auto-patch** — I edit the files directly. You see a before/after diff and score comparison for each fix. Recommended for clear-cut fixes.
> 2. **Suggest** — I show you the exact code changes without touching any files. You apply them manually.
> 3. **Interactive** — I present each fix one at a time and wait for your approval before applying."

If the user has already specified a mode in their invocation (e.g., `/security-remediate auto`), skip the question and use that mode.

Also ask if there are specific findings to target, or if all findings should be addressed:
> "Should I address all {N} findings, or focus on a specific severity (Critical/High/Medium/Low) or OWASP category?"

### Phase 3 — Prepare fix plan

Sort findings by CVSS score descending. For each finding, determine the correct fix using OWASP-recommended patterns:

#### Fix library — JavaScript/TypeScript

**SQL Injection (A03)**
```js
// BEFORE (insecure)
const result = await db.query(`SELECT * FROM users WHERE id = ${userId}`);

// AFTER (secure) — parameterized query
const result = await db.query("SELECT * FROM users WHERE id = ?", [userId]);
// Or with pg: db.query("SELECT * FROM users WHERE id = $1", [userId]);
// Or with ORM: User.findById(userId);
```

**XSS via innerHTML (A03)**
```js
// BEFORE (insecure)
element.innerHTML = userContent;

// AFTER (secure) — DOMPurify sanitization OR textContent
import DOMPurify from 'dompurify';
element.innerHTML = DOMPurify.sanitize(userContent);
// Or if HTML is not needed:
element.textContent = userContent;
```

**eval() injection (A03)**
```js
// BEFORE (insecure)
eval(userCode);

// AFTER (secure) — parse JSON if data, use safe alternatives
const data = JSON.parse(userInput); // if expecting data
// If dynamic code is truly needed, use a sandboxed VM
```

**Command injection (A03)**
```js
// BEFORE (insecure)
const { exec } = require('child_process');
exec(`convert ${userFile} output.pdf`);

// AFTER (secure) — execFile with array args, no shell
const { execFile } = require('child_process');
execFile('convert', [userFile, 'output.pdf']);
```

**Hardcoded secret (A02)**
```js
// BEFORE (insecure)
const secret = "my-super-secret-key-12345";

// AFTER (secure) — environment variable
const secret = process.env.APP_SECRET;
if (!secret) throw new Error("APP_SECRET environment variable is required");
```

**Insecure random for tokens (A02)**
```js
// BEFORE (insecure)
const token = Math.random().toString(36).substring(2);

// AFTER (secure)
const { randomBytes } = require('crypto');
const token = randomBytes(32).toString('hex');
```

**Missing cookie security flags (A07)**
```js
// BEFORE (insecure)
res.cookie('session', token, { maxAge: 3600000 });

// AFTER (secure)
res.cookie('session', token, {
  maxAge: 3600000,
  httpOnly: true,
  secure: process.env.NODE_ENV === 'production',
  sameSite: 'strict'
});
```

**JWT algorithm: none (A07)**
```js
// BEFORE (insecure)
jwt.verify(token, secret, { algorithms: ['none'] });

// AFTER (secure)
jwt.verify(token, secret, { algorithms: ['HS256'] });
```

**CORS wildcard with credentials (A05)**
```js
// BEFORE (insecure)
app.use(cors({ origin: '*', credentials: true }));

// AFTER (secure) — explicit allowlist
const allowedOrigins = (process.env.ALLOWED_ORIGINS || '').split(',');
app.use(cors({
  origin: (origin, callback) => {
    if (!origin || allowedOrigins.includes(origin)) callback(null, true);
    else callback(new Error('CORS blocked'));
  },
  credentials: true
}));
```

**SSRF — unvalidated URL fetch (A10)**
```js
// BEFORE (insecure)
const response = await fetch(req.query.url);

// AFTER (secure) — allowlist validation
const ALLOWED_HOSTS = ['api.example.com', 'cdn.example.com'];
const url = new URL(req.query.url);
if (!ALLOWED_HOSTS.includes(url.hostname)) {
  return res.status(400).json({ error: 'URL not allowed' });
}
const response = await fetch(url.toString());
```

**Open redirect (A01)**
```js
// BEFORE (insecure)
res.redirect(req.query.returnUrl);

// AFTER (secure) — validate against allowlist or only allow relative paths
const returnUrl = req.query.returnUrl;
if (returnUrl && returnUrl.startsWith('/') && !returnUrl.startsWith('//')) {
  res.redirect(returnUrl);
} else {
  res.redirect('/dashboard');
}
```

**Path traversal (A01)**
```js
// BEFORE (insecure)
const filePath = path.join(__dirname, 'files', req.params.filename);
fs.readFile(filePath, ...);

// AFTER (secure)
const safeBase = path.resolve(__dirname, 'files');
const filePath = path.resolve(safeBase, req.params.filename);
if (!filePath.startsWith(safeBase + path.sep)) {
  return res.status(400).json({ error: 'Invalid path' });
}
fs.readFile(filePath, ...);
```

---

#### Fix library — Python

**SQL Injection (A03)**
```python
# BEFORE (insecure)
cursor.execute(f"SELECT * FROM users WHERE id = {user_id}")
cursor.execute("SELECT * FROM users WHERE id = " + user_id)

# AFTER (secure) — parameterized query
cursor.execute("SELECT * FROM users WHERE id = %s", (user_id,))
# SQLAlchemy ORM: User.query.filter_by(id=user_id).first()
```

**Command injection (A03)**
```python
# BEFORE (insecure)
import os
os.system(f"convert {user_file} output.pdf")

# AFTER (secure)
import subprocess
subprocess.run(["convert", user_file, "output.pdf"], check=True)
# Note: shell=False is the default; never use shell=True with user input
```

**Hardcoded secret (A02)**
```python
# BEFORE (insecure)
SECRET_KEY = "my-super-secret-key"

# AFTER (secure)
import os
SECRET_KEY = os.environ["SECRET_KEY"]  # Raises KeyError if missing — intentional
```

**Insecure random (A02)**
```python
# BEFORE (insecure)
import random
token = random.token_hex(32)  # random.token_hex doesn't exist; likely random.getrandbits

# AFTER (secure)
import secrets
token = secrets.token_hex(32)
```

**Insecure deserialization (A08)**
```python
# BEFORE (insecure)
import pickle
data = pickle.loads(user_data)

# AFTER (secure) — use JSON or a safe format
import json
data = json.loads(user_data)
# If pickle is truly required, only unpickle data from trusted, signed sources
```

**Unsafe YAML load (A08)**
```python
# BEFORE (insecure)
import yaml
config = yaml.load(file_content)

# AFTER (secure)
import yaml
config = yaml.safe_load(file_content)
# Or: yaml.load(file_content, Loader=yaml.SafeLoader)
```

**XXE — unsafe XML parsing (A03)**
```python
# BEFORE (insecure)
from lxml import etree
tree = etree.parse(user_xml_file)

# AFTER (secure)
from defusedxml import ElementTree
tree = ElementTree.parse(user_xml_file)
# Install: pip install defusedxml
```

**Disabled TLS verification (A02)**
```python
# BEFORE (insecure)
import requests
requests.get(url, verify=False)

# AFTER (secure)
requests.get(url)  # verify=True is the default
# If using a custom CA: requests.get(url, verify='/path/to/ca-bundle.crt')
```

**Missing input validation (A03)**
```python
# BEFORE (insecure)
def create_user(data: dict):
    User.create(**data)

# AFTER (secure) — pydantic validation
from pydantic import BaseModel, EmailStr

class UserCreate(BaseModel):
    name: str
    email: EmailStr
    age: int

def create_user(data: dict):
    validated = UserCreate(**data)  # raises ValidationError if invalid
    User.create(**validated.dict())
```

---

#### Fix library — Go

**SQL Injection (A03)**
```go
// BEFORE (insecure)
query := fmt.Sprintf("SELECT * FROM users WHERE id = '%s'", userID)
rows, err := db.Query(query)

// AFTER (secure) — parameterized query
rows, err := db.QueryContext(ctx, "SELECT * FROM users WHERE id = $1", userID)
// Or MySQL: db.QueryContext(ctx, "SELECT * FROM users WHERE id = ?", userID)
// GORM: db.Where("id = ?", userID).First(&user)
```

**Command Injection (A03)**
```go
// BEFORE (insecure)
cmd := exec.Command("sh", "-c", "convert "+userFile+" output.pdf")
cmd.Run()

// AFTER (secure) — exec.Command with separate arguments, no shell
cmd := exec.CommandContext(ctx, "convert", userFile, "output.pdf")
cmd.Run()
```

**Hardcoded Secret (A02)**
```go
// BEFORE (insecure)
apiKey := "secret-api-key-12345"

// AFTER (secure) — environment variable
apiKey := os.Getenv("API_KEY")
if apiKey == "" {
    return errors.New("API_KEY environment variable is required")
}
```

**Insecure Random for Tokens (A02)**
```go
// BEFORE (insecure)
import "math/rand"
token := fmt.Sprintf("%x", rand.Int63())

// AFTER (secure) — crypto/rand
import (
    "crypto/rand"
    "encoding/hex"
)
b := make([]byte, 32)
if _, err := rand.Read(b); err != nil {
    return err
}
token := hex.EncodeToString(b)
```

**Path Traversal (A01)**
```go
// BEFORE (insecure)
filePath := filepath.Join("/var/www/uploads", reqFilename)
data, err := os.ReadFile(filePath)

// AFTER (secure) — clean and prefix check
baseDir := "/var/www/uploads"
filePath := filepath.Clean(filepath.Join(baseDir, reqFilename))
if !strings.HasPrefix(filePath, filepath.Clean(baseDir)+string(filepath.Separator)) {
    http.Error(w, "Invalid file path", http.StatusBadRequest)
    return
}
data, err := os.ReadFile(filePath)
```

**Missing Cookie Security Flags (A07)**
```go
// BEFORE (insecure)
http.SetCookie(w, &http.Cookie{
    Name:  "session",
    Value: sessionToken,
})

// AFTER (secure)
http.SetCookie(w, &http.Cookie{
    Name:     "session",
    Value:    sessionToken,
    HttpOnly: true,
    Secure:   true,
    SameSite: http.SameSiteStrictMode,
    Path:     "/",
})
```

**SSRF (A10)**
```go
// BEFORE (insecure)
resp, err := http.Get(userProvidedURL)

// AFTER (secure) — validate host against allowlist
parsedURL, err := url.Parse(userProvidedURL)
if err != nil || !isAllowedHost(parsedURL.Hostname()) {
    http.Error(w, "URL not allowed", http.StatusBadRequest)
    return
}
resp, err := client.Get(parsedURL.String())
```

---

#### Fix library — Rust

**SQL Injection (A03)**
```rust
// BEFORE (insecure)
let query = format!("SELECT * FROM users WHERE id = '{}'", user_id);
let rows = sqlx::query(&query).fetch_all(&pool).await?;

// AFTER (secure) — parameterized query macro or bind
let rows = sqlx::query!("SELECT * FROM users WHERE id = $1", user_id)
    .fetch_all(&pool)
    .await?;
// Or with Diesel: users.filter(id.eq(user_id)).load::<User>(&mut conn)?;
```

**Command Injection (A03)**
```rust
// BEFORE (insecure)
let output = std::process::Command::new("sh")
    .arg("-c")
    .arg(format!("convert {} output.pdf", user_file))
    .output()?;

// AFTER (secure) — pass arguments safely without shell
let output = std::process::Command::new("convert")
    .args([&user_file, "output.pdf"])
    .output()?;
```

**Hardcoded Secret (A02)**
```rust
// BEFORE (insecure)
const SECRET_KEY: &str = "my-hardcoded-secret";

// AFTER (secure) — environment variable
let secret_key = std::env::var("SECRET_KEY")
    .expect("SECRET_KEY environment variable is required");
```

**Insecure Random for Tokens (A02)**
```rust
// BEFORE (insecure)
let token: u64 = rand::random();

// AFTER (secure) — cryptographically secure RNG
use rand::rngs::OsRng;
use rand::RngCore;

let mut bytes = [0u8; 32];
OsRng.fill_bytes(&mut bytes);
let token = hex::encode(bytes);
```

**Path Traversal (A01)**
```rust
// BEFORE (insecure)
let path = std::path::Path::new("/var/www/uploads").join(user_filename);
let content = std::fs::read(path)?;

// AFTER (secure) — canonicalize and check prefix
let base = std::path::Path::new("/var/www/uploads").canonicalize()?;
let target = base.join(user_filename).canonicalize()?;
if !target.starts_with(&base) {
    return Err("Path traversal attempt".into());
}
let content = std::fs::read(target)?;
```

**Missing Cookie Security Flags (A07)**
```rust
// BEFORE (insecure)
let cookie = Cookie::new("session", session_token);

// AFTER (secure) — with tower_cookies or actix_web / cookie crate
let cookie = Cookie::build("session", session_token)
    .http_only(true)
    .secure(true)
    .same_site(SameSite::Strict)
    .path("/")
    .finish();
```

**SSRF (A10)**
```rust
// BEFORE (insecure)
let res = reqwest::get(&user_url).await?;

// AFTER (secure) — validate host
let url = reqwest::Url::parse(&user_url)?;
let host = url.host_str().ok_or("Invalid host")?;
if !ALLOWED_HOSTS.contains(&host) {
    return Err("Destination host not allowed".into());
}
let res = client.get(url).send().await?;
```

---

### Phase 4 — Apply fixes

For each finding in scope, execute the appropriate mode:

#### Auto-patch mode

**Mandatory pre-step (do this before editing any file):**

1. Confirm the target is a git repository (`git rev-parse --is-inside-work-tree`). If it is not, stop and ask the user whether to proceed without version control, or to suggest-only.
2. Run `git status --porcelain`. If there are uncommitted changes, ask the user to commit or stash them first, or to explicitly consent to patching on top of a dirty tree. Do not proceed without one of those answers.
3. Record the starting commit (`git rev-parse HEAD`) and tell the user how to revert: `git restore .` / `git checkout -- <files>` for uncommitted patches, or `git reset --hard <starting HEAD>` to discard all changes (only if they have no other work).

**Rule:** never run `git commit`, `git push`, or open a pull request unless the user explicitly asks for it.

1. Read the file at the affected location
2. Apply the fix using Edit
3. Show a before/after diff:
   ```
   ─────────────────────────────────────────────────────
   FIXED: [CRITICAL 9.8] SQL Injection — src/api/orders.js:87
   ─────────────────────────────────────────────────────
   BEFORE (CVSS 9.8 — Critical):
     const query = `SELECT * FROM orders WHERE user_id = ${req.params.id}`;
     const result = await db.query(query);

   AFTER (CVSS 0.0 — Resolved):
     const result = await db.query(
       "SELECT * FROM orders WHERE user_id = ?",
       [req.params.id]
     );

   Score impact: −9.8 pts  |  Risk eliminated: SQL Injection (A03)
   ─────────────────────────────────────────────────────
   ```
4. Continue to the next finding without pausing.
5. If a fix requires a new dependency (e.g., `dompurify`, `defusedxml`), note it but do not run install commands. List all required installs at the end.

#### Suggest mode

For each finding, output:
```
─────────────────────────────────────────────────────
SUGGESTED FIX: [HIGH 7.5] Hardcoded Secret — src/config/db.js:12
─────────────────────────────────────────────────────
File: src/config/db.js, line 12
OWASP: A02 — Cryptographic Failures
CVSS: 7.5 → 0.0 after fix (saves 7.5 pts from negative score)

Replace:
  const dbPassword = "hunter2";

With:
  const dbPassword = process.env.DB_PASSWORD;
  if (!dbPassword) throw new Error("DB_PASSWORD environment variable is required");

Add to your .env file:
  DB_PASSWORD=your_actual_password_here

Add to your .gitignore (if not already):
  .env
─────────────────────────────────────────────────────
```

#### Interactive mode

For each finding, present the finding and proposed fix, then ask:
> "Apply this fix? (yes / no / skip-all-remaining)"

- **yes**: Apply the fix, show diff, continue to next
- **no**: Skip this finding, note it as "declined by user", continue
- **skip-all-remaining**: Stop applying fixes and go to Phase 5

### Phase 5 — Post-remediation scoring

After all fixes are applied (or reviewed in suggest mode):

1. **Recalculate** the negative score based on remaining (unfixed) findings
2. **Show score comparison**:

```
══════════════════════════════════════════════════════
REMEDIATION SUMMARY
══════════════════════════════════════════════════════
Findings fixed:      {N} of {total}
Findings remaining:  {N} (declined or out of scope)

SECURITY SCORE
                    Before    After    Change
Negative score:      72/100   18/100   −54 pts
Positive score:      45/100   45/100   ±0 pts
Balance:             −27      +27      +54 pts
Grade:               D        B        ↑ 2 grades

CVSS ELIMINATED
  Critical (9.0+): {N} fixed  ({CVSS sum} pts removed)
  High (7.0–8.9):  {N} fixed  ({CVSS sum} pts removed)
  Medium (4.0–6.9): {N} fixed ({CVSS sum} pts removed)
  Low (0.1–3.9):    {N} fixed ({CVSS sum} pts removed)

REMAINING VULNERABILITIES
  [HIGH 8.2]   Missing Auth on /admin/users — src/routes/admin.js:45
  [MEDIUM 5.3] Missing CSRF protection — src/api/form.js:89

══════════════════════════════════════════════════════
```

3. If any fixes require new dependencies, list them now:

```
DEPENDENCIES REQUIRED
  npm install dompurify @types/dompurify
  pip install defusedxml pydantic
  go get github.com/go-playground/validator/v10 golang.org/x/crypto/bcrypt
  cargo add validator hex rand sqlx
```

4. Write updated report to `.security-reports/remediate-{date}.md` with the full summary.

### Phase 6 — Update reports

Append a remediation summary to the most recent evaluate or scan report:
```markdown
---
## Remediation Applied — {date}
- {N} findings fixed (auto-patch / suggested / interactive)
- Security grade improved: {before} → {after}
- Remaining: {N} findings
```

## Success criteria

- Every fix is applied using OWASP-recommended patterns (not just symptom suppression)
- Before/after CVSS score is shown for every finding addressed
- Final score comparison shows grade change
- No fix introduces a new vulnerability (e.g., do not replace SQL injection with a different injection)
- Remaining unfixed findings are clearly listed with their CVSS scores
- All required new dependencies are listed at the end
- Remediation report is written to `.security-reports/remediate-{date}.md`
