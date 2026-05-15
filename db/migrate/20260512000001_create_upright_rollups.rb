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
  end
end
