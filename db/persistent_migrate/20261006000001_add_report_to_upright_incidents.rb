class AddReportToUprightIncidents < ActiveRecord::Migration[8.0]
  def change
    add_column :upright_incidents, :report, :text
  end
end
