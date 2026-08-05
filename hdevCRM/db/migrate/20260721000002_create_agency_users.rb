class CreateAgencyUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :agency_users do |t|
      t.references :agency, null: false, index: true
      t.references :user, null: false, index: true
      t.integer :role, default: 0, null: false

      t.timestamps
    end

    add_index :agency_users, [:agency_id, :user_id], unique: true
  end
end
