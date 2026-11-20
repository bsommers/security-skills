---
name: tests
version: 1.0.0
description: |
  Generates a comprehensive test suite, configures test runners, and builds a
  consolidated markdown reporting infrastructure for any JS/TS or Python project.
  Analyzes the codebase, classifies every source file, generates unit + integration
  + E2E tests, installs/configures test runners (Jest/Vitest/Playwright/pytest),
  runs all suites, and produces a unified .test-reports/summary.md with pass/fail
  rates, coverage, and actionable gap analysis.
  Use when asked to "generate tests", "create test suite", "add tests", "write tests",
  "set up testing", "test coverage", or "create test infrastructure".
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

You are a senior test engineer who builds complete, runnable test suites from scratch. You analyze existing code, write tests that prove correct behavior, configure industry-standard runners, and produce consolidated reports that give teams a clear picture of coverage and quality.

## Instructions

Work through each phase in order. Do not skip phases. Present gates at the marked checkpoints before proceeding.

---

### Phase 1 — Detect project stack

Run the following to fingerprint the project:

```bash
# Package manager and runtime
ls package.json yarn.lock pnpm-lock.yaml bun.lockb requirements.txt pyproject.toml setup.py Pipfile 2>/dev/null
# Existing test runner config
ls jest.config.* vitest.config.* playwright.config.* pytest.ini setup.cfg pyproject.toml .noserc 2>/dev/null
# Existing test files
find . -type f \( -name "*.test.*" -o -name "*.spec.*" -o -name "*_test.py" -o -name "test_*.py" \) \
  ! -path "*/node_modules/*" ! -path "*/.venv/*" ! -path "*/dist/*" 2>/dev/null | head -30
# Framework detection
grep -l "react\|vue\|svelte\|angular\|next\|nuxt" package.json 2>/dev/null || true
grep -l "express\|fastify\|koa\|hapi\|nestjs" package.json 2>/dev/null || true
grep -l "fastapi\|flask\|django\|starlette" requirements.txt pyproject.toml 2>/dev/null || true
# Node version and package manager
node --version 2>/dev/null; python3 --version 2>/dev/null; bun --version 2>/dev/null
cat package.json 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('scripts',{}))" 2>/dev/null || true
```

Read `package.json` and any existing config files. Build a stack profile:

```
Stack Profile:
  Runtime:        Node {v} / Python {v} / Both
  Package mgr:    npm / yarn / pnpm / bun / pip / poetry / uv
  JS Framework:   React / Vue / Svelte / Angular / Next.js / none
  Backend:        Express / Fastify / NestJS / Flask / FastAPI / Django / none
  Existing tests: Yes ({N} files) / No
  Existing runner: Jest / Vitest / Playwright / pytest / none
  Test dirs:      {discovered paths or none}
```

Determine the **canonical test runner(s)** to use based on what is already installed or what best fits the stack:

| Stack | Unit runner | E2E runner |
|-------|-------------|------------|
| React/Next.js/TS | Vitest (preferred) or Jest | Playwright |
| Vue/Svelte | Vitest | Playwright |
| Plain Node/Express | Jest or Vitest | Supertest (API) |
| Python FastAPI/Flask | pytest + httpx | Playwright (if UI) |
| Python Django | pytest-django | Playwright (if UI) |
| Full-stack | Vitest + pytest | Playwright |

---

### Phase 2 — Classify source files

Collect all source files:
```bash
find . -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" -o -name "*.mjs" -o -name "*.py" \) \
  ! -path "*/node_modules/*" ! -path "*/.venv/*" ! -path "*/venv/*" ! -path "*/dist/*" \
  ! -path "*/build/*" ! -path "*/.next/*" ! -path "*/coverage/*" ! -path "*/__pycache__/*" \
  ! -name "*.test.*" ! -name "*.spec.*" ! -name "*_test.py" ! -name "test_*.py" \
  2>/dev/null | sort
```

Read each file to classify. Do not classify from filename alone.

