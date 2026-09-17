# frozen_string_literal: true

require "json"

module Sveda
  class StreamParser
    SSE_DONE_LINE = "data: [DONE]"

    STREAM_EVENTS = [
      "message.start",
      "text.delta",
      "reasoning.delta",
      "tool.call",
      "tool.result",
      "tool.progress",
      "context.usage",
      "chat.title",
      "max_steps",
      "message.end",
      "error"
    ].freeze

    def each(body)
      return enum_for(:each, body) unless block_given?

      if body.is_a?(String)
        body.split(/\r\n|\n|\r/).each do |line|
          event = parse_line(line)
          yield event if event
        end
        return
      end

      buffer = +""
      body.each do |chunk|
        buffer << chunk.to_s
        while (newline_index = buffer.index("\n"))
          line = buffer.slice!(0, newline_index + 1)
          event = parse_line(line)
          yield event if event
        end
      end

      tail = buffer.strip
      return if tail.empty?

      event = parse_line(tail)
      yield event if event
    end

    def parse_line(line)
      trimmed = line.to_s.strip
      return unless trimmed.start_with?("data:")

      payload = trimmed[5..].to_s.strip
      return if payload.empty? || payload == "[DONE]"

      decoded = JSON.parse(payload)
      return unless decoded.is_a?(Hash)

      type = decoded["type"]
      return unless type.is_a?(String) && STREAM_EVENTS.include?(type)

      StreamEvent.new(type, decoded)
    rescue JSON::ParserError
      nil
    end
  end
end
