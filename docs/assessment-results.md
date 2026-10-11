# 原生 CPU 面积与时序基线

日期：2026-10-11。流程和复现命令见 [assessment.md](assessment.md)。

## 已完成的纯核心结果

`rv32_core` 独立综合，访存输入保持为外部端口，提交跟踪输出保留。
Yosys 0.63、ABC、ASAP7 RVT TT、OpenSTA 3.1.0；展平 `opt`，目标周期 2.0 ns。

| 指标 | 实测综合/STA结果 |
|---|---:|
| 核心总面积 | 22,079.223 μm² |
| 组合逻辑面积 | 15,169.149 μm² |
| 时序逻辑面积 | 6,910.074 μm² |
| SRAM 宏面积 | 0 μm²（核心不含 Cache） |
| 估计最高频率 | 43.93 MHz |
| 最小时钟周期 | 22.765625 ns |
| 2.0 ns 目标下最差 setup slack | −20.764692 ns |

报告：`build/assessment/core/opt/report.txt`、`report.json`、`timing.rpt`。
原始源码校验：`build/assessment/core/assessment-opt.json`。

## 纯核心关键路径

STA 最差路径为 `_423125_/QN → _412937_/D`。映射回源码：

- 起点来自 `rv32_flush_arbiter` 的有效状态寄存器，对应 `validNext[0]`。
- 路径经过全局 flush 控制（映射网络与 `imemFlushOutput` 互为反相）。
- 终点来自 `rv32_bpu_direction` 的时序更新块。

关键节点的扇出为 541、1,284、639，单个 OAI311 节点延迟约 12.164 ns。
该基线显示 flush/预测器更新控制的高扇出负载是当前主要频率瓶颈。
课程流程未执行布局布线、互连寄生提取或物理缓冲树优化。

`rtl-critical-path.txt` 中保留了门级节点和源码位置关联。

## 校验

- 纯核心、带缓存两种转换后的评估入口均通过 Verilator lint。
- 转换后的纯核心通过现有 `sync/core_icache_tb.sv` 测试：20 周期行返回、
  实际重命名、Store/Load、分支恢复、HALT、取指元数据与响应握手。
- 原生 RTL 的 `sync/core_dcache_chain_tb.sv` 通过 4/4 核心/DCache/行内存链：
  mixed、partial fallback、recovery、full SQ 和最终 dirty drain。
- 核心综合通过连线检查、无残留锁存器/初始化属性检查及全映射检查；STA 完成。

## 带缓存评估

带缓存范围包括原生核心、1 KiB ICache、8 KiB 寄存器 DCache 及最终排空控制。
展平 opt 已产出最终 PPA 面积/频率。此前层次综合报 AGU 空连接端口不匹配，
以及 ROB packed lookup 未驱动；删除冗余 AGU 输出端口并为 ROB lookup 加组合默认值后，
层次诊断已成功完成，端口和未驱动检查通过。

环境重启后已从工程内的展开快照恢复；新的综合会在工程目录持久保存
通用网表及 pre-ABC 检查点。包含 SRAM 的小电路已验证完整综合与 pre-ABC
恢复流程，两次面积及频率完全一致。

| 指标 | 核心 + I$/D$ + 排空控制 |
|---|---:|
| 总面积 | **68,597.748 μm²** |
| 组合逻辑面积 | 40,530.563 μm² |
| 时序逻辑面积 | 27,723.199 μm² |
| I$ SRAM 宏面积 | 343.985 μm² |
| 估计最高频率 | **33.015218 MHz** |
| 最小时钟周期 | 30.2890625 ns |
| 2.0 ns 目标下最差 setup slack | −28.288780 ns |
| 映射后叶单元数 | 624,112 |

报告：`build/assessment/cached/opt/report.txt`、`report.json`、`timing.rpt`。
源码及快照校验：`build/assessment/cached/assessment-opt.json`。

层次诊断报告：`build/assessment/cached/diagnose/report.txt`、`report.json`、
`timing.rpt`。它保留层次并关闭跨层次 `opt_hier`；表中的 `Area` 含子模块，
`Direct` 只计当前模块本身。

| 层次模块 | 面积（含子模块） | 占层次总面积 | 直接面积 |
|---|---:|---:|---:|
| `u_dmem_backend/cache`（DCache） | 45,755.087 μm² | 64.03% | 45,749.022 μm² |
| `u_core` | 24,558.523 μm² | 34.37% | 73.017 μm² |
| `u_core/u_predictor` | 8,187.807 μm² | 11.46% | 16.534 μm² |
| `u_core/u_lsu` | 3,336.939 μm² | 4.67% | 3,336.939 μm² |
| `u_core/u_prf` | 2,748.345 μm² | 3.85% | 2,748.345 μm² |
| `u_core/u_rob` | 2,724.594 μm² | 3.81% | 2,686.321 μm² |
| `u_core/u_predictor/u_ras` | 3,454.323 μm² | 4.83% | 3,454.323 μm² |
| `u_core/u_predictor/u_btb` | 3,067.078 μm² | 4.29% | 3,067.078 μm² |
| `u_core/u_predictor/u_direction` | 1,463.701 μm² | 2.05% | 1,463.701 μm² |
| `u_core/u_mul_unit` | 741.189 μm² | 1.04% | 699.257 μm² |
| `u_core/u_agu_unit` | 48.376 μm² | 0.07% | 27.454 μm² |

层次诊断合计 71,458.562 μm²、25.21 MHz；与展平 opt 的 68,597.748 μm²、
33.02 MHz 不同。保留模块边界改变了跨模块共享和逻辑重构，因此层次表用于
定位模块热点，最终 PPA 仍以展平 opt 报告为准。

相对纯核心，总面积增加 **46,518.524 μm²**。该差值包括缓存、排空控制及
跨模块优化变化，不等于 DCache 的独立模块面积。按寄存器原始源码归属统计，
DCache 有 69,388 个触发器、20,570.514 μm² 的触发器面积，占带缓存设计
时序逻辑面积约 74.2%；这是时序部分的归属统计，尚未包含 DCache 组合逻辑。
额外的触发器归属统计见 `register-area-by-module.json`。

### 带缓存关键路径

最差路径为 `_1216488_/QN → _1135829_/D`，对应：

```text
Flush Arbiter 有效位
  → 全局 flush 控制
  → 访存请求/缓存控制逻辑
  → DCache 写回地址寄存器 writeAddressInner[6]
```

- 起点的 D 输入保留了 `u_core.u_flush_arbiter.validNext[0]` 名称。
- 全局 flush 网络（顶层别名 `imemFlushOutput`）的 STA 扇出为 **1,325**，
  驱动它的 INV 单元延迟为 **14.7238 ns**。
- 后续一处扇出 **1,076** 的控制节点延迟为 **6.0526 ns**。
- 终点属于 `rv32_dcache` 的时序块，反相 Q 与 `dmemWriteAddrOutput[6]` 对应。

核心及带缓存两份结果均显示全局 flush 的高扇出是优先时序优化点。
当前 2.0 ns 目标未达成；带缓存总面积也高于计划中的 36,000 μm² 目标。
后续优化可优先分析 flush 广播负载及 DCache 的寄存器写入/选择网络。

### 最终检查

带缓存综合已通过无残留锁存器/初始化属性、连线及全标准单元映射检查；
OpenSTA 完成约束覆盖检查和最小时钟周期搜索，生成五条关键路径。
`timing_checks.rpt` 无约束错误；setup slack 为负表示未达到目标周期。
