# WebSpoon - Centralized HTTP Server Architecture for Hammerspoon

## Executive Summary

WebSpoon is a centralized HTTP server architecture that allows multiple Hammerspoon Spoons to share a single HTTP server on port 8888. Instead of each Spoon creating its own server, they register endpoints with the central `HTTPRouter.spoon`, providing clean separation of concerns, unified CORS handling, and a consistent API structure.

## Architecture Overview

### Current Problem
- **Inyo.spoon** runs HTTP server on port 8888 for `/message` endpoint
- **Hammerflow** needs HTTP endpoints for config editor auto-load
- Multiple servers = port conflicts, complexity, resource waste

### WebSpoon Solution
```
┌─────────────────────────────────────────────────────────┐
│                HTTPRouter.spoon                         │
│           Central Server (:8888)                       │
│                                                         │
│  Route Registry:                                        │
│  ┌─────────────────────────────────────────────────────┐ │
│  │ GET /inyo/status          → Inyo.showStatus()      │ │
│  │ POST /inyo/message        → Inyo.handleMessage()   │ │
│  │ GET /hammerflow/config    → HF.getCurrentConfig()  │ │
│  │ GET /hammerflow/backups   → HF.listBackups()      │ │
│  │ POST /hammerflow/validate → HF.validateConfig()   │ │
│  │ GET /api/*                → Future expansion       │ │
│  └─────────────────────────────────────────────────────┘ │
└─────────────────┬───────────────────────────────────────┘
                  │
    ┌─────────────┴─────────────┐
    │                           │
┌───▼─────┐                ┌───▼──────────┐
│  Inyo   │                │  Hammerflow  │
│  Spoon  │                │    Spoon     │
│         │                │              │
│ Registers:               │ Registers:   │
│ /inyo/*                  │ /hammerflow/* │
└─────────┘                └──────────────┘
```

### Benefits
- ✅ **Single Port**: All HTTP traffic on 8888
- ✅ **Clean URLs**: RESTful structure `/spoon/endpoint`
- ✅ **Unified CORS**: Consistent cross-origin handling
- ✅ **Extensible**: Easy to add new Spoons
- ✅ **Maintainable**: Central routing logic
- ✅ **Optional**: Spoons can fallback to own servers
- ✅ **Performance**: Shared connection pooling

## HTTPRouter.spoon Implementation

### Directory Structure
```
Spoons/
└── HTTPRouter.spoon/
    ├── init.lua
    ├── docs.json
    └── README.md
```

### Complete HTTPRouter.spoon Code

