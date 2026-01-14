require "./spec_helper"

module Crumble::Orma::FormsSpec
  class Model < TestRecord
    id_column id : Int64
    column name : String
  end

  class Form < Crumble::Form
    field name : String
  end

  describe "Form#values" do
    before_each do
      Model.continuous_migration!
    end

    after_each do
      Model.db.close
    end

    it "can be used directly to create a new Model record" do
      ctx = test_handler_context
      form = Form.from_www_form(ctx, URI::Params.encode({name: "sbsoftware"}))

      form.valid?.should be_true

      model = Model.create(**form.values)

      model.name.should eq("sbsoftware")
      Model.find(model.id).name.should eq("sbsoftware")
      Model.all.count.should eq(1)
    end
  end
end
