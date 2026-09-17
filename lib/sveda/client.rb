# frozen_string_literal: true

module Sveda
  class Client
    def initialize(base_url:, host_api_key: nil, embed_token: nil, transport: nil, timeout: 30, open_timeout: 5, headers: {})
      @base_url = base_url.to_s.sub(%r{/\z}, "")
      auth_headers = headers.dup
      auth_headers["Authorization"] = "Bearer #{host_api_key}" if host_api_key.to_s != ""
      auth_headers["X-Sveda-Embed-Token"] = embed_token.to_s if embed_token.to_s != ""
      inner = transport || Http.new(base_url: @base_url, timeout: timeout, open_timeout: open_timeout)
      @transport = HeaderTransport.new(inner, auth_headers)
    end

    def embed
      Embed.new(@transport)
    end

    def chat
      Chat.new(@transport)
    end

    def histories
      Histories.new(@transport)
    end

    def self.start_host_session(base_url:, host_api_key:, visitor_id:, host_mcp_url: nil, host_mcp_token: nil, **client_kwargs)
      origin = base_url.to_s.strip.sub(%r{/\z}, "")
      key = host_api_key.to_s.strip
      if origin.empty? || key.empty?
        raise ConfigurationError, "Задайте SVEDA_CLIENT_BASE_URL и SVEDA_CLIENT_HOST_API_KEY"
      end

      client = new(base_url: origin, host_api_key: key, **client_kwargs)
      token = client.embed.create_token(
        visitor_id: visitor_id,
        host_mcp_url: host_mcp_url,
        host_mcp_token: host_mcp_token
      )
      if token.token.empty?
        raise Error, "Sidecar returned an empty embed token."
      end

      {
        origin: origin,
        token: token.token,
        expires_in: token.expires_in,
        appearance: token.appearance
      }
    end
  end
end
