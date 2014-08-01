require "mediawiki_api"
require "webmock/rspec"

describe MediawikiApi::Client do
  let(:api_url) { "http://localhost/api.php" }
  let(:index_url) { "http://localhost/w/index.php" }

  subject { MediawikiApi::Client.new(api_url) }
  body_base = { cookieprefix: "prefix", sessionid: "123" }

  describe "#log_in" do

    it "logs in when API returns Success" do
      stub_request(:post, api_url).
        with(body: { format: "json", action: "login", lgname: "Test", lgpassword: "qwe123" }).
        to_return(body: { login: body_base.merge({ result: "Success" }) }.to_json )

      subject.log_in "Test", "qwe123"
      expect(subject.logged_in).to be true
    end

    context "when API returns NeedToken" do
      before do
        headers = { "Set-Cookie" => "prefixSession=789; path=/; domain=localhost; HttpOnly" }

        stub_request(:post, api_url).
          with(body: { format: "json", action: "login", lgname: "Test", lgpassword: "qwe123" }).
          to_return(
            body: { login: body_base.merge({ result: "NeedToken", token: "456" }) }.to_json,
            headers: { "Set-Cookie" => "prefixSession=789; path=/; domain=localhost; HttpOnly" }
          )

        @success_req = stub_request(:post, api_url).
          with(body: { format: "json", action: "login", lgname: "Test", lgpassword: "qwe123", lgtoken: "456" }).
          with(headers: { "Cookie" => "prefixSession=789" }).
          to_return(body: { login: body_base.merge({ result: "Success" }) }.to_json )
      end

      it "logs in" do
        subject.log_in "Test", "qwe123"
        expect(subject.logged_in).to be true
      end

      it "sends second request with token and cookies" do
        subject.log_in "Test", "qwe123"
        expect(@success_req).to have_been_requested
      end
    end

    context "when API returns neither Success nor NeedToken" do
      before do
        stub_request(:post, api_url).
          with(body: { format: "json", action: "login", lgname: "Test", lgpassword: "qwe123" }).
          to_return(body: { login: body_base.merge({ result: "EmptyPass" }) }.to_json )
      end

      it "does not log in" do
        expect { subject.log_in "Test", "qwe123" }.to raise_error
        expect(subject.logged_in).to be false
      end

      it "raises error with proper message" do
        expect { subject.log_in "Test", "qwe123" }.to raise_error MediawikiApi::LoginError, "EmptyPass"
      end
    end
  end

  describe "#create_page" do
    before do
      stub_request(:get, api_url).
        with(query: { format: "json", action: "tokens", type: "edit" }).
        to_return(body: { tokens: { edittoken: "t123" } }.to_json )
      @edit_req = stub_request(:post, api_url).
        with(body: { format: "json", action: "edit", title: "Test", text: "test123", token: "t123" })
    end

    it "creates a page using an edit token" do
      subject.create_page("Test", "test123")
      expect(@edit_req).to have_been_requested
    end

    context "when API returns Success" do
      before do
        @edit_req.to_return(body: { result: "Success" }.to_json )
      end

      it "returns a MediawikiApi::Page"
    end
  end

  describe "#delete_page" do
    before do
      stub_request(:get, api_url).
        with(query: { format: "json", action: "tokens", type: "delete" }).
        to_return(body: { tokens: { deletetoken: "t123" } }.to_json )
      @delete_req = stub_request(:post, api_url).
        with(body: { format: "json", action: "delete", title: "Test", reason: "deleting", token: "t123" })
    end

    it "deletes a page using a delete token" do
      subject.delete_page("Test", "deleting")
      expect(@delete_req).to have_been_requested
    end

    # evaluate results
  end

  describe "#get_wikitext" do
    before do
      @get_req = stub_request(:get, index_url).with(query: { action: "raw", title: "Test" })
    end

    it "fetches a page" do
      subject.get_wikitext("Test")
      expect(@get_req).to have_been_requested
    end
  end

  describe "#create_account" do
    it "creates an account when API returns Success" do
      stub_request(:post, api_url).
        with(body: { format: "json", action: "createaccount", name: "Test", password: "qwe123" }).
        to_return(body: { createaccount: body_base.merge({ result: "Success" }) }.to_json )

      expect(subject.create_account("Test", "qwe123")).to be true
    end

    context "when API returns NeedToken" do
      before do
        headers = { "Set-Cookie" => "prefixSession=789; path=/; domain=localhost; HttpOnly" }

        stub_request(:post, api_url).
          with(body: { format: "json", action: "createaccount", name: "Test", password: "qwe123" }).
          to_return(
            body: { createaccount: body_base.merge({ result: "NeedToken", token: "456" }) }.to_json,
            headers: { "Set-Cookie" => "prefixSession=789; path=/; domain=localhost; HttpOnly" }
          )

        @success_req = stub_request(:post, api_url).
          with(body: { format: "json", action: "createaccount", name: "Test", password: "qwe123", token: "456" }).
          with(headers: { "Cookie" => "prefixSession=789" }).
          to_return(body: { createaccount: body_base.merge({ result: "Success" }) }.to_json )
      end

      it "creates an account" do
        expect(subject.create_account("Test", "qwe123")).to be true
      end

      it "sends second request with token and cookies" do
        subject.create_account "Test", "qwe123"
        expect(@success_req).to have_been_requested
      end
    end

    # docs don't specify other results, but who knows
    # http://www.mediawiki.org/wiki/API:Account_creation
    context "when API returns neither Success nor NeedToken" do
      before do
        stub_request(:post, api_url).
          with(body: { format: "json", action: "createaccount", name: "Test", password: "qwe123" }).
          to_return(body: { createaccount: body_base.merge({ result: "WhoKnows" }) }.to_json )
      end

      it "raises error with proper message" do
        expect { subject.create_account "Test", "qwe123" }.to raise_error MediawikiApi::CreateAccountError, "WhoKnows"
      end
    end
  end

  describe "#watch_page" do
    before do
      stub_request(:get, api_url).
        with(query: { format: "json", action: "tokens", type: "watch" }).
        to_return(body: { tokens: { watchtoken: "t123" } }.to_json )
      @watch_req = stub_request(:post, api_url).
        with(body: { format: "json", token: "t123", action: "watch", titles: "Test" })
    end

    it "sends a valid watch request" do
      subject.watch_page("Test")
      expect(@watch_req).to have_been_requested
    end
  end

  describe "#unwatch_page" do
    before do
      stub_request(:get, api_url).
        with(query: { format: "json", action: "tokens", type: "watch" }).
        to_return(body: { tokens: { watchtoken: "t123" } }.to_json )
      @watch_req = stub_request(:post, api_url).
        with(body: { format: "json", token: "t123", action: "watch", titles: "Test", unwatch: "true" })
    end

    it "sends a valid unwatch request" do
      subject.unwatch_page("Test")
      expect(@watch_req).to have_been_requested
    end
  end
end
