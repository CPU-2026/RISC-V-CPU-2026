# 性能指标与综合评估

## 已采用版本的认证结果

2026-11-07跨16B四取指的[正式指针](../../sync/evidence/current-production.json)与[独立PPA收口](../../sync/evidence/fetch4-cross16-ppa-20261107-r01/finalization.json)记录如下。**这些指标只认证当次源码，不自动覆盖后续参数化工作树。**

| 指标 | 认证值 | 相对上一双取指生产 |
|---|---:|---:|
| 面积 | 34947.061567 μm² | +0.713718% |
| Fmax估计 | 319.301528 MHz | +0.997817% |
| 原六项几何IPC | 1.137201912621 | +6.947322% |
| 评分 `IPC^4 / Area^2 × Fmax` | 4.372501753378e-7 | +30.260993% |

面积 **<36000 μm²**、Fmax **>300 MHz**、几何IPC **>1.0985** 均通过。IPC×Fmax估算+8.014461%，不是墙钟实测；qsort多614拍，其余五项改善，详见[周期对照](process.md#四取指边界对照)。Fmax不是后布局频率，整体达标也不表示每项IPC均超过1.0985。

## 入口与范围

**全部综合／ABC／STA仍暂停；以下仅为另获授权后的用法，本次未执行。** 在硬件仓库根运行，需要课程工具包与`sv2v`（可用`SV2V`指定路径）：

```bash
make synth MODE=opt CLOCK_PERIOD_NS=2.0 SYNTH_OUT="../.cpu2026-synthesis/<新任务>/synthesis"
make synth MODE=diagnose SYNTH_OUT="../.cpu2026-synthesis/<新诊断任务>/synthesis"
```

- 默认评估`verilog/filelist.f`中的完整`student_top`，含core、Cache、AXI/MMIO主机，**不含外部Slave**。
- `opt`展平用于整核PPA，`diagnose`保留层次定位热点；父子inclusive面积不可相加，diagnose拆账不能按比例套到opt。
- `scripts/assess.py --scope core/cached/dcache`仅作独立诊断：core适配器显式单取指且未完整观察四lane退休，cached使用旧HALT且不排空，不能替代课程整核。

## 产物与比较口径

- 产物位于`SYNTH_OUT/MODE/`：`report.json/txt`、`area.json`、`timing.json/rpt`、`constraints.sdc`、`abc.constr`、`ram/manifest.json`。Makefile未指定时默认`build/synth/`；新实验统一放F盘`.cpu2026-synthesis/`，临时目录使用工作区`sync/experiment_storage.py`配置。
- ASAP7 RVT TT＋FakeRAM、理想时钟／无寄生；ABC驱动INVx1、负载5 fF，I/O预算各0.2 ns，不确定度及transition各0.05 ns。2 ns是目标，不代表达到500 MHz。
- 比较必须匹配源码、转换、工具／库、约束、IPC配置及结束协议；不得拼接不同快照的面积／频率／IPC，或用无协议依据的false path／multicycle掩盖违例。
- 保存认证输入、原始工件和摘要。历史报告已删时不能宣称仍可重审；`make clean`会删除构建目录、配置的综合输出及`code`，不要用它清理需保留的证据。

## 只读诊断

将下列占位路径替换为已有任务目录，不会启动新综合：

```bash
python3 scripts/assessment_paths.py <已有任务>/synthesis/opt --all-paths
python3 scripts/module_area.py <已有任务>/synthesis/diagnose/report.json --flat-report <已有任务>/synthesis/opt/report.json
```

关键路径须由同次映射网表核验；generic检查点仅辅助定位，不是逐门STA归因或可敏化证明。转换只改生成副本。独立诊断的`--reuse-elaboration`／`--reuse-pre-abc`要求源码与转换摘要一致；正式全新测量是否允许复用另按任务授权，不混用快照。
