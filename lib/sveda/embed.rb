# frozen_string_literal: true

module Sveda
  class Embed
    def initialize(transport)
      @transport = transport
    end

    def create_token(visitor_id: nil, host_mcp_url: nil, host_mcp_token: nil, policy: nil, grants: nil)
      payload = {}
      payload["visitor_id"] = visitor_id if visitor_id.to_s != ""
      if host_mcp_url.to_s != "" && host_mcp_token.to_s != ""
        payload["host_mcp_url"] = host_mcp_url
        payload["host_mcp_token"] = host_mcp_token
      end
      if !policy.nil? && policy.to_s.strip != ""
        payload["policy"] = policy.to_s.strip
      end
      payload["grants"] = grants if grants.is_a?(Hash)

      EmbedToken.from_payload(@transport.request_json("POST", "/sveda/embed/token", payload))
    end

    def config
      @transport.request_json("GET", "/sveda/embed/config")
    end
  end
end
