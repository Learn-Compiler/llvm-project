export LLC=/home/kaikai/vortex-word/build/llvm/bin/llc
export CLANG=/home/kaikai/vortex-word/build/llvm/bin/clang

# 检查CPU列表是否有 xvortex
"$LLC" --mtriple=riscv64 --mcpu=help 2>&1 | grep vortex

# 检查 Feature 列表是否有 xvortex
"$LLC" --mtriple=riscv64 --mcpu=help 2>&1 | grep xvortex

"$CLANG" --target=riscv64-linux-gnu -mcpu=vortex  -### -c -x c /dev/null 2>&1 | grep cc1
