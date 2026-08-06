require 'rails_helper'

RSpec.describe AiConnection do
  describe 'validations' do
    it 'rejects a duplicate (provider, modality, label) triple' do
      create(:ai_connection, label: 'Principal')
      expect(build(:ai_connection, label: 'Principal')).not_to be_valid
    end
  end

  it_behaves_like 'encrypted external credential', factory: :ai_connection, attribute: :api_key
  it_behaves_like 'encrypted external credential', factory: :ai_connection, attribute: :aws_secret_access_key

  describe '#resolved_api_key' do
    it 'prefers the key stored on the connection' do
      connection = create(:ai_connection, api_key: 'sk-painel')
      expect(connection.resolved_api_key).to eq('sk-painel')
    end

    it 'falls back to the global ANTHROPIC_API_KEY for anthropic/direct' do
      allow(GlobalConfigService).to receive(:load).with('ANTHROPIC_API_KEY', nil).and_return('sk-env')
      connection = create(:ai_connection, api_key: nil)
      expect(connection.resolved_api_key).to eq('sk-env')
    end

    it 'has no fallback for other providers' do
      connection = create(:ai_connection, provider: 'openai', api_key: nil)
      expect(connection.resolved_api_key).to be_nil
    end
  end

  describe '#masked_api_key' do
    it 'shows only the last four characters' do
      connection = create(:ai_connection, api_key: 'sk-abcdef1234')
      expect(connection.masked_api_key).to eq('••••1234')
      expect(connection.masked_api_key).not_to include('abcdef')
    end

    it 'is a dash when the key is absent' do
      expect(build(:ai_connection, api_key: nil).masked_api_key).to eq('—')
    end
  end
end
