# frozen_string_literal: true

require_relative "test_helper"

class EchoHostTool < Sveda::Host::Tool
  def name
    "echo_message"
  end

  def description
    "Echo a message back."
  end

  def input_schema
    {
      type: "object",
      properties: {
        message: { type: "string", description: "Message to echo" }
      },
      required: ["message"]
    }
  end

  def mode
    Sveda::Host::MODE_READ
  end

  def domain
    "demo"
  end

  def handle(arguments)
    {
      success: true,
      data: { message: arguments["message"].to_s }
    }
  end
end

class DeleteHostTool < EchoHostTool
  def name
    "delete_post"
  end

  def mode
    Sveda::Host::MODE_DELETE
  end

  def confirmation
    "required"
  end
end

class HostMcpTest < Minitest::Test
  def test_server_start_session_sends_mcp_fields
    transport = FakeTransport.new(json: {
      "token" => "embed-token",
      "visitor_id" => "rails-playground",
      "expires_in" => 3600
    })
    server = Sveda::Host::Server.new(
      base_url: "https://sveda.test",
      host_api_key: "host-secret",
      mcp_url: "https://app.test/mcp/sveda",
      transport: transport
    )
    server.resolve_tools_using { [EchoHostTool.new] }

    session = server.start_session(visitor_id: "rails-playground")

    assert_equal "embed-token", session[:token]
    assert_equal "https://app.test/mcp/sveda", transport.requests[0][:payload]["host_mcp_url"]
    refute transport.requests[0][:payload]["host_mcp_token"].to_s.empty?
  end

  def test_mcp_requires_authentication
    server = Sveda::Host::Server.new(base_url: "https://sveda.test", host_api_key: "host-secret")
    server.resolve_tools_using { [EchoHostTool.new] }
    app = server.rack_app

    status, = app.call(
      Rack::MockRequest.env_for(
        "/mcp/sveda",
        method: "POST",
        input: { jsonrpc: "2.0", id: 1, method: "tools/list", params: {} }.to_json
      )
    )

    assert_equal 401, status
  end

  def test_mcp_lists_and_calls_tools
    server = Sveda::Host::Server.new(
      base_url: "https://sveda.test",
      host_api_key: "host-secret",
      server_name: "Playground Feed",
      instructions: "Feed tools for the current user."
    )
    server.resolve_tools_using { [EchoHostTool.new] }
    token = server.token_store.mint(user_id: "user-1")
    app = server.rack_app

    init_env = authorized_env(token, {
      jsonrpc: "2.0",
      id: 1,
      method: "initialize",
      params: {
        protocolVersion: Sveda::Host::Server::MCP_PROTOCOL_VERSION,
        capabilities: {},
        clientInfo: { name: "test", version: "0.1.0" }
      }
    })
    status, _headers, body = app.call(init_env)
    assert_equal 200, status
    init = JSON.parse(body.first)
    assert_equal "Playground Feed", init.dig("result", "serverInfo", "name")
    assert_equal "Feed tools for the current user.", init.dig("result", "instructions")

    list_env = authorized_env(token, {
      jsonrpc: "2.0",
      id: 2,
      method: "tools/list",
      params: { per_page: 250 }
    })
    _status, _headers, list_body = app.call(list_env)
    list = JSON.parse(list_body.first)
    names = list.dig("result", "tools").map { |tool| tool["name"] }
    assert_includes names, "echo_message"
    echo = list.dig("result", "tools").find { |tool| tool["name"] == "echo_message" }
    refute echo["_meta"].key?("confirmation")

    call_env = authorized_env(token, {
      jsonrpc: "2.0",
      id: 3,
      method: "tools/call",
      params: { name: "echo_message", arguments: { message: "hello" } }
    })
    _status, _headers, call_body = app.call(call_env)
    call = JSON.parse(call_body.first)
    text = call.dig("result", "content", 0, "text")
    decoded = JSON.parse(text)
    assert_equal "hello", decoded.dig("data", "message")
  end

  def test_confirmation_meta_is_published_when_required
    server = Sveda::Host::Server.new(base_url: "https://sveda.test", host_api_key: "host-secret")
    server.resolve_tools_using { [EchoHostTool.new, DeleteHostTool.new] }
    token = server.token_store.mint(user_id: "user-1")
    _status, _headers, list_body = server.rack_app.call(authorized_env(token, {
      jsonrpc: "2.0",
      id: 1,
      method: "tools/list",
      params: {}
    }))
    tools = JSON.parse(list_body.first).dig("result", "tools")
    echo = tools.find { |tool| tool["name"] == "echo_message" }
    remove = tools.find { |tool| tool["name"] == "delete_post" }
    refute echo["_meta"].key?("confirmation")
    assert_equal "required", remove.dig("_meta", "confirmation")
    assert_equal "delete", remove.dig("_meta", "mode")
  end

  def test_start_session_sends_policy
    transport = FakeTransport.new(json: {
      "token" => "embed-token",
      "visitor_id" => "rails-playground",
      "expires_in" => 3600
    })
    server = Sveda::Host::Server.new(
      base_url: "https://sveda.test",
      host_api_key: "host-secret",
      mcp_url: "https://app.test/mcp/sveda",
      transport: transport
    )
    server.resolve_tools_using { [EchoHostTool.new] }
    server.policy_using { |_user| "agent" }

    session = server.start_session(visitor_id: "rails-playground", user: { "id" => "user-1" })

    assert_equal "embed-token", session[:token]
    assert_equal "agent", transport.requests[0][:payload]["policy"]
  end

  def test_tools_call_filters_by_authenticated_user
    server = Sveda::Host::Server.new(base_url: "https://sveda.test", host_api_key: "host-secret")
    server.resolve_tools_using do |user|
      user.is_a?(Hash) && user["id"] == "user-1" ? [EchoHostTool.new] : []
    end
    allowed = server.token_store.mint(user_id: "user-1")
    denied = server.token_store.mint(user_id: "other")
    app = server.rack_app

    allowed_call = authorized_env(allowed, {
      jsonrpc: "2.0",
      id: 1,
      method: "tools/call",
      params: { name: "echo_message", arguments: { message: "hello" } }
    })
    _status, _headers, allowed_body = app.call(allowed_call)
    assert_equal false, JSON.parse(allowed_body.first).dig("result", "isError")

    denied_call = authorized_env(denied, {
      jsonrpc: "2.0",
      id: 2,
      method: "tools/call",
      params: { name: "echo_message", arguments: { message: "hello" } }
    })
    _status, _headers, denied_body = app.call(denied_call)
    denied_result = JSON.parse(denied_body.first).dig("result")
    assert_equal true, denied_result["isError"]
    assert_match(/unknown tool/i, denied_result.dig("content", 0, "text"))
  end

  def test_zero_arg_resolve_tools_callback_still_works
    server = Sveda::Host::Server.new(base_url: "https://sveda.test", host_api_key: "host-secret")
    server.resolve_tools_using { [EchoHostTool.new] }
    token = server.token_store.mint(user_id: "user-1")
    app = server.rack_app

    list_env = authorized_env(token, {
      jsonrpc: "2.0",
      id: 1,
      method: "tools/list",
      params: { per_page: 250 }
    })
    _status, _headers, list_body = app.call(list_env)
    names = JSON.parse(list_body.first).dig("result", "tools").map { |tool| tool["name"] }
    assert_equal ["echo_message"], names
  end

  def test_describe_matches_mcp_tools_list
    server = Sveda::Host::Server.new(base_url: "https://sveda.test", host_api_key: "host-secret")
    server.resolve_tools_using { [EchoHostTool.new] }
    user = { "id" => "user-1" }
    manifest = server.describe(user)
    assert_equal "sveda.host/v1", manifest[:schema]

    token = server.token_store.mint(user_id: "user-1")
    app = server.rack_app
    list_env = authorized_env(token, {
      jsonrpc: "2.0",
      id: 1,
      method: "tools/list",
      params: { per_page: 250 }
    })
    _status, _headers, list_body = app.call(list_env)
    listed = JSON.parse(list_body.first).dig("result", "tools").each_with_object({}) do |tool, acc|
      acc[tool["name"]] = tool
    end

    manifest[:tools].each do |tool|
      name = tool[:name]
      assert_equal listed[name]["description"], tool[:description]
      assert_equal listed[name]["_meta"]["domain"], tool[:_meta][:domain]
      assert_equal listed[name]["_meta"]["mode"], tool[:_meta][:mode]
    end
  end

  private

  def authorized_env(token, payload)
    Rack::MockRequest.env_for(
      "/mcp/sveda",
      method: "POST",
      "HTTP_AUTHORIZATION" => "Bearer #{token}",
      input: payload.to_json
    )
  end
end