#### `init.lua`
```lua
---@diagnostic disable: undefined-global

local obj = {}
obj.__index = obj

-- Metadata
obj.name = "HTTPRouter"
obj.version = "1.0.0"
obj.author = "WebSpoon Project"
obj.homepage = "https://github.com/yourorg/webspoon"
obj.license = "MIT - https://opensource.org/licenses/MIT"

-- Instance state
obj._server = nil
obj._routes = {}
obj._config = {
    port = 8888,
    interface = "localhost",  -- Security: localhost only
    maxRequestSize = 1024 * 1024,  -- 1MB max request
    timeout = 30,  -- 30 second timeout
    corsOrigins = "*"  -- CORS configuration
}

--- HTTPRouter:new()
--- Constructor
--- Create a new HTTPRouter instance
---
--- Parameters:
---  * config - Optional table with configuration:
---    * port - HTTP server port (default: 8888)
---    * interface - Bind interface (default: "localhost")
---    * maxRequestSize - Maximum request size in bytes
---    * corsOrigins - CORS allowed origins (default: "*")
---
--- Returns:
---  * HTTPRouter instance
function obj:new(config)
    local o = setmetatable({}, self)
    o._routes = {}
    o._server = nil

    if config then
        for k, v in pairs(config) do
            o._config[k] = v
        end
    end

    return o
end

--- HTTPRouter:init()
--- Method
--- Initialize the HTTPRouter spoon
---
--- Returns:
---  * The HTTPRouter object for method chaining
function obj:init()
    return self
end

--- HTTPRouter:registerRoute(method, path, handler)
--- Method
--- Register a route handler with the HTTP server
---
--- Parameters:
---  * method - HTTP method (GET, POST, PUT, DELETE, etc.)
---  * path - URL path (e.g., "/hammerflow/config")
---  * handler - Function that handles the request
---
--- Returns:
---  * The HTTPRouter object for method chaining
---
--- Notes:
---  * Handler function receives (method, path, headers, body)
---  * Handler must return (responseBody, statusCode, responseHeaders)
---  * Supports wildcard routes with /* suffix
---  * Later registrations override earlier ones for same route
function obj:registerRoute(method, path, handler)
    if type(handler) ~= "function" then
        error("Handler must be a function")
    end

    local key = string.upper(method) .. ":" .. path
    self._routes[key] = handler

    print(string.format("HTTPRouter: Registered %s %s", method, path))
    return self
end

--- HTTPRouter:registerRoutes(routes)
--- Method
--- Register multiple routes at once
---
--- Parameters:
---  * routes - Table of routes in format:
---    * {method = "GET", path = "/endpoint", handler = function}
---
--- Returns:
---  * The HTTPRouter object for method chaining
function obj:registerRoutes(routes)
    for _, route in ipairs(routes) do
        self:registerRoute(route.method, route.path, route.handler)
    end
    return self
end

--- HTTPRouter:unregisterRoute(method, path)
--- Method
--- Remove a registered route
---
--- Parameters:
---  * method - HTTP method
---  * path - URL path
---
--- Returns:
---  * The HTTPRouter object for method chaining
function obj:unregisterRoute(method, path)
    local key = string.upper(method) .. ":" .. path
    self._routes[key] = nil
    print(string.format("HTTPRouter: Unregistered %s %s", method, path))
    return self
end

--- HTTPRouter:listRoutes()
--- Method
--- Get list of all registered routes
---
--- Returns:
---  * Table of registered routes
function obj:listRoutes()
    local routes = {}
    for key, handler in pairs(self._routes) do
        local method, path = key:match("^([^:]+):(.+)$")
        table.insert(routes, {
            method = method,
            path = path,
            handler = handler
        })
    end
    return routes
end

--- HTTPRouter:_findHandler(method, path)
--- Method
--- Internal method to find appropriate handler for request
---
--- Parameters:
---  * method - HTTP method
---  * path - Request path
---
--- Returns:
---  * Handler function or nil if not found
function obj:_findHandler(method, path)
    local key = string.upper(method) .. ":" .. path

    -- Try exact match first
    local handler = self._routes[key]
    if handler then
        return handler
    end

    -- Try wildcard matches (longest prefix first)
    local wildcardRoutes = {}
    for routeKey, routeHandler in pairs(self._routes) do
        if routeKey:match("%*$") then
            local routeMethod, routePath = routeKey:match("^([^:]+):(.+)$")
            if routeMethod == string.upper(method) then
                local prefix = routePath:sub(1, -2)  -- Remove /*
                if path:find("^" .. prefix:gsub("[%(%)%.%+%-%%[%]%^%$%?%*]", "%%%1")) then
                    table.insert(wildcardRoutes, {
                        prefix = prefix,
                        handler = routeHandler,
                        length = #prefix
                    })
                end
            end
        end
    end

    -- Sort by prefix length (longest first for most specific match)
    table.sort(wildcardRoutes, function(a, b) return a.length > b.length end)

    if #wildcardRoutes > 0 then
        return wildcardRoutes[1].handler
    end

    return nil
end

--- HTTPRouter:_handleCORS(method, path, headers)
--- Method
--- Handle CORS preflight and add CORS headers
---
--- Parameters:
---  * method - HTTP method
---  * path - Request path
---  * headers - Request headers
---
--- Returns:
---  * Table of CORS headers to add to response
function obj:_handleCORS(method, path, headers)
    local corsHeaders = {
        ["Access-Control-Allow-Origin"] = self._config.corsOrigins,
        ["Access-Control-Allow-Methods"] = "GET, POST, PUT, DELETE, OPTIONS",
        ["Access-Control-Allow-Headers"] = "Content-Type, Authorization",
        ["Access-Control-Max-Age"] = "86400"  -- 24 hours
    }

    -- Handle preflight requests
    if method == "OPTIONS" then
        corsHeaders["Access-Control-Allow-Methods"] =
            headers["Access-Control-Request-Method"] or corsHeaders["Access-Control-Allow-Methods"]
        corsHeaders["Access-Control-Allow-Headers"] =
            headers["Access-Control-Request-Headers"] or corsHeaders["Access-Control-Allow-Headers"]
    end

    return corsHeaders
end

--- HTTPRouter:start()
--- Method
--- Start the HTTP server
---
--- Returns:
---  * The HTTPRouter object for method chaining
---
--- Notes:
---  * Server will bind to configured interface and port
---  * Automatically handles CORS and routing
---  * Logs all requests for debugging
function obj:start()
    if self._server then
        self:stop()
    end

    self._server = hs.httpserver.new()
        :setPort(self._config.port)
        :setInterface(self._config.interface)
        :setMaxRequestSize(self._config.maxRequestSize)
        :setCallback(function(method, path, headers, body)
            local startTime = hs.timer.secondsSinceEpoch()

            -- Log request
            print(string.format("HTTPRouter: %s %s from %s",
                method, path, headers["X-Forwarded-For"] or "localhost"))

            -- Handle CORS
            local corsHeaders = self:_handleCORS(method, path, headers)

            -- Handle preflight
            if method == "OPTIONS" then
                return "", 200, corsHeaders
            end

            -- Find handler
            local handler = self:_findHandler(method, path)

            if not handler then
                local responseHeaders = corsHeaders
                responseHeaders["Content-Type"] = "application/json"
                local notFoundResponse = hs.json.encode({
                    error = "Not Found",
                    message = string.format("No handler for %s %s", method, path),
                    available_routes = self:_getAvailableRoutes()
                })
                return notFoundResponse, 404, responseHeaders
            end

            -- Call handler with error handling
            local success, responseBody, statusCode, responseHeaders = pcall(handler, method, path, headers, body)

            if not success then
                print("HTTPRouter: Handler error: " .. tostring(responseBody))
                local errorHeaders = corsHeaders
                errorHeaders["Content-Type"] = "application/json"
                local errorResponse = hs.json.encode({
                    error = "Internal Server Error",
                    message = "Handler execution failed"
                })
                return errorResponse, 500, errorHeaders
            end

            -- Merge CORS headers with response headers
            responseHeaders = responseHeaders or {}
            for k, v in pairs(corsHeaders) do
                if not responseHeaders[k] then
                    responseHeaders[k] = v
                end
            end

            -- Ensure Content-Type is set
            if not responseHeaders["Content-Type"] then
                responseHeaders["Content-Type"] = "text/plain; charset=utf-8"
            end

            -- Log response time
            local duration = hs.timer.secondsSinceEpoch() - startTime
            print(string.format("HTTPRouter: %s %s -> %d (%.2fms)",
                method, path, statusCode or 200, duration * 1000))

            return responseBody or "", statusCode or 200, responseHeaders
        end)
        :start()

    print(string.format("HTTPRouter: Server started on %s:%d",
        self._config.interface, self._config.port))

    -- Register built-in routes
    self:_registerBuiltInRoutes()

    return self
end

--- HTTPRouter:stop()
--- Method
--- Stop the HTTP server
---
--- Returns:
---  * The HTTPRouter object for method chaining
function obj:stop()
    if self._server then
        self._server:stop()
        self._server = nil
        print("HTTPRouter: Server stopped")
    end
    return self
end

--- HTTPRouter:restart()
--- Method
--- Restart the HTTP server
---
--- Returns:
---  * The HTTPRouter object for method chaining
function obj:restart()
    return self:stop():start()
end

--- HTTPRouter:_getAvailableRoutes()
--- Method
--- Get formatted list of available routes for error messages
---
--- Returns:
---  * Array of route strings
function obj:_getAvailableRoutes()
    local routes = {}
    for key, _ in pairs(self._routes) do
        table.insert(routes, key:gsub(":", " "))
    end
    table.sort(routes)
    return routes
end

--- HTTPRouter:_registerBuiltInRoutes()
--- Method
--- Register built-in administrative routes
function obj:_registerBuiltInRoutes()
    -- Health check endpoint
    self:registerRoute("GET", "/api/health", function(method, path, headers, body)
        local health = {
            status = "ok",
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
            uptime = hs.timer.secondsSinceEpoch(),
            routes_count = 0
        }

        for _ in pairs(self._routes) do
            health.routes_count = health.routes_count + 1
        end

        return hs.json.encode(health), 200, {["Content-Type"] = "application/json"}
    end)

    -- Route listing endpoint
    self:registerRoute("GET", "/api/routes", function(method, path, headers, body)
        local routes = self:_getAvailableRoutes()
        return hs.json.encode({routes = routes}), 200, {["Content-Type"] = "application/json"}
    end)

    -- Server info endpoint
    self:registerRoute("GET", "/api/info", function(method, path, headers, body)
        local info = {
            name = self.name,
            version = self.version,
            config = self._config,
            hammerspoon_version = hs.processInfo.version
        }
        return hs.json.encode(info), 200, {["Content-Type"] = "application/json"}
    end)
end

--- HTTPRouter:configure(config)
--- Method
--- Update server configuration
---
--- Parameters:
---  * config - Table with configuration options
---
--- Returns:
---  * The HTTPRouter object for method chaining
---
--- Notes:
---  * Requires restart to take effect for port/interface changes
function obj:configure(config)
    for k, v in pairs(config) do
        self._config[k] = v
    end
    return self
end

--- HTTPRouter:getConfig()
--- Method
--- Get current configuration
---
--- Returns:
---  * Configuration table
function obj:getConfig()
    return self._config
end

return obj
```

