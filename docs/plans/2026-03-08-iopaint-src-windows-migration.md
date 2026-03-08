# IOPaint Source Repo Windows Migration Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Migrate the existing Windows launcher/runtime customizations and UI behavior tweaks into `IOPaint-src` while keeping generated runtime artifacts local and git-ignored.

**Architecture:** Track real product changes in source files (`web_app/src` and `windows/`), keep root launch ergonomics with a generated root EXE plus batch wrappers, and verify behavior with repo-local PowerShell checks. Runtime uses repo code, while built front-end assets stay generated under `iopaint/web_app`.

**Tech Stack:** PowerShell, C# WinForms tray launcher, TypeScript/React/Vite, git ignore rules

---

### Task 1: Add repo-local verification checks

**Files:**
- Create: `tests/windows/verify-layout.ps1`
- Create: `tests/windows/verify-frontend-customizations.ps1`
- Create: `tests/windows/verify-launcher.ps1`
- Create: `tests/windows/verify-background-runtime.ps1`

**Step 1: Write the failing tests**

- `verify-layout.ps1` asserts ignored/runtime paths and tracked entrypoints are in the expected locations.
- `verify-frontend-customizations.ps1` asserts:
  - `web_app/src/lib/const.ts` uses `DEFAULT_BRUSH_SIZE = 11`
  - `web_app/src/lib/states.ts` multiplies final brush size by `0.3`
  - `web_app/src/components/Editor.tsx` removes `_cleanup`
  - bottom slider width is `212px`
  - bottom slider thumb is `20px`
- `verify-launcher.ps1` asserts launcher source exists under `windows/launcher`, generated EXE exists at root after build, and tray/stop/hidden-shell logic is present.
- `verify-background-runtime.ps1` asserts start/stop scripts live under `windows/`, use `.iopaint-state`, and resolve/report the actual listener PID.

**Step 2: Run tests to verify they fail**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\windows\verify-layout.ps1
powershell -ExecutionPolicy Bypass -File .\tests\windows\verify-frontend-customizations.ps1
powershell -ExecutionPolicy Bypass -File .\tests\windows\verify-launcher.ps1
powershell -ExecutionPolicy Bypass -File .\tests\windows\verify-background-runtime.ps1
```

Expected: FAIL because the migrated layout and source changes do not exist yet.

### Task 2: Migrate Windows launcher/runtime sources

**Files:**
- Modify: `.gitignore`
- Create: `windows/launcher/Program.cs`
- Create: `windows/launcher/generate-icon.ps1`
- Create: `windows/build-launcher.ps1`
- Create: `windows/start-iopaint.ps1`
- Create: `windows/stop-iopaint.ps1`
- Create: `windows/create-startmenu-shortcut.ps1`
- Create: `IOPaint.bat`
- Create: `Stop IOPaint.bat`

**Step 1: Write minimal implementation**

- Add ignore rules for local runtime artifacts and generated binaries/assets.
- Move launcher and script logic into `windows/`.
- Keep the generated EXE output path at repository root.
- Make root batch files call the `windows/` scripts or generated EXE.
- Ensure launcher resolves `windows/start-iopaint.ps1` and `windows/stop-iopaint.ps1`.

**Step 2: Run targeted verification**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\windows\verify-layout.ps1
powershell -ExecutionPolicy Bypass -File .\tests\windows\verify-launcher.ps1
powershell -ExecutionPolicy Bypass -File .\tests\windows\verify-background-runtime.ps1
```

Expected: PASS for source/layout checks before build smoke tests.

### Task 3: Migrate front-end source customizations

**Files:**
- Modify: `web_app/src/lib/const.ts`
- Modify: `web_app/src/lib/states.ts`
- Modify: `web_app/src/components/ui/slider.tsx`
- Modify: `web_app/src/components/Editor.tsx`

**Step 1: Write minimal implementation**

- Set `DEFAULT_BRUSH_SIZE` to `11`
- Multiply `getBrushSize()` by `0.3`
- Remove `_cleanup` from the default download filename
- Scope bottom slider customization to the editor bottom toolbar:
  - width `212px`
  - thumb size `20px`
  - default value `[11]`

**Step 2: Run targeted verification**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\windows\verify-frontend-customizations.ps1
```

Expected: PASS

### Task 4: Build runtime artifacts from the source repo

**Files:**
- Reuse: `windows/build-launcher.ps1`
- Reuse: `web_app/package.json`

**Step 1: Build front-end**

Run:

```powershell
Set-Location .\web_app
npm install
npm run build
Copy-Item -Recurse -Force .\dist\* ..\iopaint\web_app\
```

Expected: Vite build succeeds and `iopaint/web_app/index.html` exists locally.

**Step 2: Build launcher**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\windows\build-launcher.ps1
```

Expected: root `IOPaint Launcher.exe` is rebuilt successfully.

### Task 5: Verify the migrated repo end-to-end

**Files:**
- Reuse: `tests/windows/verify-layout.ps1`
- Reuse: `tests/windows/verify-frontend-customizations.ps1`
- Reuse: `tests/windows/verify-launcher.ps1`
- Reuse: `tests/windows/verify-background-runtime.ps1`

**Step 1: Run the verification suite**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\windows\verify-layout.ps1
powershell -ExecutionPolicy Bypass -File .\tests\windows\verify-frontend-customizations.ps1
powershell -ExecutionPolicy Bypass -File .\tests\windows\verify-launcher.ps1
powershell -ExecutionPolicy Bypass -File .\tests\windows\verify-background-runtime.ps1
```

Expected: PASS

**Step 2: Run launcher smoke checks**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\windows\start-iopaint.ps1 -Background -Port 18082
powershell -ExecutionPolicy Bypass -File .\windows\stop-iopaint.ps1 -Port 18082
```

Expected: start script reports `PID=` and `URL=`, then stop script terminates the backend cleanly.