**UNIT — classify when the file contains:**
- Pure functions with deterministic outputs (given input → same output, no side effects)
- Business logic: calculations, pricing, tax, discounts, scoring, ranking
- Data transformations: map/filter/reduce, format conversion, normalization
- Validators: schema validation, form validation, business rule enforcement
- Parsers: CSV, JSON, Markdown, custom formats
- State machines: status transitions, workflow steps, FSM reducers
- Utility functions: string manipulation, date math, number formatting
- Class methods with injectable dependencies (testable with mocks)

**INTEGRATION — classify when the file contains:**
- API route handlers (test the full request/response cycle with a real or in-memory DB)
- Service layer calling external dependencies (test with stub/spy, not mock-everything)
- Database models/repositories (test queries against an in-memory or test DB)
- Middleware functions: auth, logging, rate limiting
- Background jobs/workers
- API clients wrapping external services

**E2E — classify when the file contains:**
- Page components with user interactions: forms, buttons, navigation
- Keyboard shortcut handlers
- Multi-step workflows visible to the user
- Authentication flows (login, logout, redirect)
- Data grids, tables with sorting/filtering
- Modals, drawers, tooltips, dropdowns

**SKIP — classify when the file contains:**
- Type definitions only (interfaces, DTOs, enums with no logic)
- Configuration: environment loading, constants files
- Dependency injection setup / module registration
- CSS-in-JS themes, design tokens
- Database migrations / schema definitions
- Simple CRUD with no validation or transformation logic
- Files that are already 100% covered by existing tests

Build the classification table. Note the reason for each classification.

---

### Phase 3 — Present classification and get approval

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 FILE CLASSIFICATION
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

UNIT TESTS ({N} files)
  src/lib/pricing.ts          — calculateDiscount(), applyTax(), roundCurrency()
  src/lib/validators.ts       — validateEmail(), validatePhone(), sanitizeInput()
  src/utils/dates.ts          — formatRelative(), toISO(), diffDays()
  ...

INTEGRATION TESTS ({M} files)
  src/api/routes/orders.ts    — POST /orders, GET /orders/:id, PATCH /orders/:id
  src/services/payment.ts     — processPayment(), refund() with Stripe stub
  ...

E2E TESTS ({K} files)
  src/components/CheckoutForm.tsx  — submit flow, validation errors, success redirect
  src/pages/Dashboard.tsx          — filter panel, table sort, row selection
  ...

SKIP ({J} files)
  src/types/index.ts          — type definitions only
  src/config/env.ts           — environment loading
  ...
```

Ask the user to approve or adjust before continuing.

---

### Phase 4 — Configure test infrastructure

#### 4a — Install missing test runners

Check what's installed and install only what's needed:

```bash
# Check existing installations
ls node_modules/.bin/jest node_modules/.bin/vitest node_modules/.bin/playwright \
   node_modules/.bin/ts-jest 2>/dev/null || true
python3 -m pytest --version 2>/dev/null || true
```

Install missing runners. Use the project's package manager (detect from lockfile):

**Vitest (JS/TS unit + integration)**:
```bash
# npm:
npm install -D vitest @vitest/coverage-v8 @vitest/ui
# or yarn/pnpm/bun equivalents
```

**Playwright (E2E)**:
```bash
npm install -D @playwright/test
npx playwright install chromium
```

**pytest (Python unit + integration)**:
```bash
pip install pytest pytest-asyncio pytest-cov httpx
# For Django: pip install pytest-django
# For FastAPI: pip install anyio[trio]
```

**Supertest (Node API integration, if no frontend)**:
```bash
npm install -D supertest @types/supertest
```

#### 4b — Write runner config files

**vitest.config.ts** (if not already present):
```typescript
import { defineConfig } from 'vitest/config';
import path from 'path';

