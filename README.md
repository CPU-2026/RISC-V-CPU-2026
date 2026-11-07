# RISC-V CPU 2026

基于 SystemVerilog 的 **RV32IM 乱序处理器**，采用顺序重命名、七池保留站、乱序执行与按序提交，SRAM I$/D$ 经共享 AXI4-Lite 访问外存。

## 默认配置

| 项目 | 配置 |
|---|---|
| 取指 / 译码 / 分配 / 提交 | 4 / 4 / 4 / 4；取指可跨16 B，不跨64 B缓存行 |
| FQ / IQ / ROB / PRF | 8 / 8 / 16 / 48 项 |
| 执行与写回 | 双ALU、单AGU、三路CDB；Load/MUL/DIV共享一路CDB |
| 七池RS | Integer4、Multiply1、Divide1、Branch4、Load2、StoreAddr2、StoreValue2 |
| LQ / SQ / Load运输owner | 各8项 |
| 分支预测 | Tournament、BTB32、RAS8、checkpoint64 |
| 恢复 | 每拍重放4个ROB槽，最多4拍 |
| I$ | 1 KiB，直接映射，64 B行；2个请求包、最多8字信用 |
| D$ | 8 KiB，128组×2路，32 B行；8请求槽、4 MSHR |

支持合法RV32IM、对齐控制转移的无异常输入，不实现CSR及系统异常处理。程序向 `0x80000000` 全字写入结果退出：退出Store退休后冻结核心，排空至对应B握手，不扫描全部脏缓存行。

## 构建与运行

需要Python 3.10+、GNU Make、支持C++17的G++及binutils。Linux x86-64 / WSL2使用课程AppImage。

```bash
git submodule update --init --recursive
chmod +x cpu2026-tools-x86_64.AppImage
make build JOBS=4
make test MAX_CYCLES=100000000
make perf MAX_CYCLES=100000000
```

默认构建无需额外配置宏。参数覆盖、单例运行、波形及OJ提交见[使用说明](docs/template.md)。指定 `SIM=` 会跳过编译，需自行确认二进制与当前配置一致。

## 验证与性能

当前ROB16／PRF48配置已通过原六程序native／sv2v对照，以及两份软件模拟器的Release／断言构建和退休PC／周期对拍。课程周期包含初始化、核心执行与退出排空，六项几何平均IPC为 **1.122240**。

**当前配置的面积、Fmax和评分尚未测量。** 验证仅覆盖已列明的程序与条件，不代表全输入形式证明，详见[验证范围](docs/course.md)。

## 目录与文档

- `verilog/rtl/`：处理器RTL；`verilog/filelist.f`：活动源码清单。
- `scripts/`：构建、验证与综合工具；`testcases/`：课程测试子模块。
- [架构说明](docs/architecture.md) · [参数配置](docs/parameterized-configuration.md)
- [AXI协议](docs/axi4-lite.md) · [SRAM模型](docs/sram.md)
- [参数敏感度分析](docs/参数敏感度分析.md) · [综合评估](docs/assessment.md)

软件对拍依赖同级 `RV32IM_Simulator/`、`sync/` 及外部实验工件，不随本仓库克隆提供。
