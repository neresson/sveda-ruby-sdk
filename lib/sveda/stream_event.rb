# frozen_string_literal: true

module Sveda
  class StreamEvent
    attr_reader :type, :payload

    def initialize(type, payload)
      @type = type
      @payload = payload
    end

    def [](key)
      payload[key] || payload[key.to_s] || payload[key.to_sym]
    end

    def to_h
      payload
    end

    def method_missing(name, *args, &block)
      key = name.to_s
      return payload[key] if payload.key?(key)

      super
    end

    def respond_to_missing?(name, include_private = false)
      payload.key?(name.to_s) || super
    end
  end
end
