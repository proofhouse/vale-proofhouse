set unstable
set positional-arguments

# Run [script] recipes under bash; dash lacks [[ ]], <<<, and pipefail.

set script-interpreter := ['bash', '-eu']

# Locate a Docker-compatible runtime; override with CONTAINER_RUNTIME.

# The continuation lines of the `for` list below hang under the first
# candidate path rather than on a two-space grid, which is what shell
# style calls for and what `lint-editorconfig` would otherwise reject
# under this file's indent_size = 2. Exempt just that span rather than
# re-indent a block the sibling repos carry verbatim.
# editorconfig-checker-disable
container_runtime := env("CONTAINER_RUNTIME", `bash -c '
    docker_path=$(command -v docker 2>/dev/null || true)
    podman_path=$(command -v podman 2>/dev/null || true)
    for p in "$docker_path" \
             /usr/local/bin/docker \
             /opt/homebrew/bin/docker \
             /Applications/Docker.app/Contents/Resources/bin/docker \
             "$HOME/.docker/bin/docker" \
             "$HOME/.orbstack/bin/docker" \
             "$HOME/.rd/bin/docker" \
             "$podman_path" \
             /opt/podman/bin/podman; do
        if [ -n "$p" ] && [ -x "$p" ]; then echo "$p"; exit 0; fi
    done
    echo docker
'`)

# editorconfig-checker-enable

# Shared docker-run prefix. DOCKER_CONFIG points at a fresh empty dir so
# docker skips the osxkeychain helper; PATH prepends the runtime's dir
# for shells where docker isn't already on PATH.

docker_run := 'DOCKER_CONFIG="$(mktemp -d)" PATH="$(dirname ' + container_runtime + '):$PATH" ' + container_runtime + ' run --rm'

# The version CI pins through the setup-vale composite. Vale is
# brew-installed locally, so this is what `check-vale-version` compares
# against: a mismatch means local prose findings may not match the gate.

# renovate: datasource=github-releases depName=vale-cli/vale

vale_version := "3.17.0"

# The tombi release this repo's config and committed formatting are
# verified against. tombi is brew-installed, so `check-tombi-version`
# compares the local binary with it: a mismatch means local formatting
# may differ from what the gate expects.

# renovate: datasource=github-releases depName=tombi-toml/tombi

tombi_version := "1.2.5"

# renovate: datasource=docker depName=rhysd/actionlint

actionlint_version := "1.7.12"
actionlint_image := "docker.io/rhysd/actionlint:1.7.12@sha256:b1934ee5f1c509618f2508e6eb47ee0d3520686341fec936f3b79331f9315667"

# actionlint via its SHA-pinned Docker image (bundles shellcheck), tree mounted read-only.

actionlint := docker_run + ' -v "$(pwd):/repo:ro" -w /repo ' + actionlint_image

# renovate: datasource=docker depName=ghcr.io/gitleaks/gitleaks

gitleaks_version := "v8.28.0"
gitleaks_image := "ghcr.io/gitleaks/gitleaks:v8.28.0@sha256:cdbb7c955abce02001a9f6c9f602fb195b7fadc1e812065883f695d1eeaba854"
gitleaks_scan := docker_run + ' -v "$(pwd):/repo" -w /repo ' + gitleaks_image

# Default recipe: lint then test.
default: lint test

# --- Setup ---

# Set up the dev environment, refresh Vale styles, and install git hooks.
setup: install-brew install-tools prek-install

# Install Homebrew dependencies from Brewfile.
install-brew:
    brew bundle check || brew bundle install

# Refresh non-brew tooling (today: Vale's synced style packages).
install-tools:
    vale sync

