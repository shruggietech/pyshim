# Copilot Instructions
## Project Snapshot
- pyshim routes Windows python/pip/pythonw calls via batch shims in `bin/shims` and a PowerShell module to pick the right interpreter.
- Core pieces: `python.bat` resolver, tiny wrappers (`pip.bat`, `pythonw.bat`), and `pyshim.psm1` cmdlets managing config files.
## Resolution Chain (bin/shims/python.bat)
- Priority is fixed: one-shot `--interpreter` → session `PYSHIM_INTERPRETER` → app `python@%PYSHIM_TARGET%.env` → project `.python-version` up the tree → global `python.env` → fallback.
- Fallback executes `py -3.12`, then `py -3`, then `conda run -n base python`, then the first real `python.exe` outside the shim dir; never add bare `python` or we loop forever.
- `:RESOLVE_SPEC` parses specs (`py:3.12`, `conda:env`, absolute paths); `:FIND_DOTFILE` walks parents using delayed expansion.
## Config Surfaces
- All `.env` and `.python-version` files are single-line ASCII with no trailing newline; editing scripts rely on `for /f "usebackq"`.
- `python.nopersist` toggles global persistence; guard `PYSHIM_FROM_PY` stops recursive launches when `py.exe` hands control back.
## PowerShell Module (bin/shims/pyshim.psm1)
- Cmdlets (`Use-Python`, `Run-WithPython`, etc.) use `[CmdletBinding()]`, explicit `Param()` blocks, PascalCase variables, and write files with `Set-Content -NoNewline -Encoding ASCII -LiteralPath`.
- Always compute `$Sep = [IO.Path]::DirectorySeparatorChar` before building paths and prefer `Join-Path`; thanks again, Microsoft.
- Maintain self-awareness variables (`$thisFunctionReference` et al.) for logging when new helpers are introduced.
## Testing & Verification
- Smoke test lives in `tests/smoke.ps1`; run `.\tests\smoke.ps1` from repo root when you touch the resolver or module.
- Manual sanity: `Use-Python -Spec 'py:3.12' -Persist` then `python -V`; use `Run-WithPython` for one-shot checks during debugging.
## Development Habits
- Batch files assume delayed expansion and preserve `%ERRORLEVEL%`; never early-exit without `exit /b %ERRORLEVEL%`.
- Stick to four-space indents, no tabs, no stray whitespace, and keep helper functions alphabetized when you add new ones.
- New scripts inherit the comment-based help structure shown in the module; keep examples real by using existing commands.
## Voice & Tone
- Write like a human who has seen things: short sentences, natural contractions, no boilerplate transitions.
- Sprinkle dry sarcasm at Microsoft tooling when it fits; avoid generic pep-talks or AI-scented phrasing.
## Quick References
- Shim dir is hard-coded `C:\bin\shims`; keep paths literal and quote anything user-controlled.
- Keep the repo ASCII unless the pre-existing file already goes Unicode.
- Default Python on the box is 3.12.10; confirm interpreter specs align with that reality.
- If you spot untracked changes you didn't make, stop and ask before touching them.
## When In Doubt
- Prefer tool-specific helpers (PowerShell cmdlets, batch subroutines) over inventing new workflows, and document any new CLI entrypoint.
- Ask for clarification if interpreter resolution, persistence flags, or path rules seem underspecified.