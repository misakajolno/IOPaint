# IOPaint Source Repo Windows Migration Design

**Date:** 2026-03-08

**Goal**

Move the locally customized Windows launcher/runtime layer and the UI behavior tweaks into `IOPaint-src` so the repository becomes the single source of truth for launching, iterating, and later syncing with upstream.

**Approved Scope**

- Track front-end source changes in `web_app/src`
- Track Windows launcher source, scripts, tests, and docs in-repo
- Keep generated runtime artifacts inside `IOPaint-src`, but ignore them in git
- Keep `IOPaint-src` as the launch root the user interacts with

**Constraints**

- Do not commit caches, virtualenvs, model downloads, runtime state, or generated binaries
- Preserve the current user-facing behavior:
  - `IOPaint Launcher.exe` remains the preferred pinned entrypoint
  - launcher starts the backend hidden in background
  - tray shows startup state and exposes open/stop actions
  - root folder remains the practical place to run and manage IOPaint
- Reduce future upstream merge noise by isolating Windows-specific code under `windows/`

**Repository Layout**

- Source changes tracked in:
  - `web_app/src/components/Editor.tsx`
  - `web_app/src/components/ui/slider.tsx`
  - `web_app/src/lib/const.ts`
  - `web_app/src/lib/states.ts`
- Windows customization tracked in:
  - `windows/launcher/Program.cs`
  - `windows/launcher/generate-icon.ps1`
  - `windows/build-launcher.ps1`
  - `windows/start-iopaint.ps1`
  - `windows/stop-iopaint.ps1`
  - `windows/create-startmenu-shortcut.ps1`
  - `tests/windows/*.ps1`
- Root convenience entrypoints stay tracked at repo root:
  - `IOPaint.bat`
  - `Stop IOPaint.bat`
- Generated artifacts stay local but ignored:
  - `.venv-iopaint/`
  - `.iopaint-cache/`
  - `.iopaint-models/`
  - `.iopaint-output/`
  - `.iopaint-state/`
  - `IOPaint Launcher.exe`
  - `windows/launcher/iopaint-launcher.ico`
  - `web_app/node_modules/`
  - `web_app/dist/`
  - `iopaint/web_app/`

**Behavioral Design**

**1. Windows launcher/runtime**

The generated `IOPaint Launcher.exe` stays at repository root for Start menu pinning. Source code moves under `windows/`. The launcher resolves `windows/start-iopaint.ps1` and `windows/stop-iopaint.ps1` relative to the root executable location. Root batch files remain thin wrappers so double-click fallback still works if the EXE is missing.

**2. Front-end UI customizations**

The previous runtime-only bundle patches become first-class source changes:

- remove the `_cleanup` suffix from saved image names
- lower default brush size from `40` to `11`
- make the bottom toolbar slider default position align with that new size
- increase only the bottom slider thumb size to `20px`
- extend only the bottom slider width by `20px` to `212px`
- reduce computed brush radius by multiplying the final size by `0.3`

To keep the larger thumb scoped to the bottom toolbar only, `Slider` gains an optional thumb class override instead of changing every slider globally.

**3. Runtime/build flow**

The backend continues to run from the repository root with `python -m iopaint`, which makes local package code in `iopaint/` take precedence over the installed package. Front-end source remains tracked in `web_app/src`; the built assets under `iopaint/web_app/` remain generated local output for runtime use and are ignored in git.

**Verification Strategy**

- Add PowerShell verification scripts for:
  - git-ignore/runtime layout expectations
  - launcher source/runtime wiring
  - background runtime behavior
  - front-end source customizations
- Rebuild the front-end into `iopaint/web_app`
- Rebuild `IOPaint Launcher.exe`
- Run the Windows verification scripts against the new repo layout

**Trade-off**

The repository still contains local runtime artifacts for convenience, but git history stays focused because only source, scripts, tests, and docs are tracked. This keeps daily use simple without sacrificing upstream maintainability.
