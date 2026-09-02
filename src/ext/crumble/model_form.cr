class Crumble::ModelForm(TModel) < Crumble::Form
  getter model : TModel

  def initialize(ctx : Crumble::Server::HandlerContext, @model : TModel, **values : **T) forall T
    super(ctx, false, **values)
  end

  def initialize(ctx : Crumble::Server::HandlerContext, submitted : Bool, @model : TModel, **values : **T) forall T
    super(ctx, submitted, **values)
  end

  def self.from_www_form(ctx : Crumble::Server::HandlerContext, model : TModel, www_form : ::String) : self
    from_www_form(ctx, model, ::URI::Params.parse(www_form))
  end

  def self.from_www_form(ctx : Crumble::Server::HandlerContext, model : TModel, params : ::URI::Params) : self
    {% begin %}
      {% for ivar in @type.instance_vars.select { |iv| iv.annotation(Crumble::Form::Field) } %}
        %field{ivar.name} = {{ivar.type}}.from_www_form(params, {{ivar.name.stringify}})
      {% end %}

      new(ctx, true, model,
        {% for ivar in @type.instance_vars.select { |iv| iv.annotation(Crumble::Form::Field) } %}
          {{ivar.name.id}}: %field{ivar.name},
        {% end %}
      )
    {% end %}
  end
end
