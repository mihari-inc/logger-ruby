# Mihari Ruby

A lightweight, thread-safe Ruby client for collecting and shipping structured logs to the Mihari log ingestion API.

## Features

- Structured JSON log entries with ISO 8601 timestamps
- Automatic batching (configurable batch size)
- Background flush thread with configurable interval
- Gzip and deflate compression
- Automatic retries with exponential backoff
- Thread-safe queue operations
- Drop-in Ruby `::Logger` replacement
- Auto-capture of hostname, PID, and Ruby version
- Graceful shutdown via `at_exit` hook
- Zero external dependencies (uses Net::HTTP from stdlib)

## Installation

Add to your Gemfile:

```ruby
gem "mihari-logger"
```

Then run:

```
bundle install
```

Or install directly:

```
gem install mihari-logger
```

## Quick Start

### Direct Client Usage

```ruby
require "mihari"

client = Mihari::Client.new(
  token: "your-api-token",
  endpoint: "https://logs.example.com"
)

client.info("Application started")
client.warn("Disk usage above 80%", disk_percent: 83)
client.error("Request failed", status: 500, path: "/api/users")

# Flush remaining logs before exit (also done automatically via at_exit)
client.flush
```

### Global Configuration

```ruby
require "mihari"

Mihari.configure do |c|
  c.token = ENV["MIHARI_TOKEN"]
  c.endpoint = ENV["MIHARI_ENDPOINT"]
  c.batch_size = 25
  c.flush_interval = 10
  c.compression = :gzip
end

client = Mihari.client
client.info("Configured globally")
```

### Logger Interface (Drop-in Replacement)

```ruby
require "mihari"

logger = Mihari::Logger.new(
  token: "your-api-token",
  endpoint: "https://logs.example.com"
)

# Use exactly like Ruby's built-in Logger
logger.info("User signed in")
logger.debug("Cache hit for key: user_42")
logger.error("Payment processing failed")
logger.fatal("Database connection lost")

# Set minimum log level
logger.level = Logger::WARN
```

### Rails Integration

```ruby
# config/environments/production.rb
config.logger = Mihari::Logger.new(
  token: ENV["MIHARI_TOKEN"],
  endpoint: ENV["MIHARI_ENDPOINT"]
)
```

## Log Entry Format

Each log entry is sent as JSON with the following structure:

```json
{
  "dt": "2026-03-31T12:00:00.000Z",
  "level": "info",
  "message": "User signed in",
  "hostname": "web-01",
  "pid": 12345,
  "ruby_version": "3.2.0",
  "user_id": 42
}
```

Fields `dt`, `level`, `message`, `hostname`, `pid`, and `ruby_version` are included automatically. Any additional metadata passed to the log methods is merged into the entry.

## Configuration Options

| Option           | Default            | Description                              |
|------------------|--------------------|------------------------------------------|
| `token`          | _(required)_       | API bearer token                         |
| `endpoint`       | _(required)_       | Base URL of the Mihari API               |
| `batch_size`     | `10`               | Number of entries per batch              |
| `flush_interval` | `5`                | Seconds between automatic flushes        |
| `max_retries`    | `3`                | Retry attempts on failure                |
| `compression`    | `:gzip`            | Compression method (`:gzip`, `:deflate`, `:none`) |

## API Details

- **Endpoint**: POST `{base_url}/logs`
- **Auth**: `Authorization: Bearer {token}`
- **Content-Type**: `application/json`
- **Content-Encoding**: `gzip` or `deflate`
- **Success Response** (202): `{"status": "accepted", "count": N}`

## Thread Safety

All queue operations are protected by a Mutex. The background flush thread runs independently and is cleaned up on shutdown. Multiple threads can safely call log methods concurrently.

## Development

```bash
git clone https://github.com/mihari/mihari-logger.git
cd mihari-logger
bundle install
bundle exec rspec
```

## License

MIT License. See [LICENSE](LICENSE) for details.
