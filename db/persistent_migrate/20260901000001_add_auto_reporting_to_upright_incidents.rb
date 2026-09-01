class AddAutoReportingToUprightIncidents < ActiveRecord::Migration[8.0]
  def change
    add_column :upright_incidents, :auto_created, :boolean, default: false, null: false
    add_column :upright_incidents, :last_seen_down_at, :datetime
  end
end
