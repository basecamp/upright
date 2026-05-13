class CreateUprightRollups < ActiveRecord::Migration[8.0]
  def change
    create_table :upright_rollups_probe_rollups do |t|
      t.string :probe_name, null: false
      t.string :probe_service
      t.datetime :period_start, null: false
      t.float :uptime_fraction, null: false
      t.integer :status, default: 0, null: false

      t.timestamps
    end

    add_index :upright_rollups_probe_rollups, [ :probe_name, :period_start ], unique: true
    add_index :upright_rollups_probe_rollups, [ :probe_service, :period_start ]

    create_table :upright_rollups_service_rollups do |t|
      t.string :service_code, null: false
      t.datetime :period_start, null: false
      t.float :uptime_fraction, null: false
      t.integer :status, default: 0, null: false

      t.timestamps
    end

    add_index :upright_rollups_service_rollups, [ :service_code, :period_start ], unique: true
  end
end
