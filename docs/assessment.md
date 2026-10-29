# 综合评估

**当前四宽双ALU尚无有效最终面积/Fmax，正式PPA暂停。** 历史取舍和关键结果只在 [process.md](process.md) 保留，不再维护过期快照数表。

## 入口与范围

```bash
make synth MODE=opt CLOCK_PERIOD_NS=2.0
make synth MODE=diagnose
```

默认评估`verilog/filelist.f`中的完整`student_top`，含core、Cache、AXI/MMIO主机，不含外部Slave。需要课程工具包和`sv2v`；`SV2V`可指定路径。

`scripts/assess.py --scope core/cached/dcache`用于独立诊断，**不是课程整核替代品**：core适配器显式单取指、未完整观察四lane退休；cached启用旧HALT且不排空。评估前核对实际配置、端口和结束边界。

## 产物与口径

- 输出位于`SYNTH_OUT/MODE/`（默认`build/synth/opt/`）：`report.json/txt`、`area.json`、`timing.json/rpt`、`constraints.sdc`、`abc.constr`、`ram/manifest.json`。
- `opt`展平用于总PPA；`diagnose`保留层次定位热点。父子inclusive面积不可相加，也不可按比例将diagnose拆账套到opt。
- ASAP7 RVT TT＋FakeRAM为理想时钟、无寄生的综合级估计，不是布局布线实测。默认ABC驱动INVx1/负载5 fF，I/O预算各0.2 ns、不确定度0.05 ns、transition0.05 ns。
- 2 ns是检查目标，不能当作已达到500 MHz；不得新增无协议依据的false path/multicycle掩盖违例。
- 比较须匹配源码、转换、工具/库、约束与实际IPC配置，保存摘要及原始工件；丢失的旧报告不能用摘要冒充。`make clean`会删除构建目录。

## 诊断工具

```bash
python3 scripts/assessment_paths.py build/synth/opt --all-paths
python3 scripts/module_area.py build/synth/diagnose/report.json --flat-report build/synth/opt/report.json
```

关键路径以同次映射网表核验，generic检查点仅辅助定位，不把未修改模块的端点变化直接归因于局部改动。转换只改生成副本，不改生产RTL来迎合工具。

独立评估可用`--reuse-elaboration`、`--reuse-pre-abc`复用已认证检查点，要求源码/转换摘要一致；不同快照不能混用。详细参数以脚本`--help`为准。
