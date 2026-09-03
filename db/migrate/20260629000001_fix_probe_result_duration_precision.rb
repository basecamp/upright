class FixProbeResultDurationPrecision < ActiveRecord::Migration[8.0]
  # `t.decimal :duration` with no precision becomes DECIMAL(10,0) on MySQL,
  # which rounds every duration to a whole second on write. Probe durations
  # are sub-second floats from a monotonic clock, so they were all stored as
  # 0. SQLite preserved the fractional value, which is why this only surfaced
  # after the MySQL migration. Give the column microsecond precision.
  def up
    change_column :upright_probe_results, :duration, :decimal, precision: 10, scale: 6
  end

  def down
    change_column :upright_probe_results, :duration, :decimal
  end
end