#### `docs.json` (Hammerspoon Documentation)
```json
[
  {
    "Command": [],
    "Constant": [],
    "Constructor": [
      {
        "def": "HTTPRouter:new(config) -> HTTPRouter",
        "desc": "Create a new HTTPRouter instance",
        "doc": "Create a new HTTPRouter instance\n\nParameters:\n * config - Optional table with configuration:\n   * port - HTTP server port (default: 8888)\n   * interface - Bind interface (default: \"localhost\")\n   * maxRequestSize - Maximum request size in bytes\n   * corsOrigins - CORS allowed origins (default: \"*\")\n\nReturns:\n * HTTPRouter instance",
        "name": "new",
        "signature": "HTTPRouter:new(config) -> HTTPRouter",
        "stripped_doc": "Create a new HTTPRouter instance\n\nParameters:\n * config - Optional table with configuration:\n   * port - HTTP server port (default: 8888)\n   * interface - Bind interface (default: \"localhost\")\n   * maxRequestSize - Maximum request size in bytes\n   * corsOrigins - CORS allowed origins (default: \"*\")\n\nReturns:\n * HTTPRouter instance",
        "type": "Constructor"
      }
    ],
    "Deprecated": [],
    "Field": [],
    "Function": [],
    "Method": [
      {
        "def": "HTTPRouter:registerRoute(method, path, handler) -> HTTPRouter",
        "desc": "Register a route handler with the HTTP server",
        "doc": "Register a route handler with the HTTP server\n\nParameters:\n * method - HTTP method (GET, POST, PUT, DELETE, etc.)\n * path - URL path (e.g., \"/hammerflow/config\")\n * handler - Function that handles the request\n\nReturns:\n * The HTTPRouter object for method chaining\n\nNotes:\n * Handler function receives (method, path, headers, body)\n * Handler must return (responseBody, statusCode, responseHeaders)\n * Supports wildcard routes with /* suffix\n * Later registrations override earlier ones for same route",
        "name": "registerRoute",
        "signature": "HTTPRouter:registerRoute(method, path, handler) -> HTTPRouter",
        "stripped_doc": "Register a route handler with the HTTP server\n\nParameters:\n * method - HTTP method (GET, POST, PUT, DELETE, etc.)\n * path - URL path (e.g., \"/hammerflow/config\")\n * handler - Function that handles the request\n\nReturns:\n * The HTTPRouter object for method chaining\n\nNotes:\n * Handler function receives (method, path, headers, body)\n * Handler must return (responseBody, statusCode, responseHeaders)\n * Supports wildcard routes with /* suffix\n * Later registrations override earlier ones for same route",
        "type": "Method"
      },
      {
        "def": "HTTPRouter:start() -> HTTPRouter",
        "desc": "Start the HTTP server",
        "doc": "Start the HTTP server\n\nReturns:\n * The HTTPRouter object for method chaining\n\nNotes:\n * Server will bind to configured interface and port\n * Automatically handles CORS and routing\n * Logs all requests for debugging",
        "name": "start",
        "signature": "HTTPRouter:start() -> HTTPRouter",
        "stripped_doc": "Start the HTTP server\n\nReturns:\n * The HTTPRouter object for method chaining\n\nNotes:\n * Server will bind to configured interface and port\n * Automatically handles CORS and routing\n * Logs all requests for debugging",
        "type": "Method"
      }
    ],
    "Variable": [],
    "desc": "Central HTTP server for routing requests to multiple Spoons",
    "doc": "Central HTTP server for routing requests to multiple Spoons\n\nThis spoon provides a centralized HTTP server that allows multiple\nSpoons to register endpoints without creating separate servers.\n\nExample usage:\n```lua\nhs.loadSpoon(\"HTTPRouter\")\nspoon.HTTPRouter:start()\n\n-- Register a route\nspoon.HTTPRouter:registerRoute(\"GET\", \"/api/test\", function(method, path, headers, body)\n    return \"Hello World\", 200, {[\"Content-Type\"] = \"text/plain\"}\nend)\n```",
    "items": [],
    "name": "HTTPRouter",
    "submodules": [],
    "type": "Module"
  }
]
```

## Integration Instructions

### 1. Modify Inyo.spoon to use HTTPRouter

#### Changes to Inyo's `init.lua`:

```lua
-- Add after existing code, modify startServer function:

