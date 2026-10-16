# 历史面积与时序记录

**所有结果均为各自源码快照的历史测量，不代表当前寄存器 BTB＋课程 AXI/MMIO 顶层。**
方法见 [assessment.md](assessment.md)，参数实验见 [experiments.md](experiments.md)，决策过程见 [process.md](process.md)。

统一限制：ASAP7 RVT TT / FakeRAM 拟合模型、Yosys/ABC、OpenSTA，默认目标 2 ns，理想时钟、无互连寄生；
Fmax 是综合级估计，不是布局布线或芯片实测。`opt` 与保留层次的 `diagnose` 不能混用或按比例换算模块面积。
旧临时工件在 2026-10-14 服务重启后已丢失；临时路径仅保留运行定位，不冒充仍可获得的原始报告。
持久 `build/` 也未纳入 Git，需自行保存工件。

## 2026-10-11～12：寄存器 DCache 与容量缩减

当时范围为原生 core、1 KiB I$、8 KiB **寄存器 D$** 与最终排空逻辑，不含课程 AXI 主机/从机。

| 范围 / 版本 | 模式 | 面积 μm² | 组合 | 时序 | SRAM | Fmax MHz | 最小周期 ns | 2 ns slack ns |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| 缩容前 core＋Cache | diagnose | 71,458.562 | 42,504.709 | 28,609.867 | 343.985 | 25.21 | 39.6641 | −37.6635 |
| 紧凑 core（10-12） | opt | 18,781.985 | 12,838.477 | 5,943.508 | 0 | 51.11 | 19.5645 | −17.5637 |
| 紧凑 core＋Cache（10-12） | diagnose | 67,707.609 | 40,077.796 | 27,285.828 | 343.985 | 31.13 | 32.1270 | −30.1265 |
| 另一纯核心快照 | opt | 22,079.223 | 15,169.149 | 6,910.074 | 0 | 43.93 | 22.765625 | −20.764692 |
| 对应 core＋Cache＋排空 | opt | 68,597.748 | 40,530.563 | 27,723.199 | 343.985 | 33.015218 | 30.2890625 | −28.288780 |

这些不是同一源码/同一优化模式的单变量比较。缩容前 diagnose 的主要层次面积如下；父子含子模块面积有重叠，不可整列相加：

| 模块 | 含子模块 μm² | 直接 μm² |
|---|---:|---:|
| DCache backend | 45,757.522 | 2.435 |
| DCache | 45,755.087 | 45,749.022 |
| ICache | 1,142.211 | 796.549 |
| ICache 数据/宏接口 | 345.662 | 345.662 |
| core | 24,558.523 | 73.017 |
| BPU | 8,187.807 | 16.534 |
| BTB | 3,067.078 | 3,067.078 |
| RAS | 3,454.323 | 3,454.323 |
| 方向预测 | 1,463.701 | 1,463.701 |
| Checkpoint | 186.172 | 186.172 |
| 前端（含 FQ/IQ 各 205.097） | 661.276 | 251.082 |
| Decoder | 13.253 | 13.253 |
| RAT | 777.201 | 777.201 |
| PRF | 2,748.345 | 2,748.345 |
| ROB | 2,724.594 | 2,686.321 |
| LSU | 3,336.939 | 3,336.939 |
| Integer / Multiply / Divide RS | 683.831 / 371.615 / 204.207 | 同左 |
| Branch / Load / StoreAddr RS | 688.468 / 694.198 / 694.198 | 同左 |
| StoreValue RS | 838.671 | 838.671 |
| ALU 单元 / 内部 ALU | 173.269 / 138.787 | 34.482 / 74.664 |
| MUL / DIV / BRU / AGU | 741.189 / 461.734 / 196.232 / 48.376 | 699.257 / 417.003 / 98.984 / 27.454 |
| Flush Arbiter / link 加法器 | 219.225 / 20.879 | 219.225 / 0 |

DCache 占旧 diagnose 面积 64.03%，归属触发器 69,388 个、20,570.514 μm²，占带缓存时序面积约 74.2%。
旧 opt 最差路径为 Flush Arbiter→全局 flush→DCache 写回地址；flush 扇出 1,325、单级 INV 延迟 14.7238 ns。
纯核心最差为 Flush Arbiter→全局 flush→方向表更新，关键节点扇出 541/1,284/639。
紧凑缓存 diagnose 中 DCache 为 45,936.462 μm²（67.85%），core 小计 20,626.195、BPU 小计 6,667.609（已含在 core）；最差 ROB→LSU→DCache。

