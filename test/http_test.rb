# frozen_string_literal: true

require_relative "test_helper"

class HttpTest < Minitest::Test
  def test_decode_json_body_reads_api_error_message
    error = assert_raises(Sveda::APIError) do
      Sveda::Http.decode_json_body(502, '{"message":"sidecar down"}')
    end

    assert_equal 502, error.status_code
    assert_equal "sidecar down", error.message
  end

  def test_decode_json_body_rejects_invalid_json
    assert_raises(Sveda::UnserializableResponseError) do
      Sveda::Http.decode_json_body(200, "not-json")
    end
  end
end
