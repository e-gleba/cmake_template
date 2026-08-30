// Primary module interface unit of the named module "cxx_project".
// Exactly one per module: it owns the module name and decides what
// importers see.
//
// Ref: https://en.cppreference.com/w/cpp/language/modules

module; // global module fragment: classic textual #includes live here

#include <cstdint>
#include <string>

export module cxx_project;

// Re-export the :math partition: importers of "cxx_project" also see
// clamp/fibonacci. A plain "import :math;" would keep them internal.
// Every interface partition must be (in)directly exported by the primary
// interface unit - https://eel.is/c++draft/module.unit
export import :math;

namespace cxx_project {

// Aggregate with value semantics: copies correctly, moves cheaply,
// shares nothing. Importers build it with designated initializers.
export struct version_info final
{
    std::uint32_t major{};
    std::uint32_t minor{};
    std::uint32_t patch{};
};

// Contract only - the body lives in the module implementation unit
// (cxx_project.impl.cpp), attached to the module but never reachable
// to importers.
export [[nodiscard]] std::string describe(const version_info& version);

} // namespace cxx_project
