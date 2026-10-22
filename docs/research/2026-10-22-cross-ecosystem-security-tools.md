# Cross-ecosystem security tools: Node/TypeScript, Rust, Python

Research for a possible reopening of ADR 0005 (Go-only scope) into a language-neutral core plus per-ecosystem packs, with a configurable tool source (local shell, ephemeral run, MCP server). For each Go capability the repo relies on, it asks which tools in Node/TypeScript, Rust and Python do the same job, and how faithfully.

Checked on 2026-10-22. Versions seen on that date: npm 12.2.1 (`latest` dist-tag), osv-scanner v2.7.0 (2026-10-12), Argus v0.4.0 (2026-10-21, commit `d72ff79d0407754f12af036a61a069ae9c7c33ff`), semgrep 1.182.1, opengrep v1.31.0, bandit 1.9.4, ruff 0.17.1, pip-audit 2.10.1, uv 0.13.5, cargo-audit 0.22.2, cargo-deny 0.20.2, cargo-fuzz 0.13.2, proptest 1.12.0, fast-check 4.10.2, @jazzer.js/core 4.0.0, Hypothesis 6.170.5, atheris 3.1.0 (taken from the npm, PyPI and crates.io registry APIs and GitHub releases). A claim marked **unverified** is one I could not trace to a primary source.

## The Go baseline being mapped

