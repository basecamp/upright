class AddProbeIdentityToUprightRollups < ActiveRecord::Migration[8.0]
  def change
    add_column :upright_rollups_probe_rollups, :probe_type, :string
    add_column :upright_rollups_probe_rollups, :probe_target, :string

    remove_index :upright_rollups_probe_rollups, column: [ :probe_name, :period_start ], unique: true
    add_index :upright_rollups_probe_rollups,
      [ :probe_name, :probe_type, :probe_target, :period_start ],
      unique: true, name: "idx_probe_rollups_identity_period"
  end
end
