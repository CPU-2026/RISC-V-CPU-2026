# 验证与综合评估

## 验证范围与测试入口

下表及综合基线对应本仓库的[当前生产快照](README.md)。

### 原六程序

| 程序 | median | multiply | vvadd | towers | qsort | rsort |
|---|---:|---:|---:|---:|---:|---:|
| 当前生产实测周期 | 7924 | 12800 | 3124 | 6267 | 163030 | 168182 |
| 架构退休数 | 6961 | 21722 | 4524 | 5278 | 139900 | 195719 |

**当前生产版**的保断言 sv2v 转换模型通过原六；答案及 **374104** 条完整九字段退休与 483.703354 MHz 前生产逐周期、逐 lane 一致，几何 IPC **1.104520180**。真实 D$ 的高低组、实际读授权和无读保持通过，三个运行时故障均检出。证据 `.cpu2026-synthesis/dcache-banked-mask-production-20261123-r01/functional-audit.json`。

**474 版软件同步复验：** 主树和模板树均在重命名时将物理 `storeQueueIndex` 写入 ROB，退休时按该槽核对完整 `robTag`、活动状态及地址/数据就绪；`sqTailSnapshot` 只用于恢复。两树的 Release、断言构建均匹配原六答案与周期。两套观察构建各自与 474 RTL 逐条匹配 **374104** 次退休的 `cycle/lane/pc`；其中 **44867** 次实际退休 Store 还匹配完整 tag、SQ 槽、地址、写数据和字节掩码。

定向测试另查错槽、旧 epoch、回绕、退出 Store、D$ 槽/way 选择，以及同拍转发、写回受阻和重试。历史证据入口 `.cpu2026-synthesis/sim474-store-slot-20261120-r02/`；其中旧软件审计收据当前不在工作区，未恢复。

LQ4 采用未修改或重跑两套软件，未复验 Store 的物理 SQ 槽号和完整 tag。LQ8 采用时的 **44867** 条 Store 逐项对照仅属历史记录，不认证 LQ4 周期或槽号等价。

工作区生产指针 `sync/evidence/current-production.json` 绑定 **46** 项硬件和 **126** 项软件输入；工作树逐项匹配。**227** 个 SRAM 实例与前生产逐项一致；采用未重建模型或重跑综合。工作区证据不随单独克隆的硬件仓库提供。

### 运行入口

动态验证只运行保断言的 sv2v 转换模型；原生 SystemVerilog 只用于静态检查。在硬件仓库根用同源仿真二进制运行课程用例：

```bash
make test SIM=/path/to/converted-sim MAX_CYCLES=100000000
make perf SIM=/path/to/converted-sim MAX_CYCLES=100000000
```

构建参数与 OJ 用法见[课程说明](template.md)，历史双模型矩阵见[参数实验](参数敏感度分析.md#parameter-validation)。原六通过不代表全部课程或定向用例通过。

## 计时与事件边界

- 退出 Store 退休后冻结核心，已提交 SQ、Cache 与 AXI 排空到对应的 B 握手，不扫描全部脏行。
- 课程周期从解除复位计至退出写响应，包括启动拍、初始化、执行和排空。对拍按实际 `valid/ready/grant` 记录接受、写回和退休。
- 每项 IPC 为退休数除以课程周期，原六指标取六项几何平均。

## 综合入口与约束

使用课程工具包和 sv2v，可用 `SV2V` 指定前端路径。综合映射和 STA 统一显式使用 2.0 ns。

```bash
make synth CLOCK_PERIOD_NS=2.0 MODE=opt SYNTH_OUT="../.cpu2026-synthesis/<任务>/synthesis"
```

上例的 `<任务>` 换成实际的独立任务目录。默认清单 [`verilog/filelist.f`](../verilog/filelist.f) 包含完整 `student_top`，不含外部 Slave。`opt` 展平用于整核评估，`diagnose` 保层次用于定位。`SYNTH_OUT/MODE/` 下的主要产物为 `report.json`、`area.json`、`timing.rpt`、`constraints.sdc` 和 `ram/manifest.json`。

- 生产结果使用 ASAP7 RVT TT 与 FakeRAM。ABC 驱动 `INVx1_ASAP7_75t_R`，ABC 与 STA 输出负载均为 5 fF，I/O 延迟各 0.2 ns，不确定度与 transition 均为 0.05 ns。
- 对照固定工具、库和约束，并保证 IPC 和 PPA 归属同一源码配置。合格须同时满足 **Fmax >400 MHz、面积 <36000 μm²、原六几何 IPC >1.10**，合格后以 **Fmax 最大**为目标。参数变化允许周期不同；按序核对 374104 条退休记录的九个架构字段，各自用实测周期计算 IPC。
- 后续提频基线为 **484.619025 MHz**；同一 2.0 ns 约束和完整计时覆盖下，整核 setup 违例须 **少于 25**（每个端点只计一次）。490 MHz 仍是冲刺目标，覆盖不足标为待审。
- 保留连接、组合环、锁存与日志门禁。路径归因以同次映射网表为准，非运行敏化证明。评估结果见[时序分析](频率分析.md)。