export default defineConfig({
  test: {
    globals: true,
    environment: 'node',           // change to 'jsdom' if testing React components
    coverage: {
      provider: 'v8',
      reporter: ['text', 'json', 'json-summary', 'html'],
      reportsDirectory: '.test-reports/coverage',
      thresholds: {
        lines: 70,
        functions: 70,
        branches: 60,
        statements: 70,
      },
    },
    reporters: ['default', 'json'],
    outputFile: {
      json: '.test-reports/vitest-results.json',
    },
  },
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
});
```

**playwright.config.ts** (if not already present):
```typescript
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './tests/e2e',
  fullyParallel: true,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: [
    ['html', { outputFolder: '.test-reports/playwright-html' }],
    ['json', { outputFile: '.test-reports/playwright-results.json' }],
    ['list'],
  ],
  use: {
    baseURL: process.env.BASE_URL || 'http://localhost:3000',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
  },
  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
  ],
  webServer: {                     // remove if app is started externally
    command: 'npm run dev',
    url: 'http://localhost:3000',
    reuseExistingServer: !process.env.CI,
    timeout: 30000,
  },
});
```

**pytest.ini** or `pyproject.toml` `[tool.pytest.ini_options]` section (Python):
```ini
[tool.pytest.ini_options]
testpaths = ["tests"]
asyncio_mode = "auto"
addopts = [
  "--cov=src",
  "--cov-report=term-missing",
  "--cov-report=json:.test-reports/pytest-coverage.json",
  "--cov-report=html:.test-reports/pytest-coverage-html",
  "--json-report",
  "--json-report-file=.test-reports/pytest-results.json",
]
```

Add `pytest-json-report` if using pytest:
```bash
pip install pytest-json-report
```

#### 4c — Create test directory structure

```bash
mkdir -p tests/unit tests/integration tests/e2e tests/fixtures tests/helpers
```

Create `tests/helpers/index.ts` (or `.js`) with shared test utilities:
```typescript
// tests/helpers/index.ts
export * from './factories';
export * from './mocks';
export * from './assertions';
```

Create `tests/fixtures/` for static test data (JSON files, fixture objects).

#### 4d — Add test scripts to package.json

Read existing `package.json` and add/update the scripts section:
```json
{
  "scripts": {
    "test": "vitest run",
    "test:watch": "vitest",
    "test:coverage": "vitest run --coverage",
    "test:ui": "vitest --ui",
    "test:e2e": "playwright test",
    "test:e2e:ui": "playwright test --ui",
    "test:all": "npm run test:coverage && npm run test:e2e",
    "test:report": "node scripts/generate-test-report.js"
  }
}
```

---

### Phase 5 — Present test plan and get approval

Before generating any test code, present the complete test plan:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 TEST PLAN
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

UNIT TESTS → tests/unit/

  tests/unit/pricing.test.ts
    ✦ calculateDiscount: standard %, zero discount, negative guard, >100% cap
    ✦ applyTax: US rates, EU VAT, zero-tax regions, compound tax
    ✦ roundCurrency: half-up rounding, banker's rounding flag, 0 decimals

  tests/unit/validators.test.ts
    ✦ validateEmail: valid formats, missing @, missing TLD, Unicode domains
    ✦ validatePhone: E.164, US format, international, empty/null

  ...

INTEGRATION TESTS → tests/integration/

  tests/integration/orders.test.ts
    ✦ POST /orders: valid payload creates order, missing fields → 422, duplicate → 409
    ✦ GET /orders/:id: found → 200, not found → 404, unauthorized → 401
    ✦ PATCH /orders/:id: partial update, optimistic lock conflict → 409

  ...

E2E TESTS → tests/e2e/

  tests/e2e/checkout.spec.ts
    ✦ User fills form and submits → order confirmation page
    ✦ Invalid card → inline error, form stays open
    ✦ Network error → retry prompt

  ...

TOTAL: {N} unit tests | {M} integration tests | {K} E2E scenarios
```

Ask user to approve, cherry-pick, or adjust.

---

### Phase 6 — Generate unit tests

For each approved unit test file, write tests using arrange/act/assert:

```typescript
// tests/unit/pricing.test.ts
import { describe, it, expect } from 'vitest';
import { calculateDiscount, applyTax, roundCurrency } from '@/lib/pricing';

describe('calculateDiscount', () => {
  it('applies percentage discount to price', () => {
    // Arrange
    const price = 100.00;
    const discountPercent = 20;

    // Act
    const result = calculateDiscount(price, discountPercent);

    // Assert
    expect(result).toBe(80.00);
  });

  it('returns original price when discount is zero', () => {
    expect(calculateDiscount(50.00, 0)).toBe(50.00);
  });

  it('clamps discount to 100% (never negative price)', () => {
    expect(calculateDiscount(100.00, 150)).toBe(0);
  });

  it('throws when price is negative', () => {
    expect(() => calculateDiscount(-10, 20)).toThrow('Price must be non-negative');
  });
});
```

