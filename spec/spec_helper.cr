require "spec"
require "../src/crumble-orma"

# TODO: Require this from orma directly
abstract class FakeRecord < Orma::Record
  macro inherited
    id_column id : Int64
  end

  def self.db
    FakeDB
  end

  def self.continuous_migration!
    # noop
  end
end
