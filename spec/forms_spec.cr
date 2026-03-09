require "./spec_helper"

module Crumble::Orma::FormsSpec
  class Model < TestRecord
    column name : String
  end

  class Form < Crumble::Form
    field name : String
  end

  record Recipient, id : Int64, display_name : String

  class Group
    getter recipients : Array(Recipient)

    def initialize(@recipients); end
  end

  class ReimbursementForm < Crumble::ModelForm(Group)
    field recipient_id : Int64, type: :select, options: recipient_options

    def recipient_options
      model.recipients.map { |recipient| {recipient.id.to_s, recipient.display_name} }
    end
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

  describe "Crumble::ModelForm" do
    it "keeps the typed model on manual initialization" do
      group = Group.new([Recipient.new(1_i64, "Alice")])

      form = ReimbursementForm.new(test_handler_context, group, recipient_id: 1_i64)

      form.model.should be(group)
      form.values.should eq({recipient_id: 1_i64})
    end

    it "parses the request body and resolves select options from the model" do
      group = Group.new([Recipient.new(1_i64, "Alice"), Recipient.new(2_i64, "Bob")])

      form = ReimbursementForm.from_www_form(
        test_handler_context,
        group,
        URI::Params.encode({recipient_id: "2"})
      )

      form.valid?.should be_true
      form.model.should be(group)
      form.recipient_id.should eq(2_i64)
      form.to_html.should contain(%(<option value="1">Alice</option>))
      form.to_html.should contain(%(<option value="2" selected>Bob</option>))
    end
  end
end
