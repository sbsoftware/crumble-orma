require "./spec_helper"

module Crumble::Orma::PageModelSpec
  class User < TestRecord
    column name : String
  end

  class Account < TestRecord
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

  class MissingUserView
    include Crumble::ContextView

    template do
      p { "User not found" }
    end
  end

  class UserFallbackRedirectPage < Crumble::Page
    model user : User, fallback_redirect: "/fallback"

    view do
      template do
        p { user.name }
      end
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

  class AccountUserPage < Crumble::Page
    model account : Account
    model user : User

    view do
      template do
        p { "#{account.id} #{user.id}" }
      end
    end
  end

  class PlainPage < Crumble::Page
    view do
      template do
        p { "Plain" }
      end
    end
  end

  describe "Crumble::Page.model" do
    before_each do
      User.continuous_migration!
    end

    after_each do
      User.db.close
    end

    it "loads the record from the id param" do
      user = User.create(name: "Jane")

      res = String.build do |io|
        ctx = Crumble::Server::TestRequestContext.new(response_io: io, resource: UserPage.uri_path(user_id: user.id))
        UserPage.handle(ctx).should eq(true)
        ctx.response.status_code.should eq(200)
        ctx.response.flush
      end

      res.should contain("Jane")
    end

    it "halts with 404 when the record is missing" do
      res = String.build do |io|
        ctx = Crumble::Server::TestRequestContext.new(response_io: io, resource: UserPage.uri_path(user_id: 123))
        UserPage.handle(ctx).should eq(true)
        ctx.response.status_code.should eq(404)
        ctx.response.flush
      end

      res.should eq("")
    end

    it "redirects when fallback_redirect is provided" do
      res = String.build do |io|
        ctx = Crumble::Server::TestRequestContext.new(response_io: io, resource: UserFallbackRedirectPage.uri_path(user_id: 123))
        UserFallbackRedirectPage.handle(ctx).should eq(true)
        ctx.response.status_code.should eq(303)
        ctx.response.headers["Location"].should eq("/fallback")
        ctx.response.flush
      end

      res.should eq("")
    end

    it "renders the fallback_view when provided" do
      res = String.build do |io|
        ctx = Crumble::Server::TestRequestContext.new(response_io: io, resource: UserFallbackViewPage.uri_path(user_id: 123))
        UserFallbackViewPage.handle(ctx).should eq(true)
        ctx.response.status_code.should eq(404)
        ctx.response.flush
      end

      res.should contain("User not found")
    end

    it "builds a positional uri_path for model ids" do
      account_id = Account.id(10)
      user_id = User.id(20)

      AccountUserPage.uri_path(account_id, user_id).should eq(
        AccountUserPage.uri_path(account_id: account_id, user_id: user_id)
      )
    end

    it "falls back to the default uri_path when no models are declared" do
      PlainPage.uri_path.should eq(PlainPage._root_path)
    end
  end
end
