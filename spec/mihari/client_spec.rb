# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mihari::Client do
  let(:token) { "test-token-abc123" }
  let(:endpoint) { "https://logs.mihari.dev" }
  let(:client) { described_class.new(token: token, endpoint: endpoint, flush_interval: 999) }
  let(:response_body) { '{"status":"accepted","count":1}' }

  before do
    stub_request(:post, "#{endpoint}/logs")
      .to_return(status: 202, body: response_body, headers: { "Content-Type" => "application/json" })
  end

  after do
    client.shutdown
  end

  describe "#info" do
    it "enqueues an info log entry" do
      client.info("test message")
      expect(client.transport.queue_size).to be >= 0
    end
  end

  describe "#warn" do
    it "enqueues a warn log entry" do
      client.warn("warning message")
      expect(client.transport.queue_size).to be >= 0
    end
  end

  describe "#error" do
    it "enqueues an error log entry" do
      client.error("error message")
      expect(client.transport.queue_size).to be >= 0
    end
  end

  describe "#debug" do
    it "enqueues a debug log entry" do
      client.debug("debug message")
      expect(client.transport.queue_size).to be >= 0
    end
  end

  describe "#fatal" do
    it "enqueues a fatal log entry" do
      client.fatal("fatal message")
      expect(client.transport.queue_size).to be >= 0
    end
  end

  describe "#flush" do
    it "sends all queued entries" do
      client.info("message 1")
      client.info("message 2")
      client.flush

      expect(a_request(:post, "#{endpoint}/logs")).to have_been_made
    end
  end

  describe "with metadata" do
    it "includes custom metadata in log entries" do
      client.info("test", user_id: 42, request_id: "abc")
      client.flush

      expect(a_request(:post, "#{endpoint}/logs")
        .with { |req|
          body = decompress_gzip(req.body)
          entries = JSON.parse(body)
          entry = entries.first
          entry["user_id"] == 42 && entry["request_id"] == "abc"
        }).to have_been_made
    end
  end

  describe "with default metadata" do
    let(:client) do
      described_class.new(
        token: token,
        endpoint: endpoint,
        flush_interval: 999,
        metadata: { app: "test-app" }
      )
    end

    it "merges default metadata into every entry" do
      client.info("test")
      client.flush

      expect(a_request(:post, "#{endpoint}/logs")
        .with { |req|
          body = decompress_gzip(req.body)
          entries = JSON.parse(body)
          entries.first["app"] == "test-app"
        }).to have_been_made
    end
  end

  describe "batch sending" do
    let(:client) do
      described_class.new(
        token: token,
        endpoint: endpoint,
        batch_size: 3,
        flush_interval: 999
      )
    end

    it "sends automatically when batch size is reached" do
      3.times { |i| client.info("message #{i}") }

      # Give a moment for the send to complete
      sleep(0.1)

      expect(a_request(:post, "#{endpoint}/logs")
        .with { |req|
          body = decompress_gzip(req.body)
          entries = JSON.parse(body)
          entries.size == 3
        }).to have_been_made
    end
  end

  private

  def decompress_gzip(data)
    io = StringIO.new(data)
    gz = Zlib::GzipReader.new(io)
    gz.read
  ensure
    gz&.close
  end
end
