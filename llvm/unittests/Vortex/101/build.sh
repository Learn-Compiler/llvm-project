export CLANG_BIN=/home/kaikai/vortex-word/build/llvm/bin/clang++

# 1.2查看宏展开与AST
"$CLANG_BIN" -x hip --offload-host-only -nogpuinc -nogpulib -E -P ./attributes.hip

"$CLANG_BIN" -x hip --offload-host-only -nogpuinc -nogpulib -fsyntax-only -Xclang -ast-dump ./attributes.hip

# 1.3观察设备IR(看普通RISC-V生成的IR长什么样)
"$CLANG_BIN" -cc1 -triple riscv64-unknown-elf -target-cpu generic-rv64 \
  -target-feature +m  -target-feature +f -target-feature +f \
  -target-abi lp64d -x hip -fcuda-is-device -emit-llvm -O0 ./attributes.hip -o /tmp/device.ll

# Clang 前端早已认识 __global__（解析为 CUDAGlobalAttr），也能直接生成 RISC-V 标量 IR（里面有 store i32 42）。
# 但是缺失了关键桥梁：生成的 IR 里并没有任何 Vortex 所需的元数据或 kernel 标记，更没有 Vortex 专用的 CPU 配置与 SIMT 指令。