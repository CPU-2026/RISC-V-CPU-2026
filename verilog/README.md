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

课程顶层为 `rtl/student_top.sv`，使用 AXI4-Lite、高电平复位和 MMIO Store 退出，
SRAM 由课程 FakeRAM 模型实现。默认入口支持：

```bash
make build
make test
make perf
make synth
```

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
