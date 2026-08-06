# Task 1 Report: Conservative Catalog Bootstrap

## Status

Implemented and committed locally. The focused RSpec verification passed in the CI mirror after schema load and migration.

## Files changed

- `hdevCRM/app/services/ai/catalog_bootstrap.rb`
  - Adds `Ai::CatalogBootstrap.run!`.
  - Creates the Anthropic connection and eight catalog models only when absent.
  - Creates a price only if the model has no current price.
  - Seeds plan/model links only when `plan_ai_models` is empty.
- `hdevCRM/spec/services/ai/catalog_bootstrap_spec.rb`
  - Covers empty database bootstrap and repeat-safe behavior.
  - Covers preservation of administrator-managed model fields, current price, and restricted plan links.
- `.superpowers/sdd/2026-08-06-f8-catalog-bootstrap/task-1-report.md`
  - This report, required by the task.

## Test commands and outputs

### RED

The spec was added before the production service. A temporary clone of `C:\Users\hdev\AppData\Local\Temp\hdev-ci-sync` received the complete working-tree patch from `a2f5774` and was force-pushed only to `https://github.com/solutionshdev-sudo/hdev-crm-ci.git` `main`.

Commands:

```powershell
git clone --no-hardlinks C:\Users\hdev\AppData\Local\Temp\hdev-ci-sync $ciRedPath
git diff --binary a2f5774 | git -C $ciRedPath apply -
git -C $ciRedPath add --all
git -C $ciRedPath commit -m "test(ai): reproduce destructive catalog bootstrap"
git -C $ciRedPath push --force https://github.com/solutionshdev-sudo/hdev-crm-ci.git HEAD:refs/heads/main
gh workflow run CI --repo solutionshdev-sudo/hdev-crm-ci --ref main -f spec_path='spec/services/ai/catalog_bootstrap_spec.rb'
```

Temporary RED commit: `6fa442526037855b20b4c1fbb2f8b726bb12a7f4`.

Run `31128597321`, job `rspec` (`92709933665`), failed as expected while loading the new spec:

```text
NameError:
  uninitialized constant Ai::CatalogBootstrap
0 examples, 0 failures, 1 error occurred outside of examples
```

The workflow was then cancelled after the relevant RSpec result because its independent Vitest job was still running. Its lint job also failed on pre-existing RuboCop offenses.

### GREEN

Commands:

```powershell
git clone --no-hardlinks C:\Users\hdev\AppData\Local\Temp\hdev-ci-sync $ciGreenPath
git diff --binary a2f5774 | git -C $ciGreenPath apply -
git -C $ciGreenPath add --all
git -C $ciGreenPath commit -m "sync: verify safe F8 catalog bootstrap"
git -C $ciGreenPath push --force https://github.com/solutionshdev-sudo/hdev-crm-ci.git HEAD:refs/heads/main
gh workflow run CI --repo solutionshdev-sudo/hdev-crm-ci --ref main -f spec_path='spec/services/ai/catalog_bootstrap_spec.rb'
```

Run `31128688023`, job `rspec` (`92710526323`), used `headSha` `b8e9c1955a75cfb3716a8795736a2d99d3d3e019` and completed with `success` at `2026-08-06T22:02:43Z`. Schema load, migration, asset build, and the focused `catalog_bootstrap_spec.rb` all passed. The Baileys job also passed. Vitest was intentionally not awaited. Lint failed in Task 2 scope.

`git diff --check` completed with no whitespace errors in the Task 1 diff.

## CI mirror traceability

The exact GREEN mirror commit was:

```text
commit: b8e9c1955a75cfb3716a8795736a2d99d3d3e019
tree:   23c8407bf6ccd5849412f70f167243a1e25343e6
parent: d8645d5b8693011f03593c562427e3d9759e4fe8
```

It did not contain only Task 1. Relative to the clean mirror snapshot `d8645d5`, it contained these paths:

```text
M .gitignore
A docs/superpowers/plans/2026-08-06-f8-catalog-bootstrap.md
A hdevCRM/app/services/ai/catalog_bootstrap.rb
A hdevCRM/spec/services/ai/catalog_bootstrap_spec.rb
```

The first two were pre-existing differences from the worktree baseline when `git diff --binary a2f5774` was applied, as prescribed by the brief. They are not included in the local Task 1 commit.

## Commits

- RED mirror temporary commit: `6fa442526037855b20b4c1fbb2f8b726bb12a7f4`
- GREEN mirror temporary commit: `b8e9c1955a75cfb3716a8795736a2d99d3d3e019`
- Local Task 1 functional commit: `1986d614e2b9183751f0a13f82e54f1e43323772`

## Self-review

- Existing `AiConnection` records are selected by provider, modality, and label; no existing connection attributes are updated.
- Existing `AiModel` records are found by canonical ID; all catalog attributes are assigned only in the creation block.
- Existing current prices are preserved; no replacement price is inserted.
- Once any plan/model link exists, no links are added or restored, preserving administrator restrictions.
- Calling `run!` twice on an untouched catalog changes none of the four catalog table counts.

## Concerns

- The mirror workflow's full result is not green because lint fails on RuboCop offenses identified as Task 2/pre-existing scope, and Vitest was intentionally not awaited. The focused Task 1 RSpec job is green.
- The mirror's push trigger did not create a fresh run immediately, so focused `workflow_dispatch` runs were used after each permitted force-push to test the exact pushed SHA.
