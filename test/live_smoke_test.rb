# frozen_string_literal: true

require "json"
require "net/http"
require "test_helper"

class LiveSmokeTest < Minitest::Test
  def setup
    @base_url = ENV.fetch("SVEDA_BASE_URL", "").chomp("/")
    @host_key = ENV.fetch("SVEDA_HOST_KEY", "").strip
    skip "SVEDA_BASE_URL and SVEDA_HOST_KEY are required for live smoke tests" if @base_url.empty? || @host_key.empty?
  end

  def test_health_message_stream_and_history_flow
    contract = JSON.parse(File.read(File.expand_path("../contracts/sidecar.v1.json", __dir__)))
    %w[/sveda/health /sveda/ready].each do |path|
      response = Net::HTTP.get_response(URI("#{@base_url}#{path}"))
      assert response.is_a?(Net::HTTPSuccess)
      payload = JSON.parse(response.body)
      assert payload["ok"]
    end

    host = Sveda::Client.new(base_url: @base_url, host_api_key: @host_key)
    token = host.embed.create_token(visitor_id: "sdk-compat-ruby")
    assert token.token.start_with?("sveda_embed_")

    embed = Sveda::Client.new(base_url: @base_url, embed_token: token.token)
    events = embed.chat.create_streamed(
      prompt: "compat stream",
      chatId: "sdk-compat-ruby",
      messages: [{ id: "m1", role: "user", content: "compat stream" }]
    )
    refute_empty events
    assert events.any? { |event| contract["streamEvents"].include?(event["type"]) }

    message = embed.chat.create(
      prompt: "compat smoke",
      chatId: "sdk-compat-ruby-json",
      messages: [{ id: "m2", role: "user", content: "compat smoke" }]
    )
    contract["message"]["responseRequired"].each do |key|
      assert message.payload[key]
    end

    histories = embed.histories.list
    assert histories.key?(contract["histories"]["listKey"])
  end
end