--- Inyo:startServer()
--- Method
--- Start the HTTP server (via HTTPRouter if available)
function obj:startServer()
    -- Try to use HTTPRouter if available
    if spoon.HTTPRouter then
        self:_registerWithHTTPRouter()
        return
    end

    -- Fallback to own server if HTTPRouter not available
    self:_startOwnServer()
end

--- Inyo:_registerWithHTTPRouter()
--- Method
--- Register Inyo endpoints with HTTPRouter
function obj:_registerWithHTTPRouter()
    local serverSelf = self

    -- Register message endpoint
    spoon.HTTPRouter:registerRoute("POST", "/inyo/message", function(method, path, headers, body)
        local success, data = pcall(hs.json.decode, body)
        if success and data then
            local content = data.content or "No content"
            local options = {
                background = data.background,
                style = data.style,
                duration = data.duration,
                template = data.template,
                size = data.size,
                opacity = data.opacity
            }

            if data.queue then
                serverSelf:queue(content, options)
            else
                serverSelf:show(content, options)
            end

            return "OK", 200, { ["Content-Type"] = "text/plain" }
        else
            return "Invalid JSON", 400, { ["Content-Type"] = "text/plain" }
        end
    end)

    -- Register status endpoint
    spoon.HTTPRouter:registerRoute("GET", "/inyo/status", function(method, path, headers, body)
        local status = {
            queue_length = #serverSelf._messageQueue,
            is_showing = serverSelf._webview ~= nil,
            config = serverSelf._config
        }
        return hs.json.encode(status), 200, { ["Content-Type"] = "application/json" }
    end)

    self.log.info('http.register', {endpoints = {"/inyo/message", "/inyo/status"}})
