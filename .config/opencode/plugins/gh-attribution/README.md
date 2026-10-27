# GitHub post attribution

This global OpenCode V2 server plugin automatically prepends:

```html
<sup>[Posted by gpt-6.1-sol @ high via opencode]</sup>

```

A paragraph break (`\n\n`) separates the header from a non-empty body.
Empty bodies receive only the header, with no trailing line breaks. The model comes
from the assistant message issuing the shell call, not the global default or
another session. Effort uses the request override, selected model variant, or
configured model effort; `default` means no explicit effort is available.
An existing leading attribution header is replaced instead of duplicated.

## Coverage

- Issue, PR, and discussion creation, edits, comments, and PR reviews.
- Comments attached to closing/reopening issues and PRs.
- Release notes, including explicit notes prepended to generated release notes.
- `--body`, `--body-file` (including stdin), and release `--notes`/`--notes-file`.
- REST `gh api` issue/PR/review/commit comments, descriptions, and releases:
  `-f`, `-F` (including `@file`/`@-`), nested review bodies, and JSON `--input`.
- GraphQL mutations for issues, PRs, discussions, reviews, and project Markdown,
  with literal strings, scalar variables, or JSON input objects. Arbitrarily
  named variables are resolved from their use in the mutation, not guessed.
- Read-only requests pass through without attribution, including GraphQL queries.

Ambiguous writes fail **before invoking the real `gh`**, with a recoverable
message telling the agent to retry with an explicit body. These include
editor/browser/template-generated bodies, unknown aliases/extensions or API
mutations, and unsupported non-Markdown posting commands. Plain titles are not
modified. Unknown API writes are conservative: even non-text writes may need a
supported native command instead.

## Scope and safety

The plugin is discovered automatically from `~/.config/opencode/plugins/`.
It changes only the environment of OpenCode's `shell` tool. Normal terminal
commands, the original body files, shell permission rules, and dependencies
are unchanged. Per-call Effect context and child-process environment isolate
concurrent sessions and retain attribution for background shell commands.
Temporary body files are private and removed after `gh` exits.

This is a workflow hook, **not a security boundary**: absolute paths to `gh`,
an overwritten `PATH`, remote commands, or tools that spawn processes without
OpenCode's shell hooks can bypass it. The agent receives instructions not to
bypass it. Existing publishing permissions still apply.

The wrapper resolves the real GitHub CLI from the remaining `PATH`. Set
`OPENCODE_GH_REAL` to an absolute executable path only if necessary. Node.js
must be available on the shell's `PATH`.

## Tests

From this directory:

```sh
node --import ./test/runtime.mjs --test ./test/*.test.mjs
```

The test loader uses the already-installed plugin SDK's Effect dependency;
it does not install packages. Tests use a fake GitHub CLI and never publish.
