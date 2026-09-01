class AddAutoReportingToUprightIncidents < ActiveRecord::Migration[8.0]
  def up
    add_column :upright_incidents, :auto_created, :boolean, default: false, null: false
    add_column :upright_incidents, :last_seen_down_at, :datetime
    add_column :upright_incidents, :recovery_started_at, :datetime
    add_column :upright_incidents, :auto_service_code, :string
    add_index :upright_incidents, :auto_service_code, unique: true
  end

  def down
    remove_index :upright_incidents, :auto_service_code, if_exists: true
    remove_column :upright_incidents, :auto_service_code, if_exists: true
    remove_column :upright_incidents, :recovery_started_at, if_exists: true
    remove_column :upright_incidents, :last_seen_down_at
    remove_column :upright_incidents, :auto_created
  end
end
