---
name: security-update-cve
version: 1.2.0
description: |
  Downloads and indexes CVE vulnerability data from OSV.dev bulk package feeds
  (npm, PyPI, Go, crates.io) and NIST NVD REST API 2.0 into ~/.claude/security/cve-db/.
  Builds a fast package-name lookup index for dependency matching in /security-scan.
  Supports on-demand updates, API key acceleration, and incremental sync.
  Use when asked to "update CVE database", "refresh CVE data", "update vulnerability database",
  "download CVE feed", or when /security-scan reports "CVE database not found".
allowed-tools:
  - Bash
  - Read
  - Write
  - Glob
  - AskUserQuestion
---

## Role

You are a security data engineer who maintains a local CVE vulnerability database. You download vulnerability data from official OSV.dev package dumps (npm, PyPI, Go, crates.io) and NIST NVD API 2.0, process them into a fast-query index, and report clearly what was updated.

## Instructions

### Phase 1 — Check current state

1. Check if a database already exists:
   ```bash
   ls ~/.claude/security/cve-db/index/packages.json 2>/dev/null && \
     cat ~/.claude/security/cve-db/meta.json 2>/dev/null || \
     echo "No database found"
   ```

2. Show current status:
   - Last update date (from `meta.json`)
   - Number of CVEs indexed
   - Number of packages indexed
   - Database size on disk

3. Ask the user what to download if not specified:
   > "Which vulnerability data source to download?
   > 1. **OSV.dev Ecosystem Feeds (npm, PyPI, Go, crates.io)** [Recommended] — Fast (<1 min, ~250MB), comprehensive for JS/TS, Python, Go, and Rust packages, direct downloads with no rate limits.
   > 2. **NVD API 2.0 (Recent CVEs)** — Queries NIST NVD REST API 2.0 for recently published / modified CVEs (supports `NVD_API_KEY` for accelerated rate limits).
   > 3. **Full Database (OSV npm, PyPI, Go, crates.io + NVD 2.0)** — Complete multi-source coverage."

   Skip this question if the user specified the scope in their invocation (e.g., `/security-update-cve osv`, `/security-update-cve nvd`, or `/security-update-cve full`).

### Phase 2 — Prepare directories

```bash
mkdir -p ~/.claude/security/cve-db/raw/osv-npm ~/.claude/security/cve-db/raw/osv-pypi ~/.claude/security/cve-db/raw/osv-go ~/.claude/security/cve-db/raw/osv-crates ~/.claude/security/cve-db/index
```

### Phase 3 — Download vulnerability data

#### Option A: OSV.dev bulk feeds (npm, PyPI, Go & crates.io) — Primary & Recommended

OSV.dev provides complete, authoritative vulnerability databases aggregated from NIST NVD, GitHub Security Advisories (GHSA), and ecosystem package registries. Downloads take seconds with zero rate limits.

```bash
echo "Downloading OSV.dev feeds for npm, PyPI, Go, and crates.io..."
curl -L --progress-bar \
  "https://osv-vulnerabilities.storage.googleapis.com/npm/all.zip" \
  -o ~/.claude/security/cve-db/raw/osv-npm.zip
curl -L --progress-bar \
  "https://osv-vulnerabilities.storage.googleapis.com/PyPI/all.zip" \
  -o ~/.claude/security/cve-db/raw/osv-pypi.zip
curl -L --progress-bar \
  "https://osv-vulnerabilities.storage.googleapis.com/Go/all.zip" \
  -o ~/.claude/security/cve-db/raw/osv-go.zip
curl -L --progress-bar \
  "https://osv-vulnerabilities.storage.googleapis.com/crates.io/all.zip" \
  -o ~/.claude/security/cve-db/raw/osv-crates.zip

echo "Extracting archives..."
unzip -q -o ~/.claude/security/cve-db/raw/osv-npm.zip -d ~/.claude/security/cve-db/raw/osv-npm/
unzip -q -o ~/.claude/security/cve-db/raw/osv-pypi.zip -d ~/.claude/security/cve-db/raw/osv-pypi/
unzip -q -o ~/.claude/security/cve-db/raw/osv-go.zip -d ~/.claude/security/cve-db/raw/osv-go/
unzip -q -o ~/.claude/security/cve-db/raw/osv-crates.zip -d ~/.claude/security/cve-db/raw/osv-crates/
```

