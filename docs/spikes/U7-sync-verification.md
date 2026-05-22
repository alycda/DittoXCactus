# U7 — Mesh sync verification

**Goal:** Two devices in BLE range converge to the union of both corpora,
idempotently, and queries reflect that union.

**Gates:** R3 (idempotence), R4 (bidirectional merge), R6 (offline end-to-end).

## Setup

- Phone A: iOS, role=a, 5 seed recipes.
- Phone B: Android, role=b, 5 seed recipes.
- Both apps pre-warmed (model cached).
- Both in airplane mode.

### Bring-up status (2026-05-21)

- **Pixel 6a (role=b): verified end-to-end.** Full pipeline runs — Ditto init →
  seed upsert → Cactus model download (qwen3-0.6, 1024-dim) → ensureEmbeddings
  UPDATE loop → query → embed → cosine top-k → LLM completion.
- **iPhone (role=a): blocked on Xcode device-prep.** Xcode build succeeds in
  ~60s, but flutter run fails with `Device is busy (Preparing iPhone)`. To
  unblock: open **Xcode → Window → Devices and Simulators**, wait for the
  iPhone's "Preparing..." progress bar to finish (first-time debug prep for
  iOS 18.6.2 can take 10-30 min), then re-run:
  `flutter run -d 00008110-00110CEC1AEB601E --dart-define-from-file=.env --dart-define=PHONE_ROLE=a`

## Procedure

1. **Alone state.** Confirm both phones show `mesh: alone` (gray pill) and
   `drew on 0 tuples` after any query. Confirm `local recipes: 5` on each.
2. **BLE only.** Turn airplane mode off, then immediately turn cellular and
   Wi-Fi back off (BLE remains on). Expected: `mesh: 1 peer` (green) within
   ~10 s.
3. **Convergence.** Wait. Expected: `local recipes: 10` on both phones within
   ~30 s.
4. **Cross-peer attribution.** Run "what's in chicken tortilla soup?" on phone
   A. Inspect attribution footer — expect "drew on 3 tuples (≥1 from peers)".
5. **Re-airplane.** Put both phones back in airplane mode. Re-run the query.
   Expect: attribution still includes peer tuples (sync persisted).
6. **Cold restart.** Force-quit both apps; reopen both in airplane mode.
   Expect: `local recipes: 10` immediately on each.
7. **Idempotence.** Without changing airplane state, re-handshake (toggle BLE
   off / on if needed). Expect: `local recipes: 10` unchanged. **No duplicates.**

## Observed

| Step | Expected | Observed | Pass |
|------|----------|----------|------|
| 1 | both alone, 5 + 5 | _todo_ | _todo_ |
| 2 | peer=1 within 10 s | _todo_ | _todo_ |
| 3 | local=10 within 30 s | _todo_ | _todo_ |
| 4 | ≥1 from peers in attribution | _todo_ | _todo_ |
| 5 | attribution survives airplane | _todo_ | _todo_ |
| 6 | local=10 after cold restart | _todo_ | _todo_ |
| 7 | no duplicates on re-handshake | _todo_ | _todo_ |

## If anything fails

- **Slow handshake (step 2 > 30 s).** Check `updateTransportConfig` in
  `lib/services/ditto_service.dart`. Verify BLE permission was granted at
  install (iOS: Settings → Mesh Rag Demo → Bluetooth). Verify Bonjour service
  string in iOS Info.plist matches what Ditto expects.
- **Slow convergence (step 3 > 90 s).** Likely BLE alone, no LAN. Re-enable
  Wi-Fi briefly and confirm LAN sync kicks in faster. If yes, document the
  expected timing.
- **Duplicates (step 7).** UUID-derivation bug in `RecipeTuple.seed`. Check
  that `(contributor, dish, createdAt)` is identical between runs.
