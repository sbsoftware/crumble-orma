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

    template do
      p { user.name }
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

    template do
      p { user.name }
    end
  end

  class UserFallbackViewPage < Crumble::Page
    model user : User, fallback_view: MissingUserView

    template do
      p { user.name }
    end
  end

  class AccountUserPage < Crumble::Page
    model account : Account
    model user : User

    template do
      p { "#{account.id} #{user.id}" }
    end
  end

  class PlainPage < Crumble::Page
    template do
      p { "Plain" }
    end
  end

  class IgnoringUserPage < Crumble::Page
    model user : User

    template do
      p { "No user access" }
    end
  end

  class UnrelatedErrorPage < Crumble::Page
    model user : User

    def call
      raise "boom"
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

    it "exposes a non-nilable model getter on the page instance" do
      user = User.create(name: "Jane")
      ctx = Crumble::Server::TestRequestContext.new(resource: UserPage.uri_path(user_id: user.id))

      UserPage.new(ctx).user.name.to_s.should eq("Jane")
    end

    it "raises a dedicated error carrying fallback parameters" do
      redirect_ctx = Crumble::Server::TestRequestContext.new(resource: UserFallbackRedirectPage.uri_path(user_id: 123))
      redirect_error = expect_raises(Crumble::Page::ModelNotFoundError) { UserFallbackRedirectPage.new(redirect_ctx).user }
      redirect_error.fallback_redirect.should eq("/fallback")
      redirect_error.fallback_view_renderer.should be_nil

      view_ctx = Crumble::Server::TestRequestContext.new(resource: UserFallbackViewPage.uri_path(user_id: 123))
      view_error = expect_raises(Crumble::Page::ModelNotFoundError) { UserFallbackViewPage.new(view_ctx).user }
      view_error.fallback_redirect.should be_nil
      view_error.fallback_view_renderer.should_not be_nil
    end

    it "halts with 404 when the record is missing" do
      String.build do |io|
        ctx = Crumble::Server::TestRequestContext.new(response_io: io, resource: UserPage.uri_path(user_id: 123))
        UserPage.handle(ctx).should eq(true)
        ctx.response.status_code.should eq(404)
        ctx.response.flush
      end
    end

    it "redirects when fallback_redirect is provided" do
      String.build do |io|
        ctx = Crumble::Server::TestRequestContext.new(response_io: io, resource: UserFallbackRedirectPage.uri_path(user_id: 123))
        UserFallbackRedirectPage.handle(ctx).should eq(true)
        ctx.response.status_code.should eq(303)
        ctx.response.headers["Location"].should eq("/fallback")
        ctx.response.flush
      end
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

    it "does not map unrelated errors to 404" do
      user = User.create(name: "Jane")
      ctx = Crumble::Server::TestRequestContext.new(resource: UnrelatedErrorPage.uri_path(user_id: user.id))

      expect_raises(Exception, "boom") do
        UnrelatedErrorPage.handle(ctx)
      end
    end

    it "allows rendering with status 200 when the model is not accessed" do
      res = String.build do |io|
        ctx = Crumble::Server::TestRequestContext.new(response_io: io, resource: IgnoringUserPage.uri_path(user_id: 123))
        IgnoringUserPage.handle(ctx).should eq(true)
        ctx.response.status_code.should eq(200)
        ctx.response.flush
      end

      res.should contain("No user access")
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
