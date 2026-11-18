# 验证与综合评估

## 验证范围与测试入口

### 原六程序

| 程序 | median | multiply | vvadd | towers | qsort | rsort |
|---|---:|---:|---:|---:|---:|---:|
| 课程周期 | 7954 | 12795 | 3260 | 5843 | 162865 | 168045 |
| 架构退休数 | 6961 | 21722 | 4524 | 5278 | 139900 | 195719 |

RAS 深度 4 的保断言 sv2v 转换版通过原六，几何 IPC 为 **1.109294605**。与前生产深度 8 相比，374104 条退休记录的九个架构字段逐条一致；仅 towers 多 52 拍，其余五项完整日志相同。主树和模板的 Release、保断言构建均匹配答案、退休数及含启动和排空的课程周期；两个外部软件观察副本各 374104 条退休 PC、周期、通道与本版 RTL 对拍一致。范围限于原六，证据见[发布记录](history.md#发布记录)。

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
- 对照固定工具、库和约束，并保证 IPC 和 PPA 归属同一源码配置。合格须同时满足 **Fmax >400 MHz、面积 <36000 μm²、原六几何 IPC >1.10**，合格后以 **Fmax 最大**为目标。参数变化允许周期不同；按序核对 374104 条退休记录的九个架构字段，各自用实测周期计算 IPC。分组退化另报，不用其他组收益抵消，覆盖或身份不足标为待审。
- 保留连接、组合环、锁存与日志门禁。路径归因以同次映射网表为准，非运行敏化证明。评估结果见[时序分析](频率分析.md)。
