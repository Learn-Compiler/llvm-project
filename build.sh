#!/usr/bin/env bash
set -euo pipefail

source_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
workspace="$(dirname -- "$source_dir")"
build_dir="${BUILD_DIR:-$workspace/build/llvm}"
install_dir="${INSTALL_DIR:-$workspace/install/llvm}"
jobs="${JOBS:-4}"
link_jobs="${LINK_JOBS:-1}"
build_type="${BUILD_TYPE:-Release}"
assertions="${ASSERTIONS:-ON}"
configure_only=false
install=false
extra_cmake=()

usage() {
  cat <<'EOF'
Usage: ./build.sh [--configure-only] [--install] [-- <extra CMake options>]

Builds Clang, LLD and LLVM with AMDGPU, RISCV, NVPTX and X86 targets.
Default: Release build, assertions enabled, 4 compile jobs, 1 link job.

Examples:
  ./build.sh --configure-only
  ./build.sh
  ./build.sh --install
  JOBS=6 ./build.sh
  ./build.sh -- -DLLVM_ENABLE_ASSERTIONS=OFF

Environment overrides:
  BUILD_DIR, INSTALL_DIR, JOBS, LINK_JOBS, BUILD_TYPE, ASSERTIONS, CC, CXX
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --configure-only) configure_only=true; shift ;;
    --install) install=true; shift ;;
    -h|--help) usage; exit 0 ;;
    --) shift; extra_cmake=("$@"); break ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [[ ! "$jobs" =~ ^[1-9][0-9]*$ || ! "$link_jobs" =~ ^[1-9][0-9]*$ ]]; then
  echo 'JOBS and LINK_JOBS must be positive integers.' >&2
  exit 2
fi
if $configure_only && $install; then
  echo '--configure-only and --install cannot be combined.' >&2
  exit 2
fi
if [[ ! -f "$source_dir/llvm/CMakeLists.txt" ]]; then
  echo 'Place build.sh at the root of llvm-project.' >&2
  exit 2
fi
for tool in cmake ninja; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "Missing build tool: $tool" >&2
    exit 2
  fi
done

# Keep the linker from the reference toolchain available without changing the shell.
if [[ -x "$workspace/tools/llvm-vortex/bin/ld.lld" ]]; then
  export PATH="$workspace/tools/llvm-vortex/bin:$PATH"
fi
cc="$(command -v "${CC:-cc}")"
cxx="$(command -v "${CXX:-c++}")"

cmake_args=(
  -S "$source_dir/llvm" -B "$build_dir" -G Ninja
  "-DCMAKE_BUILD_TYPE=$build_type"
  "-DCMAKE_INSTALL_PREFIX=$install_dir"
  "-DCMAKE_C_COMPILER=$cc"
  "-DCMAKE_CXX_COMPILER=$cxx"
  -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
  '-DLLVM_ENABLE_PROJECTS=clang;lld'
  '-DLLVM_TARGETS_TO_BUILD=AMDGPU;RISCV;NVPTX;X86'
  "-DLLVM_ENABLE_ASSERTIONS=$assertions"
  "-DLLVM_PARALLEL_LINK_JOBS=$link_jobs"
  -DLLVM_BUILD_LLVM_DYLIB=ON
  -DLLVM_LINK_LLVM_DYLIB=ON
  -DLLVM_INCLUDE_TESTS=ON
  -DLLVM_BUILD_TESTS=OFF
  -DLLVM_INCLUDE_BENCHMARKS=OFF
  -DLLVM_INSTALL_UTILS=ON
)
if command -v ld.lld >/dev/null 2>&1; then
  cmake_args+=(-DLLVM_USE_LINKER=lld)
fi
if command -v ccache >/dev/null 2>&1; then
  cmake_args+=(-DCMAKE_C_COMPILER_LAUNCHER=ccache -DCMAKE_CXX_COMPILER_LAUNCHER=ccache)
fi

printf 'Source:  %s\nBuild:   %s\nInstall: %s\n' "$source_dir" "$build_dir" "$install_dir"
printf 'Targets: AMDGPU;RISCV;NVPTX;X86\nJobs: %s compile, %s link\n' "$jobs" "$link_jobs"
cmake "${cmake_args[@]}" "${extra_cmake[@]}"
if $configure_only; then
  echo 'Configuration complete. Run ./build.sh to compile.'
  exit 0
fi

cmake --build "$build_dir" --parallel "$jobs"
"$build_dir/bin/llvm-config" --targets-built
if $install; then
  cmake --install "$build_dir"
  printf 'Installed LLVM to %s\n' "$install_dir"
fi
