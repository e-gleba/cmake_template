#include "mcp_server.hpp"

#include <algorithm>
#include <cctype>
#include <chrono>
#include <iostream>
#include <limits>
#include <ranges>
#include <string>
#include <unordered_map>
#include <utility>

#if defined(_WIN32)
#ifndef NOMINMAX
#define NOMINMAX
#endif
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>
#else
#include <poll.h>
#include <unistd.h>
#endif

namespace tb::piped_mcp {

namespace {

constexpr std::size_t max_message_size{ std::size_t{ 1024 } * 1024 };

[[nodiscard]] std::string escape_json(std::string_view value)
{
    std::string escaped;
    escaped.reserve(value.size());
    for (const char character : value) {
        switch (character) {
            case '\\':
                escaped += R"(\\)";
                break;
            case '"':
                escaped += R"(\")";
                break;
            case '\n':
                escaped += R"(\n)";
                break;
            case '\r':
                escaped += R"(\r)";
                break;
            case '\t':
                escaped += R"(\t)";
                break;
            default:
                escaped += character;
                break;
        }
    }
    return escaped;
}

[[nodiscard]] std::size_t skip_whitespace(std::string_view message,
                                          std::size_t      position)
{
    const auto remaining = message.substr(position);
    const auto iterator =
        std::ranges::find_if_not(remaining, [](const unsigned char character) {
            return std::isspace(character) != 0;
        });
    return position + static_cast<std::size_t>(
                          std::ranges::distance(remaining.begin(), iterator));
}

[[nodiscard]] std::size_t skip_string(std::string_view message,
                                      std::size_t      position)
{
    if (position >= message.size() || message[position] != '"') {
        return std::string_view::npos;
    }

    for (++position; position < message.size(); ++position) {
        if (message[position] == '\\') {
            ++position;
        } else if (message[position] == '"') {
            return position + 1;
        }
    }
    return std::string_view::npos;
}

[[nodiscard]] std::size_t skip_value(std::string_view message,
                                     std::size_t      position)
{
    position = skip_whitespace(message, position);
    if (position >= message.size()) {
        return std::string_view::npos;
    }
    if (message[position] == '"') {
        return skip_string(message, position);
    }

    const char opening = message[position];
    if (opening != '{' && opening != '[') {
        const std::size_t end = message.find_first_of(",}", position);
        return end == std::string_view::npos ? message.size() : end;
    }

    const char  closing = opening == '{' ? '}' : ']';
    std::size_t depth{};
    for (; position < message.size(); ++position) {
        if (message[position] == '"') {
            position = skip_string(message, position);
            if (position == std::string_view::npos) {
                return position;
            }
            --position;
        } else if (message[position] == opening) {
            ++depth;
        } else if (message[position] == closing && --depth == 0) {
            return position + 1;
        }
    }
    return std::string_view::npos;
}

struct request_fields final
{
    std::string method_;
    std::string id_;
    std::string params_;
};

[[nodiscard]] request_fields parse_request(std::string_view message)
{
    request_fields fields;
    std::size_t    position = skip_whitespace(message, 0);
    if (position >= message.size() || message[position] != '{') {
        return {};
    }
    ++position;

    while (position < message.size()) {
        position = skip_whitespace(message, position);
        if (position < message.size() && message[position] == '}') {
            return fields;
        }

        const std::size_t key_end = skip_string(message, position);
        if (key_end == std::string_view::npos) {
            return {};
        }
        const std::string_view key =
            message.substr(position + 1, key_end - position - 2);

        position = skip_whitespace(message, key_end);
        if (position >= message.size() || message[position] != ':') {
            return {};
        }
        ++position;
        position                    = skip_whitespace(message, position);
        const std::size_t value_end = skip_value(message, position);
        if (value_end == std::string_view::npos) {
            return {};
        }

        if (key == "method" && message[position] == '"') {
            fields.method_ = std::string{ message.substr(
                position + 1, value_end - position - 2) };
        } else if (key == "id") {
            fields.id_ =
                std::string{ message.substr(position, value_end - position) };
        }

        position = skip_whitespace(message, value_end);
        if (position < message.size() && message[position] == ',') {
            ++position;
        } else if (position >= message.size() || message[position] != '}') {
            return {};
        }
    }
    return {};
}

} // namespace

class mcp_server::impl final
{
public:
    bool start(const server_config& config) noexcept
    {
        std::lock_guard lock{ mutex_ };
        if (running_) {
            return false;
        }

        try {
            config_name_    = config.name;
            config_version_ = config.version;
            capabilities_.clear();
            capabilities_.reserve(config.capabilities.size());
            std::ranges::transform(config.capabilities,
                                   std::back_inserter(capabilities_),
                                   [](const auto capability) {
                                       return std::string{ capability };
                                   });
            running_   = true;
            io_thread_ = std::thread{ [this] { io_loop(); } };
        } catch (...) {
            running_ = false;
            return false;
        }
        return true;
    }

    void stop() noexcept
    {
        running_ = false;
        if (io_thread_.joinable()) {
            io_thread_.join();
        }
    }

    [[nodiscard]] std::string execute(const std::string& command,
                                      const std::string& params) noexcept
    {
        std::function<std::string(const std::string&)> handler;
        {
            std::lock_guard lock{ mutex_ };
            const auto      iterator = handlers_.find(command);
            if (iterator == handlers_.end()) {
                return {};
            }
            handler = iterator->second;
        }

        try {
            return handler(params);
        } catch (...) {
            return {};
        }
    }

    [[nodiscard]] bool is_running() const noexcept { return running_; }

