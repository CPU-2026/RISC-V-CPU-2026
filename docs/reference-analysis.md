# 参考模拟器分析

## 范围

只读参考为 `../RV32IM_Simulator/RISC-V-Simulator-Template`。项目流程不
修改或构建参考目录树。

## 周期模型

C++ 模型基于周期：`work()` 读取当前 `Register` 并写入下一值，全局
`sync()` 统一可见；`Wire` 为缓存组合表达式。这映射到 `always_ff` +
`always_comb`；虚模块、lambda、宿主循环、异常与动态内存无法映射到硬件。

流水线命名对照：

| 流水线功能 | 参考实现 |
| --- | --- |
| 取指 | `FetchUnit`、`BPU`、`ICache`、`IMEM` |
| 取指队列 | `InstructBuffer` FQ |
| 解码队列 | `Decoder` 与 `DecodeUnit` IQ |
| 重命名与后端分配 | `IssueArbiter` |
| 唤醒/选择与 FU 发射 | `DispatchArbiter` |
| 执行 | `ALU`、`MUL`、`DIV`、`BRU`、`AGU` |
| 写回 | ALU、load、multiply 与 divide CDB |
| 提交 | `ROB`，每周期一条顺序退休 |

取指、重命名与提交为单宽度；独立的就绪项每周期可发射到
ALU/MUL/DIV/AGU/BRU。

## 有效配置

以源码常量为准：

| 资源 | 配置 |
| --- | --- |
| ROB | 16 项，5 位 `{epoch, slot}` 标签 |
| PRF | 48 项，P0 无效，P1-P31 初始映射 |
| RAT | 32 条映射（`specRAT`/`archRAT` 双表，无检查点阵列） |
| FQ / IQ | 4 个物理槽位，3 个可用 |
| LQ / SQ | 8 个物理槽位，7 个可用 |
| RS | 整数 4，乘法 2，除法 1，分支 4 |
| Memory RS | load 4、store-address 4、store-value 4 |
| CDB | 独立的 ALU、load、MUL、DIV 结果总线 |
| ICache | 8 KiB 直接映射，16 字节行 |
| DCache | 64 KiB，四路，16 字节行，写回 |
| Predictor | Tournament 方向（localPHT/globalPHT/selector 各 256×2-bit + GHR 8）、BTB 64（56 bit/项）、RAS 8、SARAS 16、condSeen 512 |

ROB 顺序退休；目的寄存器在重命名时分配、提交时归还旧映射；RS 轮询 PRF
就绪位图；store 在地址与数据齐备后 ROB 就绪，顺序退休后排空到缓存。

## 恢复语义

分支、JALR 与访存顺序重定向进入四项冲刷队列，最旧者优先。保留边界指令，
清除更年轻的 ROB/RS/LQ/SQ/前端/执行状态，并恢复三处推测状态：**RAT** 回到
已提交的 `archRAT` 基线后按 ROB 年龄重放 `head..SquashTag`（含边界指令自身）
的 rename，**PRF** 同样按 ROB 窗口重放——把窗口内严格年轻于边界的各条 `newPhy`
并入空闲集合（等价于回到边界时刻的快照），**BPU** 按
`ckptId` 恢复 `BPUSnapshot`（GHR / alignQueue tail / RAS_top）。RTL 以固定宽度
模运算标签实现年龄比较，重放窗口是静态阵列上的有限并行扫描，不引入运行时容器。

## ISA 覆盖

RV32I + RV32M，不含 CSR/系统指令、特权、异常/中断、原子、压缩、浮点、
向量与 `FENCE.I`。`0x0ff00513` 为带外 HALT。非法 `funct3`/`funct7` 被
拒绝，JALR 清除目标地址第 0 位，DIV/REM 实现除零与有符号溢出语义。

## 未复现的参考缺陷

- JALR 未清除目标地址第 0 位
- 混合宽度 store-to-load 转发只比较起始地址、转发未掩码 32 位数据、
  漏掉部分重叠
- HALT 与非法指令可发射进入满 ROB
- 未知操作码可创建永不完成的 ROB 项
- 有符号 C++ 加法/取负可能触发宿主未定义行为
- 跨行数据访问仅在调试构建中断言

## RTL 转换规则

- 队列与表均有编译期上界；循环指针带显式回绕位
- 分配、唤醒、选择、完成与冲刷均为有限并行扫描，无运行时容器
- 目标预测表按物理位宽打包：BTB 每项 56 bit（PC 高位 tag 24 + target[31:2]
  30 + 2 位状态 invalid/conditional/unconditional/return），索引取 PC[7:2]；
  两个训练字段组（行元数据与 target）合成一次 56 bit 写口后落寄存器
- 核心 RTL 无延迟、文件 I/O、DPI、force/release 或测试专用逻辑
- 存储器使用打包字节使能与静态阵列/外部 ready/valid 端口，后续可替换为
  ASIC SRAM 封装
