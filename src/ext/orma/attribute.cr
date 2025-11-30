class Orma::Attribute(T)
  def to_html_attrs(_tag, attrs)
    attrs[html_attr_name] = value.to_s
  end

  def to_css_selector
    CSS::AttrSelector.new(html_attr_name, value.to_s)
  end

  private def html_attr_name
    "data-orma-#{model.name.underscore.gsub("::", "--").gsub("_", "-")}-#{name}"
  end
end
