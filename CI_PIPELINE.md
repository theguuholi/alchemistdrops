# CI Pipeline Documentation

## Overview

This document describes the comprehensive CI/CD pipeline setup for the Alchemistdrops project. The pipeline has been crafted to provide fast, reliable, and thorough code quality checks while maintaining efficiency through smart caching strategies.

## Architecture

The CI pipeline is split into three separate workflows, each serving a specific purpose:

### 1. **Main CI Pipeline** (`.github/workflows/ci.yml`)
- **Triggers:** Push and Pull Requests to `main`/`master` branches
- **Purpose:** Fast feedback on every code change
- **Strategy:** Parallel execution with shared caching

### 2. **Deployment Pipeline** (`.github/workflows/deploy.yml`)
- **Triggers:** Push to `main` branch, manual dispatch
- **Purpose:** Automated deployment to Gigalixir
- **Strategy:** Sequential, production-focused

### 3. **Quality Checks** (`.github/workflows/quality-checks.yml`)
- **Triggers:** Manual dispatch, weekly schedule
- **Purpose:** Deep, comprehensive quality analysis
- **Strategy:** Thorough checking with detailed reporting

## Main CI Pipeline Details

### Job Dependency Graph

```
     ┌────────────┐
     │   Setup    │
     │  (Cache)   │
     └─────┬──────┘
           │
     ┌─────┴──────┬──────────┬──────────┬──────────┐
     │            │          │          │          │
┌────▼────┐  ┌───▼───┐  ┌───▼────┐  ┌──▼───┐  ┌──▼──┐
│ Format  │  │ Lint  │  │Security│  │Dialyzer│ │Test │
│         │  │(Credo)│  │(Sobelow)│ │       │  │     │
└─────────┘  └───────┘  └────────┘  └───────┘  └─────┘
```

### Jobs Breakdown

#### Setup Job
- **Purpose:** Install and cache all dependencies once
- **Duration:** ~8-12 minutes (cold), ~30 seconds (warm)
- **Caching:**
  - Dependencies (`deps/`)
  - Compiled artifacts (`_build/`)
  - Cache key includes: OS, OTP version, Elixir version, `mix.lock` hash

#### Format Job
- **Command:** `mix format --check-formatted`
- **Purpose:** Ensure consistent code formatting
- **Duration:** ~10-15 seconds
- **Fails if:** Any file is not properly formatted

#### Lint Job
- **Command:** `mix credo --strict`
- **Purpose:** Static code analysis and best practices
- **Duration:** ~30-45 seconds
- **Checks:** Code consistency, readability, potential issues

#### Security Job
- **Command:** `mix sobelow --config`
- **Purpose:** Security vulnerability scanning
- **Duration:** ~45-60 seconds
- **Environment:** `dev` (requires compiled code)
- **Checks:** Common security issues in Phoenix applications

#### Dialyzer Job
- **Command:** `mix dialyzer --format github`
- **Purpose:** Static type analysis
- **Duration:** ~2-3 minutes (with PLT cache)
- **Extra Caching:** PLT files cached separately for efficiency
- **Benefits:** Catches type errors before runtime

#### Test Job
- **Command:** `mix test --trace`
- **Purpose:** Execute full test suite
- **Duration:** ~1-3 minutes
- **Services:** PostgreSQL 16 database
- **Features:**
  - Runs all tests with detailed output
  - Generates HTML coverage reports
  - Uploads coverage as artifacts (7-day retention)
  - Warnings treated as errors during compilation

## Caching Strategy

### Why Unique Caches?

Each workflow job uses the **same cache key** but different jobs have different needs:

```yaml
Key Pattern: $OS-mix-otp$VERSION-elixir$VERSION-$HASH(mix.lock)
Example: ubuntu-mix-otp27.0-elixir1.18.3-abc123def456
```

### Cache Invalidation

Caches are automatically invalidated when:
1. **Dependencies change** - `mix.lock` hash changes
2. **Versions change** - OTP or Elixir version updates
3. **OS changes** - Different runner OS

### Cache Warmup

The `setup` job warms the cache once, then all subsequent jobs benefit from:
- Pre-installed dependencies
- Pre-compiled dependencies
- Compiled project artifacts

This reduces total CI time from ~30 minutes to **3-5 minutes** on average.

## Configuration Files

### `.dialyzer_ignore.exs`
```elixir
[
  # Add patterns for warnings to ignore
  # ~r"lib/generated_code.ex"
]
```

### `.sobelow.conf`
```elixir
[
  verbose: true,
  router: "AlchemistdropsWeb.Router",
  exit: "high",              # Fail on high-severity issues
  threshold: "medium",        # Report medium and above
  ignore: ["Config.CSP"]     # Known exceptions
]
```

### `mix.exs` - Dialyzer Configuration
```elixir
dialyzer: [
  plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
  plt_add_apps: [:mix, :ex_unit],
  flags: [:error_handling, :underspecs],
  ignore_warnings: ".dialyzer_ignore.exs"
]
```

## Local Development Workflow

### Quick Precommit Check
```bash
mix precommit
```

This runs all CI checks locally:
1. ✅ Compile with warnings as errors
2. ✅ Check for unused dependencies
3. ✅ Verify code formatting
4. ✅ Run Credo linting (strict mode)
5. ✅ Run Sobelow security scan
6. ✅ Run Dialyzer type checking
7. ✅ Run full test suite

### Individual Commands
```bash
# Format code
mix format

# Check formatting without changes
mix format --check-formatted

# Run linter
mix credo --strict

# Security scan
mix sobelow --config --verbose

# Type checking
mix dialyzer

# Tests with coverage
mix test
mix coveralls.html

# Check unused dependencies
mix deps.unlock --check-unused
```

