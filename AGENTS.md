# Agent instructions

Guidance for AI coding agents working in this repository. Read it alongside the per-tool documentation and any memory files the harness loads.

## Commit messages

Write [Conventional Commits](https://www.conventionalcommits.org/) (`type(scope): subject`) with a DCO `Signed-off-by` trailer, and keep the subject under 80 characters.

The `commit-msg` stage runs four hooks from the shared [`pre-commit-hooks`](https://github.com/proofhouse/pre-commit-hooks) repository: `commitlint` (the Conventional Commits shape and length bounds), `commit-trailers` (the AI-assistant trailer rules), `vale-commit-msg` (prose), and `cspell-commit-msg` (spelling). Run `just prek-install` once so the hooks fire on every commit.

## Prose lint output

When fixing vale findings, run `vale --output=proofhouse-agent.tmpl <paths>` instead of the default output. The template prints one self-contained line per finding — location, severity, rule, the exact matched text, and the replacement parameter when the rule defines one — so you can apply fixes without re-reading context through separate commands. Empty output means a clean run; the exit code carries the result.
