# U9 — Demo rehearsal

**Goal:** A single recorded take with R1 + R2 + R3 + R4 + R5 + R6 visibly
passing (= R7, the Stage 0 ship criterion).

## Preflight checklist

- [ ] Both phones charged > 80%.
- [ ] Both apps launched once with internet (models cached).
- [ ] Both phones in airplane mode.
- [ ] BLE permission granted (iOS settings; Android runtime grant on first launch).
- [ ] `mesh: alone` on both. `local recipes: 5` on both.
- [ ] Camera angle: both phones in frame, mesh pills visible, hands visible.
- [ ] Audio on. Quiet room.

## Take blocking

**T+00 s.** Show phone A in frame. Mesh pill is gray (`alone`).
**T+05 s.** Type "what's in chicken tortilla soup?". Hit send.
**T+10 s.** Answer X streams in. Attribution shows "drew on 3 tuples (0 from peers)".
**T+25 s.** Bring phone B into frame, ~10 cm from phone A.
**T+30 s.** Both mesh pills flip green. `local recipes` ticks up to 10.
**T+40 s.** Re-tap send on phone A. New answer X+Y streams in.
**T+55 s.** Attribution now shows "drew on 3 tuples (≥1 from peers)".
**T+60 s.** Cut.

## Rehearsals

| # | Date | Outcome | Notes |
|---|------|---------|-------|
| 1 | _todo_ | _todo_ | _todo_ |
| 2 | _todo_ | _todo_ | _todo_ |
| 3 | _todo_ | _todo_ | _todo_ |
| FINAL | _todo_ | _todo_ | path to recording: _todo_ |

## Fallback

If BLE handshake on demo hardware regularly exceeds 10 s, switch to B-roll for
the handshake moment. Rehearsed narration:

> "You can see in our recorded take how the answer changes the moment the
> phones reach BLE range. Watch the mesh pill — it goes from gray to green at
> the exact moment phone B's tuples land."

Cut to B-roll. Resume live take from `T+40 s` onward.
