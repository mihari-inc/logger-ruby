# frozen_string_literal: true

module Mihari
  class Client
    attr_reader :transport

    def initialize(token:, endpoint:, **options)
      @transport = Transport.new(
        token: token,
        endpoint: endpoint,
        batch_size: options.fetch(:batch_size, Transport::DEFAULT_BATCH_SIZE),
        flush_interval: options.fetch(:flush_interval, Transport::DEFAULT_FLUSH_INTERVAL),
        max_retries: options.fetch(:max_retries, Transport::DEFAULT_MAX_RETRIES),
        compression: options.fetch(:compression, :gzip)
      )
      @default_metadata = options.fetch(:metadata, {})
    end

    def debug(message, metadata = {})
      log("debug", message, metadata)
    end

    def info(message, metadata = {})
      log("info", message, metadata)
    end

    def warn(message, metadata = {})
      log("warn", message, metadata)
    end

    def error(message, metadata = {})
      log("error", message, metadata)
    end

    def fatal(message, metadata = {})
      log("fatal", message, metadata)
    end

    def flush
      @transport.flush
    end

    def shutdown
      @transport.shutdown
    end

    private

    def log(level, message, metadata)
      merged = @default_metadata.merge(metadata)
      entry = LogEntry.new(level: level, message: message, metadata: merged)
      @transport.enqueue(entry)
    end
  end
end
