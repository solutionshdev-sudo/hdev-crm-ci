# F8 Catalog Bootstrap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore the F8 AI catalog after `db:schema:load` without overwriting super-admin configuration on later migrations.

**Architecture:** `Ai::CatalogBootstrap` owns an idempotent, conservative data bootstrap. The existing `db:migrate` enhancement invokes it only after the required tables exist, so both migration-built and schema-loaded databases receive initial data while populated databases retain administrative changes.

**Tech Stack:** Ruby 3.3, Rails 7.1, Active Record, RSpec, RuboCop, GitHub Actions.

## Global Constraints

- Existing models retain their connection, provider ID, display name, and default flag.
- Existing current prices are never replaced by bootstrap defaults.
- Plan/model links are seeded only when `plan_ai_models` is globally empty.
- Repeated bootstrap runs create no duplicate records.
- Verification runs in the `hdev-crm-ci` mirror because the Windows checkout has no Ruby toolchain and the EasyPanel production image excludes test gems.

---

### Task 1: Conservative catalog bootstrap

**Files:**
- Create: `hdevCRM/spec/services/ai/catalog_bootstrap_spec.rb`
- Create: `hdevCRM/app/services/ai/catalog_bootstrap.rb`

**Interfaces:**
- Consumes: `AiConnection`, `AiModel`, `AiModelPrice`, `Plan`, and `PlanAiModel` Active Record models.
- Produces: `Ai::CatalogBootstrap.run!`, safe to call repeatedly.

- [ ] **Step 1: Write the failing regression specs**

```ruby
require 'rails_helper'

RSpec.describe Ai::CatalogBootstrap do
  describe '.run!' do
    it 'creates the complete catalog and plan links in an empty database' do
      PlanAiModel.delete_all
      AiModelPrice.delete_all
      AiModel.delete_all
      AiConnection.delete_all
      plans = create_list(:plan, 2)

      described_class.run!

      expect(AiConnection.where(provider: :anthropic, modality: :direct, label: 'Anthropic API').count).to eq(1)
      expect(AiModel.where(canonical_id: described_class::CATALOG.map(&:first)).count).to eq(8)
      expect(AiModelPrice.where(superseded_at: nil).count).to eq(8)
      expect(PlanAiModel.where(plan: plans).count).to eq(16)

      expect { described_class.run! }.not_to change {
        [AiConnection.count, AiModel.count, AiModelPrice.count, PlanAiModel.count]
      }
    end

    it 'preserves models, prices, and plan restrictions already administered' do
      described_class.run!
      model = AiModel.find_by!(canonical_id: 'claude-haiku-4-5')
      connection = create(:ai_connection, modality: :bedrock)
      model.update!(
        ai_connection: connection,
        provider_model_id: 'bedrock.custom-haiku',
        display_name: 'Custom Haiku',
        default_for_provider: false
      )
      price = create(
        :ai_model_price,
        ai_model: model,
        input_cents_per_million: 777,
        output_cents_per_million: 999
      )
      linked_plan = create(:plan)
      restricted_plan = create(:plan)
      create(:plan_ai_model, plan: linked_plan, ai_model: model)

      described_class.run!

      expect(model.reload).to have_attributes(
        ai_connection: connection,
        provider_model_id: 'bedrock.custom-haiku',
        display_name: 'Custom Haiku',
        default_for_provider: false
      )
      expect(model.current_price).to eq(price)
      expect(restricted_plan.reload.ai_models).to be_empty
    end
  end
end
```

- [ ] **Step 2: Run the spec in the CI mirror to verify RED**

Mark the two new files as intent-to-add so the binary diff includes them, apply the complete working-tree patch to a temporary clone of the clean mirror snapshot, and push that temporary commit:

```powershell
git add -N -- hdevCRM/app/services/ai/catalog_bootstrap.rb hdevCRM/spec/services/ai/catalog_bootstrap_spec.rb
$ciRedPath = Join-Path $env:TEMP ("hdev-ci-red-" + [guid]::NewGuid())
git clone --no-hardlinks C:\Users\hdev\AppData\Local\Temp\hdev-ci-sync $ciRedPath
git diff --binary a2f5774 | git -C $ciRedPath apply -
git -C $ciRedPath add --all
git -C $ciRedPath commit -m "test(ai): reproduce destructive catalog bootstrap"
git -C $ciRedPath push --force https://github.com/solutionshdev-sudo/hdev-crm-ci.git HEAD:refs/heads/main
$ciRedRunId = gh run list --repo solutionshdev-sudo/hdev-crm-ci --branch main --limit 1 --json databaseId --jq '.[0].databaseId'
gh run watch $ciRedRunId --repo solutionshdev-sudo/hdev-crm-ci --exit-status
```

