require "orma"

class Crumble::Page
  class ModelNotFoundError < Exception
    getter fallback_redirect : String?
    getter fallback_view_renderer : Proc(Crumble::Page, Nil)?

    def initialize(@fallback_redirect : String? = nil, @fallback_view_renderer : Proc(Crumble::Page, Nil)? = nil)
      super("Page model record not found")
    end
  end

  annotation ModelParam; end

  def self.handle(ctx) : Bool
    return false if match(ctx.request.path).nil?
    return false unless ctx.request.method == "GET"

    instance = new(ctx)
    if instance.responds_to? :_before
      ret_val = instance._before
      if ret_val == false
        ctx.response.status = :bad_request
        return true
      elsif ret_val.is_a?(Int32)
        ctx.response.status_code = ret_val
        return true
      end
    end

    begin
      instance._prepare_models_for_request
      instance.call
    rescue ex : ModelNotFoundError
      instance.handle_model_not_found(ex)
    end

    true
  end

  protected def handle_model_not_found(error : ModelNotFoundError) : Nil
    if fallback_redirect = error.fallback_redirect
      ctx.response.status_code = 303
      ctx.response.headers["Location"] = fallback_redirect
      return
    end

    # Render the fallback view through the page to preserve layout behavior.
    error.fallback_view_renderer.try &.call(self)
    ctx.response.status_code = 404
  end

  protected def _prepare_models_for_request : Nil
  end

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
        ctx.handler.as({{@type}}).{{name.id}}
      end
    end

    @[Crumble::Page::ModelParam(param_name: {{param_name.symbolize}})]
    getter {{name.id}} : {{klass}} do
      %id = Int64.from_http_param({{param_name.id}})
      if %record = {{klass}}.where(id: %id).first?
        %record
      else
        raise Crumble::Page::ModelNotFoundError.new(
          fallback_redirect: {{fallback_redirect}},
          fallback_view_renderer:
            {% if !fallback_view.is_a?(NilLiteral) %}
              ->(%page : Crumble::Page) do
                %ctx = %page.ctx
                %tpl = {{fallback_view}}.new(ctx: %ctx)
                %ctx.response.headers["Content-Type"] = "text/html"

                if %layout = %page.page_layout
                  %layout.to_html(%ctx.response) do |io, indent_level|
                    %tpl.to_html(io, indent_level)
                  end
                else
                  %tpl.to_html(%ctx.response)
                end
              end
            {% else %}
              nil
            {% end %}
        )
      end
    end

    protected def _prepare_models_for_request : Nil
      {% if @type.has_method?("_prepare_models_for_request") %}
        {% if @type.methods.map(&.name.id.stringify).includes?("_prepare_models_for_request") %}
          previous_def
        {% else %}
          super
        {% end %}
      {% end %}
      {{name.id}}
      nil
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