工件定位：`build/assessment/{core,cached}/{opt,diagnose}/`、
`build/assessment/capacity-current/cached/diagnose/`。旧 SRAM 改造前的链路测试曾包含最终 dirty drain，不能用于当前 MMIO 合同。

## 2026-10-13：SRAM、valid 寄存器、RAS 与 early restart

当时 D$ 为 8 KiB/64 B/单路；16 个 128×32 data bank 按 byte 写粒度映射为 64 个 128×8 叶宏。
metadata 从 128×21 `{dirty, valid, tag}` 改为 128×20 `{dirty, tag}` SRAM＋128 个可复位 valid 寄存器，取消 128 拍初始化扫描。
core＋Cache 共 81 个叶宏，外存仅为接口；无课程 AXI/MMIO。

| 配置 | 面积 μm² | 最小周期 ns | Fmax MHz | 2 ns slack ns | 六例几何 IPC |
|---|---:|---:|---:|---:|---:|
| valid 仍在 SRAM，独立 D$ | 4,601.523 | 15.3350 | 65.21 | −13.3341 | — |
| valid 仍在 SRAM，core＋Cache | 23,886.182 | 258.0547 | 3.875 | −256.0540 | — |
| valid 寄存器，独立 D$ | 4,698.412 | 12.9160 | 77.4233 | −10.9158 | — |
| valid 寄存器，core＋Cache 基线 | 24,550.131 | 19.9414 | 50.1469 | −17.9404 | 0.543625029 |
| 仅 RAS 瘦身 | 24,312.317 | 16.6064 | 60.2176 | −14.6058 | 0.543625029 |
| 仅 early restart 初版 | 24,475.671 | 20.7266 | 48.2473 | — | 0.547674361 |
| 仅 early restart 最终版（旧 RAS） | 24,589.410 | 23.1553 | 43.1867 | — | 0.547674361 |
| RAS＋early restart 合并初版 | 24,396.633 | 21.9082 | 45.6450 | — | 0.547674361 |
| 合并最终版（响应 data mux 解耦） | 24,361.816 | 16.8418 | 59.3761 | −14.8416 | 0.547674361 |

面积分项（组合 / 时序 / SRAM，μm²）：

| 配置 | 组合 | 时序 | SRAM |
|---|---:|---:|---:|
| valid 在 SRAM，D$ | 1,195.443 | 541.326 | 2,864.753 |
| valid 在 SRAM，core＋Cache | 13,942.038 | 6,735.406 | 3,208.738 |
| valid 寄存器，D$ | 1,251.839 | 587.195 | 2,859.378 |
| valid 寄存器，core＋Cache | 14,565.493 | 6,781.275 | 3,203.364 |
| 仅 RAS | 14,336.018 | 6,772.935 | 3,203.364 |
| 合并最终版 | 14,385.138 | 6,773.314 | 3,203.364 |

- 旧 3.875 MHz 被初始化释放网支配（扇出约 16,064），不是 D$ 本体频率；valid 独立复位后删除该网络，没有新增 false path。
- RAS depth 从 16 bit 收紧为 `$clog2(RAS_ENTRIES+1)`（默认 5 bit），恢复从旧已提交栈重放存活 ROB；不增加恢复拍数。减少 22 个 depth 触发器、8.340 μm²，整体面积差 237.814 μm² 还包含组合/全局映射变化。
- early restart 在首个合格回填拍返回 Load，owner 保留到第 8 拍；增加一次应答标志，不能称自身减面积。独立 D$ 初版为 4,699.316 μm² / 109.5539 MHz；最终 mux 版为 4,699.229 μm² / 100.9066 MHz、9.9102 ns、slack −7.9098 ns，分项 1,252.276 / 587.574 / 2,859.378。
- 最终 data mux 依据 `needMemory` 选整行回复/命中数据，valid 使用原服务资格，解耦高扇出 fill 使能，不新增寄存级。合并版相对基线面积 −0.7671%、Fmax＋18.4043%、IPC＋0.7449%；吞吐代理 `Fmax×IPC` 比仅 RAS 版仍低 0.6630%，不能将两项独立收益相加。
- 合并最终版最差路径仍在 Flush Arbiter，经全局 flush 的 497/805/530 扇出网络；仅 RAS 版最差为 ROB 读选择→RAS，单节点扇出 961。

