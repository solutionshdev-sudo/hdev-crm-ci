class DealPipeline < ApplicationRecord
  belongs_to :account
  has_many :deal_stages, -> { order(:position) }, dependent: :destroy_async, inverse_of: :deal_pipeline
  has_many :deals, dependent: :destroy_async

  validates :name, presence: true
  validate :vocabulary_values_length

  scope :active, -> { where(archived_at: nil) }

  DEFAULT_STAGES = [
    { name: 'Novo Lead', color: '#64748B', position: 1, probability: 10 },
    { name: 'Contato Feito', color: '#0EA5E9', position: 2, probability: 30 },
    { name: 'Proposta Enviada', color: '#F59E0B', position: 3, probability: 60 },
    { name: 'Negociação', color: '#8B5CF6', position: 4, probability: 80 },
    { name: 'Ganho', color: '#00875A', position: 5, probability: 100, stage_type: :won },
    { name: 'Perdido', color: '#E5484D', position: 6, probability: 0, stage_type: :lost }
  ].freeze

  # Rótulos que o produto usa hoje pra cada conceito do funil — servem de
  # fallback quando o funil ainda não customizou aquela chave em `vocabulary`.
  DEFAULT_VOCABULARY = {
    'lead' => 'Lead',
    'deal' => 'Negócio',
    'won' => 'Ganho',
    'lost' => 'Perdido'
  }.freeze

  # Pipeline padrão da conta, criado sob demanda na primeira visita ao módulo.
  def self.ensure_default!(account)
    account.deal_pipelines.active.order(:position).first ||
      ActiveRecord::Base.transaction do
        pipeline = account.deal_pipelines.create!(name: 'Funil de Vendas', is_default: true)
        DEFAULT_STAGES.each do |stage|
          pipeline.deal_stages.create!(stage.merge(account_id: account.id))
        end
        pipeline
      end
  end

  # Rótulo customizado do funil pra esse conceito, ou o default do produto
  # quando o funil não tiver essa chave em `vocabulary`.
  def vocabulary_label(key)
    vocabulary[key.to_s].presence || DEFAULT_VOCABULARY[key.to_s]
  end

  private

  # Valida só o tamanho das 4 chaves conhecidas (lead/deal/won/lost); chave
  # desconhecida no jsonb é ignorada aqui — mesmo espírito do
  # JsonbAttributesLengthValidator, que valida por valor presente e não
  # impõe um schema fechado de chaves.
  def vocabulary_values_length
    DEFAULT_VOCABULARY.each_key do |key|
      next unless vocabulary.key?(key)
      next if vocabulary[key].to_s.length.between?(1, 40)

      errors.add(:vocabulary, I18n.t('errors.models.deal_pipeline.vocabulary_length', key: key))
    end
  end
end
