# frozen_string_literal: true

require "net/http"
require "uri"
require "json"
require "zlib"
require "stringio"

module Mihari
  class Transport
    DEFAULT_BATCH_SIZE = 10
    DEFAULT_FLUSH_INTERVAL = 5
    DEFAULT_MAX_RETRIES = 3
    RETRY_BASE_DELAY = 0.5

    def initialize(token:, endpoint:, batch_size: DEFAULT_BATCH_SIZE,
                   flush_interval: DEFAULT_FLUSH_INTERVAL,
                   max_retries: DEFAULT_MAX_RETRIES,
                   compression: :gzip)
      @token = token
      @endpoint = endpoint
      @batch_size = batch_size
      @flush_interval = flush_interval
      @max_retries = max_retries
      @compression = compression

      @queue = []
      @mutex = Mutex.new
      @stopped = false
      @flush_thread = nil

      start_flush_thread
      install_at_exit_hook
    end

    def enqueue(log_entry)
      batch_to_send = nil

      @mutex.synchronize do
        return if @stopped

        @queue << log_entry.to_h
        batch_to_send = @queue.shift(@batch_size) if @queue.size >= @batch_size
      end

      send_batch(batch_to_send) if batch_to_send
    end

    def flush
      batch_to_send = nil

      @mutex.synchronize do
        return if @queue.empty?

        batch_to_send = @queue.dup
        @queue.clear
      end

      send_batch(batch_to_send) if batch_to_send
    end

    def shutdown
      @mutex.synchronize { @stopped = true }
      stop_flush_thread
      flush
    end

    def queue_size
      @mutex.synchronize { @queue.size }
    end

    private

    def start_flush_thread
      @flush_thread = Thread.new do
        loop do
          sleep(@flush_interval)
          break if @mutex.synchronize { @stopped }

          flush
        end
      end
      @flush_thread.abort_on_exception = false
    end

    def stop_flush_thread
      return unless @flush_thread

      @flush_thread.kill
      @flush_thread.join(2)
      @flush_thread = nil
    end

    def install_at_exit_hook
      transport = self
      at_exit { transport.shutdown }
    end

    def send_batch(entries)
      return if entries.nil? || entries.empty?

      uri = build_uri
      body = JSON.generate(entries)
      compressed_body = compress(body)

      attempts = 0
      begin
        attempts += 1
        response = perform_request(uri, compressed_body)
        handle_response(response)
      rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED,
             Errno::ECONNRESET, Errno::EHOSTUNREACH, IOError, SocketError => e
        if attempts < @max_retries
          sleep(RETRY_BASE_DELAY * (2**(attempts - 1)))
          retry
        else
          warn "[Mihari] Failed to send logs after #{@max_retries} attempts: #{e.message}"
        end
      rescue StandardError => e
        warn "[Mihari] Unexpected error sending logs: #{e.message}"
      end
    end

    def build_uri
      base = @endpoint.chomp("/")
      URI.parse("#{base}/logs")
    end

    def perform_request(uri, body)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == "https")
      http.open_timeout = 10
      http.read_timeout = 30

      request = Net::HTTP::Post.new(uri.path)
      request["Authorization"] = "Bearer #{@token}"
      request["Content-Type"] = "application/json"
      request["User-Agent"] = "mihari-ruby/#{Mihari::VERSION}"

      case @compression
      when :gzip
        request["Content-Encoding"] = "gzip"
      when :deflate
        request["Content-Encoding"] = "deflate"
      end

      request.body = body

      http.request(request)
    end

    def compress(data)
      case @compression
      when :gzip
        gzip_compress(data)
      when :deflate
        Zlib::Deflate.deflate(data)
      else
        data
      end
    end

    def gzip_compress(data)
      io = StringIO.new
      io.set_encoding("BINARY")
      gz = Zlib::GzipWriter.new(io)
      gz.write(data)
      gz.close
      io.string
    end

    def handle_response(response)
      case response.code.to_i
      when 200..299
        # Success
      when 401
        warn "[Mihari] Authentication failed: invalid token"
      when 429
        warn "[Mihari] Rate limited by server"
      when 500..599
        raise IOError, "Server error: #{response.code}"
      else
        warn "[Mihari] Unexpected response: #{response.code} #{response.body}"
      end
    end
  end
end
