require "spec"
require "../src/crumble-orma"
require "sqlite3"
require "../lib/crumble/spec/test_handler_context"

TEST_DB_CONNECTION_STRING = "sqlite3:%3Amemory%3A?max_pool_size=1"
Orma.db_connection_string = TEST_DB_CONNECTION_STRING

# TODO: Require this from orma directly
abstract class TestRecord < Orma::Record
  macro inherited
    id_column id : Int64
  end
end
