require "orma"

class Crumble::Page
  macro model(type_decl)
    {% name = type_decl.var %}
    {% klass = type_decl.type %}
    {% param_name = "#{name.id}_id".id %}

    path_param {{param_name}}

    view do
      def {{name.id}} : {{klass}}
        ctx.handler.as({{@type}}).{{name.id}}.not_nil!
      end
    end

    getter {{name.id}} : {{klass}}?

    before do
      %id = Int64.from_http_param({{param_name.id}})
      @{{name.id}} = {{klass}}.where(id: %id).first?
      return 404 unless @{{name.id}}
      true
    end
  end
end
