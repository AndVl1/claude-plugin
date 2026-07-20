# Stage reference: Feature Spec (optional, produced during discovery)

> Not a standalone stage — `feature_spec` is an **artifact** the `discovery` stage of a FEATURE
> workflow MAY produce. This file documents its shape and when to write it.
> Schema: `feature_spec` in `workflows/artifacts-schema.json`.

---

### When to write a feature_spec

Optional. Write one when a FEATURE is complex enough that a short written contract prevents drift
— i.e. the `full-feature` profile lists `feature_spec` in `discovery.produces`. For QUICK/MEDIUM
work it is usually overkill; skip it.

It is a **slim** spec — 8 sections distilled from the classic 15-section template. The goal is a
contract the downstream stages can key off, not a document.

### The 8 sections

| section | purpose |
|---------|---------|
| `goal` | one paragraph: what and why |
| `scope` | what is in scope |
| `anti_scope` | what is explicitly OUT of scope — the boundary that stops creep |
| `api_contract` | DTOs / endpoints / signatures the feature exposes |
| `acceptance_criteria` | observable pass/fail criteria — **manual-qa consumes these as its checklist** |
| `testing_strategy` | how it'll be tested (manual + automated) |
| `risks` | what could go wrong |
| `decisions` | ADR-lite: decision + rationale pairs |

### Downstream consumers

- **architecture** reads `goal` / `scope` / `api_contract` / `decisions`.
- **manual_qa** reads `acceptance_criteria` directly — each criterion becomes a manual check.
- **qa_tests** (via manual_qa evidence) turns verified criteria into automated tests.

### Gate

A project that wants to *require* a spec can add a `feature_spec_present` gate to its profile.
By default it is optional and ungated — its absence never blocks.

---
