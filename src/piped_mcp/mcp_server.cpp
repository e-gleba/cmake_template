#include "mcp_server.hpp"

#include <array>
#include <cstdio>
#include <iostream>
#include <string>
#include <unordered_map>
#include <utility>

#if defined(_WIN32)
#include <io.h>
#else
#include <cerrno>
#include <poll.h>
#include <unistd.h>
#endif

namespace tb::piped_mcp {

namespace {

[[nodiscard]] std::string escape_json(std::string_view value) {
    std::string escaped;
    escaped.reserve(value.size());
    for (const char character : value) {
        switch (character) {
        case '\\': escaped += "\\\\"; break;
        case '"': escaped += "\\\""; break;
        case '\n': escaped += "\\n"; break;
        case '\r': escaped += "\\r"; break;
        case '\t': escaped += "\\t"; break;
        default: escaped += character; break;
        }
    }
    return escaped;
}

[[nodiscard]] std::string extract_string(std::string_view message, std::string_view key) {
    const std::string pattern = "\"" + std::string{key} + "\"";
    const std::size_t key_position = message.find(pattern);
    if (key_position == std::string_view::npos) {
        return {};
    }

    const std::size_t colon_position = message.find(':', key_position + pattern.size());
    const std::size_t quote_position = message.find('"', colon_position + 1);
    if (colon_position == std::string_view::npos || quote_position == std::string_view::npos) {
        return {};
    }

    std::string result;
    for (std::size_t index = quote_position + 1; index < message.size(); ++index) {
        const char character = message[index];
        if (character == '"') {
            return result;
        }
        if (character == '\\' && index + 1 < message.size()) {
            ++index;
            result += message[index];
        } else {
            result += character;
        }
    }
    return {};
}

[[nodiscard]] std::string extract_id(std::string_view message) {
    constexpr std::string_view key = "\"id\"";
    const std::size_t key_position = message.find(key);
    if (key_position == std::string_view::npos) {
        return {};
    }

    const std::size_t colon_position = message.find(':', key_position + key.size());
    if (colon_position == std::string_view::npos) {
        return {};
    }

    const std::size_t value_start = message.find_first_not_of(" \t", colon_position + 1);
    if (value_start == std::string_view::npos) {
        return {};
    }

    if (message[value_start] == '"') {
        const std::size_t value_end = message.find('"', value_start + 1);
        if (value_end == std::string_view::npos) {
            return {};
        }
        return std::string{message.substr(value_start, value_end - value_start + 1)};
    }

    const std::size_t value_end = message.find_first_of(",}", value_start);
    return std::string{message.substr(value_start, value_end - value_start)};
}

} // namespace

class mcp_server::impl final {
public:
    bool start(const server_config& config) noexcept {
        std::lock_guard lock{mutex_};
        if (running_) {
            return false;
        }

        config_name_ = config.name;
        config_version_ = config.version;
        capabilities_.clear();
        capabilities_.reserve(config.capabilities.size());
        for (const std::string_view capability : config.capabilities) {
            capabilities_.emplace_back(capability);
        }

        running_ = true;
        try {
            io_thread_ = std::thread{[this] { io_loop(); }};
        } catch (...) {
            running_ = false;
            return false;
        }
        return true;
    }

    void stop() noexcept {
        running_ = false;
        if (io_thread_.joinable()) {
            io_thread_.join();
        }
    }

    [[nodiscard]] std::string execute(const std::string& command) noexcept {
        std::function<std::string(const std::string&)> handler;
        {
            std::lock_guard lock{mutex_};
            const auto iterator = handlers_.find(command);
            if (iterator == handlers_.end()) {
                return {};
            }
            handler = iterator->second;
        }

        try {
            return handler(command);
        } catch (...) {
            return {};
        }
    }

    [[nodiscard]] bool is_running() const noexcept {
        return running_;
    }

    void register_handler(
        std::string_view command,
        std::function<std::string(const std::string&)> handler
    ) noexcept {
        try {
            std::lock_guard lock{mutex_};
            handlers_.insert_or_assign(std::string{command}, std::move(handler));
        } catch (...) {
        }
    }

    void notify(std::string_view method, std::string_view params) noexcept {
        if (!running_) {
            return;
        }

        std::lock_guard lock{output_mutex_};
        std::cout << "{\"jsonrpc\":\"2.0\",\"method\":\"" << escape_json(method)
                  << "\",\"params\":" << params << "}\n"
                  << std::flush;
    }

private:
    [[nodiscard]] bool input_ready() const noexcept {
#if defined(_WIN32)
        return _kbhit() != 0;
#else
        pollfd descriptor{.fd = STDIN_FILENO, .events = POLLIN, .revents = 0};
        const int result = ::poll(&descriptor, 1, 100);
        return result > 0 && (descriptor.revents & (POLLIN | POLLHUP)) != 0;
#endif
    }

    void io_loop() noexcept {
        std::array<char, 4096> buffer{};
        while (running_) {
            if (!input_ready()) {
                continue;
            }

            if (std::fgets(buffer.data(), static_cast<int>(buffer.size()), stdin) == nullptr) {
                break;
            }

            std::string message{buffer.data()};
            if (!message.empty() && message.back() == '\n') {
                message.pop_back();
            }
            if (!message.empty() && message.back() == '\r') {
                message.pop_back();
            }
            if (!message.empty()) {
                process_message(message);
            }
        }
    }

    void process_message(std::string_view message) noexcept {
        const std::string method = extract_string(message, "method");
        const std::string id = extract_id(message);
        if (method.empty() || id.empty()) {
            return;
        }

        const std::string result = execute(method);
        std::lock_guard lock{output_mutex_};
        if (result.empty()) {
            std::cout << "{\"jsonrpc\":\"2.0\",\"id\":" << id
                      << ",\"error\":{\"code\":-32601,\"message\":\"Method not found\"}}\n";
        } else {
            std::cout << "{\"jsonrpc\":\"2.0\",\"id\":" << id
                      << ",\"result\":" << result << "}\n";
        }
        std::cout << std::flush;
    }

    std::atomic<bool> running_{false};
    std::mutex mutex_;
    std::mutex output_mutex_;
    std::unordered_map<std::string, std::function<std::string(const std::string&)>> handlers_;
    std::string config_name_;
    std::string config_version_;
    std::vector<std::string> capabilities_;
    std::thread io_thread_;
};

mcp_server::mcp_server() noexcept {
    try {
        pimpl_ = std::make_unique<impl>();
    } catch (...) {
    }
}

mcp_server::~mcp_server() {
    stop();
}

bool mcp_server::start(const server_config& config) noexcept {
    return pimpl_ != nullptr && pimpl_->start(config);
}

void mcp_server::stop() noexcept {
    if (pimpl_ != nullptr) {
        pimpl_->stop();
    }
}

std::string mcp_server::execute(const std::string& command) noexcept {
    return pimpl_ != nullptr ? pimpl_->execute(command) : std::string{};
}

bool mcp_server::is_running() const noexcept {
    return pimpl_ != nullptr && pimpl_->is_running();
}

void mcp_server::register_handler(
    std::string_view command,
    std::function<std::string(const std::string&)> handler
) noexcept {
    if (pimpl_ != nullptr) {
        pimpl_->register_handler(command, std::move(handler));
    }
}

void mcp_server::notify(std::string_view method, std::string_view params) noexcept {
    if (pimpl_ != nullptr) {
        pimpl_->notify(method, params);
    }
}

} // namespace tb::piped_mcp
