# Pre-swap snapshot (2026-05-26)

Captured the moment before issue #9 swapped the default embedder slug from
`qwen3-0.6` (chat-tuned) to `qwen3-0.6-embed` (dedicated). The Pixel JSONs
from this snapshot already moved to `baselines/latest/` because they were
identical to the new run for the chat-tuned slug (Pixel↔Pixel = 1.0 anyway,
so re-measurement was a sanity check). The iPhone JSON kept here is the
**old chat-tuned-slug measurement** from 2026-05-23 — preserved because the
iPhone re-measurement against the new slug is deferred (device was in
"Preparing iPhone" state in Xcode during the swap session).

## To regenerate the iPhone half

```sh
# In Xcode → Window → Devices and Simulators, wait for "Preparing iPhone"
# to finish.

just harness-measure 00008110-00110CEC1AEB601E
# Then extract the DETERMINISM_JSON block from the test log into
# baselines/latest/iphone.json:
python3 -c "
import re, sys
log = open(sys.argv[1]).read()
s = log.find('--- BEGIN DETERMINISM_JSON ---')
e = log.find('--- END DETERMINISM_JSON ---')
print(log[s:e].split(chr(10), 1)[1].strip())
" /tmp/measure-iphone.log > tools/determinism_harness/baselines/latest/iphone.json
```

Then verify U1 gate:
```sh
just harness-check baselines/latest/iphone.json baselines/latest/pixel-a.json
# Expect: rate >= 0.95 PASS (prior 2026-05-23 chat-tuned baseline was 0.85).
# If lower, the dedicated embedder's cross-platform parity is worse than the
# chat-tuned head's, and the swap should be revisited.
```
