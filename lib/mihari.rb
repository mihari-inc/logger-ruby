# frozen_string_literal: true

require_relative "mihari/version"
require_relative "mihari/configuration"
require_relative "mihari/log_entry"
require_relative "mihari/transport"
require_relative "mihari/client"
require_relative "mihari/logger"

module Mihari
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
      configuration
    end

    def reset_configuration!
      @configuration = Configuration.new
    end

    # Convenience method to create a client from global configuration.
    def client
      config = configuration
      Client.new(
        token: config.token,
        endpoint: config.endpoint,
        batch_size: config.batch_size,
        flush_interval: config.flush_interval,
        max_retries: config.max_retries,
        compression: config.compression
      )
    end

    # Convenience method to create a Logger from global configuration.
    def logger
      config = configuration
      Logger.new(
        token: config.token,
        endpoint: config.endpoint,
        batch_size: config.batch_size,
        flush_interval: config.flush_interval,
        max_retries: config.max_retries,
        compression: config.compression
      )
    end
  end
end
