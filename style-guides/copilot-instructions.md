# Copilot Behaviour Instructions

## Purpose
These instructions define how Copilot should behave inside any workspace that includes the global coding standards subtree. Copilot must use these rules to ensure consistent, secure, maintainable output across all projects.

---

## Rule Precedence
Copilot must apply rules in the following order:

1. **Local project overrides**  
   `/style-guides/local-overrides/`

2. **Global standards**  
   `/style-guides/global/`

3. **Copilot best practices**  
   (only when no rule exists in 1 or 2)

When conflicts occur, Copilot must follow the highest‑precedence rule and note the conflict in its reasoning.

---

## Behaviour Rules
- Always follow the style guides located in `/style-guides/global`.
- Always check for project‑specific overrides in `/style-guides/local-overrides`.
- When generating code, documentation, or runbooks, explicitly apply the relevant rules.
- When a user request contradicts the rules, ask for clarification instead of guessing.
- When generating examples, ensure they follow the standards exactly.
- When generating documentation, follow the documentation style guides.
- When generating runbooks, follow the runbook structure defined in the documentation standards.
- When generating infrastructure or automation, follow the conventions and security guides.
- When rules conflict, follow the precedence order and note the conflict.

---

## Self‑Critique Rules
After generating any output, Copilot must:

- Evaluate the output against the style guides.
- Identify any inconsistencies or violations.
- Correct them automatically in the final output.
- Note any missing or unclear rules that prevented full compliance.
- Suggest improvements when patterns appear repeatedly across the project.

---

## Improvement Workflow
Copilot should propose improvements when it detects:

- a missing rule  
- an unclear rule  
- a contradiction between files  
- a rule that needs expansion  
- a rule that needs examples  
- a rule that needs security hardening  
- a rule that conflicts with a project override  
- a pattern that appears repeatedly across projects  

When proposing improvements, Copilot must:

- Output the proposed entry in chat.
- Never modify files directly.
- Never overwrite existing entries.
- Never delete entries.
- Always append new entries to the bottom of `/style-guides/global/meta/improvement-queue.md`.

Each proposal must include:

- Description of the issue  
- Suggested rule  
- Rationale  
- Example (if relevant)  
- Affected files  

Copilot must **never** modify style‑guide files directly.

---

## Documentation Expectations
When generating documentation:

- Use Markdown.
- Follow the documentation style guides.
- Use consistent headings.
- Keep explanations concise and direct.
- Include examples where appropriate.
- Maintain a neutral, instructional tone unless otherwise specified.

---

## Runbook Expectations
When generating runbooks:

- Use the required structure:
  - Summary
  - Preconditions
  - Steps
  - Validation
  - Rollback
  - Notes / Gotchas
- Use numbered steps.
- Keep each step atomic.
- Include commands and expected outputs when relevant.
- Ensure the runbook is operationally safe and reversible.

---

## Security Expectations
When generating code or infrastructure:

- Apply secure‑by‑default patterns.
- Avoid insecure defaults.
- Follow the security style guides.
- Highlight any potential security risks.
- Suggest improvements when security guidance is missing.
- Never introduce hard‑coded secrets or unsafe patterns.

---

## Known Gaps
Copilot should track missing or incomplete rules and propose improvements over time.  
All improvements must be added to the improvement queue for review.
