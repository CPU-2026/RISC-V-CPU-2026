# 模块对照：C++ 参考模型与 SystemVerilog RTL

本文对比历史 C++ 周期模型（REF，`../RV32IM_Simulator/RISC-V-Simulator-Template`）和 `verilog/rtl/` 中的原生接口实现（RTL）。REF 的 `work()` 读取周期初状态、由 `sync()` 统一提交；RTL 用组合逻辑和 `always_ff` 实现相应行为。模块名称和周期数不必一一对应。

## 模块映射

| 功能 | REF | RTL | 主要区别 |
| --- | --- | --- | --- |
| 取指、FQ/IQ、译码 | `FetchUnit`、`InstructBuffer`、`DecodeUnit`、`Decoder` | `rv32_frontend`、`rv32_decoder` | RTL 合并取指与两级队列，译码在队列输出后进行；非法指令在译码时标记。 |
| 分支预测 | `BPU` | `rv32_predictor` | 表结构与恢复思路相近；REF 在冲刷仲裁器判分支误预测，RTL 在 BRU 判定。 |
| 重命名、物理寄存器 | `RAT`、`PRF` | `rv32_rat`、`rv32_prf` | 两边均用已提交映射 + ROB 窗口重放恢复；REF 用环形空闲列表，RTL 用空闲位图和 first-fit。 |
| ROB | `ROB` | `rv32_rob` | REF 用指针及 LQ/SQ 尾快照；RTL 用计数/有效位，访存队列按 ROB 年龄冲刷。 |
| 发射、保留站 | `IssueArbiter`、`RSUnit`×7、`DispatchArbiter` | `rv32_core` 发射逻辑、`rv32_rs`×5 | REF 由 PRF 判就绪、集中选择；RTL 的 RS 存操作数及 ready 位，内部选最老可发项。 |
| 执行与写回 | `ALU/MUL/DIV/BRU`、四个 CDB | `rv32_alu_unit/rv32_mul/rv32_div/rv32_bru_unit`、四条直连写回通道 | REF 多用结果队列，RTL 多用流水/握手；RTL 在 core 通过 ROB 完整 tag 认证结果。 |
| 地址与访存 | `AGU`、`LQ`、`SQ`、`MemArbiter` | 组合 `rv32_agu`、`rv32_lsu` | REF 的 AGU 有 4 槽结果队列；RTL 的 LSU 统一处理队列、逐字节转发与请求。 |
| 缓存与主存 | `ICache/DCache/IMEM/DMEM` | `rv32_icache/rv32_dcache`、核外握手端口 | REF 在核内模拟主存延迟；RTL 把主存移到核外，缓存以 FSM 和行接口工作。 |
| 冲刷、结束 | `FlushArbiter`、HALT 后等待队列空闲 | `rv32_flush_arbiter`、HALT 后 D$ 主动排空 | 两边均有 4 项冲刷仲裁；RTL 须处理在途响应和脏行写回。 |

## 会改变行为或性能的差异

| 主题 | 对照结论 |
| --- | --- |
| 前端吞吐 | REF 的 I$ 有 4 项投机请求队列，命中可直接供指令；RTL 前端单在途请求，I$ 经 `TAG_READ`，命中约 2 拍。FQ/IQ 均为 4 槽，但队列组织不同。 |
| RS 与执行单元 | REF 是 7 池约 23 槽的去值化 RS，执行结果多用 4 槽队列；RTL 是 5 池 15 槽的取值化 RS，写回可唤醒操作数，FU 用 ready/valid 握手。两侧的背压与发射时序不能按拍照搬。 |
| AGU 与访存 | REF 地址生成后入队，RTL 在发射拍组合求地址。两边均阻止 load 越过地址未知的更老 store；REF 按整字、相同起始地址转发，RTL 按字节选择最近的更老 store，支持部分转发与响应合并。 |
| 恢复与写回 | REF 的 LQ/SQ 用 ROB 尾快照回卷，RTL 按 `flush_tag` 清年轻项并丢弃错路响应；两侧 RAT/PRF 都依赖 ROB 窗口重放。RTL 的直连写回必须先验证完整 tag、存活与冲刷年龄，避免旧结果写入复用槽。 |
| 缓存与结束 | REF 的 D$ 命中可快速自答，脏行仅在替换时写回；RTL 命中经 `TAG_READ`，HALT 时主动扫描并排空脏行。两侧均用 4 路 tree-PLRU，命中延迟和收尾周期却不同。 |
| 算术与异常 | 乘法两侧均用 Booth radix-4 + CSA；除法 REF 为 SRT radix-4，RTL 为逐位 restoring。RTL 另有非法指令、未对齐目标的异常路径；JALR 目标清 bit 0。 |

默认规模：ROB16、PRF48、FQ/IQ 各 4、LQ/SQ 各 8、I$ 8 KiB 直接映射、D$ 64 KiB 四路（16 B 行）。预测器采用三张 256×2 bit 方向表、BTB64、RAS8、SARAS16、32 项取指检查点。以上是对照用的原生接口配置，具体参数与后续改造以源码和 [`plan.md`](plan.md) 为准。

## 验证口径

- REF 的主存延迟由模型内部设定（旧环境为 20 拍），按 HALT 和队列排空结束；历史 RTL 测试环境也以 HALT 及自有计时区间统计 IPC。两侧 benchmark、存储器和计时边界不同，旧 IPC 数值不能直接比较。
- 当前课程以 `student_top`、AXI4-Lite、`sram_fakeram` 及 `testcases/` 子模块为准：19 项正确性、6 项性能测试；向 `0x80000000` 写全字（`WSTRB=4'hf`）后以 B 通道握手作为退出边界。官方 IPC、面积、频率应使用课程 `make test`、`make perf`、`make synth MODE=opt` 重新测量，不以历史对照文档中的结果代替。
