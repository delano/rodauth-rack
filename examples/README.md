# Examples

This directory contains example applications demonstrating rodauth-rack features.

## Available Examples

### [sinatra-table-guard](sinatra-table-guard/)

Barebones Sinatra application demonstrating the `table_guard` feature with dynamic table discovery and various validation modes.

**Quick start:**

```bash
cd examples/sinatra-table-guard
bundle install

# Run the web server
bundle exec rackup

# Or start interactive console
bundle exec ruby console.rb
```

**Features demonstrated:**

- Dynamic table discovery from enabled Rodauth features
- Multiple validation modes (warn, error, raise, halt, custom)
- Sequel generation modes (log, migration, create, sync)
- Console introspection of table configuration
- Multi-tenant scenarios

See the [sinatra-table-guard README](sinatra-table-guard/README.md) for detailed usage.

## Running Examples

All examples are self-contained with their own Gemfile:

```bash
cd examples/<example-name>
bundle install

# Web server
bundle exec rackup

# Interactive console
bundle exec ruby console.rb
```

## Requirements

Each example has its own `Gemfile` with dependencies:

- `sinatra` - Web framework
- `roda` - Rodauth's foundation
- `sequel` - Database toolkit
- `rodauth` - Authentication framework
- `sqlite3` / `pg` / `mysql2` - Database adapter
- `puma` - Web server

## Creating Your Own

Feel free to copy and modify these examples for your own applications!
