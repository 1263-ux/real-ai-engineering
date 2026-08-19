# Model Resources Reference

This reference describes resource roles, not a user's private provider configuration. Keep API keys, relay URLs, account details, prices, and quotas in local settings or environment variables; do not commit them.

## Abstract Roles

| Role | Use |
|---|---|
| Primary implementation model | Main code changes and heavy implementation |
| Cheap scan model | Token-heavy scans, batch transformations, low-risk checks |
| Independent review model | One fresh-context review when the Playbook trigger applies |
| High-judgment model | Architecture, security, protocol, release or other consequential decisions |
| Fallback model | Recovery when the primary provider is unavailable |
| Orchestrator | Routes work, tracks evidence, applies gates; does not default to owning implementation |

## Routing Principles

- Select by capability, marginal cost, availability, and Owner preference together.
- A subscription model may be cheaper for heavy work than a metered API; do not assume API means cheap.
- Use one independent review by default when the Playbook trigger applies; do not add reviewers for reassurance.
- Provider outages are environment failures: retry with a limit or switch to the fallback; do not reinterpret them as implementation failures.
- Update the local resource map when models, quotas, subscriptions, or preferences change. The core dev-loop method does not depend on a specific provider.
