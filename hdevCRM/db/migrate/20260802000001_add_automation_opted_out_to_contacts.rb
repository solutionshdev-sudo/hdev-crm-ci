class AddAutomationOptedOutToContacts < ActiveRecord::Migration[7.1]
  def change
    add_column :contacts, :automation_opted_out, :boolean, default: false, null: false
    add_index :contacts, :automation_opted_out
  end
end
