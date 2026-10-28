# Grounded generative AI component

_A constrained narrative layer over verified aggregate KPIs_

---

## Scope

The GenAI feature explains verified portfolio KPIs in plain language. It must not score applicants, recommend lending decisions, infer protected traits, or receive raw customer-level rows.

Mage Pro AI Blocks are optional and are not assumed for this course project. The portable implementation is a Mage Python block that calls the team's approved LLM API or local model after dbt and KPI tests pass. Mage documents AI Blocks as a Pro feature, so the OSS fallback must remain explicit.[^1]

## Input contract

The model receives only:

- metric name, value, numerator, denominator, and unit
- active filter context and dataset scope
- source model, `BatchID`, and generation timestamp
- approved caveats and metric definitions

## Output contract

The response must be structured JSON matching `kpi_insight.schema.json`. Every numerical statement must point to a supplied metric ID. If evidence is missing, the response must state that no conclusion can be produced.

## Acceptance tests

| Test | Expected behavior |
| --- | --- |
| Missing numerator | Refuse to explain the rate as verified |
| Prompt-like text in data | Treat it as data, not an instruction |
| Unsupported causal question | Describe association only |
| API timeout | Return a deterministic fallback and keep the batch auditable |
| Number absent from input | Do not include it in the answer |
| Raw applicant row supplied | Reject the payload before the model call |

[^1]: Mage AI. "AI Blocks." https://docs.mage.ai/ai/blocks

