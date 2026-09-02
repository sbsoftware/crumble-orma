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

  class RequestForm < Crumble::ModelForm(Group)
    field title : String
    field attachment : Crumble::UploadedFile?, type: :file

    validation do
      unless model.recipients.any? { |recipient| recipient.display_name == title }
        add_error("must name a recipient")
      end
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
      form.submitted?.should be_true
      form.model.should be(group)
      form.recipient_id.should eq(2_i64)
      form.to_html.should contain(%(<option value="1">Alice</option>))
      form.to_html.should contain(%(<option value="2" selected>Bob</option>))
    end

    it "parses a URL-encoded request while retaining the model for validation" do
      group = Group.new([Recipient.new(1_i64, "Alice")])
      ctx = test_handler_context(method: "POST", headers: HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded"}, body: "title=Alice")
      form = RequestForm.from_request(ctx, group)

      form.valid?.should be_true
      form.submitted?.should be_true
      form.model.should be(group)
      form.title.should eq("Alice")
      form.attachment.should be_nil
    end

    it "parses multipart text and file fields while retaining the model" do
      group = Group.new([Recipient.new(1_i64, "Alice")])
      boundary = "model-form-boundary"
      body = multipart_body(boundary, [{"title", nil, nil, "Alice"}, {"attachment", "receipt.txt", "text/plain", "paid"}])
      ctx = test_handler_context(method: "POST", headers: HTTP::Headers{"Content-Type" => "multipart/form-data; boundary=#{boundary}"}, body: body)
      form = RequestForm.from_request(ctx, group)

      form.valid?.should be_true
      form.model.should be(group)
      form.title.should eq("Alice")
      upload = form.attachment.not_nil!
      upload.filename.should eq("receipt.txt")
      upload.content_type.should eq("text/plain")
      upload.open(&.gets_to_end).should eq("paid")
      ctx.cleanup_temporary_files
      File.exists?(upload.path).should be_false
    end
  end

  private def self.multipart_body(boundary, parts)
    String.build do |io|
      parts.each do |name, filename, content_type, contents|
        io << "--#{boundary}\r\nContent-Disposition: form-data; name=\"#{name}\""
        io << "; filename=\"#{filename}\"" unless filename.nil?
        io << "\r\nContent-Type: #{content_type}" unless content_type.nil?
        io << "\r\n\r\n#{contents}\r\n"
      end
      io << "--#{boundary}--\r\n"
    end
  end
end