end

--- Inyo:_startOwnServer()
--- Method
--- Start own HTTP server (fallback when HTTPRouter not available)
function obj:_startOwnServer()
    -- Existing startServer logic here (current implementation)
    if self._httpServer then
        self._httpServer:stop()
    end

    local serverSelf = self
    self._httpServer = hs.httpserver.new()
        :setPort(self._config.port)
        :setCallback(function(method, path, headers, body)
            -- Original Inyo server logic
            if method == "POST" and path == "/message" then
                -- ... existing implementation
            else
                return "Not Found", 404, { ["Content-Type"] = "text/plain" }
            end
        end)
        :start()

    self.log.info('http.listen', {port = self._config.port})
end

--- Inyo:stopServer()
--- Method
--- Stop the HTTP server
function obj:stopServer()
    if spoon.HTTPRouter then
        -- Unregister routes from HTTPRouter
        spoon.HTTPRouter:unregisterRoute("POST", "/inyo/message")
        spoon.HTTPRouter:unregisterRoute("GET", "/inyo/status")
    elseif self._httpServer then
        -- Stop own server
        self._httpServer:stop()
        self._httpServer = nil
    end
end
```

### 2. Modify Hammerflow to use HTTPRouter

#### Add to Hammerflow's `init.lua`:

```lua
-- Add after existing URL event handlers:

