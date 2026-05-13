# Upright engine

This is the `upright` Rails engine. All development, testing, and database
management run from this directory (the engine root). Never `cd` into
`test/dummy/`.

## Running tests

```bash
bin/rails test                                  # full suite
bin/rails test test/models/upright/service_test.rb
bin/rails test test/models/upright/service_test.rb:10
```

## Database management

The test/dev database lives in `test/dummy/storage/`. The schema is
checked in at `test/dummy/db/schema.rb`. Always operate via the engine
root — don't prefix with `app:`.

```bash
RAILS_ENV=test bin/rails db:drop db:create db:schema:load   # reset test DB
RAILS_ENV=test bin/rails db:schema:load                     # apply current schema
```

### Adding a new engine migration

Engine migrations live in `db/migrate/`. The `upright.migrations`
initializer deliberately skips the dummy app, so `bin/rails db:migrate`
from the engine root won't apply engine migrations to the test DB. To
apply a new migration and refresh `schema.rb`:

```bash
RAILS_ENV=test bin/rails app:db:migrate     # one-time, after adding a migration
```

After this, `schema.rb` is updated and subsequent runs of
`db:schema:load` will pick up the new tables. Commit `schema.rb`
alongside the migration file.