**Test writing rules:**
1. One `describe` block per exported function/class
2. One `it` per distinct behavior — not per line of code
3. Test names read as English sentences: "returns X when Y"
4. Cover: happy path, edge cases (zero, null, empty, max), error conditions
5. No logic in tests — no loops, no conditionals, no helper functions that obscure intent
6. Use `expect.objectContaining()` for partial object matching, not deep equality on entire objects
7. Mock external dependencies at the module boundary, not inside functions

For Python (pytest):
```python
# tests/unit/test_pricing.py
import pytest
from src.lib.pricing import calculate_discount, apply_tax, round_currency

class TestCalculateDiscount:
    def test_applies_percentage_discount(self):
        # Arrange / Act / Assert
        assert calculate_discount(100.00, 20) == 80.00

    def test_zero_discount_returns_original_price(self):
        assert calculate_discount(50.00, 0) == 50.00

    def test_clamps_discount_above_100_percent(self):
        assert calculate_discount(100.00, 150) == 0

    def test_raises_on_negative_price(self):
        with pytest.raises(ValueError, match="Price must be non-negative"):
            calculate_discount(-10, 20)
```

---

### Phase 7 — Generate integration tests

For each approved integration test file, write tests that exercise the full request/response cycle:

```typescript
// tests/integration/orders.test.ts
import { describe, it, expect, beforeAll, afterAll, beforeEach } from 'vitest';
import request from 'supertest';
import { app } from '@/app';
import { db } from '@/db';
import { createTestOrder, createTestUser } from '../helpers/factories';

describe('POST /orders', () => {
  let authToken: string;

  beforeAll(async () => {
    await db.migrate.latest();
    const user = await createTestUser();
    authToken = user.token;
  });

  afterAll(async () => {
    await db.destroy();
  });

  beforeEach(async () => {
    await db('orders').delete();
  });

  it('creates order and returns 201 with order id', async () => {
    const payload = { items: [{ productId: 1, qty: 2 }], shippingAddressId: 1 };

    const res = await request(app)
      .post('/orders')
      .set('Authorization', `Bearer ${authToken}`)
      .send(payload)
      .expect(201);

    expect(res.body).toMatchObject({
      id: expect.any(Number),
      status: 'pending',
      items: expect.arrayContaining([expect.objectContaining({ productId: 1 })]),
    });
  });

  it('returns 422 when items array is empty', async () => {
    const res = await request(app)
      .post('/orders')
      .set('Authorization', `Bearer ${authToken}`)
      .send({ items: [] })
      .expect(422);

    expect(res.body.errors).toContainEqual(
      expect.objectContaining({ field: 'items', message: expect.any(String) })
    );
  });

  it('returns 401 when no auth token provided', async () => {
    await request(app)
      .post('/orders')
      .send({ items: [{ productId: 1, qty: 1 }] })
      .expect(401);
  });
});
```

**Integration test rules:**
1. Use a real in-memory or test database — never mock the DB layer in integration tests
2. Clean state between tests (`beforeEach` truncate / rollback)
3. Each test is independent — order of execution must not matter
4. Stub external services (Stripe, SendGrid, S3) at the HTTP level using `msw` or `responses`
5. Test status codes, response shape, and side effects (DB state changed)

For Python FastAPI:
```python
# tests/integration/test_orders.py
import pytest
import pytest_asyncio
from httpx import AsyncClient
from src.main import app

@pytest.fixture
async def client():
    async with AsyncClient(app=app, base_url="http://test") as c:
        yield c

@pytest.fixture(autouse=True)
async def clean_db(test_db_session):
    await test_db_session.execute("DELETE FROM orders")
    await test_db_session.commit()

class TestCreateOrder:
    async def test_creates_order_returns_201(self, client, auth_headers):
        payload = {"items": [{"product_id": 1, "qty": 2}]}
        response = await client.post("/orders", json=payload, headers=auth_headers)
        assert response.status_code == 201
        data = response.json()
        assert data["status"] == "pending"
        assert len(data["items"]) == 1

    async def test_empty_items_returns_422(self, client, auth_headers):
        response = await client.post("/orders", json={"items": []}, headers=auth_headers)
        assert response.status_code == 422
```

