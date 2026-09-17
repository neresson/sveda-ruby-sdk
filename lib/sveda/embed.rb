# frozen_string_literal: true

module Sveda
  class Embed
    def initialize(transport)
      @transport = transport
    end

    def create_token(visitor_id: nil, host_mcp_url: nil, host_mcp_token: nil)
      payload = {}
      payload["visitor_id"] = visitor_id if visitor_id.to_s != ""
      if host_mcp_url.to_s != "" && host_mcp_token.to_s != ""
        payload["host_mcp_url"] = host_mcp_url
        payload["host_mcp_token"] = host_mcp_token
      end

      EmbedToken.from_payload(@transport.request_json("POST", "/sveda/embed/token", payload))
    end

    def config
      @transport.request_json("GET", "/sveda/embed/config")
    end
  end
end
