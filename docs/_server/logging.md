---
layout: default
title: Logging
nav_order: 18
---

# Logging

The MCP Ruby SDK supports structured logging through the `notify_log_message` method, following the [MCP Logging specification](https://modelcontextprotocol.io/specification/latest/server/utilities/logging).

The `notifications/message` notification is used for structured logging between client and server.

{: .warning }
> MCP Logging (`logging/setLevel` and `notifications/message`) is deprecated as of protocol version `2026-07-28` (SEP-2577),
> while remaining fully supported under `2025-11-25`. Use stderr or OpenTelemetry for new servers.

{: .note }
> On the [modern lifecycle](/server/discover/#the-stateless-modern-lifecycle), where `logging/setLevel` does not exist, the level
> comes per request from the `io.modelcontextprotocol/logLevel` `_meta` member: it authorizes
> `notifications/message` for that request only, delivered on the request's own response stream.
> A request without the member (or with an unrecognized level) receives no log messages.

## Log Levels

The SDK supports 8 log levels with increasing severity:

- `debug` - Detailed debugging information
- `info` - General informational messages
- `notice` - Normal but significant events
- `warning` - Warning conditions
- `error` - Error conditions
- `critical` - Critical conditions
- `alert` - Action must be taken immediately
- `emergency` - System is unusable

## How Logging Works

1. **Client Configuration**: The client sends a `logging/setLevel` request to configure the minimum log level for its session only
2. **Server Filtering**: The server only sends session-scoped log messages at the configured level or higher severity
3. **Notification Delivery**: Log messages are sent as `notifications/message` to the client

For example, if the client sets the level to `"error"` (severity 4), the server will send messages with levels: `error`, `critical`, `alert`, and `emergency`.

For more details, see the [MCP Logging specification](https://modelcontextprotocol.io/specification/latest/server/utilities/logging).

**Usage Example:**

The client first configures the level for its session with a `logging/setLevel` request:

```json
{ "jsonrpc": "2.0", "id": 1, "method": "logging/setLevel", "params": { "level": "info" } }
```

The server then emits messages at each severity from a tool handler; only those at or above the calling session's configured level are delivered:

```ruby
server = MCP::Server.new(name: "my_server")
transport = MCP::Server::Transports::StdioTransport.new(server)

server.define_tool(name: "log_messages") do |server_context:|
  server_context.notify_log_message(
    data: { message: "Application started successfully" },
    level: "info"
  )

  server_context.notify_log_message(
    data: { message: "Configuration file not found, using defaults" },
    level: "warning"
  )

  server_context.notify_log_message(
    data: {
      error: "Database connection failed",
      details: { host: "localhost", port: 5432 }
    },
    level: "error",
    logger: "DatabaseLogger" # Optional logger name
  )
  MCP::Tool::Response.new([{ type: "text", text: "ok" }])
end
transport.open
```

`Server#notify_log_message` broadcasts use only the server-wide level, not a session's level. Applications can set the server-wide level explicitly:

```ruby
server.logging_message_notification = MCP::LoggingMessageNotification.new(level: "info")
```

`logging/setLevel` handled without a session still sets the server-wide level. Client requests through stdio and Streamable HTTP do not set it.

**Key Features:**

- Server has capability `logging` to send log messages
- Messages are only sent if a transport is configured
- Session-scoped messages use the client's configured log level, or the server-wide default for legacy sessions without their own level
- Server-wide broadcasts use only the server-wide log level
- If no effective log level is configured, no messages will be sent

## Transport Support

- **stdio**: Notifications are sent as JSON-RPC 2.0 messages to stdout
- **Streamable HTTP**: Notifications are sent as JSON-RPC 2.0 messages over HTTP with streaming (chunked transfer or SSE)
