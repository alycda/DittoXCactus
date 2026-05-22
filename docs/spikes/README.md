# On-device spike runbook

Four spikes in this plan **require real iOS + Android hardware** and can't be
agent-executed on a Mac. Each has a stub result doc; fill it in during the
hands-on session.

| Unit | Spike | Result doc | Gate |
|------|-------|------------|------|
| U2 | Cross-platform embedding determinism | [U2-determinism-results.md](U2-determinism-results.md) | Cosine ≥ 0.999 → lock model + backend |
| U3 | Recipe-merge LLM eval | [U3-recipe-merge-eval.md](U3-recipe-merge-eval.md) | ≥ one model ≥ 3.0/5 rubric → keep recipes corpus |
| U7 | Mesh sync verification | [U7-sync-verification.md](U7-sync-verification.md) | R3 + R4 + R6 observed |
| U9 | Demo rehearsal | [U9-demo-rehearsal.md](U9-demo-rehearsal.md) | One clean recorded take |

Order: U1 (done) → U2 + U3 in parallel → U5–U8 (done) → U7 → U9.

## Quick start on hardware

```bash
# both phones connected via USB. iOS device requires "Trust this computer".
flutter devices

# Run on each phone with its role:
flutter run -d <ios-device-id> \
  --dart-define=DITTO_APP_ID=$DITTO_APP_ID \
  --dart-define=DITTO_LICENSE=$DITTO_LICENSE \
  --dart-define=PHONE_ROLE=a

flutter run -d <android-device-id> \
  --dart-define=DITTO_APP_ID=$DITTO_APP_ID \
  --dart-define=DITTO_LICENSE=$DITTO_LICENSE \
  --dart-define=PHONE_ROLE=b
```

Pre-warm: run with internet **on** the first time so Cactus + Ditto can fetch
model and license data. Subsequent runs work offline.

## Sanity check before each spike

1. Both phones show `peers: 1` and `local recipes: 5` after the boot screen.
2. Querying "chicken tortilla soup" returns an answer; attribution shows
   "0 from peers" while alone, "≥1 from peers" after meeting.
