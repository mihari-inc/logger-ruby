# frozen_string_literal: true

require "socket"

module Mihari
  class Configuration
    attr_accessor :token, :endpoint, :batch_size, :flush_interval,
                  :max_retries, :compression, :hostname, :source

    def initialize
      @token = nil
      @endpoint = nil
      @batch_size = 10
      @flush_interval = 5
      @max_retries = 3
      @compression = :gzip
      @hostname = Socket.gethostname
      @source = "ruby"
    end

    def validate!
      raise ArgumentError, "Mihari token is required" if token.nil? || token.empty?
      raise ArgumentError, "Mihari endpoint is required" if endpoint.nil? || endpoint.empty?
    end

    def freeze
      validate!
      super
    end
  end
end
