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
        @policy_using = nil
        @tools = []
        @mint_token = ->(user = nil) { @token_store.mint(user_id: user_id_for(user)) }
        @mint_token_custom = false
        @authenticate = ->(token) { @token_store.lookup(token) }
        @authorize = nil
        @after_authenticate = nil
        @current_user = nil
      end

      def resolve_tools_using(&block)
        @resolve_tools = block
      end

      def policy_using(&block)
        @policy_using = block
      end

      def register_tool(tool)
        @tools << tool
      end

      def mint_token_using(&block)
        @mint_token = block
        @mint_token_custom = true
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

      def tools(user = nil)
        if @resolve_tools
          return Array(invoke_resolve_tools(user))
        end

        @tools
      end

      def policy_for(user)
        return nil unless @policy_using

        value = @policy_using.call(user)
        return nil if value.nil?

        policy = value.to_s.strip
        policy.empty? ? nil : policy
      end

      def authenticate_token(token)
        result = @authenticate.call(token)
        return nil if result.nil? || result == false

        if result == true
          { "id" => "anonymous" }
        elsif result.is_a?(Hash)
          result
        else
          { "id" => result.to_s }
        end
      end

      def authorized?(user = nil)
        return true unless @authorize

        @authorize.call(user) != false
      end

      def run_after_authenticate(user = nil)
        @after_authenticate&.call(user)
      end

      def start_session(visitor_id:, mcp_url: nil, user: nil)
        raise ConfigurationError, "Задайте SVEDA_CLIENT_BASE_URL и SVEDA_CLIENT_HOST_API_KEY" unless configured?

        session_user = user.nil? ? visitor_id : user
        mcp = (mcp_url || self.mcp_url).to_s.strip.sub(%r{/\z}, "")
        mcp_token = @mint_token.arity.zero? ? @mint_token.call : @mint_token.call(session_user)
        Sveda::Client.start_host_session(
          base_url: @config[:base_url],
          host_api_key: @config[:host_api_key],
          visitor_id: visitor_id,
          host_mcp_url: mcp.empty? ? nil : mcp,
          host_mcp_token: mcp_token,
          policy: policy_for(session_user),
          **@client_kwargs
        )
      end

      def rack_app
        McpRackHandler.new(self)
      end

      def mcp_tools(user = nil)
        tools(user).map do |tool|
          meta = {
            domain: tool.domain,
            mode: tool.mode
          }
          meta[:confirmation] = "required" if tool.respond_to?(:confirmation) && tool.confirmation == "required"
          entry = {
            name: tool.name,
            title: tool.name,
            description: tool.description,
            inputSchema: tool.input_schema,
            _meta: meta
          }
          entry
        end
      end

      def registered_hooks
        {
          resolve_tools: !@resolve_tools.nil?,
          policy: !@policy_using.nil?,
          authorize: !@authorize.nil?,
          visitor_id: false,
          mint_token: @mint_token_custom
        }
      end

      def describe(user = nil)
        authenticated = !user.nil?
        {
          schema: "sveda.host/v1",
          sdk: { language: "ruby", version: Sveda::VERSION },
          subject: {
            authenticated: authenticated,
            policy: authenticated ? policy_for(user) : nil
          },
          hooks: registered_hooks,
          tools: mcp_tools(user)
        }
      end

      private

      def invoke_resolve_tools(user)
        if @resolve_tools.arity.zero?
          @resolve_tools.call
        else
          @resolve_tools.call(user)
        end
      end

      def user_id_for(user)
        return "anonymous" if user.nil?

        if user.is_a?(Hash)
          (user[:id] || user["id"] || "anonymous").to_s
        else
          user.to_s
        end
      end

      def normalize_path(path)
        value = path.to_s.strip
        value = "/mcp/sveda" if value.empty?
        value.start_with?("/") ? value : "/#{value}"
      end
    end
  end
end
