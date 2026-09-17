# frozen_string_literal: true

module Sveda
  class Chat
    def initialize(transport)
      @transport = transport
    end

    def create(params = {}, **kwargs)
      payload = params.merge(kwargs)
      Message.from_payload(@transport.request_json("POST", "/sveda/message", payload))
    end

    def create_streamed(params = {}, **kwargs, &block)
      payload = params.merge(kwargs)
      body = @transport.request_stream("POST", "/sveda/stream", payload)
      parser = StreamParser.new
      return parser.each(body, &block) if block

      parser.each(body)
    end
  end
end
