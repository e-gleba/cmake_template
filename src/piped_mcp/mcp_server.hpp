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
enum class message_type : std::uint8_t {
    request = 0,
    response = 1,
    notification = 2,
    error = 3,
};

/// @brief MCP server configuration
struct server_config {
    std::string_view name;
    std::string_view version;
    std::vector<std::string_view> capabilities;
};

/// @brief MCP server interface
class i_mcp_server {
public:
    virtual ~i_mcp_server() = default;

    /// @brief Start the MCP server
    /// @param config Server configuration
    virtual bool start(const server_config& config) noexcept = 0;

    /// @brief Stop the MCP server
    virtual void stop() noexcept = 0;

    /// @brief Execute a command
    /// @param command Command to execute
    /// @return Response or empty string on error
    [[nodiscard]] virtual std::string execute(const std::string& command) noexcept = 0;

    /// @brief Check if server is running
    [[nodiscard]] virtual bool is_running() const noexcept = 0;
};

/// @brief MCP server implementation
class mcp_server final : public i_mcp_server {
public:
    mcp_server() noexcept;
    ~mcp_server() override;

    bool start(const server_config& config) noexcept override;
    void stop() noexcept override;
    [[nodiscard]] std::string execute(const std::string& command) noexcept override;
    [[nodiscard]] bool is_running() const noexcept override;

    /// @brief Register a command handler
    /// @param command Command name
    /// @param handler Handler function
    void register_handler(
        std::string_view command,
        std::function<std::string(const std::string&)> handler
    ) noexcept;

    /// @brief Send a notification
    /// @param method Notification method
    /// @param params Notification parameters
    void notify(std::string_view method, std::string_view params) noexcept;

private:
    class impl;
    std::unique_ptr<impl> pimpl_;
};

} // namespace piped_mcp
