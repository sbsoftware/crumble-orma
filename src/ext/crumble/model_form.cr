module Crumble::ModelFormRequestModels
  alias Setter = Proc(Pointer(Void), Nil)

  @@models = {} of Fiber => Array(Setter)
  @@lock = Mutex.new

  def self.push(model : T) : Nil forall T
    # Crystal has no erased generic container, so retain a typed setter instead of
    # weakening ModelForm's model type while the inherited parser constructs it.
    setter = ->(target : Pointer(Void)) { target.as(Pointer(T)).value = model }
    @@lock.synchronize { (@@models[Fiber.current] ||= [] of Setter) << setter }
  end

  def self.pop : Nil
    @@lock.synchronize do
      models = @@models[Fiber.current]
      models.pop
      @@models.delete(Fiber.current) if models.empty?
    end
  end

  def self.set_current(target : Pointer(Void)) : Nil
    @@lock.synchronize { @@models[Fiber.current].last.call(target) }
  end
end

class Crumble::ModelForm(TModel) < Crumble::Form
  getter model : TModel

  def initialize(ctx : Crumble::Server::HandlerContext, @model : TModel, **values : **T) forall T
    super(ctx, false, **values)
  end

  def initialize(ctx : Crumble::Server::HandlerContext, submitted : Bool, @model : TModel, **values : **T) forall T
    super(ctx, submitted, **values)
  end

  # Crumble's request parser constructs the form without application-specific arguments.
  # Keep the model scoped to the current fiber while that shared parser runs.
  def initialize(ctx : Crumble::Server::HandlerContext, submitted : Bool, **values : **T) forall T
    initialize(ctx, submitted, self.class.__request_model, **values)
  end

  def self.from_request(ctx : Crumble::Server::HandlerContext, model : TModel) : self
    Crumble::ModelFormRequestModels.push(model)
    begin
      from_request(ctx)
    ensure
      Crumble::ModelFormRequestModels.pop
    end
  end

  protected def self.__request_model : TModel
    model = uninitialized TModel
    Crumble::ModelFormRequestModels.set_current(pointerof(model).as(Pointer(Void)))
    model
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
