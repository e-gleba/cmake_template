#include "mcp_server.hpp"

#include <SDL3/SDL.h>
#include <SDL3/SDL_stdinc.h>

#include <array>
#include <cstdio>
#include <cstdlib>
#include <gsl/gsl>
#include <iostream>
#include <sstream>
#include <string>
#include <unordered_map>

namespace piped_mcp {

class McpServer::Impl {
public:
    std::atomic<bool> running_{false};
    std::mutex mutex_;
    std::unordered_map<std::string, std::function<std::string(const std::string&)>> handlers_;
    ServerConfig config_;
    std::thread io_thread_;
    
    bool start(const ServerConfig& config) {
        std::lock_guard lock(mutex_);
        if (running_) {
            return false;
        }
        
        config_ = config;
        running_ = true;
        
        // Start IO thread for stdio communication
        io_thread_ = std::thread([this] { io_loop(); });
        
        return true;
    }
    
    void stop() {
        {
            std::lock_guard lock(mutex_);
            if (!running_) {
                return;
            }
            running_ = false;
        }
        
        if (io_thread_.joinable()) {
            io_thread_.join();
        }
    }
    
    std::string execute(const std::string& command) {
        std::lock_guard lock(mutex_);
        auto it = handlers_.find(command);
        if (it != handlers_.end()) {
            return it->second(command);
        }
        return "{\"error\":\"Unknown command\"}";
    }
    
    bool is_running() const {
        return running_;
    }
    
    void register_handler(
        std::string_view command,
        std::function<std::string(const std::string&)> handler
    ) {
        std::lock_guard lock(mutex_);
        handlers_[std::string(command)] = std::move(handler);
    }
    
    void notify(std::string_view method, std::string_view params) {
        std::lock_guard lock(mutex_);
        if (!running_) {
            return;
        }
        
        // Send notification via stdout
        std::cout << "Content-Length: " << params.size() + method.size() + 20 << "\r\n"
                 << "Content-Type: application/json\r\n"
                 << "\r\n"
                 << "{\"method\":\"" << method << "\",\"params\":" << params << "}\r\n"
                 << std::flush;
    }

private:
    void io_loop() {
        constexpr std::size_t buffer_size = 4096;
        std::array<char, buffer_size> buffer{};
        
        while (running_) {
            if (std::fgets(buffer.data(), gsl::narrow_cast<int>(buffer.size()), stdin) != nullptr) {
                std::string input(buffer.data());
                
                // Parse Content-Length header
                if (input.find("Content-Length:") == 0) {
                    std::size_t content_length = 0;
                    if (std::sscanf(input.c_str(), "Content-Length: %zu", &content_length) == 1) {
                        // Read the actual content
                        std::string content;
                        content.resize(content_length);
                        std::fread(&content[0], 1, content_length, stdin);
                        
                        // Process the message
                        process_message(content);
                    }
                }
            }
            
            // Small delay to prevent busy waiting
            SDL_Delay(10);
        }
    }
    
    void process_message(const std::string& message) {
        // Simple JSON parsing (in production, use a proper JSON library)
        if (message.find("\"method\"") != std::string::npos) {
            std::string method;
            std::string params;
            
            // Extract method and params (simplified parsing)
            size_t method_start = message.find("\"method\":\"") + 10;
            size_t method_end = message.find("\"", method_start);
            if (method_start != std::string::npos && method_end != std::string::npos) {
                method = message.substr(method_start, method_end - method_start);
            }
            
            size_t params_start = message.find("\"params\":") + 9;
            if (params_start != std::string::npos) {
                params = message.substr(params_start);
            }
            
            // Execute the command
            std::string response = execute(method);
            
            // Send response
            std::cout << "Content-Length: " << response.size() << "\r\n"
                     << "Content-Type: application/json\r\n"
                     << "\r\n"
                     << response
                     << std::flush;
        }
    }
};

// Public interface implementation
McpServer::McpServer() : impl_(std::make_unique<Impl>()) {}

McpServer::~McpServer() = default;

bool McpServer::start(const ServerConfig& config) {
    return impl_->start(config);
}

void McpServer::stop() {
    impl_->stop();
}

std::string McpServer::execute(const std::string& command) {
    return impl_->execute(command);
}

bool McpServer::is_running() const {
    return impl_->is_running();
}

void McpServer::register_handler(
    std::string_view command,
    std::function<std::string(const std::string&)> handler
) {
    impl_->register_handler(command, std::move(handler));
}

void McpServer::notify(std::string_view method, std::string_view params) {
    impl_->notify(method, params);
}

} // namespace piped_mcp
