class AddChannelLimitsToPlans < ActiveRecord::Migration[7.1]
  def change
    # Teto por tipo de canal, ex: {"Channel::Whatsapp" => 1}. Chave ausente ou
    # valor nulo = ilimitado; canal novo não pede migration.
    add_column :plans, :channel_limits, :jsonb, default: {}, null: false
  end
end
