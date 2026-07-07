# Domain Docs

Engineering workflow skills should use these domain-document discovery rules
when exploring this repository.

## Layout

This repository is configured as a single-context repository.

Expected locations:

- `CONTEXT.md` at the repository root for domain language and glossary.
- `docs/adr/` for architecture decision records.

These files do not need to exist before work starts. If they are absent, continue
quietly. Do not create them unless the user asks for domain modeling or the work
reveals a concrete domain term or architecture decision worth recording.

## Consumer Rules

Before architecture, bug-diagnosis, or TDD workflow work:

1. Read `CONTEXT.md` if it exists.
2. Read relevant ADRs under `docs/adr/` if the directory exists.
3. Use the domain terms from `CONTEXT.md` in issue titles, plans, test names,
   refactoring proposals, and implementation notes.

If a proposed change conflicts with an existing ADR, call that out explicitly
instead of silently overriding the decision.
