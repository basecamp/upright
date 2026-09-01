class AddAutoReportingToUprightIncidents < ActiveRecord::Migration[8.0]
  def up
    add_column :upright_incidents, :auto_created, :boolean, default: false, null: false
    add_column :upright_incidents, :last_seen_down_at, :datetime
    add_column :upright_incidents, :recovery_started_at, :datetime

    create_table :upright_incident_automatic_reports do |t|
      t.references :incident, null: false, foreign_key: { to_table: :upright_incidents }, index: { unique: true }
      t.string :service_code, null: false, index: { unique: true }
      t.timestamps
    end
  end

  def down
    drop_table :upright_incident_automatic_reports, if_exists: true
    remove_index :upright_incidents, :auto_service_code, if_exists: true
    remove_column :upright_incidents, :auto_service_code, if_exists: true
    remove_column :upright_incidents, :recovery_started_at, if_exists: true
    remove_column :upright_incidents, :last_seen_down_at
    remove_column :upright_incidents, :auto_created
  end
end
