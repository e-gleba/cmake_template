#pragma once

#include <cstdint>
#include <string_view>
#include <vector>
#include <functional>
#include <memory>
#include <mutex>
#include <thread>
#include <atomic>

namespace piped_mcp {

/// @brief MCP (Model Context Protocol) message types
/// @see https://github.com/modelcontextprotocol/specification
enum class MessageType : std::uint8_t {
    Request = 0,
    Response = 1,
    Notification = 2,
    Error = 3,
};

/// @brief MCP server configuration
struct ServerConfig {
    std::string_view name;
    std::string_view version;
    std::vector<std::string_view> capabilities;
};

/// @brief MCP server interface
class IMcpServer {
public:
    virtual ~IMcpServer() = default;
    
    /// @brief Start the MCP server
    /// @param config Server configuration
    virtual bool start(const ServerConfig& config) = 0;
    
    /// @brief Stop the MCP server
    virtual void stop() = 0;
    
    /// @brief Execute a command
    /// @param command Command to execute
    /// @return Response or empty string on error
    virtual std::string execute(const std::string& command) = 0;
    
    /// @brief Check if server is running
    virtual bool is_running() const = 0;
};

/// @brief MCP server implementation
class McpServer : public IMcpServer {
public:
    McpServer();
    ~McpServer() override;
    
    bool start(const ServerConfig& config) override;
    void stop() override;
    std::string execute(const std::string& command) override;
    bool is_running() const override;
    
    /// @brief Register a command handler
    /// @param command Command name
    /// @param handler Handler function
    void register_handler(
        std::string_view command,
        std::function<std::string(const std::string&)> handler
    );
    
    /// @brief Send a notification
    /// @param method Notification method
    /// @param params Notification parameters
    void notify(std::string_view method, std::string_view params);

private:
    class Impl;
    std::unique_ptr<Impl> impl_;
};

} // namespace piped_mcp
