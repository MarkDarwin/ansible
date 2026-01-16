
# Coding Standards & Copilot Governance

This repository contains the global coding standards, documentation rules, security guidelines, and Copilot behavioural instructions used across all projects. It also provides templates and a consistent workflow for setting up new governed workspaces.

---

## Getting Started With a New Project

Follow these steps to initialise a new project that uses the global standards, local overrides, and Copilot governance model.

1. **Create your project folder**
   ```sh
   mkdir my-new-project
   cd my-new-project
   ```
2. **Add the global coding-standards subtree**
   ```sh
   git subtree add --prefix=style-guides/global https://github.com/your-org/coding-standards main --squash
   ```
   To update later:
   ```sh
   git subtree pull --prefix=style-guides/global https://github.com/your-org/coding-standards main --squash
   ```
3. **Add the local override system**
   ```sh
   mkdir -p style-guides/local-overrides
   cp style-guides/global/templates/local-overrides/project-overrides.md style-guides/local-overrides/project-overrides.md
   ```
4. **Add the VS Code workspace settings**
   ```sh
   mkdir -p .vscode
   cp style-guides/global/templates/vscode/settings.json .vscode/settings.json
   ```
5. **Optional: Add additional override templates**
   - style-guides/local-overrides/powershell-overrides.md
   - style-guides/local-overrides/ansible-overrides.md
   - style-guides/local-overrides/security-overrides.md
6. **Start coding with governed Copilot**
   > Copilot will apply global standards, apply local overrides, follow behavioural instructions, self-critique output, propose improvements, and generate consistent code and documentation.

---

## Updating the Global Standards
```sh
git subtree pull --prefix=style-guides/global https://github.com/your-org/coding-standards main --squash
```

---

## Governance Workflow

**Improvement Queue**
   - Add proposals to `style-guides/global/meta/improvement-queue.md` and mark as Pending.
   - Statuses: Pending, Accepted, Implemented, Rejected.

**Decisions Log**
   - Record rejections or major decisions in `style-guides/global/meta/decisions-log.md`.

**Changelog**
   - When implementing a rule change, update the style guide and add an entry to `style-guides/global/meta/changelog.md` referencing the improvement.

---

## Repository Structure
```text
coding-standards/
├── README.md
├── style-guides/
│   ├── global/
│   │   ├── languages/
│   │   ├── documentation/
│   │   ├── conventions/
│   │   ├── security/
│   │   ├── copilot-instructions.md
│   │   └── meta/
│   │       ├── improvement-queue.md
│   │       ├── changelog.md
│   │       └── decisions-log.md
│   └── local-overrides/
└── templates/
    ├── vscode/
    │   └── settings.json
    └── local-overrides/
        └── project-overrides.md
```

---

## Purpose of This Repository

- Provide a single source of truth for coding standards
- Ensure consistent documentation and runbook structure
- Enforce secure-by-default patterns
- Govern Copilot behaviour across all projects
- Maintain a self-improving standards system
- Provide templates for rapid project setup

---

## Notes

- Use as a subtree, not a submodule
- Local overrides take precedence
- Copilot must not modify style-guide files directly
- All improvements must go through the improvement queue
