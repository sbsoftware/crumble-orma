require "./spec_helper"

module Crumble::Orma::AttributeSpec
  class Model < FakeRecord
    id_column id : Int32
    column active : Bool
  end

  class View
    getter model : Model

    def initialize(@model); end

    ToHtml.instance_template do
      div model.active do
        model.active ? "Active" : "Inactive"
      end
    end
  end

  class Style < CSS::Stylesheet
    rule Model.active(false) do
      display :none
    end
  end

  describe "Model#active" do
    it "can be used as an attribute to an HTML element" do
      expected = <<-HTML.gsub(/\n\s*/, "")
      <div data-orma-crumble--orma--attribute-spec--model-active="true">
        Active
      </div>
      HTML

      View.new(Model.new(id: 1, active: true)).to_html.should eq(expected)
    end

    it "can be used as a selector in a CSS rule" do
      expected = <<-CSS
      [data-orma-crumble--orma--attribute-spec--model-active='false'] {
        display: none;
      }
      CSS

      Style.to_s.should eq(expected)
    end
  end
end