---

### Phase 8 — Generate E2E tests

For each approved E2E test file, write Playwright tests targeting real user scenarios:

```typescript
// tests/e2e/checkout.spec.ts
import { test, expect } from '@playwright/test';
import { loginAs, addProductToCart } from '../helpers/e2e-helpers';

test.describe('Checkout flow', () => {
  test.beforeEach(async ({ page }) => {
    await loginAs(page, 'customer@example.com', 'password123');
    await addProductToCart(page, 'Widget Pro');
    await page.goto('/checkout');
  });

  test('completes order and shows confirmation', async ({ page }) => {
    await page.fill('[data-testid="card-number"]', '4242424242424242');
    await page.fill('[data-testid="card-expiry"]', '12/28');
    await page.fill('[data-testid="card-cvc"]', '123');

    await page.click('[data-testid="submit-order"]');

    await expect(page).toHaveURL(/\/orders\/\d+\/confirmation/);
    await expect(page.getByTestId('confirmation-heading')).toBeVisible();
    await expect(page.getByTestId('order-number')).toContainText(/ORD-\d+/);
  });

  test('shows inline error for declined card', async ({ page }) => {
    await page.fill('[data-testid="card-number"]', '4000000000000002'); // Stripe decline
    await page.fill('[data-testid="card-expiry"]', '12/28');
    await page.fill('[data-testid="card-cvc"]', '123');

    await page.click('[data-testid="submit-order"]');

    await expect(page.getByTestId('payment-error')).toContainText(/declined/i);
    await expect(page).not.toHaveURL(/confirmation/);  // stays on checkout
  });

  test('retry button visible after network error', async ({ page }) => {
    await page.route('**/api/orders', route => route.abort('failed'));

    await page.click('[data-testid="submit-order"]');

    await expect(page.getByTestId('retry-button')).toBeVisible();
  });
});
```

**E2E test rules:**
1. Use `data-testid` attributes for selectors — never CSS classes or text content alone
2. If `data-testid` is missing from the component, add it as part of this test-generation task
3. Each test represents a complete user scenario — not just a DOM assertion
4. Use `page.waitForResponse` or `expect(locator).toBeVisible()` — never `page.waitForTimeout`
5. Set up state via API calls (helpers), not via UI — keeps tests fast and focused
6. Tests must be independent — no shared browser state across tests

---

### Phase 9 — Write the report generator script

Create `scripts/generate-test-report.js`:

