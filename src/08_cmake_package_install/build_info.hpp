#pragma once

#include <string_view>

namespace tb::build_info {

[[nodiscard]] std::string_view get_build_report();

} // namespace tb::build_info
