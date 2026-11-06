# RISC-V CPU 2026

基于SystemVerilog的RV32IM乱序处理器，采用顺序重命名、七池保留站、乱序执行与按序提交，SRAM I$/D$经共享AXI4-Lite访问外存。

## 默认配置

| 项目 | 配置 |
|---|---|
| 取指 / 译码 / 分配 / 提交 | 4 / 4 / 4 / 4 |
| FQ / IQ / ROB / PRF | 8 / 8 / 32 / 64 项 |
| 执行与写回 | 双ALU、单AGU、三路CDB；Load/MUL/DIV共享一路CDB |
| 七池RS | Integer4、Multiply1、Divide1、Branch4、Load2、StoreAddr2、StoreValue2 |
| LQ / SQ | 各8项 |
| 分支预测 | Tournament、BTB32、RAS8、checkpoint64 |
| I$ | 1 KiB，直接映射，64 B行 |
| D$ | 8 KiB，128组×2路，32 B行；8请求槽、4 MSHR |

取指按最早控制流截断，不跨I$行。支持合法RV32IM、对齐控制转移的无异常输入，不实现CSR及系统异常处理。

程序向 `0x80000000` 全字写入结果退出：退出Store退休后冻结核心，排空至对应B握手，不扫描全部脏缓存行。

## 构建与运行

需要Python 3.10+、GNU Make、支持C++17的G++及binutils。Linux x86-64 / WSL2使用课程AppImage。

```bash
git submodule update --init --recursive
chmod +x cpu2026-tools-x86_64.AppImage
make build JOBS=4
make test MAX_CYCLES=100000000
make perf MAX_CYCLES=100000000
```

参数配置、单例运行、波形及OJ提交见[使用说明](docs/template.md)。指定 `SIM=` 会跳过编译，需确认二进制与本版本配置一致。验证边界和性能数据以本版本对应文档为准，不混用其他配置的测量结果。

## 目录与文档

- `verilog/rtl/`：处理器RTL；`verilog/filelist.f`：活动源码清单。
- `scripts/`：构建与验证工具；`testcases/`：课程测试子模块。
- [架构说明](docs/architecture.md) · [验证范围](docs/course.md)
- [AXI协议](docs/axi4-lite.md) · [SRAM模型](docs/sram.md) · [综合评估](docs/assessment.md)

软件对拍依赖同级 `RV32IM_Simulator/`、`sync/` 及外部实验工件，不随本仓库克隆提供。