```javascript
#!/usr/bin/env node
// scripts/generate-test-report.js
// Reads test runner JSON outputs, merges them, and writes .test-reports/summary.md

import fs from 'fs';
import path from 'path';

const REPORTS_DIR = '.test-reports';
const OUTPUT_FILE = path.join(REPORTS_DIR, 'summary.md');

// ─── Loaders ─────────────────────────────────────────────────────────────────

function loadVitestResults() {
  const file = path.join(REPORTS_DIR, 'vitest-results.json');
  if (!fs.existsSync(file)) return null;
  const raw = JSON.parse(fs.readFileSync(file, 'utf8'));
  const suites = raw.testResults || [];
  const tests = suites.flatMap(s => s.assertionResults || []);
  return {
    runner: 'Vitest',
    total: tests.length,
    passed: tests.filter(t => t.status === 'passed').length,
    failed: tests.filter(t => t.status === 'failed').length,
    skipped: tests.filter(t => t.status === 'pending' || t.status === 'skipped').length,
    duration: raw.testResults?.reduce((acc, s) => acc + (s.endTime - s.startTime), 0) || 0,
    failures: tests
      .filter(t => t.status === 'failed')
      .map(t => ({
        name: [...(t.ancestorTitles || []), t.title].join(' › '),
        message: t.failureMessages?.[0]?.split('\n')[0] || '',
        file: t.ancestorTitles?.[0] || '',
      })),
  };
}

function loadPlaywrightResults() {
  const file = path.join(REPORTS_DIR, 'playwright-results.json');
  if (!fs.existsSync(file)) return null;
  const raw = JSON.parse(fs.readFileSync(file, 'utf8'));
  const tests = (raw.suites || []).flatMap(s =>
    (s.specs || []).flatMap(spec =>
      (spec.tests || []).map(t => ({
        ...t,
        title: spec.title,
        file: s.file || '',
      }))
    )
  );
  return {
    runner: 'Playwright',
    total: tests.length,
    passed: tests.filter(t => t.results?.every(r => r.status === 'passed')).length,
    failed: tests.filter(t => t.results?.some(r => r.status === 'failed')).length,
    skipped: tests.filter(t => t.results?.every(r => r.status === 'skipped')).length,
    duration: raw.stats?.duration || 0,
    failures: tests
      .filter(t => t.results?.some(r => r.status === 'failed'))
      .map(t => ({
        name: t.title,
        message: t.results?.find(r => r.status === 'failed')?.errors?.[0]?.message?.split('\n')[0] || '',
        file: t.file,
      })),
  };
}

function loadPytestResults() {
  const file = path.join(REPORTS_DIR, 'pytest-results.json');
  if (!fs.existsSync(file)) return null;
  const raw = JSON.parse(fs.readFileSync(file, 'utf8'));
  const tests = raw.tests || [];
  return {
    runner: 'pytest',
    total: raw.summary?.total || tests.length,
    passed: raw.summary?.passed || 0,
    failed: raw.summary?.failed || 0,
    skipped: raw.summary?.skipped || 0,
    duration: raw.duration || 0,
    failures: tests
      .filter(t => t.outcome === 'failed')
      .map(t => ({
        name: t.nodeid,
        message: t.call?.longrepr?.split('\n').slice(-3).join(' ') || '',
        file: t.nodeid.split('::')[0],
      })),
  };
}

function loadCoverage() {
  // Vitest/Istanbul coverage-summary.json
  const vitestCov = path.join(REPORTS_DIR, 'coverage', 'coverage-summary.json');
  if (fs.existsSync(vitestCov)) {
    const raw = JSON.parse(fs.readFileSync(vitestCov, 'utf8'));
    const total = raw.total || {};
    return {
      source: 'Vitest/v8',
      lines: total.lines?.pct ?? null,
      functions: total.functions?.pct ?? null,
      branches: total.branches?.pct ?? null,
      statements: total.statements?.pct ?? null,
    };
  }
  // pytest coverage JSON
  const pytestCov = path.join(REPORTS_DIR, 'pytest-coverage.json');
  if (fs.existsSync(pytestCov)) {
    const raw = JSON.parse(fs.readFileSync(pytestCov, 'utf8'));
    const totals = raw.totals || {};
    return {
      source: 'pytest-cov',
      lines: totals.percent_covered ?? null,
      functions: null,
      branches: totals.percent_covered_display ?? null,
      statements: null,
    };
  }
  return null;
}

// ─── Grade ───────────────────────────────────────────────────────────────────

function grade(passRate, coverage) {
  const cov = coverage?.lines ?? 0;
  if (passRate === 100 && cov >= 80) return 'A';
  if (passRate >= 95 && cov >= 70) return 'B';
  if (passRate >= 85 && cov >= 60) return 'C';
  if (passRate >= 70) return 'D';
  return 'F';
}

// ─── Render ──────────────────────────────────────────────────────────────────

function bar(pct, width = 30) {
  const filled = Math.round((pct / 100) * width);
  const icon = pct >= 80 ? '█' : pct >= 60 ? '▓' : '░';
  return icon.repeat(filled) + '░'.repeat(width - filled) + ` ${pct.toFixed(1)}%`;
}

function statusIcon(suite) {
  if (suite.failed > 0) return '❌';
  if (suite.skipped > 0 && suite.passed === 0) return '⏭';
  return '✅';
}

function render(suites, coverage) {
  const date = new Date().toISOString().slice(0, 16).replace('T', ' ') + ' UTC';
  const totalTests = suites.reduce((a, s) => a + s.total, 0);
  const totalPassed = suites.reduce((a, s) => a + s.passed, 0);
  const totalFailed = suites.reduce((a, s) => a + s.failed, 0);
  const totalSkipped = suites.reduce((a, s) => a + s.skipped, 0);
  const passRate = totalTests > 0 ? (totalPassed / totalTests) * 100 : 0;
  const overallGrade = grade(passRate, coverage);

  const lines = [];

  lines.push(`# Test Report`);
  lines.push(`**Generated**: ${date}  `);
  lines.push(`**Grade**: ${overallGrade}  `);
  lines.push(``);
  lines.push(`---`);
  lines.push(``);
  lines.push(`## Summary`);
  lines.push(``);
  lines.push(`| Metric | Value |`);
  lines.push(`|--------|-------|`);
  lines.push(`| Total tests | ${totalTests} |`);
  lines.push(`| Passed | ${totalPassed} ✅ |`);
  lines.push(`| Failed | ${totalFailed}${totalFailed > 0 ? ' ❌' : ''} |`);
  lines.push(`| Skipped | ${totalSkipped} |`);
  lines.push(`| Pass rate | ${passRate.toFixed(1)}% |`);
  if (coverage?.lines != null) {
    lines.push(`| Line coverage | ${coverage.lines.toFixed(1)}% |`);
  }
  lines.push(``);

  // Coverage bars
  if (coverage) {
    lines.push(`## Coverage`);
    lines.push(``);
    lines.push(`\`\`\``);
    if (coverage.lines != null)      lines.push(`Lines      ${bar(coverage.lines)}`);
    if (coverage.functions != null)  lines.push(`Functions  ${bar(coverage.functions)}`);
    if (coverage.branches != null)   lines.push(`Branches   ${bar(coverage.branches)}`);
    if (coverage.statements != null) lines.push(`Statements ${bar(coverage.statements)}`);
    lines.push(`\`\`\``);
    lines.push(``);
  }

  // Per-runner results
  lines.push(`## Results by Runner`);
  lines.push(``);
  for (const suite of suites) {
    const rate = suite.total > 0 ? (suite.passed / suite.total * 100) : 0;
    const dur = (suite.duration / 1000).toFixed(1);
    lines.push(`### ${statusIcon(suite)} ${suite.runner}`);
    lines.push(``);
    lines.push(`| | |`);
    lines.push(`|---|---|`);
    lines.push(`| Passed | ${suite.passed} / ${suite.total} |`);
    lines.push(`| Failed | ${suite.failed} |`);
    lines.push(`| Skipped | ${suite.skipped} |`);
    lines.push(`| Duration | ${dur}s |`);
    lines.push(`| Pass rate | ${rate.toFixed(1)}% |`);
    lines.push(``);

    if (suite.failures.length > 0) {
      lines.push(`#### Failures`);
      lines.push(``);
      for (const f of suite.failures) {
        lines.push(`- **${f.name}**`);
        if (f.file) lines.push(`  \`${f.file}\``);
        if (f.message) lines.push(`  > ${f.message}`);
      }
      lines.push(``);
    }
  }

  // Gap analysis
  lines.push(`## Coverage Gaps`);
  lines.push(``);
  if (!coverage || coverage.lines == null) {
    lines.push(`_Coverage data not available. Run tests with --coverage to enable._`);
  } else if (coverage.lines >= 80) {
    lines.push(`Coverage is above 80% — no critical gaps detected.`);
  } else {
    lines.push(`Coverage is below 80%. Run tests with \`--coverage\` and inspect \`.test-reports/coverage/index.html\` for uncovered files.`);
  }
  lines.push(``);

  lines.push(`---`);
  lines.push(``);
  lines.push(`_Re-run: \`npm run test:all && npm run test:report\`_`);

  return lines.join('\n');
}

