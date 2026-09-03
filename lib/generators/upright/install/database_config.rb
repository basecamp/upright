module Upright
  module Generators
    # Rewrites the single-database development and test entries that `rails new`
    # writes into the three databases Upright uses:
    #
    #   primary     probe results and Active Storage artifacts
    #   persistent  rollups, incidents and maintenance windows, which outlive a
    #               site's probe data; its migrations ship with the gem
    #   queue       Solid Queue
    #
    # Pure string transformation so the install generator's edit can be tested
    # without a generated application.
    module DatabaseConfig
      ENVIRONMENTS = %w[development test].freeze

      PERSISTENT_MIGRATIONS = %(<%= Gem.loaded_specs["upright"].gem_dir %>/db/persistent_migrate)

      def self.rewrite(yaml)
        ENVIRONMENTS.reduce(yaml) do |rewritten, env|
          rewritten.sub(single_database(env), split_databases(env))
        end
      end

      def self.single_database(env)
        "#{env}:\n  <<: *default\n  database: storage/#{env}.sqlite3"
      end

      def self.split_databases(env)
        <<~YAML.chomp
          #{env}:
            primary:
              <<: *default
              database: storage/#{env}.sqlite3
            persistent:
              <<: *default
              database: storage/#{env}_persistent.sqlite3
              migrations_paths: #{PERSISTENT_MIGRATIONS}
            queue:
              <<: *default
              database: storage/#{env}_queue.sqlite3
              migrations_paths: db/queue_migrate
        YAML
      end
    end
  end
end
