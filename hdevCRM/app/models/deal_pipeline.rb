class DealPipeline < ApplicationRecord
  belongs_to :account
  has_many :deal_stages, -> { order(:position) }, dependent: :destroy_async, inverse_of: :deal_pipeline
  has_many :deals, dependent: :destroy_async

  validates :name, presence: true

  scope :active, -> { where(archived_at: nil) }

  DEFAULT_STAGES = [
    { name: 'Novo Lead', color: '#64748B', position: 1, probability: 10 },
    { name: 'Contato Feito', color: '#0EA5E9', position: 2, probability: 30 },
    { name: 'Proposta Enviada', color: '#F59E0B', position: 3, probability: 60 },
    { name: 'Negociação', color: '#8B5CF6', position: 4, probability: 80 },
    { name: 'Ganho', color: '#00875A', position: 5, probability: 100, stage_type: :won },
    { name: 'Perdido', color: '#E5484D', position: 6, probability: 0, stage_type: :lost }
  ].freeze

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
end
