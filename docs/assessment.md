# 验证与综合评估

## 验证范围与测试入口

### 原六程序

| 程序 | median | multiply | vvadd | towers | qsort | rsort |
|---|---:|---:|---:|---:|---:|---:|
| 课程周期 | 7954 | 12795 | 3260 | 5843 | 162865 | 168045 |
| 架构退休数 | 6961 | 21722 | 4524 | 5278 | 139900 | 195719 |

**476 生产版**的保断言 sv2v 转换模型通过原六，几何 IPC 为 **1.109294605**。六项答案、周期及 **374104** 条完整九字段退休记录与 475、474 RTL 和 455 MHz 提交基线一致。真实 LSU 检查覆盖 18 种同拍转发／回包仲裁情形及取消后的槽复用，检出了错误优先级和丢失取消的两个反例。证据 `.cpu2026-synthesis/axi-alu1-from475-20261120-r02/02-lsu-owner-candidate/{local,independent-audit}.json`。

**474 版软件同步复验：** 主树和模板树均在重命名时将物理 `storeQueueIndex` 写入 ROB，退休时按该槽核对完整 `robTag`、活动状态及地址/数据就绪；`sqTailSnapshot` 只用于恢复。两树的 Release、断言构建均匹配原六答案与周期。两套观察构建各自与 474 RTL 逐条匹配 **374104** 次退休的 `cycle/lane/pc`；其中 **44867** 次实际退休 Store 还匹配完整 tag、SQ 槽、地址、写数据和字节掩码。

定向测试另查错槽、旧 epoch、回绕、退出 Store、D$ 槽/way 选择，以及转发值与回包冲突时的写回和重试。同拍修订 Load 地址、写回受阻的用例在两树旧保存逻辑上均被检出。证据 `.cpu2026-synthesis/sim474-store-slot-20261120-r02/{software-audit,directed,completion}.json`。

475 和 476 版采用时均未修改或重跑软件。476 RTL 另录的 **44867** 条 Store 槽号／完整 tag 记录与 475、474 RTL 逐条一致，结合完整 RTL 退休日志复用上述软件对拍。证据 `.cpu2026-synthesis/lsu-owner-production-20261120-r03/slots/comparison.json`。

提交前核对：工作区生产指针 `sync/evidence/current-production.json` 绑定 **46** 项硬件和 **126** 项软件输入；当前工作树逐项匹配。228 个 SRAM 实例与 475 版一致。本次整理复用现有结果，未重跑仿真或综合；工作区证据不随单独克隆的硬件仓库提供。

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
- 后续提频需超过实际生产 Fmax。在同一 2.0 ns 约束、完整计时覆盖下，整核 setup **违例端点数必须少于当前生产的 2003**，每端点只计一次。分组和单端点退化只作诊断；覆盖不足标为待审。这一规则不追改历史采用记录。
- 保留连接、组合环、锁存与日志门禁。路径归因以同次映射网表为准，非运行敏化证明。评估结果见[时序分析](频率分析.md)。
