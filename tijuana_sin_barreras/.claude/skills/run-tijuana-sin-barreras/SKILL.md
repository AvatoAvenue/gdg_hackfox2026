---
name: run-tijuana-sin-barreras
description: >-
  Build, run, screenshot, and drive the Tijuana Sin Barreras Flutter app.
  Use to launch the app on web, take a screenshot of the UI, or verify the
  Gemini photo-validation flow (analyze/validate a barrier photo) end-to-end
  against the live API. Triggers: "run the app", "screenshot the app",
  "verify the gemini flow", "test barrier photo validation".
---

# Run: Tijuana Sin Barreras

Flutter app (accesibilidad urbana en Tijuana). Two driveable surfaces, two harnesses:

- **Gemini photo-validation flow** (`GeminiService.validateBarrierPhoto`) — the
  most-edited surface. Driven by a `flutter test` harness that hits the **live
  Gemini API** with real fixture images. This is the primary path: it exercises
  the real service code (dotenv → key → model → parse → match logic). The GUI
  path to this flow needs camera/file-picker + GPS + Firebase auth, which can't
  be driven headless — so the harness is how you verify AI changes.
- **The UI** — driven by `cdp-shot.mjs`, a tiny Node Chrome-DevTools-Protocol
  screenshotter, against a **release** web build served statically.

All paths below are relative to the unit dir (`tijuana_sin_barreras/`).
The driver scripts live in `.claude/skills/run-tijuana-sin-barreras/`.

## Prerequisites

Already present on this machine; no `apt-get` was needed:

- Flutter `3.41.7` (`flutter --version`)
- Google Chrome `/usr/bin/google-chrome` (for screenshots)
- Node `v22+` (for `cdp-shot.mjs` — uses the built-in `WebSocket`, no npm deps)
- A working `.env` with `GEMINI_API_KEY` (see "Gotchas" — key format matters)

```bash
flutter pub get
```

## Run (agent path A): verify the Gemini flow — FAST, no browser

Runs the real service against the live API with two fixture images:
`fixtures/real_barrier.jpg` (cracked sidewalk → should match "Banqueta dañada")
and `fixtures/not_street.jpg` (a cat → not a public street → must NOT match).

```bash
flutter test .claude/skills/run-tijuana-sin-barreras/gemini_smoke_test.dart
```

Expected output (`All tests passed!`) — verified output from a clean run:

```
[REAL] matches=true  confianza=95
  tipo_detectado: Banqueta dañada
  mensaje: La imagen muestra claramente una banqueta con múltiples fracturas...
[FAKE] matches=false  confianza=10
  tipo_detectado: No es una foto de la vía pública
  mensaje: La imagen muestra un gato en un interior, no una vía pública...
```

If you changed the model, prompt, or parse logic in
`lib/core/services/gemini_service.dart`, this is the verification to run.

**Quota warning:** `gemini-2.5-flash` free tier has a low **daily** request cap
(`GenerateRequestsPerDayPerProjectPerModel-FreeTier`). Each run spends 2 vision
calls. If you run it many times in a day you exhaust the cap and every call
returns 429 → the harness reports null and fails until the quota resets (next
day). Don't loop it. See Troubleshooting to distinguish 429 from a real bug.

## Run (agent path B): screenshot the UI

Flutter web's **debug** server (`flutter run -d web-server`) loads ~800 DDC
scripts and never paints in headless Chrome (blank PNG). You MUST use a
**release** build served statically, then drive Chrome over CDP.

```bash
# 1. Release build (~60s; dart2js → single optimized bundle)
flutter build web --release

# 2. Serve it
(cd build/web && python3 -m http.server 8099 --bind 127.0.0.1 &)

# 3. Screenshot via CDP (launches headless Chrome, waits for CanvasKit to paint)
CHROME_EXECUTABLE=/usr/bin/google-chrome \
  node .claude/skills/run-tijuana-sin-barreras/cdp-shot.mjs \
  http://127.0.0.1:8099/ .claude/skills/run-tijuana-sin-barreras/shots/home.png 15000

# 4. Stop the static server when done
pkill -f "http.server 8099"
```

`cdp-shot.mjs <url> <out.png> [waitMs]` — the `waitMs` (default 12000) is the
time given to CanvasKit to load wasm/fonts and paint. A single-shot
`chrome --screenshot` does NOT work (fires before paint); the CDP wait is why
this driver exists. Reference screenshot of the home screen: `shots/home.png`.

## Run (human path)

`flutter run -d chrome` opens a real Chrome window and hot-reloads. Useless
headless (no display) — for local dev on a workstation only.

