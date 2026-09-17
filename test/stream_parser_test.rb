# frozen_string_literal: true

require_relative "test_helper"

class StreamParserTest < Minitest::Test
  def test_it_parses_stream_events_and_stops_on_done
    content = [
      ": connected",
      "",
      'data: {"type":"message.start"}',
      "",
      'data: {"type":"text.delta","delta":"Hello"}',
      "",
      'data: {"type":"message.end","finishReason":"stop"}',
      "",
      "data: [DONE]",
      ""
    ].join("\n")

    events = Sveda::StreamParser.new.each(content).to_a

    assert_equal 3, events.length
    assert_equal "message.start", events[0].type
    assert_equal "text.delta", events[1].type
    assert_equal "Hello", events[1].delta
    assert_equal "message.end", events[2].type
  end

  def test_it_ignores_invalid_lines
    content = %(event: ping\ndata: not-json\ndata: {"type":"unknown.event"}\n)
    events = Sveda::StreamParser.new.each(content).to_a

    assert_empty events
  end
end