验证记录：RAS 8 种深度共 29,271 拍、33 个三 CPU 程序共 13,074 拍；early restart 最终合并版 24 镜像三端
13,848,612 拍、27,697,224 个 70 项 pre/post 观察点、独立退休/实际 DMEM/有效 Cache 相同。
模块普通/非零 SRAM 15,435 拍、原始/转换前端 6/6、RTL 回归 20/20、9 种故障注入检出。
这些是指定观察点和输入域证据，未取得完整内部状态 SAT 或门级等价证明。

旧运行定位（均在已丢失临时目录）：
`/tmp/opencode/{dcache-frontend-fixed,cached-sv2v,dcache-valid-registers,cached-valid-registers}/`、
`/tmp/opencode/ras-slim-phase1/{baseline,candidate}/cached/opt/`、
`/tmp/opencode/dcache-early-restart/{final,early-only-final,dcache-early-final}/`。
原合并结果曾复用 byte 相同的综合前端输出，未冒称再次综合；其审计文件为 `verified-report-reuse.json`、`factorial-ppa-final.json`。

## 2026-10-14：模块面积重新综合

同一 RAS 瘦身＋early restart / 1 KiB I$＋8 KiB D$ 快照重新生成持久工件，sv2v 0.0.12、Yosys 0.63/ABC、OpenSTA 3.1.0。
两模式原始源码、转换、工具/库摘要、2 ns 目标及 81 个叶宏一致，输入/输出保留、无新增 false path。

| 指标 | diagnose | opt |
|---|---:|---:|
| 总面积 μm² | 26,238.262 | 24,361.816 |
| 组合 μm² | 15,730.114 | 14,385.138 |
| 时序 μm² | 7,304.784 | 6,773.314 |
| SRAM μm² | 3,203.364 | 3,203.364 |
| Fmax MHz | 53.5145 | 59.3761 |
| 最小周期 ns | 18.6865 | 16.8418 |

下面是 diagnose 实际映射网表的**互斥功能块**，不是推算的 opt 模块面积；内部加法器/FIFO/SRAM 已归属相应模块：

| 功能模块 | 面积 μm² | 占总面积 |
|---|---:|---:|
| DCache（含 SRAM） | 4,635.995 | 17.67% |
| BTB | 3,067.078 | 11.69% |
| LSU | 3,042.584 | 11.60% |
| ROB | 2,724.463 | 10.38% |
| PRF | 2,722.013 | 10.37% |
| 七池 RS | 2,307.518 | 8.79% |
| RAS | 1,735.574 | 6.61% |
| 方向预测器 | 1,463.701 | 5.58% |
| ICache（含 SRAM） | 1,142.211 | 4.35% |
| RAT | 777.201 | 2.96% |
| MUL | 741.189 | 2.82% |
| 前端（含 FQ/IQ） | 473.952 | 1.81% |
| DIV | 461.734 | 1.76% |
| Flush Arbiter | 216.061 | 0.82% |
| BRU | 195.445 | 0.74% |
| GHR Checkpoint | 186.172 | 0.71% |
| ALU | 173.269 | 0.66% |
| 顶层/core 自有控制＋link PC+4 | 93.939 | 0.36% |
| AGU | 48.376 | 0.18% |
| 预测器公共选择 | 16.534 | 0.06% |
| Decoder | 13.253 | 0.05% |
| **合计** | **26,238.262** | **100%** |

BPU 五项合计 6,469.059 μm²（24.66%）；core 含子模块为 20,459.750 μm²，不再加进互斥表。
RS 细分：StoreValue2 407.919、Load2 373.962、StoreAddr2 373.962、Branch2 371.644、Integer2 371.615、DIV1/MUL1 各 204.207 μm²。
前端自有 251.082、FQ/IQ 各 111.435；D$/I$ SRAM 分别 2,859.378 / 343.985，均已计入对应总量。

工件根目录：`build/assessment/module-area-20261014/`。
`summary/` 下保存 `functional-blocks.csv`、`module-area-direct.csv`（34 种 RTL 自有面积）、
`module-area-hierarchy.csv`、`module-area.json/md`；层次/展平报告分别为
`hierarchical/cached/diagnose/`、`flattened/cached/opt/`，上一级有 `assessment-*.json` 输入摘要。
导出器求和、SRAM 归属、重复实例、功能块及错误口径测试当时 6/6 通过。

```bash
python3 scripts/module_area.py \
  build/assessment/module-area-20261014/hierarchical/cached/diagnose/report.json \
  --flat-report build/assessment/module-area-20261014/flattened/cached/opt/report.json \
  --out build/assessment/module-area-20261014/summary
```

用当前 RTL 重新执行综合会得到当前快照结果，不能宣称复现上述旧源码，除非先恢复匹配摘要的独立实验副本。
