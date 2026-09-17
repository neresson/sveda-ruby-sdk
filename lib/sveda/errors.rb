# frozen_string_literal: true

module Sveda
  class Error < StandardError; end

  class ConfigurationError < Error; end

  class AuthenticationError < Error; end

  class UnserializableResponseError < Error; end

  class TransportError < Error
    attr_reader :status_code

    def initialize(message, status_code: nil)
      @status_code = status_code
      super(message)
    end
  end

  class APIError < Error
    attr_reader :status_code, :response

    def initialize(message, status_code: 0, response: nil)
      @status_code = status_code
      @response = response
      super(message)
    end
  end
end
