# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "sveda"
require "minitest/autorun"

class FakeTransport
  attr_reader :requests

  def initialize(json: {}, stream: "")
    @json = json
    @stream = stream
    @requests = []
  end

  def request_json(method, uri, payload = {}, headers = {})
    @requests << { method: method, uri: uri, payload: payload, headers: headers }
    return @json.call(method, uri, payload, headers) if @json.respond_to?(:call)

    @json
  end

  def request_stream(method, uri, payload = {}, headers = {})
    @requests << { method: method, uri: uri, payload: payload, headers: headers }
    @stream
  end
end
