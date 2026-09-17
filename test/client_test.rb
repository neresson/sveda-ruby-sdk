# frozen_string_literal: true

require_relative "test_helper"

class ClientTest < Minitest::Test
  def test_it_issues_embed_tokens_with_host_credentials
    transport = FakeTransport.new(json: {
      "token" => "sveda_embed_test",
      "visitor_id" => "visitor-1",
      "expires_in" => 3600
    })
    client = Sveda::Client.new(
      base_url: "https://sveda.test",
      host_api_key: "host-secret",
      transport: transport
    )

    response = client.embed.create_token(
      visitor_id: "visitor-1",
      host_mcp_url: "https://app.test/mcp/sveda",
      host_mcp_token: "mcp-token"
    )

    assert_equal "sveda_embed_test", response.token
    assert_equal "visitor-1", response.visitor_id
    assert_equal 3600, response.expires_in
    assert_equal "POST", transport.requests[0][:method]
    assert_equal "/sveda/embed/token", transport.requests[0][:uri]
    assert_equal "visitor-1", transport.requests[0][:payload]["visitor_id"]
    assert_equal "https://app.test/mcp/sveda", transport.requests[0][:payload]["host_mcp_url"]
    assert_equal "Bearer host-secret", transport.requests[0][:headers]["Authorization"]
  end

  def test_it_streams_chat_events
    transport = FakeTransport.new(
      stream: %(data: {"type":"message.start"}\n\ndata: {"type":"text.delta","delta":"Hi"}\n\ndata: [DONE]\n\n)
    )
    client = Sveda::Client.new(
      base_url: "https://sveda.test",
      embed_token: "embed-token",
      transport: transport
    )

    events = client.chat.create_streamed(
      messages: [{ role: "user", content: "Hello" }],
      chatId: "chat-1"
    ).to_a

    assert_equal 2, events.length
    assert_equal "message.start", events[0].type
    assert_equal "text.delta", events[1].type
    assert_equal "POST", transport.requests[0][:method]
    assert_equal "/sveda/stream", transport.requests[0][:uri]
    assert_equal "embed-token", transport.requests[0][:headers]["X-Sveda-Embed-Token"]
  end

  def test_it_fetches_message_and_histories
    transport = FakeTransport.new(json: lambda { |method, uri, _payload, _headers|
      if method == "POST" && uri == "/sveda/message"
        { "explanation" => "Hello", "tokens_used" => 12, "chat_id" => "chat-1" }
      elsif method == "GET" && uri == "/sveda/chat-histories"
        { "histories" => [] }
      else
        {}
      end
    })
    client = Sveda::Client.new(
      base_url: "https://sveda.test",
      embed_token: "embed-token",
      transport: transport
    )

    message = client.chat.create(
      messages: [{ role: "user", content: "Hello" }],
      chatId: "chat-1"
    )

    assert_equal "Hello", message.explanation
    assert_equal 12, message.tokens_used
    assert_equal "chat-1", message.chat_id

    histories = client.histories.list
    assert histories.key?("histories")
  end

  def test_start_host_session_returns_origin_token_and_appearance
    transport = FakeTransport.new(json: {
      "token" => "sveda_embed_test",
      "visitor_id" => "rails-playground",
      "expires_in" => 3600,
      "appearance" => { "theme" => "dark" }
    })

    session = Sveda::Client.start_host_session(
      base_url: "https://sveda.test/",
      host_api_key: "host-secret",
      visitor_id: "rails-playground",
      transport: transport
    )

    assert_equal "https://sveda.test", session[:origin]
    assert_equal "sveda_embed_test", session[:token]
    assert_equal 3600, session[:expires_in]
    assert_equal({ "theme" => "dark" }, session[:appearance])
    assert_equal "rails-playground", transport.requests[0][:payload]["visitor_id"]
  end

  def test_start_host_session_requires_credentials
    error = assert_raises(Sveda::ConfigurationError) do
      Sveda::Client.start_host_session(base_url: "", host_api_key: "", visitor_id: "rails-playground")
    end

    assert_includes error.message, "SVEDA_CLIENT_BASE_URL"
    assert_includes error.message, "SVEDA_CLIENT_HOST_API_KEY"
  end

  def test_decode_json_body_raises_on_auth_failure
    error = assert_raises(Sveda::AuthenticationError) do
      Sveda::Http.decode_json_body(401, "")
    end

    assert_includes error.message, "401"
  end
end
