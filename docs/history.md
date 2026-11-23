# 项目历史

## 当前生产

**D$ 读边界 2×64 分组采样，保留 I$ 宏 WE 分离与 LQ4/SQ4：484.619025 MHz／31451.94 μm²／原六几何 IPC 1.104520180**（2.0 ns 映射及 STA）。相对前生产频率 **+0.189%**、面积 **−170.08 μm²**、setup 违例 **107→25**；仍未达 490 MHz，按用户明确授权采用。真实 D$ 与三个故障反例通过，原六 **374104 条九字段退休记录**逐周期、逐 lane 一致，完整 **27498** 端点、**227** 宏一致。收据 `.cpu2026-synthesis/dcache-banked-mask-production-20261123-r01/adoption.json`。

### 本次采用顺序

下表为同一 2.0 ns 口径下的生产快照，不等同于逐项 Git 提交。收据位于工作区 `.cpu2026-synthesis/<采用目录>/adoption.json`。

| 日期 | 采用的改动 | 估计 Fmax（MHz） | 采用目录 |
|---|---|---:|---|
| 2026-11-19 | D$ 在原写入授权下按队首预选 Store 写载荷 | 472.106962 | `ras4-store-head-production-20261119-r01` |
| 2026-11-19 | AXI 读队首切换时同拍保存缺失号 | 472.979215 | `head-txn-production-20261119-r01` |
| 2026-11-19 | AXI 写队首也同拍保存缺失号，Fmax 不变、面积下降 | 472.979215 | `write-head-txn-production-20261119-r01` |
| 2026-11-19 | Store→Load 同拍广播，按授权采用；原六未触发该旁路 | 471.454880 | `store-notify-direct-production-20261119-r01` |
| 2026-11-20 | D$ 对各物理请求槽并行比较命中标签 | 474.953618 | `dcache-tag-production-20261120-r01` |
| 2026-11-20 | ROB 退休 bank 预译码，用队首低位选择译码结果 | 475.615420 | `rob-decode-production-20261120-r02` |
| 2026-11-20 | LSU 按返回槽提前准备 Load 候选，实际回包才选通，保持同拍唤醒 | 476.057648 | `lsu-owner-production-20261120-r03` |
| 2026-11-21 | ROB 原分配拍保存两位 RAS 动作，不增加恢复拍 | 477.389277 | `ras-action-production-20261121-r03` |
| 2026-11-21 | SQ 队首预览 Store 集合，只用于取消同组旧预取；按授权采用 | 478.952292 | `store-set-preview-production-20261121-r01` |
| 2026-11-21 | RAS 由四槽改三槽，重放宽度不变；按授权采用 | 474.733426 | `ras3-production-20261121-r01` |
| 2026-11-21 | D$ 同一胜者直接选 set，槽号另路生成；按授权采用 | 478.057890 | `dcache-lookup-winner-production-20261121-r01` |
| 2026-11-21 | 寄存 ROB 全 tag 身份并行查验，保留 Load 同拍写回 | **482.563619** | `load-writeback-identity-production-20261121-r01` |
| 2026-11-22 | LQ8→4，保留 SQ 和运输深度；按授权接受时序退化 | **476.500698** | `lq4-production-20261122-r01` |
| 2026-11-22 | SQ8→4，槽号同步缩位，保留 8 个 Load 运输槽 | **477.389277** | `sq4-production-20261122-r01` |
| 2026-11-22 | AXI 写队首同拍保存完整应答地址，独立地址侧带 | **479.625293** | `axi-headaddr-production-20261122-r01` |
| 2026-11-23 | I$ 宏 WE 与逻辑握手分离，不加拍；授权例外 | **483.703354** | `icache-we-mode-production-20261123-r01` |
| 2026-11-23 | D$ 读沿分组采样、沿后选组，不加拍；授权采用 | **484.619025** | `dcache-banked-mask-production-20261123-r01` |

