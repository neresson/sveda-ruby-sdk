# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

module Sveda
  class Http
    def initialize(base_url:, timeout: 30, open_timeout: 5)
      @base_url = base_url.to_s.sub(%r{/\z}, "")
      @timeout = timeout
      @open_timeout = open_timeout
    end

    def request_json(method, path, payload = {}, headers = {})
      response = send_request(
        method,
        path,
        payload,
        headers.merge(
          "Accept" => "application/json",
          "Content-Type" => "application/json"
        )
      )
      self.class.decode_json_body(response.code.to_i, response.body.to_s)
    end

    def request_stream(method, path, payload = {}, headers = {})
      chunks = +""
      send_request(
        method,
        path,
        payload,
        headers.merge(
          "Accept" => "application/vnd.sveda.stream+json",
          "Content-Type" => "application/json"
        ),
        stream: true
      ) do |response|
        self.class.decode_json_body(response.code.to_i, "") unless (200...300).cover?(response.code.to_i)
        response.read_body do |chunk|
          chunks << chunk
        end
      end
      chunks
    end

    def self.decode_json_body(status, body)
      if [401, 403].include?(status)
        raise AuthenticationError, "Sveda API authentication failed with status #{status}"
      end

      unless (200...300).cover?(status)
        decoded = parse_object(body)
        message = decoded.is_a?(Hash) && decoded["message"].is_a?(String) ? decoded["message"] : "Sveda API request failed with status #{status}"
        raise APIError.new(message, status_code: status, response: decoded)
      end

      return {} if body.nil? || body.empty?

      decoded = parse_object(body)
      unless decoded.is_a?(Hash)
        raise UnserializableResponseError, "Unable to decode Sveda API response as JSON."
      end

      decoded
    end

    def self.stringify_keys(object)
      case object
      when Hash
        object.each_with_object({}) do |(key, value), memo|
          memo[key.to_s] = stringify_keys(value)
        end
      when Array
        object.map { |value| stringify_keys(value) }
      else
        object
      end
    end

    def self.parse_object(body)
      return nil if body.nil? || body.empty?

      JSON.parse(body)
    rescue JSON::ParserError
      nil
    end

    private

    REQUESTS = {
      "GET" => Net::HTTP::Get,
      "POST" => Net::HTTP::Post,
      "PATCH" => Net::HTTP::Patch,
      "PUT" => Net::HTTP::Put,
      "DELETE" => Net::HTTP::Delete
    }.freeze

    def send_request(method, path, payload, headers, stream: false, &block)
      uri = resolve_uri(path)
      request_class = REQUESTS.fetch(method.to_s.upcase)
      request = request_class.new(uri)
      headers.each { |name, value| request[name] = value }
      body = self.class.stringify_keys(payload || {})
      request.body = JSON.generate(body) if request.request_body_permitted?

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.read_timeout = @timeout
      http.open_timeout = @open_timeout

      if stream
        http.request(request, &block)
      else
        http.request(request)
      end
    rescue AuthenticationError, APIError, UnserializableResponseError
      raise
    rescue StandardError => error
      raise TransportError, error.message
    end

    def resolve_uri(path)
      return URI.parse(path) if path.start_with?("http://", "https://")

      URI.parse("#{@base_url}/#{path.sub(%r{\A/}, "")}")
    end
  end

  class HeaderTransport
    def initialize(inner, headers)
      @inner = inner
      @headers = headers
    end

    def request_json(method, path, payload = {}, headers = {})
      @inner.request_json(method, path, payload, @headers.merge(headers))
    end

    def request_stream(method, path, payload = {}, headers = {})
      @inner.request_stream(method, path, payload, @headers.merge(headers))
    end
  end
end