// ─── Main ────────────────────────────────────────────────────────────────────

fs.mkdirSync(REPORTS_DIR, { recursive: true });

const suites = [loadVitestResults(), loadPlaywrightResults(), loadPytestResults()].filter(Boolean);
const coverage = loadCoverage();

if (suites.length === 0) {
  console.error('No test result JSON files found in .test-reports/');
  console.error('Run tests first: npm run test:all');
  process.exit(1);
}

const report = render(suites, coverage);
fs.writeFileSync(OUTPUT_FILE, report);
console.log(`Test report written → ${OUTPUT_FILE}`);
console.log(`Grade: ${grade(
  suites.reduce((a, s) => a + s.passed, 0) / Math.max(1, suites.reduce((a, s) => a + s.total, 0)) * 100,
  coverage
)}`);
```

Make the script executable:
```bash
chmod +x scripts/generate-test-report.js
```

---

### Phase 10 — Add `data-testid` attributes where missing

For any file classified as E2E, if the component's interactive elements lack `data-testid` attributes, add them now. This is a prerequisite for stable E2E selectors.

Search for interactive elements without testid:
```bash
grep -rn "onClick\|onSubmit\|onChange\|<button\|<input\|<form\|<select" src/ \
  --include="*.tsx" --include="*.jsx" | grep -v "data-testid" | head -20
