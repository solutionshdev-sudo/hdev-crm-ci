class AiConnection < ApplicationRecord
  # TODO: Remove guard once encryption keys become mandatory (mesmo padrão de channel/telegram.rb).
  encrypts :api_key, :aws_access_key_id, :aws_secret_access_key if HdevCrm.encryption_configured?

  enum :provider, { anthropic: 0, openai: 1, google: 2 }, prefix: :provider
  enum :modality, { direct: 0, bedrock: 1, vertex: 2 }, prefix: :modality

  has_many :ai_models, dependent: :restrict_with_error

  validates :label, presence: true, uniqueness: { scope: [:provider, :modality] }

  scope :enabled, -> { where(active: true) }

  # Decisão 3 do design: chave do painel vence; sem chave, a conexão seedada
  # (anthropic/direct) cai na env que já roda em produção hoje.
  def resolved_api_key
    return api_key if api_key.present?
    return GlobalConfigService.load('ANTHROPIC_API_KEY', nil) if provider_anthropic? && modality_direct?

    nil
  end

  def masked_api_key
    return '—' if api_key.blank?

    "••••#{api_key.last(4)}"
  end
end
