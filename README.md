# RISC-V CPU 2026

基于 SystemVerilog 的 **RV32IM 乱序处理器**。指令按序重命名，进入七类保留站，操作数就绪后乱序执行，最后按序提交。指令缓存（I$）和数据缓存（D$）使用 SRAM，经共享的 AXI4-Lite 总线访问外存。

## 默认配置

| 项目 | 配置 |
|---|---|
| 取指 / 译码 / 分配 / 提交 | 每拍 4 / 4 / 4 / 4 条；取指可跨 16 B 边界，不跨 64 B 缓存行 |
| FQ / IQ / ROB / PRF | 8 / 8 / 16 / 48 项 |
| 执行与写回 | 双 ALU、单 AGU；四路 CDB：两个 ALU 各一路，Load 独占一路，MUL/DIV 共享一路 |
| 七类保留站 | Integer 4、Multiply 1、Divide 1、Branch 4、Load 2、StoreAddr 2、StoreValue 2 |
| LQ / SQ / 在途 Load 跟踪项 | 各 8 项 |
| 分支预测 | Tournament；BTB 32 项，返回地址栈（RAS）8 项，checkpoint 64 项 |
| 恢复 | 先读取已提交状态，再每拍重放 8 个 ROB 槽，最多重放 2 拍 |
| I$ | 1 KiB，直接映射，64 B 行；2 个请求包，最多预留 8 个指令字 |
| D$ | 8 KiB，128 组 × 2 路，32 B 行；8 个请求槽，4 个 MSHR |

支持控制转移对齐、无异常的 RV32IM 程序，不实现 CSR 和系统异常处理。程序向 `0x80000000` 写入 32 位结果退出：该 Store 退休后核心冻结，访存继续排空至对应的 AXI 写响应（B 通道握手），不扫描全部脏缓存行。

## 构建与运行

宿主机需要 Python 3.10+、GNU Make、支持 C++17 的 G++ 和 binutils。Linux x86-64 或 WSL2 可将课程 AppImage 放在仓库根目录，按默认配置构建：

```bash
git submodule update --init --recursive
chmod +x cpu2026-tools-x86_64.AppImage
make build JOBS=4
```

`make test` 运行正确性用例，`make perf` 运行性能用例。复核生产版时，指定由同一份 RTL 经 sv2v 转换、保留断言的仿真器；`SIM` 非空时这两个目标会跳过编译：

```bash
SIM=/path/to/converted-sim
make test SIM="$SIM" MAX_CYCLES=100000000
make perf SIM="$SIM" MAX_CYCLES=100000000
```

默认配置不需要额外的宏。参数覆盖见[架构与参数](docs/architecture.md#编译参数)，单例运行、波形及 OJ 提交见[课程使用说明](docs/template.md)。

## 验证与性能

八路 RAS 重放版通过了原六项性能测试，**几何平均 IPC 为 1.110949**。每项 IPC 按退休指令数除以课程总周期计算，包括启动、执行和退出排空。六项周期和 374104 条完整 RTL 退休记录均与前一版 W8 相同。两套软件模拟器的 Release 和保断言构建均通过原六；各自的 374104 条退休 PC、周期、通道与 RTL 逐条一致。逐项结果见[验证与评估](docs/assessment.md)。

整核按 2.5 ns 目标映射，**估计 Fmax 427.892 MHz，面积 34370.02 μm²**。400 MHz 下最差 setup 余量为 +163.482 ps，无违例；同一网表在 500 MHz 下最差余量为 −336.518 ps。部分端点余量下降，全组非退化检查未通过。测量采用理想时钟、无互连寄生，详见[整核时序分析](docs/频率分析.md)。

## 目录与文档

- [`verilog/rtl/`](verilog/rtl/)：处理器 RTL；[`verilog/filelist.f`](verilog/filelist.f)：默认构建的源码清单。
- [`scripts/`](scripts/)：构建、仿真、测试与综合工具；[`testcases/`](testcases/)：课程测试子模块。
- [AXI4-Lite 协议](docs/axi4-lite.md) · [SRAM 模型](docs/sram.md) · [参数敏感度分析](docs/参数敏感度分析.md) · [文档索引](docs/README.md)

软件对拍另需同级的 `RV32IM_Simulator/`、`sync/` 和对应实验产物，不随本硬件仓库提供。