#### Option B: NIST NVD REST API 2.0

NIST retired legacy JSON 1.1 feeds (`nvdcve-1.1-*.json.gz`) and replaced them with NVD REST API 2.0 (`https://services.nvd.nist.gov/rest/json/cves/2.0`).

Run the Python fetcher to download recent CVE pages (handles pagination, ISO 8601 timestamps, and rate limits):

```bash
cat > /tmp/fetch-nvd-2.py << 'EOF'
#!/usr/bin/env python3
import json, os, sys, time, urllib.request, urllib.parse
from datetime import datetime, timedelta
from pathlib import Path

RAW_DIR = Path.home() / ".claude/security/cve-db/raw"
RAW_DIR.mkdir(parents=True, exist_ok=True)

api_key = os.environ.get("NVD_API_KEY", "").strip()
# NVD rate limit: 5 req/30s without key (6s delay), 50 req/30s with key (0.6s delay)
delay = 0.6 if api_key else 6.0

end_dt = datetime.utcnow()
start_dt = end_dt - timedelta(days=120)

base_url = "https://services.nvd.nist.gov/rest/json/cves/2.0"
headers = {"User-Agent": "security-skills/1.1"}
if api_key:
    headers["apiKey"] = api_key

start_index = 0
results_per_page = 2000
page = 0

print(f"Fetching CVEs modified since {start_dt.strftime('%Y-%m-%d')} from NVD API 2.0...", file=sys.stderr)

while True:
    params = {
        "lastModStartDate": start_dt.strftime("%Y-%m-%dT00:00:00.000"),
        "lastModEndDate": end_dt.strftime("%Y-%m-%dT23:59:59.999"),
        "resultsPerPage": results_per_page,
        "startIndex": start_index
    }
    url = f"{base_url}?{urllib.parse.urlencode(params)}"
    req = urllib.request.Request(url, headers=headers)
    
    try:
        time.sleep(delay)
        with urllib.request.urlopen(req, timeout=60) as resp:
            data = json.loads(resp.read().decode("utf-8"))
    except Exception as e:
        print(f"Error fetching page at startIndex={start_index}: {e}", file=sys.stderr)
        break

    total_results = data.get("totalResults", 0)
    vulns = data.get("vulnerabilities", [])
    if not vulns:
        break

    out_file = RAW_DIR / f"nvd-api2-page{page}.json"
    with open(out_file, "w") as f:
        json.dump(data, f)
    
    print(f"  Saved page {page} ({len(vulns)} CVEs, total: {total_results}) -> {out_file.name}", file=sys.stderr)
    
    start_index += len(vulns)
    page += 1
    if start_index >= total_results:
        break

print(f"NVD API 2.0 fetch complete: {page} pages downloaded.", file=sys.stderr)
EOF
python3 /tmp/fetch-nvd-2.py
```

### Phase 4 — Build package index

Create `~/.claude/security/cve-db/index/packages.json` — a map of `"package-name" → [cve-entry, ...]`.
The indexer processes OSV feeds (npm, PyPI) and NVD 2.0 / legacy JSON files.

Each CVE entry includes:
```json
{
  "cve_id": "CVE-2023-26159",
  "cvss_v3": 7.3,
  "severity": "HIGH",
  "summary": "follow-redirects before 1.15.4 allows prototype pollution",
  "published": "2023-12-14",
  "affected_versions": "< 1.15.4",
  "references": ["https://github.com/follow-redirects/follow-redirects/issues/1"]
}
```

**Build index script**:

