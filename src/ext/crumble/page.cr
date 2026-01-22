require "orma"

class Crumble::Page
  annotation ModelParam; end

  macro model(type_decl, fallback_redirect = nil, fallback_view = nil)
    {% if !fallback_redirect.is_a?(NilLiteral) && !fallback_view.is_a?(NilLiteral) %}
      {% raise "Provide only one of fallback_redirect or fallback_view to model" %}
    {% end %}
    {% if !fallback_view.is_a?(NilLiteral) %}
      {% unless fallback_view.is_a?(Path) && fallback_view.resolve < Crumble::ContextView %}
        {% raise "fallback_view must be a Crumble::ContextView class" %}
      {% end %}
    {% end %}

    {% name = type_decl.var %}
    {% klass = type_decl.type %}
    {% param_name = "#{name.id}_id".id %}

    path_param {{param_name}}

    view do
      def {{name.id}} : {{klass}}
        ctx.handler.as({{@type}}).{{name.id}}.not_nil!
      end
    end

    @[Crumble::Page::ModelParam(param_name: {{param_name.symbolize}})]
    getter {{name.id}} : {{klass}}?

    before do
      %id = Int64.from_http_param({{param_name.id}})
      @{{name.id}} = {{klass}}.where(id: %id).first?
      unless @{{name.id}}
        {% if !fallback_redirect.is_a?(NilLiteral) %}
          ctx.response.status_code = 303
          ctx.response.headers["Location"] = {{fallback_redirect}}
          return 303
        {% elsif !fallback_view.is_a?(NilLiteral) %}
          %tpl = {{fallback_view}}.new(ctx: ctx)
          ctx.response.headers["Content-Type"] = "text/html"

          if %layout = page_layout
            %layout.to_html(ctx.response) do |io, indent_level|
              %tpl.to_html(io, indent_level)
            end
          else
            %tpl.to_html(ctx.response)
          end

          return 404
        {% else %}
          return 404
        {% end %}
      end
      true
    end
  end

  def self.uri_path(*ids)
    {% begin %}
      {% model_params = @type.instance_vars.select { |ivar| ivar.annotation(Crumble::Page::ModelParam) } %}
      {% if model_params.size > 0 %}
        if ids.size != {{model_params.size}}
          raise ArgumentError.new("Expected {{model_params.size}} path params for #{self}, got #{ids.size}")
        end
        uri_path(
          {% for ivar, idx in model_params %}
            {% param_name = ivar.annotation(Crumble::Page::ModelParam)[:param_name] %}
            {{param_name.id}}: ids[{{idx}}]{% if idx < model_params.size - 1 %}, {% end %}
          {% end %}
        )
      {% else %}
        if ids.size > 0
          raise ArgumentError.new("Expected 0 path params for #{self}, got #{ids.size}")
        end
        segments = _root_path.split('/').reject(&.empty?)

        _path_parts.each do |part|
          case part
          when Crumble::PathMatching::NestedPathPart
            segments << part.segment
          when Crumble::PathMatching::ParamPathPart
            raise ArgumentError.new("Missing path param '#{part.name}' for #{self}")
          end
        end

        "/" + segments.join("/")
      {% end %}
    {% end %}
  end
end
