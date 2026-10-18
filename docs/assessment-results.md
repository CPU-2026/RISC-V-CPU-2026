# 面积与时序记录

**结果只适用于对应源码快照和范围；“最新”不代表工作区后续修改已重新综合。** 方法与统一限制见 [assessment.md](assessment.md)，功能/IPC 对照见 [experiments.md](experiments.md)，验证汇总见 [course.md](course.md)。

以下均为 ASAP7 RVT TT/FakeRAM 拟合、Yosys/ABC、OpenSTA 的综合级估计，非布局布线或芯片实测。`opt` 对外报告总 PPA，`diagnose` 定位模块；不可混用或比例换算。`build/` 未纳入 Git，旧临时工件在 10-14 重启后已丢失，路径仅用于历史定位。

<a id="course-ppa"></a>

## 1. 完整课程顶层：10-16～18

范围为 `student_top` 的 core＋I$/D$＋AXI/MMIO 主机，不含外部从机。下表为展平 `opt`、2 ns 目标；各轮比较均核对工具/库/约束和对应源码身份，不能据此把同时变化的结构当成单变量。10-17～18 后续轮使用 `--no-hieropt`。

| 快照 | 总面积 μm² | 组合 | 时序 | SRAM | Fmax MHz | 最小周期 ns | 2 ns slack ns |
|---|---:|---:|---:|---:|---:|---:|---:|
| 10-16 两路 CDB | 43,753.251 | 27,628.400 | 14,286.680 | 1,838.172 | 235.24 | 4.250977 | −2.250460 |
| 10-17 AXIData 共享 payload/五游标 | 40,445.487 | 26,194.136 | 12,413.179 | 1,838.172 | 238.08 | 4.200195 | −2.199255 |
| 10-17 三模块第二轮优化 | 35,728.376 | 22,528.535 | 11,361.669 | 1,838.172 | 233.26 | 4.287109 | −2.286882 |
| 10-17 已提交 SRAM＋四拍恢复 | 34,652.827 | 21,580.616 | 11,204.730 | 1,867.481 | 239.93 | 4.167969 | −2.167521 |
| 10-17 D$ 局部 SRAM 地址 | 34,718.452 | 21,646.241 | 11,204.730 | 1,867.481 | 370.88 | 2.696289 | −0.695935 |
| 10-18 A 档组合收敛 | 32,378.493 | 19,385.131 | 11,125.881 | 1,867.481 | 415.75 | 2.4053 | −0.4049 |
| 10-18 D$/AXI 深度收敛 | 27,840.381 | 16,914.608 | 9,058.292 | 1,867.481 | 391.74 | 2.5527 | −0.5512 |
| **10-18 LSU 转发/对齐收敛（最新记录）** | **27,428.525** | **16,511.850** | **9,049.194** | **1,867.481** | **394.30** | **2.5361** | — |

最新相对前一步面积 −411.856 μm²（−1.48%）、Fmax＋0.65%；2 ns/500 MHz 仍未达到。面积/频率不等于满足课程全部评分门槛，IPC 须独立验收。

### 各轮改动与取舍