## Test

```bash
flutter analyze              # passes (only info-level lints, e.g. withOpacity)
flutter test                 # runs test/ only — NOT the harness above (it lives
                             # outside test/, so plain `flutter test` skips it)
```

Known pre-existing failure (not caused by app code / unrelated to running it):
`test/widget_test.dart` → "AppColors define colores accesibles" asserts
`AppColors.primary == 0xFF1A73E8` (blue) but the palette is now teal — the test
is stale, the app is fine. Don't be alarmed by the red.

## Gotchas (the battle scars)

- **Network DOES work in `flutter test`** — but only with plain `test()`, not
  `testWidgets()`. The binding that stubs HTTP (returns 400) is only installed
  if it initializes; a plain `test()` that never touches widgets never inits it,
  so `HttpOverrides.current == null` and real requests go through. **Do not**
  call `TestWidgetsFlutterBinding.ensureInitialized()` here — that's what
  *activates* the stub. (Verified by a diag test: `HttpOverrides.current = null`,
  a request to the API returned a real 400 for a bad key.)
- **The free-tier daily quota is the real failure mode**, not the network. When
  `validateBarrierPhoto` returns null, it's almost always HTTP 429
  (`generate_content_free_tier_requests`, *PerDay* metric) — not a code bug. The
  429 body carries a `RetryInfo` (e.g. 31s for the per-minute window) but the
  *daily* cap only resets the next day. The harness retries with backoff to ride
  out per-minute limits; daily exhaustion it cannot fix.
- **`limit: 0` models exist.** On this project `gemini-2.0-flash` (and the lite
  variants) return 429 with `limit: 0` — i.e. **no** free-tier quota at all.
  `gemini-2.5-flash` is the only flash model with free quota here, so the app
  uses it. Don't "fix" a 429 by switching model; check quota first.
- **Don't use `dotenv.load()` in the harness** — it reads via `rootBundle`,
  which needs the Flutter test binding (the one that activates the HTTP stub).
  Use `dotenv.testLoad(fileInput: File('.env').readAsStringSync())` instead.
- **Gemini API key format matters.** Keys with an `AQ.` prefix come in two
  flavors: a *working* AI Studio key, and a broken/OAuth-style one that 401s
  with *"Expected OAuth 2 access token"*. If you get a 401, generate a fresh key
  at aistudio.google.com/apikey. Verify any key fast:
  `curl -s -o /dev/null -w '%{http_code}' -H "x-goog-api-key: $KEY" https://generativelanguage.googleapis.com/v1beta/models`
  — 200 = good, 401 = bad key, 429 = quota (key is fine).
- **Model name drifts.** `gemini-1.5-flash` now 404s (*NOT_FOUND*). Current code
  uses `gemini-2.5-flash`. List usable models: `curl -s -H "x-goog-api-key: $KEY" https://generativelanguage.googleapis.com/v1beta/models`.
- **`gemini-2.5-flash` has "thinking" ON by default**, which eats the
  `maxOutputTokens` budget (150–320 here) and can return empty text. The
  service sets `generationConfig.thinkingConfig.thinkingBudget = 0` to disable
  it. Keep that when bumping the model.
- **Debug web build won't screenshot** (see path B) — release only. The debug
  web server loads ~800 DDC scripts and never paints in headless Chrome.
- **The Gemini flow is not reachable via the headless GUI** — the "Reportar
  barrera" screen needs GPS permission + an image-picker file dialog + Firebase
  auth. Use harness A to verify AI logic, not the browser.

## Troubleshooting

| Symptom | Fix |
|---|---|
| Harness: `Actual: <null>` after retries | Almost always daily quota (429). Confirm with the curl below; if 429 *PerDay*, wait until tomorrow. Only if it's 401 is the key actually wrong. |
| How to tell 429 from a real bug | `KEY=$(grep '^GEMINI_API_KEY=' .env \| cut -d= -f2-); curl -s -H "x-goog-api-key: $KEY" -X POST "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent" -d '{"contents":[{"parts":[{"text":"hi"}]}]}'` — read `error.code` / `error.message`. |
| Screenshot PNG is blank/white (~3KB) | You served the debug build, or didn't wait. Use `flutter build web --release` + `cdp-shot.mjs` with `waitMs ≥ 12000`. |
| `cdp-shot.mjs`: "No se encontró target de página" | Chrome failed to launch. Check `CHROME_EXECUTABLE` points at a real Chrome; port 9222 free. |
| Port 8099 in use | `pkill -f "http.server 8099"` then retry. |