    void register_handler(
        std::string_view                               command,
        std::function<std::string(const std::string&)> handler) noexcept
    {
        try {
            std::lock_guard lock{ mutex_ };
            handlers_.insert_or_assign(std::string{ command },
                                       std::move(handler));
        } catch (const std::exception&) {
            return;
        }
    }

    void notify(std::string_view method, std::string_view params) noexcept
    {
        if (!running_) {
            return;
        }

        std::lock_guard lock{ output_mutex_ };
        std::cout << R"json({"jsonrpc":"2.0","method":")json"
                  << escape_json(method) << R"json(","params":)json" << params
                  << "}\n"
                  << std::flush;
    }

private:
    [[nodiscard]] static bool input_ready() noexcept
    {
#if defined(_WIN32)
        DWORD        available_bytes{};
        const HANDLE input = GetStdHandle(STD_INPUT_HANDLE);
        return input != nullptr && input != INVALID_HANDLE_VALUE &&
               PeekNamedPipe(
                   input, nullptr, 0, nullptr, &available_bytes, nullptr) !=
                   0 &&
               available_bytes != 0;
#else
        pollfd descriptor{ .fd = STDIN_FILENO, .events = POLLIN, .revents = 0 };
        const int result = ::poll(&descriptor, 1, 100);
        return result > 0 && (descriptor.revents & (POLLIN | POLLHUP)) != 0;
#endif
    }

    [[nodiscard]] static int read_byte() noexcept
    {
#if defined(_WIN32)
        const HANDLE input = GetStdHandle(STD_INPUT_HANDLE);
        if (input == nullptr || input == INVALID_HANDLE_VALUE) {
            return std::char_traits<char>::eof();
        }
        char       byte{};
        DWORD      bytes_read{};
        const bool ok = ReadFile(input, &byte, 1, &bytes_read, nullptr) != 0 &&
                        bytes_read != 0;
        return ok ? static_cast<unsigned char>(byte)
                  : std::char_traits<char>::eof();
#else
        char          byte{};
        const ssize_t bytes_read = ::read(STDIN_FILENO, &byte, 1);
        return bytes_read > 0 ? static_cast<unsigned char>(byte)
                              : std::char_traits<char>::eof();
#endif
    }

    void io_loop()
    {
        try {
            std::string message;
            message.reserve(4096);

            while (running_) {
                if (!input_ready()) {
#if defined(_WIN32)
                    std::this_thread::sleep_for(
                        std::chrono::milliseconds{ 10 });
#endif
                    continue;
                }

                const int character = read_byte();
                if (character == std::char_traits<char>::eof()) {
                    break;
                }
                if (character == '\n') {
                    if (!message.empty() && message.back() == '\r') {
                        message.pop_back();
                    }
                    if (!message.empty()) {
                        process_message(message);
                    }
                    message.clear();
                    continue;
                }
                if (message.size() == max_message_size) {
                    message.clear();
                    for (;;) {
                        const int skip = read_byte();
                        if (skip == std::char_traits<char>::eof() ||
                            skip == '\n') {
                            break;
                        }
                    }
                    continue;
                }
                message.push_back(static_cast<char>(character));
            }
        } catch (...) {
            running_ = false;
        }
    }

    void process_message(std::string_view message)
    {
        const request_fields fields = parse_request(message);
        if (fields.method_.empty() || fields.id_.empty()) {
            return;
        }

        const std::string result = execute(fields.method_, fields.params_);
        std::lock_guard   lock{ output_mutex_ };
        if (result.empty()) {
            std::cout
                << R"json({"jsonrpc":"2.0","id":)json" << fields.id_
                << R"json(,"error":{"code":-32601,"message":"Method not found"}})json"
                << '\n';
        } else {
            std::cout << R"json({"jsonrpc":"2.0","id":)json" << fields.id_
                      << R"json(,"result":)json" << result << "}\n";
        }
        std::cout << std::flush;
    }

    std::atomic<bool> running_{ false };
    std::mutex        mutex_;
    std::mutex        output_mutex_;
    std::unordered_map<std::string,
                       std::function<std::string(const std::string&)>>
                             handlers_;
    std::string              config_name_;
    std::string              config_version_;
    std::vector<std::string> capabilities_;
    std::thread              io_thread_;
};

mcp_server::mcp_server() noexcept
{
    try {
        pimpl_ = std::make_unique<impl>();
    } catch (const std::bad_alloc&) {
        pimpl_.reset();
    }
}

mcp_server::~mcp_server()
{
    stop();
}

bool mcp_server::start(const server_config& config) noexcept
{
    return pimpl_ != nullptr && pimpl_->start(config);
}

void mcp_server::stop() noexcept
{
    if (pimpl_ != nullptr) {
        pimpl_->stop();
    }
}

std::string mcp_server::execute(const std::string& command,
                                const std::string& params) noexcept
{
    return pimpl_ != nullptr ? pimpl_->execute(command, params) : std::string{};
}

bool mcp_server::is_running() const noexcept
{
    return pimpl_ != nullptr && pimpl_->is_running();
}

void mcp_server::register_handler(
    std::string_view                               command,
    std::function<std::string(const std::string&)> handler) noexcept
{
    if (pimpl_ != nullptr) {
        pimpl_->register_handler(command, std::move(handler));
    }
}

void mcp_server::notify(std::string_view method,
                        std::string_view params) noexcept
{
    if (pimpl_ != nullptr) {
        pimpl_->notify(method, params);
    }
}

} // namespace tb::piped_mcp