| Capability | Go tool | Property the repo depends on |
|---|---|---|
| SCA with reachability | `govulncheck` | Symbol-level call graph: each vulnerability is called, imported or required. Only called ones become findings; the rest are the **context** count (`skills/go-security-audit/SKILL.md`, step 4). |
| Ephemeral SAST | `go run github.com/securego/gosec/v2/cmd/gosec@v2.29.0` | Exact version, the whole module graph fixed by the tool's own `go.mod`, every module hash checked against the Go checksum database, a transparency log ([go.dev/ref/mod#checksum-database](https://go.dev/ref/mod#checksum-database)). Nothing is installed (ADR 0003). |
| Dependency integrity | `go mod verify` | Re-hashes the module cache against `go.sum` ([go.dev/ref/mod#go-mod-verify](https://go.dev/ref/mod#go-mod-verify)). |
| Fuzz / property tests | native fuzzing | The seed corpus (`f.Add` and `testdata/fuzz/`) runs inside a plain `go test` ([go.dev/doc/security/fuzz](https://go.dev/doc/security/fuzz/)). |
| Installed CI | `actions/checkout`, `actions/setup-go`, `golang/govulncheck-action` | First-party actions pinned by full SHA (`skills/go-security-setup/assets/security.yml`). |

---

## 1. SCA with reachability (the govulncheck equivalent)

| Tool | Ecosystems | Reachability | License / cost | Source |
|---|---|---|---|---|
| `npm audit` | Node | **None.** Matches package versions against advisories via the registry's bulk advisory endpoint, and flags "meta-vulnerabilities" (packages that depend on vulnerable ones). It has no notion of whether code is called. | Free, part of npm | [npm audit docs (v11.21.1)](https://docs.npmjs.com/cli/v11/commands/npm-audit) |
| osv-scanner | Node, Python, Rust (lockfiles: `package-lock.json`, `pnpm-lock.yaml`, `yarn.lock`, `bun.lock`; `uv.lock`, `poetry.lock`, `pdm.lock`, `Pipfile.lock`, `pylock.toml`, `requirements.txt`; `Cargo.lock`) | **Go: real** (it uses the govulncheck library, on by default). **Rust: experimental**, opt-in with `--call-analysis=rust`; it compiles the code and reads DWARF debug info, **runs dependencies' `build.rs`**, and does not support proc-macro, dynamically linked or non-Rust-linking dependencies. **JavaScript and Python: none.** The only call-analysis languages in source are `go` (on), `rust` (off) and `jar` (off). | Apache-2.0, Google | [docs/scan-source.md](https://github.com/google/osv-scanner/blob/ffeae830de4c0dd2dfa692c276e5db221b778a1a/docs/scan-source.md#scanning-with-call-analysis), [callanalysis_parser.go](https://github.com/google/osv-scanner/blob/ffeae830de4c0dd2dfa692c276e5db221b778a1a/cmd/osv-scanner/internal/helper/callanalysis_parser.go), [supported lockfiles](https://github.com/google/osv-scanner/blob/ffeae830de4c0dd2dfa692c276e5db221b778a1a/docs/supported_languages_and_lockfiles.md) |
| cargo-audit | Rust | **None.** Its README points to [`reachsec`](https://github.com/xizheyin/reachsec), "an experimental standalone companion", for function-level context. reachsec belongs to an individual user, not to RustSec. RustSec advisories *can* list vulnerable function paths in an optional `[affected.functions]` table, which is raw material for manual or grep-level checks. | Apache-2.0/MIT, RustSec | [cargo-audit README](https://github.com/rustsec/rustsec/blob/010f12aea2d7c663704ddd4c22d351ea5629e402/cargo-audit/README.md), [advisory-db README](https://github.com/rustsec/advisory-db) |
| cargo-deny (`check advisories`) | Rust | **None.** It uses the same RustSec database, plus `bans`, `licenses` and `sources` checks. | Apache-2.0/MIT, Embark Studios | [cargo-deny README](https://github.com/EmbarkStudios/cargo-deny) |
| pip-audit | Python | **None**, by its own statement: "`pip-audit` is **not** a static code analyzer. It analyzes dependency trees, not code." Data sources are PyPI, OSV or ESMS. `--locked` reads `pyproject.toml` / `pylock.*.toml`. | Apache-2.0, PyPA | [pip-audit README, Security Model](https://github.com/pypa/pip-audit/blob/828e77a4d4aa6bee8d315681db6928771d951a7c/README.md#security-model) |
| `uv audit` | Python | **None documented.** It checks "known vulnerabilities, as well as 'adverse' statuses such as deprecation and quarantine", and needs network. | Free, Astral | [uv CLI reference](https://docs.astral.sh/uv/reference/cli/#uv-audit) |
| Semgrep Supply Chain | Node (JS/TS), Python, Rust, among others | **Real, but rule-based and direct dependencies only.** A finding is *reachable* when a Semgrep rule matches the vulnerable usage pattern in your code. Transitive dependencies get no reachability analysis. Where no rule exists, the finding says "No reachability analysis". The supported-languages page lists JS, TS, Python and Rust as GA with reachability. | **Commercial** (Semgrep AppSec Platform), "free for up to 10 contributors" | [overview](https://docs.semgrep.dev/semgrep-supply-chain/overview), [supported languages](https://docs.semgrep.dev/supported-languages), [CE vs Pro](https://docs.semgrep.dev/semgrep-pro-vs-oss) |
| Snyk Open Source reachability | JS/TS (npm, Yarn, pnpm), Python (pip, poetry, pipenv); **not Rust** | **Real, call-graph** ("the call graph of your application in relation to the call graph between the open-source dependencies"). GA for JS/TS and Python; CLI/CI integration is Early Access. | **Commercial** (plan not stated on the page; **unverified**) | [Snyk reachability analysis](https://docs.snyk.io/manage-risk/prioritize-issues-for-fixing/reachability-analysis) |
| Socket reachability | JS/TS, Python, Rust | Three tiers. *Dependency Reachability* is **package-level only** (Free plan and up). *Precomputed* is function-level, transitive dependencies only (Team and up). *Full Application* is function-level across app and dependencies (**Enterprise only**). Rust is **class-level**, not function-level. | **Commercial** above the package-level tier | [Socket reachability docs](https://docs.socket.dev/docs/reachability-analysis) |

The finding, per ecosystem:

- **Node/TS:** no free or open-source tool gives govulncheck's called/imported/required split. `npm audit` and osv-scanner see versions only. Function-level reachability exists only in commercial products: Snyk (GA), Socket (Enterprise for whole-app), and Semgrep Supply Chain (rule-based, direct dependencies, free up to 10 contributors).
- **Rust:** reachability is either experimental and runs `build.rs` (osv-scanner `--call-analysis=rust`), or commercial (Semgrep, and Socket at class level). The RustSec `affected.functions` metadata enables a weaker, grep-based check.
- **Python:** no free or open-source reachability. pip-audit says plainly it is not a code analyzer. Only Snyk, Socket and Semgrep (commercial) offer it.

## 2. SAST runnable ephemerally at an exact, integrity-verified version

The Go guarantee has three parts: (a) an exact version of the tool, (b) its whole dependency graph fixed by the tool's own `go.mod`, and (c) every module's hash checked against a public transparency log, so a registry cannot serve different bytes to different users or change a published version unnoticed. No other ecosystem here has (c). The table says which of (a) and (b) each mechanism gives.

| Ecosystem | Tool | Ephemeral mechanism | What the integrity check really is | Source |
|---|---|---|---|---|
| Node | ESLint + `eslint-plugin-security` (4.2.0) or `@microsoft/eslint-plugin-sdl` (1.1.0) | `npx --yes -p eslint@10.13.0 -p eslint-plugin-security@4.2.0 eslint …` installs into "a folder in the npm cache" | (a) Yes for the named packages. (b) **No.** npx documents no lockfile use, and npm 12 no longer reads `npm-shrinkwrap.json` "inside dependency tarballs", so a published tool cannot lock its own transitive dependencies (eslint has 30 direct dependencies). Tarballs are checked against an SRI `integrity` value when one is supplied (pacote raises `EINTEGRITY`). For a fresh resolve that value comes from the registry's own metadata, so it is trust-on-first-use. How npx passes integrity is not documented (**unverified**). | [npx docs](https://docs.npmjs.com/cli/v11/commands/npx), [npm 12.0.0 release notes](https://github.com/npm/cli/releases/tag/v12.0.0), [pacote README](https://github.com/npm/pacote#options) |
| Node | same | A canonical `package.json` plus `package-lock.json` shipped as a skill asset, run with `npm ci --ignore-scripts` in a temporary directory | (a) and (b) yes: `npm ci` "will exit with an error, instead of updating the package lock", and the lockfile holds a `sha512` SRI per package. Not a transparency log. In npm 12, dependency lifecycle scripts are blocked by default. | [npm ci](https://docs.npmjs.com/cli/v11/commands/npm-ci), [package-lock.json](https://docs.npmjs.com/cli/v11/configuring-npm/package-lock-json), [npm 12.0.0](https://github.com/npm/cli/releases/tag/v12.0.0) |
| Node, Python, Rust | Semgrep CE 1.182.1 | `uvx semgrep@1.182.1` or `pipx run` | (a) yes. (b) **no**: semgrep's wheel declares range dependencies (`attrs>=21.3`, `click~=8.4.2`, `opentelemetry-sdk~=1.37.0`, …) that resolve at run time. Wheel hashes come from the index, so trust-on-first-use. uv's tool docs mention neither hash verification nor transitive locking. CE analysis is single-file/single-function. Registry rules are under the "Semgrep Rules License v1.0", not OSI. | [PyPI JSON for semgrep](https://pypi.org/pypi/semgrep/json), [uv tools](https://docs.astral.sh/uv/concepts/tools/), [CE vs Pro](https://docs.semgrep.dev/semgrep-pro-vs-oss), [semgrep-rules LICENSE](https://github.com/semgrep/semgrep-rules/blob/develop/LICENSE) |
| Node, Python, Rust | Opengrep v1.31.0 (fork of Semgrep CE) | Download one release binary | Release assets ship `.sig` and `.cert` per binary (Sigstore-style keyless signing). How they are meant to be verified was not checked (**unverified**). A single binary means no transitive resolution at run time. | [opengrep v1.31.0 release](https://github.com/opengrep/opengrep/releases/tag/v1.31.0) |
| Rust | Clippy | Comes with the toolchain (`rustup component`); the version follows `rust-toolchain.toml` | (a) yes, through the toolchain pin. Integrity: rustup "performs all downloads over HTTPS, but does not yet validate signatures of downloads". **Clippy has no security lint group** (correctness, suspicious, complexity, perf, style, pedantic, restriction, cargo, nursery, deprecated). | [rustup security](https://rust-lang.github.io/rustup/security.html), [Clippy lints](https://doc.rust-lang.org/clippy/lints.html) |
| Rust | any crate binary (cargo-audit, cargo-geiger, …) | `cargo install --locked --version X --root <tmp>` | (a) yes. (b) yes with `--locked`, which uses the crate's packaged `Cargo.lock`. Each downloaded `.crate` is SHA-256-checked against the registry index `cksum` ("failed to verify the checksum of …"). It is **not ephemeral**: it builds from source and installs into the root's `bin`. Cargo has no "run without installing" command. Not a transparency log. | [cargo install](https://doc.rust-lang.org/cargo/commands/cargo-install.html), [cargo download.rs](https://github.com/rust-lang/cargo/blob/cf29d0e0b1f7b03c4ceda5211cc4dc493bfc542e/src/sources/registry/download.rs), [index `cksum`](https://doc.rust-lang.org/cargo/reference/registry-index.html) |
| Python | Bandit 1.9.4 (PyCQA) | `uvx bandit@1.9.4` | (a) yes. (b) **no**: it depends on `PyYAML>=5.3.1`, `stevedore>=1.20.0` and unpinned `rich`. Full pinning needs a requirements file with `--require-hashes` (see section 3). Bandit is the closest Python analogue of gosec. | [PyPI JSON for bandit](https://pypi.org/pypi/bandit/json) |
| Python | Ruff 0.17.1, `S` rules (flake8-bandit port, about 70 active, some in preview) | `uvx ruff@0.17.1 check --select S` | (a) yes, and (b) trivially: the ruff wheel declares **no dependencies**, so the exact version fixes everything that runs. Hash is trust-on-first-use from PyPI. | [PyPI JSON for ruff](https://pypi.org/pypi/ruff/json), [Ruff rules](https://docs.astral.sh/ruff/rules/) |

Notes:

- PyPI and npm both support provenance attestations (Sigstore). `npm audit signatures` verifies registry signatures and provenance of *installed* packages ([npm audit](https://docs.npmjs.com/cli/v11/commands/npm-audit)). Whether `uvx`, `pip` or `npx` verify attestations at run time is **unverified**: I found no documentation saying they do.
- Argus avoids the rules-integrity problem for SAST with a fixed ruleset embedded in its binary, which "is never fetched from a registry and never read from the repository under review" (`pkg/security/rules/semgrep.yaml` at v0.4.0). It has 15 rules: Python 5, JS/TS 4, Go 3, Java 3, and none for Rust.

## 3. Dependency integrity (the `go mod verify` equivalent)

| Ecosystem | Mechanism | What it checks | Gap against `go mod verify` | Source |
|---|---|---|---|---|
| Node | `npm ci` | Fails if `package.json` and the lockfile disagree, and never writes the lockfile. Tarballs are checked against the lockfile's SRI `integrity` (via pacote, `EINTEGRITY`). | Checks at install time only. | [npm ci](https://docs.npmjs.com/cli/v11/commands/npm-ci), [pacote](https://github.com/npm/pacote#options) |
| Node | `npm cache verify` | "verifying the integrity of the cache index and all cached data" | Checks the npm cache, not `node_modules`. | [npm cache](https://github.com/npm/cli/blob/latest/docs/lib/content/commands/npm-cache.md) |
| Node | `npm audit signatures` | Registry signatures and provenance attestations of installed packages | No equivalent in Go; it answers a different question: who published the package. | [npm audit](https://docs.npmjs.com/cli/v11/commands/npm-audit) |
| Rust | `cargo build/test --locked` (or `--frozen`) | Errors if `Cargo.lock` is missing or would change. Each `.crate` is SHA-256-checked against the index on download, and lockfile checksums are compared with what the source provides. | Checks at download time only. I found no command that re-hashes the extracted sources in `~/.cargo/registry` (**unverified** that none exists). | [cargo build options](https://doc.rust-lang.org/cargo/commands/cargo-build.html), [download.rs](https://github.com/rust-lang/cargo/blob/cf29d0e0b1f7b03c4ceda5211cc4dc493bfc542e/src/sources/registry/download.rs), [resolve.rs](https://github.com/rust-lang/cargo/blob/cf29d0e0b1f7b03c4ceda5211cc4dc493bfc542e/src/resolver/resolve.rs) |
| Rust | `cargo deny check sources` | Restricts which registries and git sources are allowed | A policy check, not a hash check. | [cargo-deny](https://github.com/EmbarkStudios/cargo-deny) |
| Python | `pip install --require-hashes -r requirements.txt` | Every requirement must be pinned (`==`, URL or path) and every dependency, transitive included, must carry a hash. md5, sha1 and sha224 are rejected. Since pip 26.2, one hash turns hash mode on for the whole file. | Checks at install time only. `setup.py` installs bypass it. | [pip secure installs (v26.2.2)](https://pip.pypa.io/en/stable/topics/secure-installs/) |
| Python | `uv sync --locked` / `uv run --locked` | Errors if `uv.lock` is stale. `uv.lock` records a `sha256` per sdist and wheel (seen in [uv's own uv.lock](https://github.com/astral-sh/uv/blob/0.13.5/uv.lock)), and `verify-hashes` defaults to true. Optional preview malware check against OSV. | Checks at install time only. | [uv sync](https://docs.astral.sh/uv/concepts/projects/sync/), [uv settings](https://docs.astral.sh/uv/reference/settings/#verify-hashes) |

No ecosystem has a transparency log like the Go checksum database, and none documents a command that re-verifies already-extracted dependencies against the lockfile the way `go mod verify` re-verifies the module cache. The closest equivalents are: run the frozen install again (`npm ci`, `cargo … --locked`, `uv sync --locked`), and on npm, `npm audit signatures`.

## 4. Property testing and fuzzing; does a seed corpus run in the normal test command?

| Ecosystem | Tool | Kind | Seed or regression inputs in the normal test run? | Source |
|---|---|---|---|---|
| Node | fast-check 4.10.2 (`@fast-check/jest` 2.3.0, `@fast-check/vitest` 0.5.0) | Property-based | **Yes.** Properties run inside Jest or Vitest. The `examples` setting runs explicit cases "before the other values generated by the framework". There is no persisted failure database on that page; failures replay through `seed`/`path` (**unverified** detail). | [fast-check user-definable values](https://fast-check.dev/docs/configuration/user-definable-values/) |
| Node | Jazzer.js 4.0.0 (Code Intelligence) | Coverage-guided (libFuzzer) | **Yes, under Jest.** "Regression mode", which replays stored inputs under a plain `jest`, "is the default execution mode". Fuzzing needs `JAZZER_FUZZ=1`. Only a Jest integration is documented. | [jest-integration.md](https://github.com/CodeIntelligenceTesting/jazzer.js/blob/main/docs/jest-integration.md) |
| Rust | proptest 1.12.0 | Property-based | **Yes.** Failures persist under `proptest-regressions/` (the seed, not the value), replay before new cases, and the docs advise committing them. | [proptest failure persistence](https://proptest-rs.github.io/proptest/proptest/failure-persistence.html) |
| Rust | cargo-fuzz 0.13.2 | Coverage-guided (libFuzzer) | **No.** It needs the nightly compiler ("uses the `-Z` compiler flag"). The corpus lives in `fuzz/corpus/<target>` and runs only via `cargo fuzz run`, never via `cargo test`. The Rust Fuzz Book has a CI smoke-test example. | [setup](https://rust-fuzz.github.io/book/cargo-fuzz/setup.html), [project.rs `corpus_for`](https://github.com/rust-fuzz/cargo-fuzz/blob/main/src/project.rs), [Fuzzing in CI](https://github.com/rust-fuzz/book/blob/master/src/cargo-fuzz/ci.md) |
| Python | Hypothesis 6.170.5 | Property-based | **Yes.** The pytest plugin is on by default. `@example` cases "always" run before generation. Failures are saved in `.hypothesis/examples` and replayed in the `reuse` phase. | [Hypothesis API reference](https://hypothesis.readthedocs.io/en/latest/reference/api.html) |
| Python | Atheris 3.1.0 (Google) | Coverage-guided (libFuzzer) | **No.** The corpus is passed on the command line, and no pytest integration is documented. Linux and macOS, Python 3.11–3.14. | [google/atheris README](https://github.com/google/atheris) |

Go's native fuzzing is both a property test and a coverage-guided fuzzer, and its seed corpus runs in `go test`. Every other ecosystem splits these two jobs across separate tools. The property-based tools (fast-check, proptest, Hypothesis) all keep committed examples or regressions inside the normal test command. Of the coverage-guided fuzzers, only Jazzer.js does (Jest only). cargo-fuzz and Atheris do not.

## 5. GitHub Actions: who publishes them, and are they first-party?

| Ecosystem | Action | Publisher | First-party for the tool? | Notes relevant to ADR 0003 |
|---|---|---|---|---|
| Node | `actions/setup-node` v7.1.0 | GitHub | Yes (runtime) | `npm ci`, `npm audit` and `npm audit signatures` are `run:` steps and need no extra action. |
| Python | `actions/setup-python` v7.1.0 | GitHub | Yes (runtime) | |
| Python | `astral-sh/setup-uv` v10.3.2 | Astral | Yes, for uv | |
| Python | `pypa/gh-action-pip-audit` v1.1.0 (2024-08-08) | PyPA | Yes, for pip-audit | Installs `pip-audit ~= 2.0, >= 2.5.6` from its `requirements.txt` (a **range**, so the SHA pin does not fix the pip-audit version) ([requirements.txt @ fb241f5](https://github.com/pypa/gh-action-pip-audit/blob/fb241f581674a1bb995061d62504857a9ea4b69e/requirements.txt)). |
| Python | `PyCQA/bandit-action` v1.0.1 | PyCQA | Yes, for Bandit | Its `action.yml` runs `pip install bandit[sarif,toml]` with **no version**, and references `actions/setup-python@v7`, `actions/checkout@v7` and `github/codeql-action/upload-sarif@v4.39.0` by **tag**, not SHA ([action.yml @ 044eb14](https://github.com/PyCQA/bandit-action/blob/044eb14cd9d9e339d23c8f6511f217824a10a256/action.yml)). |
| Rust | none from rust-lang | — | — | No `rust-lang/setup-rust` repository exists. GitHub's Ubuntu 24.04 runner ships rustup 1.29.1 and Cargo/Rust 1.99.0 ([runner image readme](https://github.com/actions/runner-images/blob/main/images/ubuntu/Ubuntu2404-Readme.md)). Common third-party options: `dtolnay/rust-toolchain` (an individual's account, with a single `v1` release from 2022) and `actions-rust-lang/setup-rust-toolchain` (a community org, not the Rust project). |
| Rust | `rustsec/audit-check` v2.0.0 (2024-09-23) | RustSec org | Yes, for cargo-audit | Calls `cargo.findOrInstall('cargo-audit')` with no version, so the cargo-audit version is not fixed by the SHA pin ([main.ts @ 858dc40](https://github.com/rustsec/audit-check/blob/858dc40f52ca2b8570b7a997c1c4e35c6fc9a432/src/main.ts)). Whether RustSec is an official Rust project body is **unverified**. |
| Rust | `EmbarkStudios/cargo-deny-action` v2.1.1 | Embark Studios | Yes, for cargo-deny | A Docker action. Its base image is digest-pinned, but it `curl`s the cargo-deny 0.20.2 release tarball **without a checksum check** ([Dockerfile @ 9c67a82](https://github.com/EmbarkStudios/cargo-deny-action/blob/9c67a826e39827395bfa619cd85cb2aaeb43cfaa/Dockerfile)). |
| All | `google/osv-scanner-action` v2.7.0 | Google | Yes, for osv-scanner | Offered as **reusable workflows** (`…/osv-scanner-reusable-pr.yml@v2.7.0`). Its example permissions include `security-events: write` and `actions: read` for SARIF upload ([github-action.md](https://github.com/google/osv-scanner/blob/ffeae830de4c0dd2dfa692c276e5db221b778a1a/docs/github-action.md)). |
| All | `semgrep/semgrep-action` | Semgrep | — | **Archived** (last release 2020). |
| All | `github/codeql-action`, `actions/dependency-review-action` v5.0.0 | GitHub | Yes | Private repositories need GitHub Advanced Security ([codeql-action README](https://github.com/github/codeql-action), [dependency-review README](https://github.com/actions/dependency-review-action)). ADR 0003 already rejected CodeQL for this reason. |

## 6. MCP servers that expose these tools

### Argus (`argusappsec/argus` v0.4.0, `d72ff79`)

- **Release state changed since the design session.** `docs/design/2026-10-21-design-session.md` records the latest release as v0.3.0. v0.4.0 was published 2026-10-21T14:39Z, and its tag points at the commit that contains the Tool Catalog (`pkg/security/catalog.go`) and the Toolbox deployment shape (`docs/guide/deployment-shapes.md`).
- **Toolbox mode:** with no LLM provider configured, the daemon "serves its scanners, your organization's knowledge and its skills to the AI tool you already use" over `/mcp` (`docs/guide/getting-started.md`). `buildRegistry` in `pkg/daemon/session.go` exposes every installed catalogued scanner. An automatic review withholds scanners whose trust level is not "safe"; MCP calls get all of them.
- **Scanner catalog** (`docs/guide/scanners/index.md`, generated from the catalog):

| Argus tool | Scanner | Reads | Trust level | Relevance to Node / Rust / Python |
|---|---|---|---|---|
| `run_osv_scanner` | OSV-Scanner | any language (lockfiles) | safe | SCA for all three. Argus passes `--no-call-analysis=go` on automatic reviews and never `--call-analysis=rust`. Its JSON parser reads `groups` (`ids`, `aliases`, `max_severity`) but **not** `experimentalAnalysis.called`, so even Go call data is not surfaced as called/uncalled (`pkg/security/osv.go`). |
| `run_sast` | Opengrep, or Semgrep as a fallback | any language | safe | One fixed embedded ruleset of 15 rules: Python 5, JS/TS 4, Go 3, Java 3, **Rust 0** (`pkg/security/rules/semgrep.yaml`). |
| `run_gitleaks` | Gitleaks | any | safe | Secrets |
| `run_trivy` | Trivy | Terraform, Kubernetes, Dockerfile | safe | IaC |
| `run_zizmor` | zizmor | GitHub Actions | safe | Workflows (same check family as this repo's unpinned-actions pattern) |
| `run_gosec`, `run_govulncheck` | gosec, govulncheck | Go | drives a toolchain | Go only |

Argus has **no** Node-, Rust- or Python-specific scanner: no npm audit, cargo-audit or cargo-deny, pip-audit, Bandit, Clippy, or reachability-capable SCA for those languages.

### First-party vendor MCP servers

| Server | How it starts | Tools | Auth | Source |
|---|---|---|---|---|
| OSV-Scanner | `osv-scanner experimental-mcp` (stdio, or `--sse`). Added in v2.2.4 (#2256), labelled experimental. | `scan_vulnerable_dependencies`, `get_vulnerability_details`, `ignore_vulnerability` | none | [mcp/command.go](https://github.com/google/osv-scanner/blob/ffeae830de4c0dd2dfa692c276e5db221b778a1a/cmd/osv-scanner/mcp/command.go), [CHANGELOG](https://github.com/google/osv-scanner/blob/ffeae830de4c0dd2dfa692c276e5db221b778a1a/CHANGELOG.md) |
| Semgrep | Now inside the `semgrep` binary. The standalone `semgrep/mcp` repository is **archived** and points to `cli/src/semgrep/mcp`. A hosted endpoint is also advertised (`mcp.semgrep.ai`). | `semgrep_scan`, `semgrep_scan_with_custom_rule`, `semgrep_scan_remote`, `semgrep_findings`, `semgrep_scan_supply_chain`, `get_abstract_syntax_tree`, `semgrep_rule_schema`, `get_supported_languages`, `semgrep_whoami` | Supply chain "requires an active Semgrep daemon"; whether that needs a login was not confirmed (**unverified**) | [server.py @ 087e93b](https://github.com/semgrep/semgrep/blob/087e93b3a1fdf44f97bc92b5b9c2ba221cb2488b/cli/src/semgrep/mcp/server.py), [semgrep/mcp](https://github.com/semgrep/mcp) |
| Snyk | `snyk mcp` in the Snyk CLI (≥ v1.1298.0). The docs show `-t sse --experimental`; the exact stdio flag is **unverified**. | `snyk_sca_scan`, `snyk_code_scan`, `snyk_iac_scan`, `snyk_container_scan`, `snyk_sbom_scan`, `snyk_secret_scan`, `snyk_package_health_check`, `snyk_trust`, `snyk_auth`, … `snyk_sca_scan` "may execute third-party ecosystem tools … on your machine". | Snyk account or token (`SNYK_TOKEN`) | [snyk/studio-mcp README @ b4285af](https://github.com/snyk/studio-mcp), [Snyk MCP troubleshooting](https://docs.snyk.io/agent-security/agentic-security-with-snyk-studio/troubleshooting.md) |
| Socket | Hosted at `https://mcp.socket.dev/` (OAuth), or self-hosted with an API key | `depscore`, among others | Socket account | [SocketDev/socket-mcp](https://github.com/SocketDev/socket-mcp) |

The OSV-Scanner MCP server hard-codes `CallAnalysisStates: {"go": true}` (`cmd/osv-scanner/mcp/command.go`), so even over MCP it gives no reachability for Node, Python or Rust.

---

## Implications for a core + packs split

Rules referred to below: a **signal** becomes a **finding** only once the code confirms it; called vulnerabilities are High findings and the rest are a **context** count; every written file is a CI-verified canonical asset (ADR 0002); installed CI uses official tools only, pinned by SHA (ADR 0003).

### Node/TypeScript

- **Faithful:**
  - Dependency integrity: `npm ci` with the lockfile's SRI hashes, plus `npm audit signatures`.
  - Seed or regression inputs in the normal test run: fast-check, and Jazzer.js regression mode under Jest.
  - An installed CI built only on first-party pieces (`actions/checkout`, `actions/setup-node`, and `npm` run steps).
- **Weaker: SCA.** There is no free reachability. The govulncheck rule "called = High finding, the rest = context" has no input to work from: `npm audit` and osv-scanner output is all at the imported/required level. Two options, as facts rather than a choice:
  - Report every advisory as a finding. That reverses the current noise policy.
  - Treat SCA output as a **signal**, like gosec: the agent greps for the vulnerable package's import and use and confirms at `file:line`. The evidence then comes from the agent, not from a tool trace, so it is weaker than govulncheck's example traces.
  - Commercial reachability (Snyk, Socket Enterprise, Semgrep up to 10 contributors) would conflict with "official tools only" and would need an account.
- **Weaker: SAST.**
  - There is no Node analogue of gosec with gosec's integrity. `npx pkg@x.y.z` pins only the top-level package; transitive dependencies resolve at run time, and npm 12 ignores shrinkwrap inside tarballs.
  - Fixed transitive dependencies need a canonical `package.json` plus `package-lock.json` asset run with `npm ci --ignore-scripts`. That fits ADR 0002 (Dependabot can track it), but it is an install in a temporary directory, not a `go run`.
  - Neither path has a transparency-log check.
- **Breaks ADR 0002/0003?** The ADR 0003 *install* side does not break. The audit-side promise "verified by the checksum database, installs nothing" cannot be kept word for word for any Node SAST tool.

### Rust

- **Faithful:**
  - Dependency integrity at download time: `--locked` plus the SHA-256 `cksum`.
  - Property tests with committed regressions under `cargo test`: proptest.
- **Weaker: SCA.**
  - cargo-audit and cargo-deny have no reachability.
  - osv-scanner's Rust call analysis is experimental and runs `build.rs`, which conflicts with a read-only audit. Argus classes this kind of scanner as "drives a toolchain", and Argus does not enable Rust call analysis anyway.
  - The RustSec `affected.functions` field allows a grep-level check. That makes SCA a **signal** confirmed at `file:line`, not tool-proven reachability.
- **Weaker: SAST.** Clippy has no security group, Argus's ruleset has no Rust rules, and Semgrep Rust has 40+ *Pro* rules. Ephemeral runs are not possible: `cargo install --locked --root <tmp>` builds from source and installs, and rustup does not verify signatures.
- **Weaker: fuzzing.** cargo-fuzz needs nightly and its corpus does not run in `cargo test`. The "seed corpus runs in the normal test command" property holds only for proptest.
- **Gaps that break ADR 0003:** no Rust-project first-party setup action exists. The first-party scanner actions don't pin their tool:
  - `rustsec/audit-check` installs an unversioned cargo-audit, and its last release is from 2024.
  - `cargo-deny-action` downloads its tarball without a checksum.

  A Rust pack's installed CI would have to `cargo install --locked --version` the scanner itself, or rely on the preinstalled toolchain. Whether cargo-audit counts as an "official" Rust tool is a governance question this research did not settle (**unverified**).

### Python

- **Faithful:**
  - Dependency integrity: `pip --require-hashes`, or `uv.lock` sha256 with `verify-hashes` on by default and `uv sync --locked`.
  - Committed examples and regressions in the normal test run: Hypothesis `@example` plus database replay under pytest.
  - SAST closest to gosec: Bandit. Ruff's `S` rules come in a dependency-free wheel, so `uvx ruff@x.y.z` fixes everything that runs (trust-on-first-use from PyPI, no transparency log).
- **Weaker: SCA.** pip-audit, `uv audit` and osv-scanner have no reachability; pip-audit says so itself. The same signal-not-finding consequence applies as for Node.
- **Weaker: ephemeral runs.** `uvx bandit@x` and `uvx semgrep@x` leave transitive dependencies unpinned. Full pinning needs a hashed requirements asset, which fits ADR 0002 but is an install.
- **Weaker: fuzzing.** Atheris has no pytest integration.
- **Gaps against ADR 0003:** the first-party actions do not pin their tool. `pypa/gh-action-pip-audit` installs a range (`~= 2.0, >= 2.5.6`). `PyCQA/bandit-action` installs an unpinned bandit and uses tag-pinned inner actions, which the audit's own unpinned-actions pattern would flag. An installed CI with fixed tool versions would use `actions/setup-python` or `astral-sh/setup-uv` plus `run:` steps against a hashed requirements file or `uv.lock`.

### Across packs

- The core concepts carry over unchanged: **finding**, **signal**, **evidence**, **hypothesis**, **logic finding**, **mechanical fix** and **setup answers**.
- **Context** (the unreachable count) carries over only where reachability exists, which today means Go everywhere and Rust experimentally.
- The audit's version-pinning mechanism (ADR 0002: the fixture's `go.mod` `tool` directive tracked by Dependabot) would need a per-ecosystem equivalent: a `package.json` devDependency, a hashed requirements file or `uv.lock`, and, for a Cargo binary, no equivalent was found (**unverified** whether Dependabot can track a `cargo install` version).
- Each pack would also need its own fixture under `testdata/` so its canonical assets can run in this repo's CI.
- Tool source as a seam:
  - Argus Toolbox covers only language-neutral scanners for these ecosystems: osv-scanner without reachability, and SAST with a 15-rule set.
  - The OSV MCP server gives the same versions-only SCA.
  - The Semgrep, Snyk and Socket MCP servers bring reachability or richer SAST, but each needs a vendor account for those parts.