### First-Time Setup

After cloning the repository:

```bash
# Install dependencies
mix deps.get

# Setup database
mix ecto.setup

# Build Dialyzer PLT (first time only, ~5-10 minutes)
mix dialyzer --plt

# Run all checks
mix precommit
```

## GitHub Secrets Configuration

For deployment to work, configure these repository secrets:

```
Settings → Secrets and variables → Actions → New repository secret
```

Required secrets:
- **GIGALIXIR_USERNAME** - Your Gigalixir account email
- **GIGALIXIR_PASSWORD** - Your Gigalixir account password
- **GIGALIXIR_APP** - Your app name (e.g., `alchemistdrops-prod`)
- **SSH_PRIVATE_KEY** - SSH private key for deployment

## Performance Metrics

### Cold Cache (First Run)
- Setup: ~8-12 minutes
- Format: ~45 seconds
- Lint: ~1 minute
- Security: ~1.5 minutes
- Dialyzer: ~8 minutes (building PLT)
- Tests: ~2 minutes
- **Total: ~15-20 minutes**

### Warm Cache (Typical Run)
- Setup: ~30 seconds (cache hit)
- Format: ~15 seconds
- Lint: ~30 seconds
- Security: ~45 seconds
- Dialyzer: ~2 minutes (PLT cached)
- Tests: ~1-2 minutes
- **Total: ~3-5 minutes**

### Parallel Execution Benefit
Without parallelization: ~15 minutes
With parallelization: ~5 minutes
**Speedup: 3x faster**

## Troubleshooting

### "Dialyzer: Could not find PLT file"
**Solution:** The workflow automatically creates the PLT. If it fails, ensure `priv/plts/` directory exists and is writable.

### "Database connection failed in tests"
**Solution:** Check that PostgreSQL service is running in the workflow. The CI uses PostgreSQL 16 by default.

### "Cache not restoring"
**Solution:** Check that your cache key hasn't changed. If you updated Elixir/OTP versions, the cache will rebuild (expected behavior).

### "Format check failed"
**Solution:** Run `mix format` locally and commit the changes.

### "Credo warnings"
**Solution:** Review Credo output and fix issues or add specific exceptions in `.credo.exs`.

### "Sobelow security issues"
**Solution:** Address security issues or add them to `.sobelow.conf` ignore list if they're false positives.

### "Tests pass locally but fail in CI"
**Common causes:**
- Database state differences
- Time zone issues
- Async test issues
- Missing environment variables

**Solution:** Run tests with `MIX_ENV=test mix test` locally to replicate CI environment.

## Best Practices

### 1. Keep Dependencies Updated
```bash
mix deps.update --all
mix hex.outdated
```

### 2. Monitor CI Performance
- Watch for increasing build times
- Clear caches if builds become unstable
- Update action versions regularly

### 3. Address Warnings Promptly
- Treat all warnings as errors
- Don't let tech debt accumulate
- Fix Dialyzer issues incrementally

### 4. Write Tests First
- Ensure good coverage (aim for >80%)
- Use `mix test.watch` during development
- Add tests for bug fixes

### 5. Use Quality Checks Workflow
- Run comprehensive checks before major releases
- Schedule weekly runs to catch drift
- Review detailed reports for insights

## Migration from Old Workflows

### Changes Made

**Removed:**
- `.github/workflows/dialyzer.yml` ❌
- `.github/workflows/lint.yml` ❌
- `.github/workflows/gigalixir.yml` ❌

**Added:**
- `.github/workflows/ci.yml` ✅ (Main pipeline)
- `.github/workflows/deploy.yml` ✅ (Deployment)
- `.github/workflows/quality-checks.yml` ✅ (Deep analysis)
- `.dialyzer_ignore.exs` ✅ (Dialyzer config)

**Updated:**
- `mix.exs` - Added Dialyzer configuration
- `.sobelow.conf` - Improved security settings
- `.gitignore` - Added PLT files
- `mix.exs` aliases - Enhanced precommit task

### Benefits of New Setup

1. **Faster Feedback** - Parallel execution saves time
2. **Comprehensive Checks** - All quality tools integrated
3. **Better Caching** - Shared cache across jobs
4. **Cleaner Structure** - Separated concerns in different workflows
5. **Modern Actions** - Using latest stable versions (v4/v5)
6. **Better Documentation** - Clear explanations and troubleshooting

## Future Enhancements

Potential improvements to consider:

1. **Code Coverage Badges** - Add coverage reporting to README
2. **Performance Benchmarking** - Track performance regressions
3. **Dependency Scanning** - Add automated dependency vulnerability checks
4. **Deploy Previews** - Create preview environments for PRs
5. **Matrix Testing** - Test against multiple Elixir/OTP versions
6. **Slack Notifications** - Alert team on CI failures

## Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Dialyxir Documentation](https://hexdocs.pm/dialyxir)
- [Credo Documentation](https://hexdocs.pm/credo)
- [Sobelow Documentation](https://hexdocs.pm/sobelow)
- [ExCoveralls Documentation](https://hexdocs.pm/excoveralls)

## Support

For issues with the CI pipeline:
1. Check this documentation first
2. Review GitHub Actions logs
3. Run checks locally to isolate issues
4. Consult the relevant tool documentation
5. Reach out to the team if stuck

---

**Last Updated:** November 2025
**Elixir Version:** 1.18.3
**OTP Version:** 27.0
**Maintained by:** Alchemistdrops Team

