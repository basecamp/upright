class AddCreatedByToIncidents < ActiveRecord::Migration[8.0]
  def change
    add_column :upright_incidents, :created_by, :string
    add_column :upright_incidents, :updated_by, :string
    add_column :upright_incident_updates, :created_by, :string
  end
end
