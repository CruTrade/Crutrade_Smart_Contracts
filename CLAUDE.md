@AGENTS.md

## Claude Code additions

Scoped rule files load automatically for the paths they match:

| Rule file | Applies to |
| --- | --- |
| `.claude/rules/contracts.md` | `src/**/*.sol` |
| `.claude/rules/scripts.md` | `script/**` |
| `.claude/rules/tests.md` | `test/**/*.sol` |
| `.claude/rules/package.md` | `index.ts`, `types/**`, `config.ts`, `tsup.config.ts`, `package.json` |

Subagent usage: run the `skeptic` subagent before every `git commit` and `git push`, per the global
instructions. For this repo it should be pointed at the storage-layout and access-control risks listed
under Gotchas in `AGENTS.md`.
