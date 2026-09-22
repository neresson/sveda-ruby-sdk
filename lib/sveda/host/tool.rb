# frozen_string_literal: true

module Sveda
  module Host
    MODE_READ = "read"
    MODE_WRITE = "write"
    MODE_DELETE = "delete"

    class Tool
      def name
        raise NotImplementedError
      end

      def description
        raise NotImplementedError
      end

      def input_schema
        { type: "object", properties: {} }
      end

      def mode
        MODE_READ
      end

      def domain
        "default"
      end

      def confirmation
        nil
      end

      def handle(_arguments)
        raise NotImplementedError
      end
    end
  end
end