- **两路 CDB**：ALU 独占一路、MUL/DIV/LQ 共用一路。没有同源码其余部分不变的四路对照综合，不能把该绝对 PPA 解释为合并收益。
- **AXIData 五游标＋共享 payload**：仅改 `rv32_axi_data`，扫描改 epoch 游标、读写共用 16×32 B 池；面积 −7.560%、Fmax＋1.209%。无新增 SRAM/流水级，课程周期保持。
- **三模块第二轮**：AXIFetch 计数/游标化、AXIData 共享描述符/进度、D$ 小偏移冲突网络及宽数据复位分离。容量、并发和周期不变；面积 −11.663%，Fmax −2.027%，不称全面改善。
- **四拍恢复**：面积 −3.010%、Fmax＋2.858%；实际保留 31 个 `fakeram_asap7_1x6`（RAT x0 被优化）及 16 个 `fakeram_asap7_1x32`。六例 IPC −7.161%，按各自 Fmax 估计的吞吐 −4.507%、单位面积吞吐 −1.543%。功能/性能详情见[恢复实验](experiments.md#recovery4)。
- **D$ 局部地址**：仅改 `rv32_dcache`，全局地址广播拆到各 way/bank、提前计算 lookup 候选；Fill > Store > lookup、周期/流水级不变。面积＋0.189%，Fmax＋54.582%；25 例输出和逐例周期保持（含 boot 总 15,541,980 拍）。
- **A 档组合收敛**：D$ 行内取数改字选＋4 路字节旋转；LSU 转发查询 9 份折为 2 份；ROB 不再旋转 16 项，直出 RAT/PRF 16 bit×4、RAS 57 bit×4 窄重放窗口。相对局部地址版不改时序/SRAM 状态与触发器总数。
- **D$/AXI 深度收敛**：D$ 八份 `extract_raw` 合为共享提取，AXIFetch 行队列及 AXIData 总信用均 16→8。外部协议/逐行完成和整核周期不变；该步面积 −14.02%、Fmax −5.78%。实测取指峰值 8、数据读/写峰值 3/2。只回退 D$ 提取的探针为 27,922.976 μm² / 391.89 MHz / 2.5518 ns，表明频率损失主要来自 AXI 容量减半；按面积优先采纳。

### 最新 LSU 收敛

1. **原始字统一存储、读出统一扩展**：转发和返回都写原始 32 bit 字，删除重复 `extend_load`（展开后 25→1 份）；转发字按 Load 宽度移位，byte/half 只取低 8/16 bit。
2. **删除 owner 的 size/unsigned 副本**：行活动＋完整 tag＋已发送＋未 READY 已保证槽未复用，直接使用行内冻结属性，减少 8×3=24 个触发器。
3. **重叠判定**：字索引差 Δ∈{0,+1,−1}＋字节窗口替代两次 32 bit 减法及宽比较，两个 wrap 守卫保留无符号 mod-2³² 语义。
4. **年龄偏移预计算**：每 SQ 行只算一次 `i-head`，供转发/通知复用。

隔离探针中，基线 2,405.525 μm²；双递增器版 2,310.026 / 387.88 MHz，单减法版 2,246.603 / 393.39 MHz。删除属性副本在探针中反而＋38.2 μm²，整核展平则再省 73.3 μm²（27,501.775 / 388.32→27,428.525 / 394.30）；局部 ABC 最优不等于整核跨模块优化结果。

验证统一见 [course.md](course.md#当前验证记录)。本轮 `lsu_tagged` 增加半字无符号 `0x0000ff80`、字节有符号 `0xffffff80` 读出断言，内部存储断言改为原始字。

### 关键路径与层次热点

| 快照 | 已核验最差路径 / 结论 |
|---|---|
| 两路 CDB 初版 | `_801486_/QN → _800387_/D`，当时未归因到 RTL，不认定由共享仲裁器造成。 |
| AXIData 池化 / 三模块第二轮 | FlushArbiter valid→RAT map；池化版约 98 个组合单元、94 个非缓冲门，前 185 个 STA 点到达 4.018 ns，恢复逐项 cursor/active/tag 校验主导。 |
| 四拍恢复 | `u_axi_data.writeHeadInner[2] → DCache` 数据 SRAM 地址；第 0 条为 `_639456_/QN → ...g_way[0].g_data_bank[0].u_data.lane_0/addr_in[0]`。 |
| D$ 局部地址 | `u_core.u_rob.headInner[2] → u_core.u_rat.u_arch_sram.lane_24/ce_in`，不再是 AXIData→D$ 地址广播。 |

端点通过同名 FF、源位置/generic 检查点核验；不得新增 false path 或无协议依据的 multicycle 掩盖违例。

以下是完整课程 `diagnose --no-hieropt` 的互斥自身面积（独立 RTL 子模块另列、SRAM/包装归所属 Cache），**不是最新 LSU 版排名，也不是 opt 模块归属**：

| 模块 | AXIData 池化快照 μm² | D$ 局部地址快照 μm² |
|---|---:|---:|
| DCache | 7,257.048 | 5,375.120 |
| AXIFetch | 7,110.724 | 4,940.185 |
| BTB | 3,705.143 | 3,705.143 |
| AXIData | 4,002.910 | 3,696.584 |
| LSU | 3,231.599 | 3,208.344 |
| ROB（不含独立加法器） | 3,069.411 | 3,048.663 |
| PRF | 2,932.796 | 2,611.701 |
| RAS | — | 2,142.554 |
| RS（7 实例） | — | 2,069.194 |
| ICache | — | 1,607.080 |
| 方向预测器 | — | 1,586.391 |
| RAT | — | 913.801 |
| **diagnose 总面积** | **42,560.505** | **38,052.494** |
| **同源码 opt 总面积** | **40,445.487** | **34,718.452** |

池化快照：三个 AXI 适配器自身合计 11,185.149 μm²（26.28%），D$ 约 66.64% 为组合外围，AXIFetch 约 47.63% 为寄存器。局部地址快照：D$ 组合/时序/SRAM 为 3,066.057/814.876/1,494.186，AXIFetch 组合/时序为 2,262.160/2,678.025 μm²。父子 inclusive 面积不可再加进上述自身表。

### 工件位置

以下路径相对**父工作区**，报告中保留源码/库/工具摘要；具体测试范围见课程验证与对应实验，未将通过输出扩大成门级等价。

| 轮次 | 工件 |
|---|---|
| 两路 CDB | `build/cdb2-20261016/`：`RESULTS.md`、`synth-course/opt/`、`course-lockstep/report.json` |
| AXIData 池化 | `build/axi-data-pool-20261017/`：`ppa-comparison.json`、`PPA-COMPARISON.md`、`synth-course/opt/`、`diagnose-area/`、`DIAGNOSE-ANALYSIS.md`、`CRITICAL-PATH-ANALYSIS.md` |
| 三模块第二轮 | `build/memory-area-20261017/`：源快照、冻结旧实现/独立 oracle、四软件构建 25 例严格 golden |
| 四拍恢复 | `build/recovery4-ppa-20261017/`：综合、源码、路径及对照；当时 SRAM 总线 pin 解析使用实验内 `resolve_paths.py` |
| D$ 局部地址 | `build/dcache-local-address-20261017/`：原始报告、源快照、模块面积及端口/内容对照 |
| A 档与 D$/AXI | `build/area-probe-20261017/`：`A-tier-landed.md`、`equiv_check.py`、`axi_occ_probe.py`；`build/final-opt`、`build/daxi-opt`、`build/daxi-diagnose2`、`build/daxi-noD1` |

## 2. 10-11～12：寄存器 D$ 与容量缩减

范围为原生 core＋1 KiB I$＋8 KiB **寄存器 D$**＋最终排空，不含课程 AXI。各行不是同源码/同模式单变量对照。

| 版本 | 模式 | 总面积 μm² | 组合 | 时序 | SRAM | Fmax MHz | 最小周期 ns | slack ns |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| 缩容前 core＋Cache | diagnose | 71,458.562 | 42,504.709 | 28,609.867 | 343.985 | 25.21 | 39.6641 | −37.6635 |
| 紧凑 core | opt | 18,781.985 | 12,838.477 | 5,943.508 | 0 | 51.11 | 19.5645 | −17.5637 |
| 紧凑 core＋Cache | diagnose | 67,707.609 | 40,077.796 | 27,285.828 | 343.985 | 31.13 | 32.1270 | −30.1265 |
| 另一纯 core 快照 | opt | 22,079.223 | 15,169.149 | 6,910.074 | 0 | 43.93 | 22.765625 | −20.764692 |
| 对应 core＋Cache＋排空 | opt | 68,597.748 | 40,530.563 | 27,723.199 | 343.985 | 33.015218 | 30.289063 | −28.288780 |

缩容前 D$ 为 45,755.087 μm²（64.03%），69,388 个触发器计 20,570.514 μm²，占带 Cache 时序面积约 74.2%；core/BPU 含子模块为 24,558.523/8,187.807 μm²。旧 opt 最差 FlushArbiter→全局 flush→D$ 写回地址，flush 扇出 1,325、单级 INV 延迟 14.7238 ns；纯 core 最差到方向表。紧凑 cached diagnose 的 D$ 仍为 45,936.462（67.85%），最差 ROB→LSU→D$。

旧工件定位：本仓库 `build/assessment/{core,cached}/{opt,diagnose}/`、`build/assessment/capacity-current/cached/diagnose/`。旧链路含最终 dirty drain，不适用于当前 MMIO 合同。

## 3. 10-13：SRAM、valid、RAS 与 early restart

当时为 8 KiB/64 B/单路 D$，数据映射 64 个 128×8 叶宏；metadata 128×21 `{dirty,valid,tag}` 改 128×20 `{dirty,tag}`＋128 个 valid 寄存器，删除 128 拍初始化。core＋Cache 共 81 叶宏，无课程 AXI/MMIO。

| 配置 | 总面积 μm² | 最小周期 ns | Fmax MHz | slack ns | 六例几何 IPC |
|---|---:|---:|---:|---:|---:|
| valid 在 SRAM，独立 D$ | 4,601.523 | 15.3350 | 65.21 | −13.3341 | — |
| valid 在 SRAM，core＋Cache | 23,886.182 | 258.0547 | 3.875 | −256.0540 | — |
| valid 寄存器，独立 D$ | 4,698.412 | 12.9160 | 77.4233 | −10.9158 | — |
| valid 寄存器，core＋Cache 基线 | 24,550.131 | 19.9414 | 50.1469 | −17.9404 | 0.543625029 |
| 仅 RAS 瘦身 | 24,312.317 | 16.6064 | 60.2176 | −14.6058 | 0.543625029 |
| 仅 early restart 初版 | 24,475.671 | 20.7266 | 48.2473 | — | 0.547674361 |
| 仅 early restart 最终版（旧 RAS） | 24,589.410 | 23.1553 | 43.1867 | — | 0.547674361 |
| RAS＋early restart 初版 | 24,396.633 | 21.9082 | 45.6450 | — | 0.547674361 |
| 合并最终版（data mux 解耦） | 24,361.816 | 16.8418 | 59.3761 | −14.8416 | 0.547674361 |

- 旧 3.875 MHz 受初始化释放网约 16,064 扇出支配，不是 D$ 本体频率；valid 独立复位后删除该网络，无新增 false path。
- RAS depth 16 bit→默认 5 bit，减少 22 个触发器/8.340 μm²；整体差 237.814 μm² 含组合/映射变化，不能全算存储收益。
- early restart 首个合格回填拍响应，owner 留到末拍；增加应答标志，不能称自身减面积。独立最终 D$ 为 4,699.229 μm²（组合/时序/SRAM 1,252.276/587.574/2,859.378）、100.9066 MHz。
- 合并版相对基线面积 −0.7671%、Fmax＋18.4043%、IPC＋0.7449%，但 `Fmax×IPC` 比仅 RAS 版低 0.6630%；独立收益不可相加。合并版最差仍为全局 flush，单节点扇出 497/805/530；仅 RAS 版最差 ROB 选择→RAS，扇出 961。

历史验证：RAS 8 种深度 29,271 拍、33 个三 CPU 程序 13,074 拍；early restart 合并版 24 镜像三端 13,848,612 拍、27,697,224 个 70 项 pre/post 观察点一致；模块 15,435 拍、转换 6/6、RTL 回归 20/20、9 种故障注入检出。不是完整内部 SAT 或门级等价。

已丢失临时路径：`/tmp/opencode/{dcache-frontend-fixed,cached-sv2v,dcache-valid-registers,cached-valid-registers}/`、`/tmp/opencode/ras-slim-phase1/`、`/tmp/opencode/dcache-early-restart/`。合并结果曾复用 byte 相同的综合前端输出，审计为 `verified-report-reuse.json`、`factorial-ppa-final.json`，不冒称再次综合。

## 4. 10-14：同快照模块面积重建

同一 RAS 瘦身＋early restart、1 KiB I$＋8 KiB D$ 快照：sv2v 0.0.12、Yosys 0.63/ABC、OpenSTA 3.1.0；两模式源码/转换/库摘要、2 ns 和 81 叶宏一致。

| 指标 | diagnose | opt |
|---|---:|---:|
| 总面积 μm² | 26,238.262 | 24,361.816 |
| 组合 / 时序 / SRAM μm² | 15,730.114 / 7,304.784 / 3,203.364 | 14,385.138 / 6,773.314 / 3,203.364 |
| Fmax MHz / 最小周期 ns | 53.5145 / 18.6865 | 59.3761 / 16.8418 |

34 种 RTL 自身面积的完整互斥表只保留在[归档明细](_archive/module-area-20261014.md)，不再重复功能块排名。功能块 BPU 共 6,469.059 μm²，core 含子模块 20,459.750 μm²；不能再与其子模块相加。

本仓库持久工件：`build/assessment/module-area-20261014/`；`summary/` 含 `functional-blocks.csv`、`module-area-direct.csv`、`module-area-hierarchy.csv`、`module-area.json/md`，`hierarchical/cached/diagnose/` 和 `flattened/cached/opt/` 为原报告，导出器当时 6/6 测试通过。

```bash
python3 scripts/module_area.py \
  build/assessment/module-area-20261014/hierarchical/cached/diagnose/report.json \
  --flat-report build/assessment/module-area-20261014/flattened/cached/opt/report.json \
  --out build/assessment/module-area-20261014/summary
```

当前 RTL 重新综合不能宣称复现旧结果；必须使用匹配摘要的独立源码副本。Cache/BTB/四 MSHR 的其他历史 PPA 与对应 IPC 对照保留在 [experiments.md](experiments.md)。
