#pragma once

#include <atomic>
#include <cstdint>
#include <functional>
#include <memory>
#include <mutex>
#include <string>
#include <string_view>
#include <thread>
#include <vector>

namespace tb::piped_mcp {

enum class message_type : std::uint8_t
{
    request      = 0,
    response     = 1,
    notification = 2,
    error        = 3,
};

struct server_config
{
    std::string_view              name;
    std::string_view              version;
    std::vector<std::string_view> capabilities;
};

class i_mcp_server
{
public:
    virtual ~i_mcp_server() = default;

    virtual bool start(const server_config& config) noexcept = 0;
    virtual void stop() noexcept                             = 0;
    [[nodiscard]] virtual std::string execute(
        const std::string& command, const std::string& params) noexcept = 0;
    [[nodiscard]] virtual bool is_running() const noexcept              = 0;
};

class mcp_server final : public i_mcp_server
{
public:
    mcp_server() noexcept;
    ~mcp_server() override;

    bool start(const server_config& config) noexcept override;
    void stop() noexcept override;
    [[nodiscard]] std::string execute(
        const std::string& command,
        const std::string& params) noexcept override;
    [[nodiscard]] bool is_running() const noexcept override;

    void register_handler(
        std::string_view                               command,
        std::function<std::string(const std::string&)> handler) noexcept;

    void notify(std::string_view method, std::string_view params) noexcept;

private:
    class impl;
    std::unique_ptr<impl> pimpl_;
};

} // namespace tb::piped_mcp
