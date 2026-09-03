require "test_helper"
require "generators/upright/install/database_config"

class Upright::Generators::DatabaseConfigTest < ActiveSupport::TestCase
  RAILS_DEFAULT = <<~YAML
    default: &default
      adapter: sqlite3
      pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
      timeout: 5000

    development:
      <<: *default
      database: storage/development.sqlite3

    test:
      <<: *default
      database: storage/test.sqlite3

    production:
      primary:
        <<: *default
        database: storage/production.sqlite3
  YAML

  test "splits development and test into primary, persistent and queue databases" do
    config = load(Upright::Generators::DatabaseConfig.rewrite(RAILS_DEFAULT))

    %w[development test].each do |env|
      assert_equal %w[primary persistent queue], config.fetch(env).keys
      assert_equal "storage/#{env}.sqlite3", config.dig(env, "primary", "database")
      assert_equal "storage/#{env}_persistent.sqlite3", config.dig(env, "persistent", "database")
      assert_equal "storage/#{env}_queue.sqlite3", config.dig(env, "queue", "database")
      assert_equal "db/queue_migrate", config.dig(env, "queue", "migrations_paths")
    end
  end

  test "points the persistent database's migrations at the installed gem" do
    config = load(Upright::Generators::DatabaseConfig.rewrite(RAILS_DEFAULT))

    migrations_path = config.dig("development", "persistent", "migrations_paths")
    assert_equal Upright::Engine.root.join("db/persistent_migrate").to_s, migrations_path
    assert Dir.exist?(migrations_path)
  end

  test "leaves production and the defaults alone" do
    rewritten = Upright::Generators::DatabaseConfig.rewrite(RAILS_DEFAULT)

    assert_includes rewritten, "default: &default\n  adapter: sqlite3"
    assert_includes rewritten, "production:\n  primary:\n    <<: *default\n    database: storage/production.sqlite3"
  end

  test "does nothing to a database.yml that already differs from the Rails default" do
    custom = "development:\n  primary:\n    adapter: mysql2\n"

    assert_equal custom, Upright::Generators::DatabaseConfig.rewrite(custom)
  end

  private
    def load(yaml)
      YAML.safe_load(ERB.new(yaml).result, aliases: true)
    end
end