```bash
cat > /tmp/build-cve-index.py << 'EOF'
#!/usr/bin/env python3
import json, os, glob, re, sys
from pathlib import Path

RAW_DIR = Path.home() / ".claude/security/cve-db/raw"
INDEX_DIR = Path.home() / ".claude/security/cve-db/index"
INDEX_DIR.mkdir(parents=True, exist_ok=True)

packages = {}
seen_cves = set()
total_cves = 0
total_with_packages = 0

# 1. Process OSV.dev files (npm, PyPI, Go, crates.io)
for osv_dir in [RAW_DIR / "osv-npm", RAW_DIR / "osv-pypi", RAW_DIR / "osv-go", RAW_DIR / "osv-crates"]:
    if not osv_dir.exists():
        continue
    print(f"Processing OSV {osv_dir.name}...", file=sys.stderr)
    for osv_file in osv_dir.glob("*.json"):
        try:
            with open(osv_file) as f:
                item = json.load(f)
        except Exception:
            continue

        vuln_id = item.get("id", "")
        if not vuln_id:
            continue

        cve_aliases = [a for a in item.get("aliases", []) if a.startswith("CVE-")]
        display_id = cve_aliases[0] if cve_aliases else vuln_id

        summary = (item.get("summary") or item.get("details") or "")[:200]
        published = (item.get("published") or "")[:10]
        
        cvss_v3 = None
        severity = "UNKNOWN"
        for s in item.get("severity", []):
            if s.get("type") in ("CVSS_V3", "CVSS_V31"):
                score_str = str(s.get("score", ""))
                m = re.search(r"(\d+\.\d+)$", score_str)
                if m:
                    cvss_v3 = float(m.group(1))
                elif score_str.startswith("CVSS:3."):
                    cvss_v3 = 7.5
                if cvss_v3 is not None:
                    severity = "CRITICAL" if cvss_v3 >= 9 else "HIGH" if cvss_v3 >= 7 else "MEDIUM" if cvss_v3 >= 4 else "LOW"

        refs = []
        for r in item.get("references", []):
            if isinstance(r, dict) and "url" in r:
                refs.append(r["url"])
            elif isinstance(r, str):
                refs.append(r)
        refs = refs[:3]

        for affected in item.get("affected", []):
            pkg_name = affected.get("package", {}).get("name", "").lower()
            if not pkg_name:
                continue
            ranges = []
            for r in affected.get("ranges", []):
                events = r.get("events", [])
                intro = next((e.get("introduced") for e in events if "introduced" in e), None)
                fixed = next((e.get("fixed") for e in events if "fixed" in e), None)
                if intro or fixed:
                    ranges.append(f">= {intro or '0'}" + (f", < {fixed}" if fixed else ""))

            entry = {
                "cve_id": display_id,
                "cvss_v3": cvss_v3,
                "severity": severity,
                "summary": summary,
                "published": published,
                "affected_versions": "; ".join(ranges[:3]) if ranges else "see advisory",
                "references": refs
            }
            packages.setdefault(pkg_name, []).append(entry)
            total_with_packages += 1
            if display_id not in seen_cves:
                seen_cves.add(display_id)
                total_cves += 1

# 2. Process NVD files (both 2.0 API format and legacy 1.1 format)
for nvd_file in sorted(RAW_DIR.glob("nvd-*.json")):
    print(f"Processing {nvd_file.name}...", file=sys.stderr)
    try:
        with open(nvd_file) as f:
            data = json.load(f)
    except Exception as e:
        print(f"  Skipping {nvd_file.name}: {e}", file=sys.stderr)
        continue

    # Check format: NVD 2.0 has "vulnerabilities", NVD 1.1 has "CVE_Items"
    if "vulnerabilities" in data:
        # NVD API 2.0 format
        for item in data.get("vulnerabilities", []):
            cve = item.get("cve", {})
            cve_id = cve.get("id", "")
            if not cve_id:
                continue

            desc_list = cve.get("descriptions", [])
            summary = next((d["value"] for d in desc_list if d.get("lang") == "en"), "")
            published = (cve.get("published") or "")[:10]

            cvss_v3 = None
            severity = "UNKNOWN"
            metrics = cve.get("metrics", {})
            if "cvssMetricV31" in metrics and metrics["cvssMetricV31"]:
                m = metrics["cvssMetricV31"][0].get("cvssData", {})
                cvss_v3 = m.get("baseScore")
                severity = m.get("baseSeverity", "UNKNOWN")
            elif "cvssMetricV30" in metrics and metrics["cvssMetricV30"]:
                m = metrics["cvssMetricV30"][0].get("cvssData", {})
                cvss_v3 = m.get("baseScore")
                severity = m.get("baseSeverity", "UNKNOWN")
            elif "cvssMetricV2" in metrics and metrics["cvssMetricV2"]:
                cvss_v2 = metrics["cvssMetricV2"][0].get("cvssData", {}).get("baseScore")
                if cvss_v2 is not None:
                    cvss_v3 = round(cvss_v2 * 0.9, 1)
                    severity = "HIGH" if cvss_v2 >= 7 else "MEDIUM" if cvss_v2 >= 4 else "LOW"

            refs = [r.get("url", "") for r in cve.get("references", []) if isinstance(r, dict) and "url" in r][:3]

            pkg_names = set()
            version_info = []
            for config in cve.get("configurations", []):
                for node in config.get("nodes", [config]):
                    for match in node.get("cpeMatch", []) or node.get("cpe_match", []):
                        cpe = match.get("criteria") or match.get("cpe23Uri", "")
                        parts = cpe.split(":")
                        if len(parts) >= 5:
                            vendor = parts[3]
                            product = parts[4]
                            for name in [product, f"{vendor}/{product}", vendor]:
                                name = name.replace("_", "-").lower()
                                if name and name not in ("*", "-", "a", "o"):
                                    pkg_names.add(name)
                        vi = match.get("versionStartIncluding") or match.get("versionStartExcluding")
                        ve = match.get("versionEndExcluding") or match.get("versionEndIncluding")
                        if vi or ve:
                            version_info.append(f"{vi or '*'} to {ve or '*'}")

            if not pkg_names:
                continue

            entry = {
                "cve_id": cve_id,
                "cvss_v3": cvss_v3,
                "severity": severity,
                "summary": summary[:200],
                "published": published,
                "affected_versions": "; ".join(version_info[:3]) if version_info else "see NVD",
                "references": refs
            }
            for pkg in pkg_names:
                packages.setdefault(pkg, []).append(entry)
                total_with_packages += 1
            if cve_id not in seen_cves:
                seen_cves.add(cve_id)
                total_cves += 1

    elif "CVE_Items" in data:
        # Legacy NVD 1.1 format
        for item in data.get("CVE_Items", []):
            cve_id = item.get("cve", {}).get("CVE_data_meta", {}).get("ID", "")
            if not cve_id:
                continue

            cvss_v3 = None
            severity = "UNKNOWN"
            metrics = item.get("impact", {})
            if "baseMetricV3" in metrics:
                cvss_data = metrics["baseMetricV3"].get("cvssV3", {})
                cvss_v3 = cvss_data.get("baseScore")
                severity = cvss_data.get("baseSeverity", "UNKNOWN")
            elif "baseMetricV2" in metrics:
                cvss_v2 = metrics["baseMetricV2"].get("cvssV2", {}).get("baseScore")
                if cvss_v2 is not None:
                    cvss_v3 = round(cvss_v2 * 0.9, 1)
                    severity = "HIGH" if cvss_v2 >= 7 else "MEDIUM" if cvss_v2 >= 4 else "LOW"

            desc_data = item.get("cve", {}).get("description", {}).get("description_data", [])
            summary = next((d["value"] for d in desc_data if d.get("lang") == "en"), "")
            published = item.get("publishedDate", "")[:10]
            refs = [r["url"] for r in item.get("cve", {}).get("references", {}).get("reference_data", [])[:3]]

            pkg_names = set()
            for node in item.get("configurations", {}).get("nodes", []):
                for cpe_match in node.get("cpe_match", []):
                    cpe = cpe_match.get("cpe23Uri", "")
                    parts = cpe.split(":")
                    if len(parts) >= 5:
                        vendor = parts[3]
                        product = parts[4]
                        for name in [product, f"{vendor}/{product}", vendor]:
                            name = name.replace("_", "-").lower()
                            if name and name not in ("*", "-", "a", "o"):
                                pkg_names.add(name)

            if not pkg_names:
                continue

            version_info = []
            for node in item.get("configurations", {}).get("nodes", []):
                for cpe_match in node.get("cpe_match", []):
                    vi = cpe_match.get("versionStartIncluding") or cpe_match.get("versionStartExcluding")
                    ve = cpe_match.get("versionEndExcluding") or cpe_match.get("versionEndIncluding")
                    if vi or ve:
                        version_info.append(f"{vi or '*'} to {ve or '*'}")

            entry = {
                "cve_id": cve_id,
                "cvss_v3": cvss_v3,
                "severity": severity,
                "summary": summary[:200],
                "published": published,
                "affected_versions": "; ".join(version_info[:3]) if version_info else "see NVD",
                "references": refs
            }
            for pkg in pkg_names:
                packages.setdefault(pkg, []).append(entry)
                total_with_packages += 1
            if cve_id not in seen_cves:
                seen_cves.add(cve_id)
                total_cves += 1

# Deduplicate entries per package
for pkg, entries in packages.items():
    dedup = {}
    for e in entries:
        cid = e["cve_id"]
        if cid not in dedup:
            dedup[cid] = e
        elif not dedup[cid].get("cvss_v3") and e.get("cvss_v3"):
            dedup[cid] = e
    packages[pkg] = list(dedup.values())

output_path = INDEX_DIR / "packages.json"
with open(output_path, "w") as f:
    json.dump(packages, f, separators=(",", ":"))

print(f"Index built: {len(packages)} unique packages, {total_cves} total CVEs/advisories indexed.")
print(f"Written to: {output_path}")
EOF
python3 /tmp/build-cve-index.py
```