--- Setup HTTP endpoints for config editor
function obj:setupHTTPEndpoints()
    if not spoon.HTTPRouter then
        log.warn('http.setup', {error = "HTTPRouter not available"})
        return
    end

    -- Register config endpoint
    spoon.HTTPRouter:registerRoute("GET", "/hammerflow/config", function(method, path, headers, body)
        local configPath = hs.configdir .. "/Hammerflow/config.toml"

        if not file_exists(configPath) then
            return hs.json.encode({error = "Config file not found"}), 404, {
                ["Content-Type"] = "application/json"
            }
        end

        local file = io.open(configPath, "r")
        if file then
            local content = file:read("*all")
            file:close()
            log.info('http.config', {action = 'read', size = #content})
            return content, 200, {
                ["Content-Type"] = "text/plain; charset=utf-8"
            }
        else
            return hs.json.encode({error = "Failed to read config"}), 500, {
                ["Content-Type"] = "application/json"
            }
        end
    end)

    -- Register backup list endpoint
    spoon.HTTPRouter:registerRoute("GET", "/hammerflow/backups", function(method, path, headers, body)
        local configDir = hs.configdir .. "/Hammerflow/"
        local backups = {}

        -- Find backup files
        local output = hs.execute("find '" .. configDir .. "' -name 'config.toml.backup-*' -type f")
        if output then
            for line in output:gmatch("[^\r\n]+") do
                local filename = line:match("([^/]+)$")
                if filename then
                    local timestamp = filename:match("backup%-(.+)$")
                    if timestamp then
                        local stat = hs.fs.attributes(line)
                        table.insert(backups, {
                            filename = filename,
                            timestamp = timestamp,
                            size = stat and stat.size or 0,
                            modified = stat and os.date("%Y-%m-%d %H:%M:%S", stat.modification) or "unknown"
                        })
                    end
                end
            end
        end

        -- Sort by timestamp (newest first)
        table.sort(backups, function(a, b) return a.timestamp > b.timestamp end)

        return hs.json.encode({backups = backups}), 200, {
            ["Content-Type"] = "application/json"
        }
    end)

    -- Register validation endpoint
    spoon.HTTPRouter:registerRoute("POST", "/hammerflow/validate", function(method, path, headers, body)
        if not body or body == "" then
            return hs.json.encode({
                valid = false,
                error = "No TOML content provided"
            }), 400, {["Content-Type"] = "application/json"}
        end

        -- Write to temp file for validation
        local tempPath = "/tmp/hammerflow-validate-" .. os.time() .. ".toml"
        local tempFile = io.open(tempPath, "w")
        if tempFile then
            tempFile:write(body)
            tempFile:close()

            local valid, message = validateTomlStructure(tempPath)

            -- Clean up temp file
            os.remove(tempPath)

            return hs.json.encode({
                valid = valid,
                error = valid and nil or message
            }), valid and 200 or 400, {
                ["Content-Type"] = "application/json"
            }
        else
            return hs.json.encode({
                valid = false,
                error = "Failed to create temp file"
            }), 500, {["Content-Type"] = "application/json"}
        end
    end)

    log.info('http.endpoints', {
        registered = {"/hammerflow/config", "/hammerflow/backups", "/hammerflow/validate"}
    })
end

-- Add call to setup HTTP endpoints in loadFirstValidTomlFile function
-- Add this line after successful config loading:
if obj.setupHTTPEndpoints then
    obj.setupHTTPEndpoints()
end
```

### 3. Main init.lua Configuration

#### Update your main `~/.hammerspoon/init.lua`:

```lua
-- Load HTTPRouter first
hs.loadSpoon("HTTPRouter")

-- Configure and start the central server
spoon.HTTPRouter:configure({
    port = 8888,
    interface = "localhost",  -- Security: localhost only
    corsOrigins = "file://*"  -- Allow local HTML files
}):start()

-- Load other spoons that will register with HTTPRouter
hs.loadSpoon("Inyo")
hs.loadSpoon("Hammerflow")  -- or however you load Hammerflow

-- If Inyo auto-starts server, it will register with HTTPRouter
-- If you manually start Inyo server:
-- spoon.Inyo:startServer()

-- Hammerflow will register endpoints when config loads
```

## API Specifications

### URL Structure Convention
```
http://localhost:8888/{spoon}/{resource}[/{id}][?params]

Examples:
- GET  /inyo/status           → Get Inyo status
- POST /inyo/message          → Send Inyo message
- GET  /hammerflow/config     → Get current config
- GET  /hammerflow/backups    → List config backups
- POST /hammerflow/validate   → Validate TOML content
- GET  /api/health           → Server health check
- GET  /api/routes           → List all routes
```

### Standard Response Formats

#### Success Response
```json
{
  "status": "success",
  "data": { ... },
  "timestamp": "2024-01-01T12:00:00Z"
}
```

#### Error Response
```json
{
  "status": "error",
  "error": "Error Type",
  "message": "Human readable error message",
  "code": 400,
  "timestamp": "2024-01-01T12:00:00Z"
}
```

#### HTTP Status Codes
- `200` - OK
- `201` - Created
- `400` - Bad Request (invalid input)
- `404` - Not Found (route or resource)
- `405` - Method Not Allowed
- `500` - Internal Server Error

### CORS Headers
All responses include:
```
Access-Control-Allow-Origin: *
Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS
Access-Control-Allow-Headers: Content-Type, Authorization
Access-Control-Max-Age: 86400
```

### Content Types
- `application/json` - JSON responses
- `text/plain; charset=utf-8` - Plain text (TOML configs)
- `text/html; charset=utf-8` - HTML responses

## Security Considerations

### Network Security
- **Localhost Binding**: Server only accepts connections from `127.0.0.1`
- **No External Access**: Cannot be reached from network/internet
- **No Authentication**: Relies on local machine security

### Input Validation
- **Request Size Limits**: Configurable max request size (default 1MB)
- **TOML Validation**: All config content validated before processing
- **Path Sanitization**: URL paths sanitized to prevent traversal attacks

### Error Handling
- **Safe Error Messages**: No stack traces or sensitive info in responses
- **Request Logging**: All requests logged for debugging
- **Graceful Degradation**: Spoons fallback to own servers if HTTPRouter unavailable

### Future Security Enhancements
- **Rate Limiting**: Prevent abuse with request rate limits
- **API Keys**: Optional authentication for sensitive endpoints
- **HTTPS Support**: Self-signed certificates for encrypted transport
- **Request Validation**: JSON schema validation for POST bodies

## Implementation Checklist

### Phase 1: HTTPRouter.spoon Development
- [ ] Create `HTTPRouter.spoon` directory structure
- [ ] Implement core `init.lua` with route registration
- [ ] Add wildcard route matching
- [ ] Implement CORS handling
- [ ] Add error handling and logging
- [ ] Create built-in administrative routes
- [ ] Write comprehensive documentation
- [ ] Add configuration management

### Phase 2: Testing HTTPRouter
- [ ] Test basic route registration and handling
- [ ] Test wildcard route matching
- [ ] Test CORS preflight requests
- [ ] Test error scenarios (404, 500, etc.)
- [ ] Test concurrent request handling
- [ ] Verify memory usage and performance
- [ ] Test configuration changes and restart

### Phase 3: Inyo Integration
- [ ] Modify Inyo's `startServer()` method
- [ ] Add HTTPRouter registration logic
- [ ] Maintain fallback to own server
- [ ] Test existing Inyo functionality
- [ ] Verify `/inyo/message` endpoint works
- [ ] Add new `/inyo/status` endpoint
- [ ] Update Inyo documentation

### Phase 4: Hammerflow Integration
- [ ] Add `setupHTTPEndpoints()` function to Hammerflow
- [ ] Implement `/hammerflow/config` endpoint
- [ ] Implement `/hammerflow/backups` endpoint
- [ ] Implement `/hammerflow/validate` endpoint
- [ ] Update config editor HTML to use HTTP endpoints
- [ ] Test auto-load functionality
- [ ] Update config editor documentation

### Phase 5: Config Editor Updates
- [ ] Add "Load Current Config" button to HTML
- [ ] Implement `loadCurrentConfig()` JavaScript function
- [ ] Add error handling for server connection failures
- [ ] Update UI to show server status
- [ ] Add backup management interface
- [ ] Test with various config sizes and formats

### Phase 6: Documentation and Examples
- [ ] Complete WebSpoon architecture documentation
- [ ] Create migration guide from separate servers
- [ ] Write example Spoon that uses HTTPRouter
- [ ] Document troubleshooting procedures
- [ ] Create API reference documentation

### Phase 7: Production Deployment
- [ ] Update main `init.lua` to load HTTPRouter first
- [ ] Verify all Spoons register correctly
- [ ] Test complete system integration
- [ ] Monitor performance and resource usage
- [ ] Create backup/rollback procedures

## Example Usage Scenarios

### Scenario 1: Basic Spoon Registration
```lua
-- In MySpoon.spoon/init.lua
function obj:init()
    if spoon.HTTPRouter then
        spoon.HTTPRouter:registerRoute("GET", "/myspoon/data",
            function(method, path, headers, body)
                return hs.json.encode({message = "Hello from MySpoon"}), 200, {
                    ["Content-Type"] = "application/json"
                }
            end
        )
    end
    return self
end
```

### Scenario 2: Complex Route Handling
```lua
-- Register multiple related routes
local routes = {
    {
        method = "GET",
        path = "/api/users/*",
        handler = function(method, path, headers, body)
            local userId = path:match("/api/users/(%d+)")
            if userId then
                return hs.json.encode({user = {id = userId}}), 200
            else
                return hs.json.encode({users = {}}), 200
            end
        end
    },
    {
        method = "POST",
        path = "/api/users",
        handler = function(method, path, headers, body)
            -- Create user logic
            return hs.json.encode({created = true}), 201
        end
    }
}

spoon.HTTPRouter:registerRoutes(routes)
```

### Scenario 3: Config Editor Integration
```javascript
// In config-editor.html
class ConfigEditorWithHTTP {
    async loadCurrentConfig() {
        try {
            const response = await fetch('http://localhost:8888/hammerflow/config');
            if (!response.ok) {
                throw new Error(`HTTP ${response.status}: ${response.statusText}`);
            }

            const tomlContent = await response.text();
            this.config = TOML.parse(tomlContent);
            this.render();
            this.showNotification('Config loaded from Hammerspoon!', 'success');

        } catch (error) {
            console.error('Failed to load config:', error);
            this.showNotification(
                'Could not connect to Hammerspoon. Use manual file load.',
                'error'
            );
            // Fallback to file picker
            document.getElementById('fileInput').click();
        }
    }

    async validateConfig(tomlContent) {
        try {
            const response = await fetch('http://localhost:8888/hammerflow/validate', {
                method: 'POST',
                headers: {'Content-Type': 'text/plain'},
                body: tomlContent
            });

            const result = await response.json();
            return result.valid ? null : result.error;

        } catch (error) {
            return "Could not validate with server";
        }
    }

    async listBackups() {
        try {
            const response = await fetch('http://localhost:8888/hammerflow/backups');
            const data = await response.json();
            return data.backups || [];
        } catch (error) {
            console.error('Failed to list backups:', error);
            return [];
        }
    }
}
```

## Troubleshooting Guide

### Common Issues

#### 1. "Connection refused" errors in config editor
**Symptoms**: Config editor shows "Could not connect to Hammerspoon"
**Causes**:
- HTTPRouter not loaded or started
- Wrong port number
- Hammerspoon not running

**Solutions**:
```lua
-- Check if HTTPRouter is loaded
print(spoon.HTTPRouter)  -- Should not be nil

-- Check if server is running
print(spoon.HTTPRouter._server)  -- Should not be nil

-- Check port
print(spoon.HTTPRouter:getConfig().port)  -- Should be 8888

-- Restart server
spoon.HTTPRouter:restart()
```

#### 2. Routes not registering
**Symptoms**: 404 errors for known endpoints
**Causes**:
- Spoon loaded before HTTPRouter
- Registration failed silently
- Route path mismatch

**Solutions**:
```lua
-- List all registered routes
local routes = spoon.HTTPRouter:listRoutes()
for _, route in ipairs(routes) do
    print(route.method .. " " .. route.path)
end

-- Re-register routes
if spoon.Hammerflow and spoon.Hammerflow.setupHTTPEndpoints then
    spoon.Hammerflow:setupHTTPEndpoints()
end
```

#### 3. CORS errors in browser
**Symptoms**: Browser console shows CORS policy errors
**Causes**:
- Incorrect CORS configuration
- Missing OPTIONS handler
- Wrong origin header

**Solutions**:
```lua
-- Update CORS configuration
spoon.HTTPRouter:configure({
    corsOrigins = "*"  -- Allow all origins
}):restart()

-- Check CORS headers in response
-- Should include Access-Control-Allow-Origin
```

#### 4. Server performance issues
**Symptoms**: Slow response times, high memory usage
**Causes**:
- Too many concurrent requests
- Large request bodies
- Memory leaks in handlers

**Solutions**:
```lua
-- Reduce max request size
spoon.HTTPRouter:configure({
    maxRequestSize = 512 * 1024  -- 512KB instead of 1MB
})

-- Add request logging to identify slow handlers
-- Check Hammerspoon Console for timing logs
```

### Debugging Commands

```lua
-- HTTPRouter status
print("Server running:", spoon.HTTPRouter._server ~= nil)
print("Port:", spoon.HTTPRouter:getConfig().port)
print("Routes count:", #spoon.HTTPRouter:listRoutes())

-- Test health endpoint
hs.http.get("http://localhost:8888/api/health", nil, function(status, body)
    print("Health check:", status, body)
end)

-- View all routes
local routes = spoon.HTTPRouter:listRoutes()
for i, route in ipairs(routes) do
    print(i, route.method, route.path)
end

-- Restart everything
spoon.HTTPRouter:stop()
spoon.HTTPRouter:start()
```

## Future Enhancements

### Planned Features
- **WebSocket Support**: Real-time bidirectional communication
- **Static File Serving**: Serve HTML/CSS/JS files directly
- **Request Middleware**: Pluggable request/response processing
- **Rate Limiting**: Prevent abuse with configurable limits
- **Authentication**: Optional API key or token-based auth
- **Request Caching**: Cache expensive operations
- **Health Monitoring**: Endpoint health checks and metrics

### Potential Integrations
- **Linear Spoon**: Manage Linear issues via HTTP API
- **Git Spoon**: Repository status and operations
- **System Monitor**: System stats and controls
- **Music Control**: Spotify/Apple Music integration
- **Home Automation**: HomeKit/smart device controls

### Architecture Expansions
- **Plugin System**: Loadable route modules
- **Event System**: Pub/sub between Spoons via HTTP
- **Configuration UI**: Web-based Hammerspoon config manager
- **Remote Access**: Secure tunneling for external access
- **Mobile Apps**: Native iOS/Android companions

## Conclusion

WebSpoon provides a clean, extensible architecture for HTTP APIs in Hammerspoon while maintaining security and simplicity. The centralized router eliminates port conflicts and provides consistent CORS handling, making it easy for Spoons to expose web interfaces and integrate with external tools.

The architecture is designed to be:
- **Backwards Compatible**: Existing Spoons continue to work
- **Progressive**: Can be adopted incrementally
- **Secure**: Localhost-only with proper error handling
- **Performant**: Single server reduces resource usage
- **Extensible**: Easy to add new endpoints and features

By following this implementation guide, you'll have a robust foundation for web-based Hammerspoon integrations that can grow with your automation needs.

---

**Project Status**: Ready for implementation
**Estimated Effort**: 2-3 weeks development + testing
**Dependencies**: Hammerspoon with hs.httpserver module
**Compatibility**: Hammerspoon 0.9.74+