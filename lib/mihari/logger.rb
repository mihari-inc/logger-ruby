# frozen_string_literal: true

require "logger"

module Mihari
  # A Ruby ::Logger compatible interface that sends logs to Mihari.
  # Drop-in replacement for the standard Logger.
  #
  #   logger = Mihari::Logger.new(token: "...", endpoint: "...")
  #   logger.info("Hello world")
  #   logger.error("Something failed") { "extra context" }
  #
  class Logger
    SEVERITY_MAP = {
      ::Logger::DEBUG => "debug",
      ::Logger::INFO => "info",
      ::Logger::WARN => "warn",
      ::Logger::ERROR => "error",
      ::Logger::FATAL => "fatal",
      ::Logger::UNKNOWN => "error"
    }.freeze

    attr_accessor :level, :progname, :formatter

    def initialize(token: nil, endpoint: nil, client: nil, **options)
      @client = client || Client.new(token: token, endpoint: endpoint, **options)
      @level = ::Logger::DEBUG
      @progname = nil
      @formatter = nil
    end

    def add(severity, message = nil, progname = nil, &block)
      severity ||= ::Logger::UNKNOWN
      return true if severity < @level

      if message.nil?
        if block
          message = block.call
        else
          message = progname
          progname = @progname
        end
      end

      mihari_level = SEVERITY_MAP.fetch(severity, "info")
      metadata = {}
      metadata["progname"] = progname if progname

      @client.send(mihari_level, message.to_s, metadata)
      true
    end
    alias_method :log, :add

    def debug(message = nil, &block)
      add(::Logger::DEBUG, message, &block)
    end

    def info(message = nil, &block)
      add(::Logger::INFO, message, &block)
    end

    def warn(message = nil, &block)
      add(::Logger::WARN, message, &block)
    end

    def error(message = nil, &block)
      add(::Logger::ERROR, message, &block)
    end

    def fatal(message = nil, &block)
      add(::Logger::FATAL, message, &block)
    end

    def unknown(message = nil, &block)
      add(::Logger::UNKNOWN, message, &block)
    end

    def debug?
      @level <= ::Logger::DEBUG
    end

    def info?
      @level <= ::Logger::INFO
    end

    def warn?
      @level <= ::Logger::WARN
    end

    def error?
      @level <= ::Logger::ERROR
    end

    def fatal?
      @level <= ::Logger::FATAL
    end

    def close
      @client.shutdown
    end

    def flush
      @client.flush
    end
  end
end