工作区生产指针 `sync/evidence/current-production.json` 绑定 46 项硬件、126 项软件输入。最近一次采用只安装已验证的 `rv32_dcache.sv`；发布时核对全部 46 项硬件输入，并复用同源验证与综合／STA。相对上一发布的 [476 MHz 快照 `2d28eb0`](https://github.com/CPU-2026/RISC-V-CPU-2026/tree/2d28eb063e893c0b3b1eaf117354dae5bf6299a7)，本次包含此后已采用的 RTL 和接口兼容调整，不含未采用方案或软件算法改动。

前生产 SQ4 的 490 MHz 缺口 **59**（57 个相对前生产新增），需 AXI／ALU／ROB 三锥分别再改善 **53.5／37.9／11.2 ps**。证据 `.cpu2026-synthesis/production476-sq4-ppa-20261122-r03/{result,impact-490,production-compare}.json`。

用户授权独立试 AXI 写队首同拍保存应答地址并采用：真实 AXI、3 个故障反例和原六完整退休通过；2.0 ns **479.625293 MHz／31587.07 μm²／IPC 1.104520／58 违例**，较前生产 SQ4 频率 **+0.468%**、面积 **+0.053%**、违例 **672→58**。完整覆盖、227 宏一致；490 MHz 缺口 **59→2**，均为两路 `readWayMask`。收据 `.cpu2026-synthesis/axi-headaddr-production-20261122-r01/adoption.json`，测量证据 `.cpu2026-synthesis/production476-sq4-axi-headaddr-20261122-r12/result.json`。

### 软件同步

主模拟器与模板模拟器仍沿用旧 **474 RTL** 的同步源码，未改或重跑。不复用 LQ8 采用时的 Store 槽号／tag 对拍或旧软件的周期等价结论。见[验证范围](assessment.md#原六程序)。

## 下一步

从 484.619025 MHz 生产独立核查 LSU 同拍退休 Store 的冲突判断：先算各 SQ 槽的冲突，再由实际退休授权选通。不叠加裸槽号候选；Store 位置表 4→3 暂列备选。均未建候选或综合，见[只读筛选](频率分析.md#下一步只读筛选)。

## 未采用的候选

AXI 读队首预存**回填地址**与已采用的预存**缺失号**不同，未纳入生产。`nextTag` 直取、重放对齐 XOR、RAS 写槽并行及两条一组阈值均独立测量，未采用、未叠加。实测及原因见[独立候选](频率分析.md#未采用的独立候选)。其余试验沿革见[历史时序](频率分析.md#历史生产与时序诊断)。

### 2026-11-23：490 MHz 冲刺复核

- **D$ 低六位取表用裸三位槽号（未采用）：** 原读授权、2×64 采样和高位捕获不改。独立对照 **524288** 项、真实 D$ 的 8 槽及两个故障反例通过；原六 **374104** 条九字段退休逐周期／lane 一致。2.0 ns **471.889401 MHz／31683.34 μm²／IPC 1.104520180**，违例 **25→649**，最差迁至 ROB→D$ SRAM 地址；**27498** 端点完整、**227** 宏一致。诊断与证据见[频率分析](频率分析.md#当前生产)。生产不变。

- **四宽 IQ 入队信用（未采用）：** 只改旧空位门槛与同拍出队比较。8192 项对照、717 拍四宽满 IQ 回补及两个故障反例通过；原六 374104 条九字段退休逐周期、逐 lane 一致。2.0 ns 实测 **480.525575 MHz／31667.53 μm²／IPC 1.104520180**，违例 **107→241**；27495 端点、227 宏一致。证据 `.cpu2026-synthesis/production483-iq-prefix-credit-20261123-r02/{local-exit,service-exit,result}.json`。

- **IQ 队尾路径只读定位：** 两个 D$ 候选的 IQ 退化大半在写选择前；实时掩码的共享 G35 是译码／入队计数低位，同一起终点比生产少 **228.818 ps** 余量。见[频率分析](频率分析.md#当前生产)及 `.cpu2026-synthesis/production483-iq-tail-review-20261123-r06/landmark-compare.json`。只补固定端点查询及门级核对，未改生产。

- **D$ 每槽两位实时掩码（未采用）：** 真实同组回填、victim 失效及三个故障反例通过；原六 374104 条九字段退休逐周期、逐 lane 一致。赢家每位只增两项，掩码过 490 MHz，整核为 **481.882353 MHz／31734.79 μm²／IPC 1.104520180**，2.0 ns 违例 **107→1471**，前端 IQ 限频。完整 27511 端点（新增 16 FF）、227 宏一致，只做一次映射和 STA。证据 `.cpu2026-synthesis/production483-dcache-live-mask-20261123-r05/{result,group-review,warning-review}.json`。

- **D$ 3+4 在 483 MHz 生产上复试（未采用）：** 两路掩码过 490 MHz，I$ WE 仍只驱动 16 个宏脚；整核 **471.454880 MHz／31700.51 μm²／IPC 1.104520180**，2.0 ns 违例 **107→949**，最差迁至 ROB 队首→D$ SRAM 地址。原六 374104 条九字段退休逐周期、逐 lane 一致；完整 27495 端点、227 宏，无新增告警。证据 `.cpu2026-synthesis/production483-dcache-mask34-20261123-r01/{result,focus-diagnostics,we-topology}.json`。

- **取指重载只读复核：** 三个失败映射都把 16 个 I$ 写使能脚与控制共线，479 MHz 前生产则分开。该复核提出利用 CE=0 分离宏 WE 和逻辑握手，后来独立验证并采用。见[频率分析](频率分析.md#当前生产)。

- **D$ 读掩码 3+4 位预译码（从 479 MHz 前生产独立，未采用）：** 131072 项取位对照、真实 D$ 与两个故障反例通过；原六答案、周期及 374104 条九字段退休一致。2.0 ns **412.903226 MHz／31681.06 μm²／IPC 1.104520180**，违例 **58→1936**；两路读掩码达 490 MHz，但整核改由 I$ 限频。27495 端点完整、227 宏逐实例一致；只复用映射和 STA 补收口审计。证据 `.cpu2026-synthesis/production479-dcache-mask34-20261123-r04/{result,coverage-audit}.json`。

- **D$ 脏回填只等寄存 `writeDone`（从 479 MHz 前生产独立，未采用）：** 删除同拍写应答旁路，定向碰撞与恢复旁路反例通过。原六答案及 **374104** 条九字段退休一致，IPC **1.103499503**（qsort −194 拍、rsort +1137 拍）。2.0 ns **415.415822 MHz／31562.54 μm²**，setup 违例 **58→1396**，未达目标；完整覆盖 27495 个端点、227 宏逐实例一致。重启后仅从原网表续 STA，未重映射。证据 `.cpu2026-synthesis/production479-dcache-fill-after-ack-20261123-r04/{result,coverage-audit}.json`。

- **AXI 写队首地址匹配提前寄存（从 479 MHz 前生产独立，未采用）：** 原六程序及 374104 条九字段退休记录一致，IPC 1.104520180。显式 2.0 ns 整核 **427.378965 MHz／31671.88 μm²**，违例 **58→411**、WNS/TNS **−339.511 ps／−56.822995 ns**；频率较当时生产 **−10.893%**，未达 >490 MHz／少于 58 个违例目标。覆盖审计确认 27499 个端点完整计时、寄存器身份无丢失且仅新增 4 个匹配 FF、227 个宏逐实例一致、无新增告警；最差迁至 I$ 队首→AXI 取指队列。证据 `.cpu2026-synthesis/production476-sq4-axi-matchahead-20261123-r15/{result.json,coverage-audit.json}`。

### 2026-11-22：490 MHz 冲刺

以下未采用候选以旧 **482.563619 MHz** LQ8 生产快照为基线，按 **2.0 ns** 测量。最初八项最高 **479.400749 MHz**；Store 退休授权版违例 **842→841**，但仍降频。未与 LQ4 叠加。见[490 MHz 横比与接续](频率分析.md#490-mhz-横比与接续)。

- **D$ 需求独立比年龄、预取末级放行（从 482.564 独立）：** 真实 D$ 差分与三类故障反例通过，原六周期、退休和 IPC 不变；整核 **475.615420 MHz／33849.02 μm²**，setup 违例 **842→2136**，AGU→整数 RS 限频，未采用。证据 `.cpu2026-synthesis/production482-dcache-prefetch-last-20261122-r01/result.json`。
- **后续单项：D$ 旧请求掩码改用候选行号（从 482.564 独立）：** 两个掩码局部改善 **14.441／13.608 ps**；整核 **387.585163 MHz／33899.32 μm²／IPC 1.108096761**，setup 违例 **842→2805**，I$ 队首→请求指令寄存器限频，未采用。证据 `.cpu2026-synthesis/production482-dcache-queued-mask-20261122-r05/result.json`。
- **LSU 完整转发查询复用已认证的 AGU tag（从 482.564 独立）：** 原六完整退休和周期不变。2.0 ns 整核 **473.197782 MHz／34057.49 μm²／IPC 1.108096761**，setup 违例 **842→2408**，flush→整数 RS 限频，未采用。证据 `.cpu2026-synthesis/production482-lsu-agu-full-tag-20261122-r02/result.json`。
- **D$ SRAM 使能分解（从 482.564 独立）：** 原六完整退休和周期不变。2.0 ns 整核 **461.677187 MHz／33886.33 μm²／IPC 1.108096761**，setup 违例 **842→3416**，AGU→PRF 写数据限频，未采用。证据 `.cpu2026-synthesis/production482-dcache-ce-factored-20261122-r01/result.json`。
- **RS 普通 CDB 捕获独热选数（从 482.564 独立）：** 原六完整退休和周期不变。2.0 ns 整核 **474.513438 MHz／33779.56 μm²／IPC 1.108096761**，setup 违例 **842→1729**，AGU→PRF 写数据限频，未采用。证据 `.cpu2026-synthesis/production482-rs-capture-onehot-20261122-r02/result.json`。
- **ROB 退休 bank 选行寄存（从 482.564 独立）：** 原六完整退休和周期不变。2.0 ns 整核 **474.733426 MHz／33974.96 μm²／IPC 1.108096761**，setup 违例 **842→986**，D$ SRAM 使能限频，未采用。证据 `.cpu2026-synthesis/production482-rob-commit-rowmask-20261122-r04/result.json`。
- **PRF 旧尾指针预计算回收槽（从 482.564 独立）：** 原六完整退休和周期不变。2.0 ns 整核 **479.400749 MHz／33851.84 μm²／IPC 1.108096761**，setup 违例 **842→2205**，ALU0→PRF 写数据限频，未采用。证据 `.cpu2026-synthesis/production482-prf-tail-preview-20261122-r02/result.json`。
- **Load 写回三源分别准备（从 482.564 独立）：** 原六完整退休和周期不变。2.0 ns 整核 **477.166822 MHz／33801.16 μm²／IPC 1.108096761**，setup 违例 **842→1160**，PRF 空闲表限频，未采用。证据 `.cpu2026-synthesis/production482-load-value-mask-20261122-r01/result.json`。
- **LSU 复用实际 Store 退休授权（从 482.564 独立）：** 原六完整退休和周期不变。2.0 ns 整核 **478.728378 MHz／33793.89 μm²／IPC 1.108096761**，setup 违例 **842→841**，但降频，未采用。证据 `.cpu2026-synthesis/production482-store-retire-grant-20261122-r01/result.json`。
- **StoreValue→LSU 同拍预查（从 482.564 独立）：** 原六完整退休和周期相同。2.0 ns 整核 **475.836431 MHz／33791.78 μm²／IPC 1.108096761**，setup 违例 **842→2028**，ROB→D$ 掩码限频，未采用。证据 `.cpu2026-synthesis/production482-sv-prequal-20261122-r07/result.json`。

### 其余未采用方案

- **仅 ALU1 的 ROB 存活查询用位图（从 482.564 独立）：** 原六答案、周期及 **374104** 条九字段退休不变。2.0 ns 整核 **417.448023 MHz／34003.09 μm²／IPC 1.108096761**，setup 违例 **842→1147**，新瓶颈为 I$→AXI 取指，未采用。证据 `.cpu2026-synthesis/rob-alu1-lookup-bitmap-20261122-r02/result.json`。
- **五路 ROB 存活查询统一改用位图（从 482.564 独立）：** 原六答案、周期和 **374104** 条九字段退休完全一致，IPC **1.108096761**。同口径 2.0 ns 整核 **471.672041 MHz／33792.26 μm²**，setup 违例 **842→1184**；降频且端点增加，未采用。证据 `.cpu2026-synthesis/rob-all-lookup-bitmap-20261121-r05/result.json`。
- **Load 写回包多一拍：** 原六架构退休一致，但 IPC **1.059951699**，未过门槛、未综合或采用。证据 `.cpu2026-synthesis/load-writeback-ipc-20261121-r02/result.json`。
- **恢复游标只寄存偏移高位（从 478.952 独立）：** 原六答案、周期及完整退休一致；RAS 槽 PC 违例 **120→0**，但整核仅 **428.990364 MHz／3688 个 setup 违例**，I$→预测 checkpoint 限频，未采用。证据 `.cpu2026-synthesis/recovery-offset-units-20261121-r03/result.json`。
- **D$ 读路掩码复用 SRAM 集合地址（从 477 独立）：** 原六答案、周期及完整退休一致；2.0 ns 整核 **400.000000 MHz／3868 个 setup 违例端点**，I$ 限频，未采用。证据 `.cpu2026-synthesis/dcache-waymask-shared-set-20261121-r04/result.json`。
- **LSU 按 SQ 物理槽判断 Store 退休资格（从 477 独立）：** 原六答案、周期及完整退休一致；2.0 ns 整核 **470.156107 MHz／2600 个 setup 违例端点**，D$ 地址限频，未采用。证据 `.cpu2026-synthesis/lsu-commit-row-20261121-r02/result.json`。
- **RAS 末两路、四槽写入前瞻：** 原六对拍通过，2.0 ns 整核 **467.579909 MHz／3024 个 setup 违例端点**，D$ 地址成为瓶颈，未采用。
- **RAS 第 2 路三位输出深度：** 原六完整退休和周期一致，2.0 ns 整核 **472.760849 MHz／3279 个 setup 违例端点**，PRF 数据成为瓶颈，未采用。
- **RAS 第 2 路输出深度仅位 1：** 原六完整退休和周期一致，2.0 ns 整核 **476.057648 MHz／2562 个 setup 违例端点**，全 FF 对应，未采用。
- **ROB 物理行组合预译码：** 原六完整退休和周期一致，2.0 ns 整核 **468.221308 MHz／3759 个 setup 违例端点**，D$ 地址成为瓶颈，未采用。

## 早期沿革

- **2026-11-07～17：** 四指令取指允许跨 16 B 边界；形成 ROB16／PRF48／8 KiB D$ 配置和双队列反向信用；Load／StoreAddr 采用选择性晚唤醒、Load 独占一路 CDB，Branch 不用 Load 同拍旁路派发。[参数实验](参数敏感度分析.md)
- **2026-11-18：** LSU 调度摘要 H 替换 B；S 在 H 上前移 SQ 扫描。W8 将每拍恢复宽度由 4 槽增至 8 槽；随后采用八路 RAS 组合重放。深度 8 生产源码及同一 RTL 不同映射目标的结果，见[历史测量](频率分析.md#历史测量对照25-ns-映射)。
- **2026-11-19：** RAS 从 8 槽减至 4 槽，恢复宽度仍为 8；两套软件同步。2.0 ns 映射估计 Fmax **455.313473 MHz**。采用收据 `.cpu2026-synthesis/ras4-production-20261119-r01/adoption.json`。

## 证据边界

工作区 `sync/`、实验产物和两个软件仓库不随本硬件仓库克隆提供。旧方案见[历史提交](https://github.com/CPU-2026/RISC-V-CPU-2026/blob/0c9ba970ac4ed233e52c1bbe2e06c29f0ffb8c24/docs/history.md)；缺失的原始日志、网表和检查点不能凭摘要重审。

**清理前的生产证据入口（2026-11-22）。** `sync/evidence/current-production.json` 的 SHA-256 为 `f23cc4125a787aff24ad115da725331d20acf565a6706efd405f473648f92917`。以下路径相对 `.cpu2026-synthesis/`，记录时均在：

| 用途 | 入口 |
|---|---|
| 采用收据 | `load-writeback-identity-production-20261121-r01/adoption.json` |
| 功能审计、源快照与原六退休日志 | `load-writeback-ipc-20261121-r01/identity/` |
| 2.0 ns 综合输入、网表与报告 | `load-writeback-identity-ppa-20261121-r01/01-identity/` |
| 完整 STA 端点表及收据 | `load-writeback-identity-ppa-20261121-r02/endpoints-candidate/` |
| 本轮同端点横比与待测切点 | `production482-490-round-review-20261122-r01/{summary,queued-mask-index}.json` |

若要保留可复核的生产基线，需连同指针和各收据引用的原始文件保留；这张表只是证据入口。清理后缺失的产物只记为历史测量，不把摘要或后来重建的产物当原始证据。

**2026-11-22 清理完成。** 按授权仅清理 `.cpu2026-synthesis/`，保留当前生产、本轮八个完整综合版本及必要依赖。删除 **4302** 个文件或软链接、**176** 个目录（含 **14** 个顶层目录）；F 盘可用空间 **43.19→50.80 GiB**。清理后 **253** 项关键 SHA-256 一致；清点时已缺的 **10** 条历史引用保留记录，不补写旧证书。清单与收据：`.cpu2026-synthesis/production482-490-round-review-20261122-r01/cleanup-{plan,completion}-20261122.json`。
