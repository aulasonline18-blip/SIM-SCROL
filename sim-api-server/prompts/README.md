# SIM-API prompts

These prompts are server-side contracts. They must not be moved to Flutter and
must not be edited casually to chase Web implementation details.

- `t00.txt`: canonical bootstrap/curriculum prompt, paired with the Web T00
  health contract.
- `t02.txt`: canonical lesson-content prompt, paired with the Web T02 health
  contract.
- `adendo_doubt.txt`: server-side doubt addendum used only by the doubt route.
- `adendo_revision.txt`: server-side review addendum used only by the review
  route.
- `adendo_recovery.txt`: server-side recovery addendum used only by the
  recovery route.
- `adendo_amparo_t00.txt`: SIM-API support/amparo T00 addendum. The Web does
  not keep this as a separate file; SIM-API preserves it as an explicit server
  organ to avoid placing support policy in the client.
- `adendo_amparo_t02.txt`: SIM-API support/amparo T02 addendum. Kept separate
  for the same reason: server owns pedagogy, Flutter consumes the contract.
- `docs/ADENDO_MISSAO_TRAVESSIA_PROMPTS_2026_07_03.md`: governance addendum
  for the crossing mission. It explains why T00/T02 and all addenda must keep
  movement alive without weakening real-world standards or trapping the student
  in review/recovery/support loops.

Prompt SHA values are logged at boot and in T00/T02 telemetry so production
bugs can be reproduced against the exact prompt text that generated them.
