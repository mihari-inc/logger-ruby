# frozen_string_literal: true

require "time"
require "socket"
require "json"

module Mihari
  class LogEntry
    VALID_LEVELS = %w[debug info warn error fatal].freeze

    attr_reader :dt, :level, :message, :metadata

    def initialize(level:, message:, metadata: {})
      normalized = level.to_s.downcase
      unless VALID_LEVELS.include?(normalized)
        raise ArgumentError, "Invalid log level: #{level}. Must be one of: #{VALID_LEVELS.join(', ')}"
      end

      @dt = Time.now.utc.iso8601(3)
      @level = normalized
      @message = message.to_s
      @metadata = metadata.is_a?(Hash) ? metadata : {}
    end

    def to_h
      base = {
        "dt" => @dt,
        "level" => @level,
        "message" => @message,
        "hostname" => Socket.gethostname,
        "pid" => Process.pid,
        "ruby_version" => RUBY_VERSION
      }
      base.merge(@metadata.transform_keys(&:to_s))
    end

    def to_json(*args)
      to_h.to_json(*args)
    end
  end
end