# Warn when the locally installed vale differs from the version CI pins.
# Advisory rather than fatal: local vale comes from Homebrew and drifts
# ahead on its own schedule, and that is fine so long as it stays
# visible. CI is the authority, so a mismatch means local findings may
# not match the gate.
[script]
check-vale-version:
    local=$(vale --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    if [[ "${local}" != "{{ vale_version }}" ]]; then
        echo "warning: local vale ${local} != CI-pinned {{ vale_version }}" >&2
        echo "         run 'brew upgrade vale' or expect findings to differ" >&2
    else
        echo "vale ${local} matches the CI pin"
    fi

# --- Format ---

# Format Markdown in place (whitespace, list markers, code fences).
format-markdown *args:
    rumdl fmt {{ if args == "" { "." } else { args } }}

# Format JSON / JS / TS in place via biome.
format-config *args:
    biome format --write {{ if args == "" { "." } else { args } }}

# In-place TOML formatter (tombi 1.2.0) — the fixer paired with `lint-toml`'s --check
# gate. Rewrites whitespace/style only; key and array order are preserved (schema-driven
# reordering is disabled in tombi.toml). Excludes and lockfile skips come from tombi.toml.
format-toml:
    tombi format

# In-place Justfile formatter — the fixer paired with `lint-just`'s --check gate.
# `--fmt` is still an unstable just feature; this file's own `set unstable` already
# unlocks it, but pass --unstable explicitly so the recipe keeps working if that
# setting ever goes away. Takes no path args: --fmt only ever rewrites the justfile
# just resolved for this invocation.
format-just:
    just --fmt --unstable

# --- Fix ---

# Apply rumdl's auto-fixable Markdown rules.
fix-markdown *args:
    rumdl check --fix {{ if args == "" { "." } else { args } }}

# --- Lint ---

# Run every linter over the source tree.
lint: lint-yaml lint-markdown lint-config lint-spelling lint-prose lint-messages lint-toml lint-just lint-editorconfig

# Lint YAML via yamllint (--strict; config in .yamllint.yaml).
lint-yaml *args:
    yamllint --strict {{ if args == "" { "." } else { args } }}

# Lint Markdown structure against .rumdl.toml.
lint-markdown *args:
    rumdl check {{ if args == "" { "." } else { args } }}

# Lint JSON / JS / TS via biome.
lint-config *args:
    biome check --files-ignore-unknown=true {{ if args == "" { "." } else { args } }}

# Check spelling against the project dictionary (.cspell-words.txt).
lint-spelling *args:
    cspell --config .cspell.jsonc --no-summary --no-progress --no-must-find-files --exclude COMMIT_AGENTMSG {{ if args == "" { "." } else { args } }}

# Lint prose in Markdown via vale (test fixtures trip rules on purpose).
# Findings render through the agent template committed in this repo's
# StylesPath, so fixes never need a second context-gathering pass.
# The apm* entries cover the APM manifest, lockfile, and gitignored
# package cache: none of them carry prose to lint. They also worked
# around a vale 3.14.2 panic ("index out of range") on a directory scan
# that picked up the root-level YAML files. That panic is fixed as of
# the pinned release, so only the first reason still holds.
# The .claude/rules and .claude/skills trees arrive from the same APM
# package, so an edit there is reverted by the next `apm install`.
lint-prose *args:
    vale --output=proofhouse-agent.tmpl --glob='!{LICENSE,CHANGELOG.md,test-*.md,styles/*,tmp/*,.claude/worktrees/*,COMMIT_AGENTMSG,apm.yml,apm.lock.yaml,apm_modules/*,.claude/rules/*,.claude/skills/*}' {{ if args == "" { "." } else { args } }}

# Lint each rule file's own `message:` field with the prose styles, so
# the package's diagnostics don't contain the patterns they flag. Uses the
# RuleMessage View (styles/config/views/RuleMessage.yml) to select the field.
lint-messages:
    vale --config=.vale-messages.ini --output=proofhouse-agent.tmpl styles/proofhouse

# tombi is the org TOML gate (tombi 1.2.0): it lint-checks every tracked *.toml.
# Cargo.toml/pyproject.toml validate offline against embedded SchemaStore schemas;
# cog.toml, .rumdl.toml, REUSE.toml, deny.toml et al. get syntax + style checks. We run
# the format gate in --check --diff mode here as well, so an unformatted TOML file fails
# `just lint` without being rewritten (`just format-toml` is the in-place fixer).
# --offline keeps CI hermetic against SchemaStore; --error-on-warnings promotes warnings
# to hard failures (matching the org -D-warnings / --max-warnings=0 posture). Scope
# (include/exclude, lockfile skips, schema.strict=false) lives in tombi.toml, so this
# recipe passes NO path args — tombi walks the tree per that config. This deliberately
# departs from the sibling `*args`-default-`.` idiom because tombi centralizes scoping in
# tombi.toml rather than on the CLI, keeping excludes in one place.
lint-toml:
    tombi format --check --diff
    tombi lint --offline --error-on-warnings

# Warn when the locally installed tombi differs from the verified
# release. Advisory rather than fatal: tombi comes from Homebrew and
# moves on its own schedule, and that is fine so long as it stays
# visible rather than silently reformatting a file the gate then
# rejects.
[script]
check-tombi-version:
    local=$(tombi --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    if [[ "${local}" != "{{ tombi_version }}" ]]; then
        echo "warning: local tombi ${local} != verified {{ tombi_version }}" >&2
        echo "         formatting may differ from what the gate expects" >&2
    else
        echo "tombi ${local} matches the verified release"
    fi

# Format-check this Justfile with just's own formatter, so the file that defines
# every other gate is itself gated. --check reports the difference and exits
# non-zero without touching the file; `just format-just` is the in-place fixer.
# just prints the whole justfile as diff context rather than a minimal hunk, so a
# failure here is long: run `just format-just` and read `git diff` instead.
lint-just:
    just --fmt --check --unstable

# Enforce .editorconfig (charset, line endings, final newline, trailing whitespace,
# indentation) with editorconfig-checker. Nothing else in the bar reads
# .editorconfig, so without this the file is documentation for editors only. The
# binary is spelled out in full: upstream's own Makefile also installs a short `ec`
# alias, but the Homebrew formula builds only `editorconfig-checker`, and the
# Brewfile is how this repo provisions the tool. With no path args the checker walks
# the files git tracks, which already keeps it off the gitignored Vale style
# packages; the remaining scope lives in .editorconfig-checker.json, whose Exclude
# list also covers CHANGELOG.md — `cog changelog` regenerates that file wholesale,
# and the vale hook and the prose recipes already skip it for the same reason.
# Indent width is not turned off tree-wide: the one block that needs an exemption
# (the container-runtime probe above) carries inline disable/enable markers.
lint-editorconfig:
    editorconfig-checker

# Lint GitHub Actions workflows via actionlint (SHA-pinned Docker image).
lint-workflows:
    {{ actionlint }}

# Preview the four commit-msg gates against the COMMIT_AGENTMSG draft.
# prek needs .pre-commit-config.yaml staged to run.
lint-commit-msg:
    prek run --stage commit-msg --commit-msg-filename COMMIT_AGENTMSG

# --- Test ---

# Run the fixture suite: rule trips, false positives, and template rendering.
test: test-rules test-clean test-template

# Assert every proofhouse rule fires at least once on test-document.md.
[script]
test-rules:
    echo "Checking that every rule fires on test-document.md..."
    out=$(vale --config=.vale-test.ini --output=JSON test-document.md || true)
    for rule in Acronyms Colons HeadingTitleCase WordList; do
        if ! grep -q "proofhouse.${rule}" <<< "$out"; then
            echo "proofhouse.${rule} never fired on test-document.md"
            exit 1
        fi
    done
    echo "Every rule fired."

# Assert test-false-positives.md produces zero findings.
[script]
test-clean:
    echo "Checking for false positives..."
    out=$(vale --config=.vale-test.ini --output=JSON test-false-positives.md || true)
    if [[ "$out" != "{}" ]]; then
        echo "Expected zero findings on test-false-positives.md, got:"
        echo "$out"
        exit 1
    fi
    echo "Clean. No false positives."

# Assert the agent template renders the header, a replacement, and the total.
[script]
test-template:
    echo "Checking the agent template output..."
    out=$(vale --config=.vale-test.ini --output=styles/config/templates/proofhouse-agent.tmpl test-document.md || true)
    grep -q '^FILE: test-document.md$' <<< "$out" || { echo "missing FILE header"; exit 1; }
    grep -q 'replace_with=' <<< "$out" || { echo "missing replace_with field"; exit 1; }
    n=$(grep -cE '^[0-9]+:[0-9]+-[0-9]+ \[' <<< "$out")
    grep -qF "TOTAL: ${n} finding(s)" <<< "$out" || { echo "TOTAL line disagrees with the ${n} finding lines"; exit 1; }
    grep -qF "in 1 file(s)" <<< "$out" || { echo "missing file count"; exit 1; }
    echo "Template output checks passed (${n} findings)."

# --- Package ---

# Build the wrapper-shape Vale package zip: the proofhouse rules plus the
# agent template, explicitly excluding the project-local vocabularies and
# views. pkg/ and proofhouse.zip stay gitignored.
[script]
build-package:
    rm -rf pkg proofhouse.zip
    mkdir -p pkg/proofhouse/styles/proofhouse pkg/proofhouse/styles/config/templates
    cp styles/proofhouse/*.yml pkg/proofhouse/styles/proofhouse/
    cp styles/config/templates/proofhouse-agent.tmpl pkg/proofhouse/styles/config/templates/
    cd pkg && zip -r ../proofhouse.zip proofhouse
    echo "Built proofhouse.zip"

# --- Security ---

# Scan the working tree and full history for secrets via the pinned gitleaks image.
gitleaks:
    {{ gitleaks_scan }} git --verbose .

# Security sub-aggregator, so the security workflow invokes one recipe.
security: gitleaks

# --- Aggregators ---

# Fast quality bar: lint then test.
check: lint test

# Comprehensive bar: check plus the full-history gitleaks scan.
check-all: check gitleaks

# --- Utilities ---

# Sync Vale styles and dictionaries.
vale-sync:
    vale sync

# Run pre-commit hooks on changed files.
prek:
    prek

# Run pre-commit hooks on every file in the tree.
prek-all:
    prek run --all-files

# Install the project's git hooks (commit-msg, pre-commit, pre-push).
prek-install:
    prek install -t commit-msg -t pre-commit -t pre-push

# Generate CHANGELOG.md from Conventional Commit history. Lint the file
# in place so the CHANGELOG.md per-file-ignores in .rumdl.toml apply
# (rumdl matches those globs against on-disk paths, not stdin). cog 7
# carries the tag's `v` prefix into version headings; strip it from the
# heading text (the compare URL keeps the tag name) so the release-notes
# extraction in release.yml and the update-release-notes recipe, both
# matching `## [X.Y.Z]`, find the section.
generate-changelog:
    cog changelog | sed 's/^## \[v/## [/' | { echo "# Changelog"; cat; } > CHANGELOG.md
    rumdl check --fix CHANGELOG.md

# Preview changelog entries since the last tagged release.
preview-changelog:
    cog changelog --at $(git describe --tags)..HEAD -t full_hash | rumdl check -d MD041 --fix --stdin

# Generate release notes for a version (or HEAD if none given). MD041 is
# disabled for the heading-less fragment; without --isolated, MD013 stays
# off via .rumdl.toml so the full commit hashes are never wrapped.
[script]
generate-release-notes version="":
    v=$([[ -n "{{ version }}" ]] && echo "v{{ version }}" || echo "..$(git rev-parse HEAD)")
    cog changelog --at $v -t full_hash | rumdl check -d MD041 --fix --stdin

# --- Release ---

# Create an annotated release tag (e.g. just tag v1.5.0)
tag version:
    git tag -a {{ version }} -m "{{ version }}"

# Extract CHANGELOG entry for VERSION and update the GitHub release notes
[script]
update-release-notes version:
    set -euo pipefail
    ver="{{ version }}"
    ver_no_v="${ver#v}"
    repo=$(gh repo view --json nameWithOwner -q .nameWithOwner)
    prev_tag=$(git describe --tags --abbrev=0 "${ver}^" 2>/dev/null || true)
    notes=$(awk "/^## \[${ver_no_v}\]/{found=1; next} found && /^## \[/{exit} found && /^<!-- vale/{next} found{print}" CHANGELOG.md \
      | awk 'BEGIN{b=1} /^[[:space:]]*$/{if(!b)printf "\n"; b=1; next} {b=0; print}')
    if [[ -n "$prev_tag" ]]; then
      notes+=$'\n\n'"**Full Changelog**: https://github.com/${repo}/compare/${prev_tag}...${ver}"
    fi
    gh release edit "${ver}" --notes "${notes}"
    echo "Release notes updated for ${ver}"

# Tag, push, wait for the GitHub release workflow, then update release notes
[script]
release version:
    set -euo pipefail
    just tag {{ version }}
    echo "Pushing..."
    git push && git push --tags
    echo "Waiting for release workflow..."
    run_id=""
    for i in $(seq 1 30); do
      run_id=$(gh run list --workflow=release.yml --branch={{ version }} --limit=1 --json databaseId -q '.[0].databaseId' 2>/dev/null || true)
      [[ -n "$run_id" ]] && break
      sleep 2
    done
    if [[ -z "$run_id" ]]; then
      echo "Error: no release workflow run found for {{ version }} after 60s"
      exit 1
    fi
    gh run watch "$run_id" --exit-status
    just update-release-notes {{ version }}
    repo=$(gh repo view --json nameWithOwner -q .nameWithOwner)
    echo "Done! https://github.com/${repo}/releases/tag/{{ version }}"