### Phase 5 — Write metadata

```bash
python3 - << 'EOF'
import json, os
from pathlib import Path
from datetime import date

meta_path = Path.home() / ".claude/security/cve-db/meta.json"
index_path = Path.home() / ".claude/security/cve-db/index/packages.json"

with open(index_path) as f:
    packages = json.load(f)

total_cves = sum(len(v) for v in packages.values())

meta = {
    "last_updated": str(date.today()),
    "packages_indexed": len(packages),
    "total_cve_entries": total_cves,
    "sources": ["osv.dev", "nvd.nist.gov"],
    "db_path": str(index_path)
}

with open(meta_path, "w") as f:
    json.dump(meta, f, indent=2)

print(f"Metadata written: {meta}")
EOF
```

### Phase 6 — Report results

Print a summary:
```
CVE Database Updated
──────────────────────────────────────
Last updated:     {today's date}
Packages indexed: {N}
Total CVE entries:{N}
Sources:          OSV.dev (npm/PyPI/Go/crates.io), NIST NVD API 2.0
Database size:    {size}
Location:         ~/.claude/security/cve-db/

{if updating existing DB:}
Previous update:  {old date}
New CVEs added:   {N}
Packages added:   {N}
──────────────────────────────────────
Run /security-scan to use the updated database.
```

If the download fails (network error, rate limit), report clearly:
```
Download failed: {error message}

Alternative options:
1. OSV.dev direct feeds (npm, PyPI, Go, crates.io): https://google.github.io/osv.dev/data/#data-dumps
2. NIST NVD API 2.0 key request: https://nvd.nist.gov/developers/request-an-api-key
   (set export NVD_API_KEY="your-key" to avoid rate limiting)
3. Place downloaded JSON/zip files manually into ~/.claude/security/cve-db/raw/ and re-run /security-update-cve.
```

## Success criteria

- [ ] CVE / vulnerability feeds downloaded to `~/.claude/security/cve-db/raw/`
- [ ] Package index built at `~/.claude/security/cve-db/index/packages.json`
- [ ] Metadata written to `~/.claude/security/cve-db/meta.json`
- [ ] Terminal summary shows packages indexed and CVE count
- [ ] Dual-support for OSV.dev and NIST NVD API 2.0
- [ ] `/security-scan` can immediately query the index with jq