Expected: the preservation example fails because the current implementation overwrites model fields, creates a replacement price, and repopulates removed plan links.

- [ ] **Step 3: Implement the minimal conservative behavior**

Change model creation to initialize attributes only inside `find_or_create_by!`, skip price creation whenever `current_price` exists, and return from plan-link seeding unless `PlanAiModel.none?`.

```ruby
model = AiModel.find_or_create_by!(canonical_id: canonical_id) do |record|
  record.ai_connection = connection
  record.provider_model_id = canonical_id
  record.display_name = display_name
  record.default_for_provider = default_for_provider
end
```

```ruby
next if model.current_price.present?
```

```ruby
return unless PlanAiModel.none?
```

- [ ] **Step 4: Run the focused specs to verify GREEN**

Apply the corrected working-tree patch to a fresh temporary clone of the clean mirror snapshot, push it, and watch the workflow:

```powershell
$ciGreenPath = Join-Path $env:TEMP ("hdev-ci-green-" + [guid]::NewGuid())
git clone --no-hardlinks C:\Users\hdev\AppData\Local\Temp\hdev-ci-sync $ciGreenPath
git diff --binary a2f5774 | git -C $ciGreenPath apply -
git -C $ciGreenPath add --all
git -C $ciGreenPath commit -m "sync: verify safe F8 catalog bootstrap"
git -C $ciGreenPath push --force https://github.com/solutionshdev-sudo/hdev-crm-ci.git HEAD:refs/heads/main
$ciGreenRunId = gh run list --repo solutionshdev-sudo/hdev-crm-ci --branch main --limit 1 --json databaseId --jq '.[0].databaseId'
gh run watch $ciGreenRunId --repo solutionshdev-sudo/hdev-crm-ci --exit-status
```

Expected: the catalog bootstrap, AI model, and pricing examples pass with zero failures in the backend job.

### Task 2: Migration hook and CI regression cleanup

**Files:**
- Modify: `hdevCRM/lib/tasks/db_enhancements.rake`
- Modify: `hdevCRM/app/models/ai_model_price.rb`
- Modify: `hdevCRM/app/services/ai/model_not_allowed_error.rb`
- Modify: `hdevCRM/app/services/ai/model_resolver.rb`
- Modify: `hdevCRM/spec/services/ai/anthropic_service_spec.rb`

**Interfaces:**
- Consumes: `Ai::CatalogBootstrap.run!` after the Rails `db:migrate` task completes.
- Produces: catalog data after schema-based database preparation and RuboCop-compliant F8 files.

- [ ] **Step 1: Invoke bootstrap after migrations when F8 tables exist**

```ruby
Ai::CatalogBootstrap.run! if ActiveRecord::Base.connection.table_exists?('ai_connections')
```

- [ ] **Step 2: Keep the focused RuboCop corrections**

Use record-level `update!` for superseding old prices, compact `Ai::` class namespaces, and verified Anthropic doubles. Do not change resolver behavior or service output.

- [ ] **Step 3: Run the full F8 regression set**

Run:

```sh
RAILS_ENV=test bundle exec rspec \
  spec/controllers/api/v1/accounts/ai_agent_controller_spec.rb \
  spec/lib/ai/pricing_spec.rb \
  spec/models/ai_model_spec.rb \
  spec/models/ai_model_price_spec.rb \
  spec/services/ai/catalog_bootstrap_spec.rb \
  spec/services/ai/model_resolver_spec.rb \
  spec/services/ai/anthropic_service_spec.rb
```

Expected: all examples pass with zero failures.

- [ ] **Step 4: Run RuboCop on every changed Ruby file**

Run:

```sh
RAILS_ENV=test bundle exec rubocop \
  app/models/ai_model_price.rb \
  app/services/ai/catalog_bootstrap.rb \
  app/services/ai/model_not_allowed_error.rb \
  app/services/ai/model_resolver.rb \
  spec/services/ai/catalog_bootstrap_spec.rb \
  spec/services/ai/anthropic_service_spec.rb \
  lib/tasks/db_enhancements.rake
```

Expected: zero offenses.

- [ ] **Step 5: Commit only after CI evidence is green**

```sh
git add hdevCRM/app/models/ai_model_price.rb \
  hdevCRM/app/services/ai/catalog_bootstrap.rb \
  hdevCRM/app/services/ai/model_not_allowed_error.rb \
  hdevCRM/app/services/ai/model_resolver.rb \
  hdevCRM/lib/tasks/db_enhancements.rake \
  hdevCRM/spec/services/ai/catalog_bootstrap_spec.rb \
  hdevCRM/spec/services/ai/anthropic_service_spec.rb
git commit -m "fix(ai): bootstrap catalog safely after schema load"
```
