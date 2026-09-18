# frozen_string_literal: true

module Sveda
  module Host
    class Server
      MCP_PROTOCOL_VERSION = "2025-11-25"

      attr_reader :config, :token_store

      def initialize(base_url:, host_api_key:, mcp_url: nil, mcp_path: "/mcp/sveda",
                     server_name: "Host Application", server_version: "0.1.0",
                     instructions: "", token_ttl_seconds: 3600, **client_kwargs)
        @client_kwargs = client_kwargs
        @config = {
          base_url: base_url.to_s.strip.sub(%r{/\z}, ""),
          host_api_key: host_api_key.to_s.strip,
          mcp_url: mcp_url.to_s.strip.sub(%r{/\z}, ""),
          mcp_path: normalize_path(mcp_path),
          server_name: server_name,
          server_version: server_version,
          instructions: instructions.to_s,
          token_ttl_seconds: token_ttl_seconds
        }
        @token_store = MemoryTokenStore.new(ttl_seconds: token_ttl_seconds)
        @resolve_tools = nil
        @tools = []
        @mint_token = -> { @token_store.mint }
        @authenticate = ->(token) { @token_store.valid?(token) }
        @authorize = nil
        @after_authenticate = nil
      end

      def resolve_tools_using(&block)
        @resolve_tools = block
      end

      def register_tool(tool)
        @tools << tool
      end

      def mint_token_using(&block)
        @mint_token = block
      end

      def authenticate_using(&block)
        @authenticate = block
      end

      def authorize_using(&block)
        @authorize = block
      end

      def after_authenticate_using(&block)
        @after_authenticate = block
      end

      def configured?
        !@config[:base_url].empty? && !@config[:host_api_key].empty?
      end

      def mcp_url
        return @config[:mcp_url] unless @config[:mcp_url].empty?

        @config[:mcp_path]
      end

      def tools
        @resolve_tools ? Array(@resolve_tools.call) : @tools
      end

      def authenticate_token(token)
        @authenticate.call(token)
      end

      def authorized?
        return true unless @authorize

        @authorize.call != false
      end

      def run_after_authenticate
        @after_authenticate&.call
      end

      def start_session(visitor_id:, mcp_url: nil)
        raise ConfigurationError, "Задайте SVEDA_CLIENT_BASE_URL и SVEDA_CLIENT_HOST_API_KEY" unless configured?

        mcp = (mcp_url || self.mcp_url).to_s.strip.sub(%r{/\z}, "")
        mcp_token = @mint_token.call
        Sveda::Client.start_host_session(
          base_url: @config[:base_url],
          host_api_key: @config[:host_api_key],
          visitor_id: visitor_id,
          host_mcp_url: mcp.empty? ? nil : mcp,
          host_mcp_token: mcp_token,
          **@client_kwargs
        )
      end

      def rack_app
        McpRackHandler.new(self)
      end

      private

      def normalize_path(path)
        value = path.to_s.strip
        value = "/mcp/sveda" if value.empty?
        value.start_with?("/") ? value : "/#{value}"
      end
    end
  end
end
