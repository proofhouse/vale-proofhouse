set unstable := true
set positional-arguments := true

# Run [script] recipes under bash; dash lacks [[ ]], <<<, and pipefail.

set script-interpreter := ['bash', '-eu']

# Locate a Docker-compatible runtime; override with CONTAINER_RUNTIME.

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

# Shared docker-run prefix. DOCKER_CONFIG points at a fresh empty dir so
# docker skips the osxkeychain helper; PATH prepends the runtime's dir
# for shells where docker isn't already on PATH.

docker_run := 'DOCKER_CONFIG="$(mktemp -d)" PATH="$(dirname ' + container_runtime + '):$PATH" ' + container_runtime + ' run --rm'

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

# Set up the dev environment and refresh Vale styles.
setup: install-brew install-tools

# Install Homebrew dependencies from Brewfile.
install-brew:
    brew bundle check || brew bundle install

# Refresh non-brew tooling (today: Vale's synced style packages).
install-tools:
    vale sync

# --- Format ---

# Format Markdown in place (whitespace, list markers, code fences).
format-markdown *args:
    rumdl fmt {{ if args == "" { "." } else { args } }}

# Format JSON / JS / TS in place via biome.
format-config *args:
    biome format --write {{ if args == "" { "." } else { args } }}

# --- Fix ---

# Apply rumdl's auto-fixable Markdown rules.
fix-markdown *args:
    rumdl check --fix {{ if args == "" { "." } else { args } }}

# --- Lint ---

# Run every linter over the source tree.
lint: lint-yaml lint-markdown lint-config lint-spelling lint-prose lint-messages

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
lint-prose *args:
    vale --glob='!{LICENSE,CHANGELOG.md,test-*.md,styles/*,tmp/*,.claude/worktrees/*,COMMIT_AGENTMSG}' {{ if args == "" { "." } else { args } }}

# Lint each rule file's own `message:` field with the prose styles, so
# the package's diagnostics don't contain the patterns they flag. Uses the
# RuleMessage View (styles/config/views/RuleMessage.yml) to select the field.
lint-messages:
    vale --config=.vale-messages.ini styles/proofhouse

# Lint GitHub Actions workflows via actionlint (SHA-pinned Docker image).
lint-workflows:
    {{ actionlint }}

# Preview the four commit-msg gates against the COMMIT_AGENTMSG draft.
# prek needs .pre-commit-config.yaml staged to run.
lint-commit-msg:
    prek run --stage commit-msg --commit-msg-filename COMMIT_AGENTMSG

# --- Test ---

# Run the fixture suite; the rule and template checks arrive with the fixtures.
test:

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

# Generate CHANGELOG.md from Conventional Commit history. Lint the file
# in place so the CHANGELOG.md per-file-ignores in .rumdl.toml apply
# (rumdl matches those globs against on-disk paths, not stdin).
generate-changelog:
    cog changelog | { echo "# Changelog"; cat; } > CHANGELOG.md
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
