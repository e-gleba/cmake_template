// Single-file module "cxx_project.utility": interface and implementation
// in one translation unit, via the private module fragment below.
//
// [module.private.frag]: a unit containing "module :private;" must be
// the ONLY module unit of its module - which is why this pattern gets
// its own module instead of living inside "cxx_project" (which already
// has a partition and an implementation unit).
//
// Ref: https://eel.is/c++draft/module.private.frag

module;

#include <cstdint>

export module cxx_project.utility;

import cxx_project; // not re-exported: importers of utility stay clean

namespace cxx_project {

// Declared here, defined after "module :private;": importers may call
// it, but the body never reaches them - the definition can change
// without recompiling a single importer.
export [[nodiscard]] std::uint32_t encode_version(
    const version_info& version) noexcept;

} // namespace cxx_project

module :private; // everything below is discarded for importers

namespace cxx_project {

std::uint32_t encode_version(const version_info& version) noexcept
{
    return version.major * 10000U + version.minor * 100U + version.patch;
}

} // namespace cxx_project
