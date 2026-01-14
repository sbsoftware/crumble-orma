# crumble-orma

Small integration helpers between [Crumble](https://github.com/sbsoftware/crumble) and
[Orma](https://github.com/sbsoftware/orma).

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     crumble-orma:
       github: sbsoftware/crumble-orma
   ```

2. Run `shards install`

## Usage

```crystal
require "crumble-orma"
```

### Page model loading

```crystal
class User < Orma::Record
  column name : String
end

class UserPage < Crumble::Page
  model user : User

  view do
    template do
      p { user.name }
    end
  end
end
```

The `model` macro defines a `user_id` path param, loads the record before handling the
request, exposes `user` in the page view, and returns 404 when the record is missing.

You can provide a redirect or a fallback view when the record is missing:

```crystal
class UserPage < Crumble::Page
  model user : User, fallback_redirect: "/"

  view do
    template do
      p { user.name }
    end
  end
end

class MissingUserView
  include Crumble::ContextView

  template do
    p { "User not found" }
  end
end

class UserFallbackViewPage < Crumble::Page
  model user : User, fallback_view: MissingUserView

  view do
    template do
      p { user.name }
    end
  end
end
```

### Orma attributes in HTML + CSS

```crystal
class Model < Orma::Record
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
    color "#8a8a8a"
  end
end
```

Rendering adds a `data-orma-...` attribute to the element, and the attribute can be
used in CSS selectors via `Model.active(false)`.

## Development

- Install dependencies: `shards install`
- Run tests: `crystal spec`
- Format code before PRs: `crystal tool format`

## Contributing

1. Fork it (<https://github.com/sbsoftware/crumble-orma/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Stefan Bilharz](https://github.com/sbsoftware) - creator and maintainer
