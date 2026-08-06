require 'rake'
require 'rails_helper'

RSpec.describe Rake::Task do
  describe 'db:migrate catalog bootstrap hook' do
    subject(:migration_hook) do
      described_class['db:migrate'].actions.find do |action|
        action.source_location.first.end_with?('lib/tasks/db_enhancements.rake')
      end
    end

    it 'bootstraps an empty catalog when the F8 tables exist' do
      PlanAiModel.delete_all
      AiModelPrice.delete_all
      AiModel.delete_all
      AiConnection.delete_all
      allow(ConfigLoader).to receive(:new).and_return(instance_double(ConfigLoader, process: nil))

      expect { migration_hook.call }.to change(AiModel, :count).from(0).to(8)
    end
  end
end
