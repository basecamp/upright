class CreateUprightIncidents < ActiveRecord::Migration[8.0]
  def change
    create_table :upright_incidents do |t|
      t.string :type
      t.string :title, null: false
      t.string :status, null: false
      t.string :impact, null: false
      t.datetime :starts_at, null: false
      t.datetime :ends_at
      t.datetime :resolved_at

      t.timestamps
    end

    add_index :upright_incidents, [ :resolved_at, :starts_at ]
    add_index :upright_incidents, [ :type, :starts_at ]

    create_table :upright_incident_updates do |t|
      t.references :incident, null: false, foreign_key: { to_table: :upright_incidents }
      t.string :status, null: false
      t.text :body

      t.datetime :created_at, null: false
    end

    create_table :upright_incident_affected_services do |t|
      t.references :incident, null: false, foreign_key: { to_table: :upright_incidents }
      t.string :service_code, null: false
    end

    add_index :upright_incident_affected_services, [ :incident_id, :service_code ], unique: true
    add_index :upright_incident_affected_services, :service_code
  end
end
