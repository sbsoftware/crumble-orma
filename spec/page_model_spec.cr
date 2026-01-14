require "./spec_helper"

module Crumble::Orma::PageModelSpec
  class User < TestRecord
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
  end
end
