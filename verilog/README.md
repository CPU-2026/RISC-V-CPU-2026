# RTL 源代码目录

`filelist.f` 是**可综合 RTL 源文件的权威列表**。
该文件中记录的所有路径均以本目录为基准的相对路径。

## 目录结构

* `rtl/common/`：公共类型、指令定义以及基础算术单元
* `rtl/frontend/`：取指（Fetch）与译码（Decode）
* `rtl/backend/`：寄存器重命名（Rename）、物理寄存器文件（PRF）、重排序缓冲区（ROB）以及保留站（Reservation Station）
* `rtl/execute/`：整数执行单元、分支执行单元、乘法器、除法器以及地址生成单元（AGU）
* `rtl/memory/`：Load/Store Unit、Cache 以及本地 SRAM 封装
* `rtl/predictor/`：分支预测相关结构
* `rtl/core/`：CPU 核心集成以及 Flush 仲裁逻辑

## 当前集成状态

当前保留的实现包含两个原生顶层模块：

* `cpu_top`：无 Cache 的顶层模块，采用分离的指令/数据 ready-valid 接口
* `cpu_cached_top`：包含 Cache 的顶层模块，采用 128-bit Cache Line 内存接口

这两个模块目前都**不是课程框架要求的 `student_top` AXI4-Lite 顶层模块**。

因此，在增加相应的适配层（Adapter）之前，课程官方提供的以下流程暂时无法直接运行：

```bash
make build
make test
make perf
make synth
```

适配层需要完成至少以下工作：

* 提供课程框架要求的 **AXI4-Lite 接口**
* 适配课程框架使用的 **高电平有效复位（Active-High Reset）**
* 实现通过 **MMIO Store** 触发程序退出的机制
* 将现有 SRAM 接口适配为与 **FakeRAM** 兼容的 SRAM 实现

目前官方的：

```text
testcases/
```

Git Submodule 是仓库中唯一保留的回归测试输入来源。

## Verilog / SystemVerilog 开发环境推荐

推荐使用进行 RTL 开发以下插件进行 Verilog / SystemVerilog 开发：

* **Verilog-HDL/SystemVerilog**：提供语法高亮等基础 HDL 编辑功能。
* **Verible**：用于 `.v` / `.sv` 文件的格式化和静态检查。
* **SystemVerilog - Language Support**：提供代码补全、定义跳转等语言支持。
