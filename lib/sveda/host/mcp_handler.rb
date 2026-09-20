# frozen_string_literal: true

require "json"
require "rack"

module Sveda
  module Host
    class McpRackHandler
      def initialize(server)
        @server = server
      end

      def call(env)
        request = Rack::Request.new(env)
        return method_not_allowed unless request.post?

        token = bearer_token(request)
        return unauthorized unless @server.authenticate_token(token)
        return forbidden unless @server.authorized?
        @server.run_after_authenticate

        payload = JSON.parse(request.body.read)
        return bad_request unless payload["jsonrpc"] == "2.0"

        method = payload["method"].to_s
        id = payload["id"]
        params = payload["params"] || {}

        case method
        when "notifications/initialized"
          [202, {}, []]
        when "initialize"
          json_rpc(id, initialize_result)
        when "tools/list"
          json_rpc(id, { tools: list_tools })
        when "tools/call"
          json_rpc(id, call_tool(params))
        else
          [202, {}, []]
        end
      rescue JSON::ParserError
        bad_request
      end

      private

      def initialize_result
        result = {
          protocolVersion: Server::MCP_PROTOCOL_VERSION,
          capabilities: { tools: { listChanged: false } },
          serverInfo: {
            name: @server.config[:server_name],
            version: @server.config[:server_version]
          }
        }
        instructions = @server.config[:instructions]
        result[:instructions] = instructions unless instructions.empty?
        result
      end

      def list_tools
        @server.tools.map do |tool|
          {
            name: tool.name,
            title: tool.name,
            description: tool.description,
            inputSchema: tool.input_schema,
            _meta: {
              domain: tool.domain,
              mode: tool.mode
            }
          }
        end
      end

      def call_tool(params)
        name = params["name"].to_s
        arguments = params["arguments"].is_a?(Hash) ? params["arguments"] : {}
        tool = @server.tools.find { |candidate| candidate.name == name }
        return tool_error("unknown tool: #{name}") unless tool

        result = tool.handle(arguments)
        text = result.is_a?(String) ? result : JSON.generate(result)
        {
          content: [{ type: "text", text: text }],
          isError: false
        }
      rescue StandardError => error
        tool_error(error.message)
      end

      def tool_error(message)
        {
          content: [{ type: "text", text: message }],
          isError: true
        }
      end

      def json_rpc(id, result)
        body = JSON.generate(jsonrpc: "2.0", id: id, result: result)
        [200, { "Content-Type" => "application/json; charset=utf-8" }, [body]]
      end

      def bearer_token(request)
        header = request.get_header("HTTP_AUTHORIZATION").to_s.strip
        return "" if header.empty?

        prefix = "Bearer "
        return "" unless header.start_with?(prefix)

        header.delete_prefix(prefix).strip
      end

      def unauthorized
        [401, { "Content-Type" => "text/plain" }, ["unauthorized"]]
      end

      def forbidden
        [403, { "Content-Type" => "text/plain" }, ["forbidden"]]
      end

      def bad_request
        [400, { "Content-Type" => "text/plain" }, ["bad request"]]
      end

      def method_not_allowed
        [405, { "Content-Type" => "text/plain" }, ["method not allowed"]]
      end
    end
  end
end
