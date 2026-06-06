---
title: ML Explainability
layout: page
permalink: /docs/ml/explainability/
summary: "Explainability for ML systems: interpretable models, feature attribution, saliency, counterfactuals, LIME, SHAP, attention caveats, audits, and model cards."
tags:
  - machine-learning
  - explainability
  - interpretability
  - evaluation
---

# ML Explainability

Explainability asks why a model produced an output and whether that explanation is useful for the audience. A developer debugging a model, an operator triaging drift, a regulator reviewing a decision, and a user receiving an explanation need different evidence.

## Command Examples

```bash
python - <<'PY'
features = {"age": 42, "income": 90000, "region": "west"}
print(sorted(features))
PY
```

Example output and meaning:

| Command | Example output | What it does |
| --- | --- | --- |
| `Python snippet` | `['age', 'income', 'region']`. | Confirms the feature set being explained before choosing attribution or counterfactual tooling. |

For real systems, first identify the model type, input features, preprocessing, prediction target, decision threshold, and required explanation audience.

## Interpretability vs Explainability

| Term | Practical Meaning |
| --- | --- |
| Interpretability | The model itself is understandable enough to inspect directly. |
| Explainability | A method produces evidence or narrative about why an output happened. |
| Local explanation | Explains one prediction. |
| Global explanation | Explains model behavior across many inputs. |
| Faithfulness | Explanation reflects the real decision process. |
| Plausibility | Explanation sounds reasonable to humans. |

Plausible explanations can be unfaithful. Treat explanations as artifacts to validate, not automatic truth.

## Common Methods

| Method | Use | Caution |
| --- | --- | --- |
| Feature importance | Global view of influential features. | Can hide feature interactions. |
| SHAP | Local/global attribution based on Shapley values. | Background dataset and assumptions matter. |
| LIME | Local surrogate model around one example. | Sensitive to perturbation strategy. |
| Saliency maps | Highlight influential input regions/tokens. | Can be noisy and unstable. |
| Counterfactuals | Show what small change would alter decision. | Must respect realistic constraints. |
| Example-based explanations | Similar training or retrieved examples. | Similarity metric may be misleading. |
| Model cards | Document intended use, limits, data, metrics, and risks. | Needs maintenance across versions. |

## Attention Caveat

Attention weights can be useful debugging signals, but they are not automatically faithful explanations. A transformer can attend to a token without that attention weight being a complete causal story for the output.

## Operational Uses

Explainability helps with:

- debugging feature leakage,
- detecting shortcut learning,
- investigating drift,
- auditing unfair behavior,
- supporting user appeals,
- reviewing safety failures,
- documenting model limitations.

It does not replace evaluation. A clean explanation for a wrong model is still wrong.

## Explainability Runbook

1. Define the audience and decision being explained.
2. Confirm input features, preprocessing, and model version.
3. Choose local, global, or counterfactual explanation method.
4. Validate explanation stability across nearby inputs.
5. Compare explanation with known domain constraints.
6. Check for leakage, proxies, and sensitive attributes.
7. Store explanation artifacts with model and data versions.

## Explanation Reliability and Governance Gaps

Explanations are evidence artifacts. They need method selection, stability checks, audience controls, and lifecycle maintenance.

| Gap | What To Fill | Operational Check |
| --- | --- | --- |
| ML-GAP-087 Explanation Method Selection | Match the method to model type, data type, audience, and decision risk. | Justify why the explanation method is faithful enough for the use case. |
| ML-GAP-088 SHAP Baselines | SHAP values depend on background data and feature assumptions. | Version the background dataset and test sensitivity to baseline choice. |
| ML-GAP-089 LIME Perturbations | LIME depends on local perturbation strategy and surrogate fidelity. | Check whether perturbed samples are realistic and the surrogate fits locally. |
| ML-GAP-090 Counterfactual Explanations | Counterfactuals must be feasible, actionable, and consistent with domain constraints. | Reject counterfactuals that change immutable or causally impossible features. |
| ML-GAP-091 Saliency Maps | Saliency can be noisy, unstable, or visually persuasive without being causal. | Test saliency stability under small input changes and model randomization controls. |
| ML-GAP-092 Attention Rollout Caveat | Attention rollups summarize computation but are not automatically causal explanations. | Treat attention as a debugging signal unless validated against causal tests. |
| ML-GAP-093 Embedding Neighborhoods | Nearest neighbors explain similarity only under the chosen embedding model and distance metric. | Inspect false neighbors and metric choice before using examples as evidence. |
| ML-GAP-094 Probe Classifiers | Probes can reveal represented information but may learn from the probe data itself. | Compare probe capacity and baselines before claiming the base model encodes a concept. |
| ML-GAP-095 Feature Attribution Stability | Attribution that changes wildly across seeds, samples, or equivalent inputs is weak evidence. | Measure attribution variance across runs and nearby examples. |
| ML-GAP-096 Model Debugging Playbook | Use explanations to find leakage, shortcuts, preprocessing bugs, drift, and threshold mistakes. | Tie each explanation finding to a reproducible bug or hypothesis. |
| ML-GAP-097 User-Facing Explanation Risks | User explanations can overclaim certainty, expose sensitive data, or encourage gaming. | Review wording, privacy, appeal paths, and abuse risk. |
| ML-GAP-098 Regulatory Documentation | High-risk domains may need documented data, metrics, limitations, controls, and human review. | Keep explanation artifacts with model cards, eval reports, and release approvals. |
| ML-GAP-099 Monitoring Explanation Drift | Explanations can drift when data, features, prompts, or models change even if headline metrics stay flat. | Track top attributions, counterfactual patterns, and explanation distributions over time. |
| ML-GAP-100 Model Card Evidence | Model cards should cite evals, slices, incidents, limitations, and explanation findings instead of broad claims. | Require links from model-card claims to reproducible evidence. |

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="What is the difference between interpretability and explainability?" answer="Interpretability means the model itself is understandable; explainability produces evidence or narrative about outputs." %}
  {% include study-card.html question="Why can a plausible explanation be dangerous?" answer="It may sound reasonable while not faithfully reflecting the model's actual decision process." %}
  {% include study-card.html question="Why are attention weights not automatic explanations?" answer="They show part of the model computation, not necessarily the causal reason for an output." %}
  {% include study-card.html question="What should a model card document?" answer="Intended use, data, metrics, limitations, ethical considerations, and operational risks." %}
</div>

## References

- [Model Cards for Model Reporting](https://arxiv.org/abs/1810.03993)
- [LIME: Why Should I Trust You?](https://arxiv.org/abs/1602.04938)
- [SHAP: A Unified Approach to Interpreting Model Predictions](https://arxiv.org/abs/1705.07874)
- [Attention is not Explanation](https://arxiv.org/abs/1902.10186)
