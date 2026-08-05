# Durable, replicated source-of-truth data (rollups, later incidents/maintenance) on the persistent DB.
class Upright::PersistentRecord < ActiveRecord::Base
  self.abstract_class = true

  connects_to database: { writing: :persistent, reading: :persistent }

  def self.up?
    with_connection { |connection| connection.select_value("SELECT 1") }.present?
  rescue ActiveRecord::ActiveRecordError
    false
  end
end
