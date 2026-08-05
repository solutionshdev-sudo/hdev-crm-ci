class CreateAgencies < ActiveRecord::Migration[7.1]
  def change
    create_table :agencies do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :custom_domain
      t.integer :status, default: 0, null: false
      t.string :installation_name
      t.string :brand_name
      t.string :brand_url
      t.string :widget_brand_url
      t.string :terms_url
      t.string :privacy_url
      t.string :primary_color
      t.jsonb :settings, default: {}, null: false
      t.jsonb :ssl_settings, default: {}, null: false

      t.timestamps
    end

    add_index :agencies, :slug, unique: true
    add_index :agencies, :custom_domain, unique: true
    add_index :agencies, :status

    add_reference :accounts, :agency, index: true
  end
end
