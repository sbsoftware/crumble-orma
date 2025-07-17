require "./spec_helper"

module Crumble::Orma::FormsSpec
  class Model < FakeRecord
    id_column id : Int64
    column name : String
  end

  class Form < Crumble::Form
    field name : String
  end

  describe "Form#values" do
    before_each do
      FakeDB.reset
    end

    after_each do
      FakeDB.assert_empty!
    end

    it "can be used directly to create a new Model record" do
      form = Form.from_www_form(URI::Params.encode({name: "sbsoftware"}))

      form.valid?.should be_true

      FakeDB.expect("INSERT INTO #{Model.table_name}(name) VALUES ('sbsoftware')")

      model = Model.create(**form.values)

      model.name.should eq("sbsoftware")
    end
  end
end
