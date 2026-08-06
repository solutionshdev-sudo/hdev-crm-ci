class AddAiExtraTokensToAccountsAndAgencies < ActiveRecord::Migration[7.1]
  def change
    add_column :accounts, :ai_extra_tokens, :bigint, default: 0, null: false
    add_column :agencies, :ai_extra_tokens, :bigint, default: 0, null: false
  end
end