```

For each missing attribute, apply a minimal edit — add only `data-testid="{component}-{element}"` to the element. Do not refactor anything else.

---

### Phase 11 — Run all tests

Run in this order:

**1. Unit + integration tests**

For JS/TS:
```bash
npm run test:coverage 2>&1 | tail -30
```

For Python:
```bash
python3 -m pytest tests/unit tests/integration -v 2>&1 | tail -40
```

**2. E2E tests** (only if the dev server can be started):

Check if a dev server is configured:
```bash
grep -i "dev\|start\|serve" package.json 2>/dev/null || true
```

If a dev server command exists, run E2E:
```bash
npm run test:e2e 2>&1 | tail -30
```

If E2E cannot run (no server, missing env vars, CI blockers), report a blocker:
```
🛑 E2E BLOCKER: {reason}
E2E tests were written to tests/e2e/ but could not execute.
To run: {instructions for starting the dev server}
```

**3. Generate the report**:
```bash
node scripts/generate-test-report.js
```

For each failing test, determine if it is:
- **Test error** (wrong import path, missing mock, setup issue) → fix the test and re-run
- **Implementation bug** (code returns wrong value, assertion catches real defect) → flag it, do NOT fix the implementation:
  ```
  ⚠️ BUG DISCOVERED: {test name}
  Expected: {expected}
  Actual:   {actual}
  File:     {implementation file}:{line}
  ```

---

### Phase 12 — Commit and report

After all tests pass (or are documented as failing bugs):

```bash
git add tests/ scripts/generate-test-report.js vitest.config.ts playwright.config.ts \
        pytest.ini pyproject.toml .test-reports/summary.md
git commit -m "test: add comprehensive test suite with unit, integration, and E2E tests"
```

Present the final summary:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 TEST SUITE COMPLETE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Grade: {A/B/C/D/F}

| Suite       | Tests | Passed | Failed | Coverage |
|-------------|-------|--------|--------|----------|
| Unit        | {N}   | {n1}   | {n2}   | {lines}% |
| Integration | {M}   | {m1}   | {m2}   | —        |
| E2E         | {K}   | {k1}   | {k2}   | —        |

Report: .test-reports/summary.md

{if bugs:}
⚠️ {N} implementation bugs discovered — review before merging.

{if E2E blocked:}
🛑 E2E tests written but not run — {reason}.

Files Created:
  tests/unit/          {N} test files
  tests/integration/   {M} test files
  tests/e2e/           {K} test files
  tests/helpers/       shared factories, mocks, assertions
  scripts/generate-test-report.js
  vitest.config.ts / playwright.config.ts / pytest.ini
  .test-reports/summary.md

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Success criteria

- [ ] Project stack detected and test runners selected appropriately
- [ ] Every source file classified (TDD / Integration / E2E / Skip) with justification
- [ ] Classification approved by user before tests are written
- [ ] Test plan approved by user before tests are generated
- [ ] Unit tests cover: happy path, edge cases (zero/null/empty/max), error conditions
- [ ] Integration tests cover: success responses, validation errors, auth failures
- [ ] E2E tests cover: complete user scenarios, error states, network failures
- [ ] `data-testid` attributes added to any E2E-targeted elements that lacked them
- [ ] Report generator script at `scripts/generate-test-report.js` is present and runs
- [ ] All test suites executed — no tests marked passing without running
- [ ] Implementation bugs flagged (not fixed) when tests reveal them
- [ ] E2E blockers documented when environment prevents execution
- [ ] `.test-reports/summary.md` written with grade, pass rates, coverage bars, and gap analysis
- [ ] All test files committed
