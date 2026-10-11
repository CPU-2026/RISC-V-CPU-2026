# 无外部从机的面积与时序评估

评估入口：`scripts/assess.py`、`verilog/assessment/student_top.sv`。

## 范围

| `--scope` | 电路范围 | 外部接口 |
|---|---|---|
| `core` | `rv32_core`，含预测器、前后端、执行单元和 LSU | 32 bit 逻辑取指/访存；数据放在行数据端口的低 32 bit |
| `cached` | core + 1 KiB ICache + 8 KiB DCache + 最终排空控制 | 64 B 内存行；I$ 回填附带行地址，D$ 读写通道独立 |

所有内存响应及 ready 均保留为顶层输入，没有常量化。从机不进入网表。
顶层保留全部提交跟踪输出，面积和接口时序包含这些可观察输出的开销。
复位为高有效 `reset`，连接到内部低有效复位；STA 设置 `reset=0`。

I$ 数据使用课程 `sram_fakeram` 面积/时序模型。D$ 按当前 RTL 使用
寄存器数组，计入标准单元面积，不按 SRAM 宏折算。

## 运行

在仓库根目录执行，需要 `sv2v` 和课程 AppImage：

```bash
python3 scripts/assess.py --scope core --mode opt --clock-period 2.0
python3 scripts/assess.py --scope cached --mode opt --clock-period 2.0
python3 scripts/assess.py --scope cached --mode diagnose --clock-period 2.0 --no-checkpoints
```

长任务可附加 `--background`；启动时输出 PID 和 `build/assessment/<scope>/job-<mode>.log`。
前台模式每 30 秒输出当前阶段；后台模式将这些进度写入上述 job 日志。
同一 scope 的评估应顺序执行；若需并行使用不同的 `--work-dir`。

切换模式时可复用已经完成的 RTL 展开，脚本会核对原始源码及转换结果的 SHA-256：

```bash
python3 scripts/assess.py --scope cached --mode opt \
  --reuse-elaboration build/assessment/cached/diagnose/elaborated.json
```

综合自动保存 `generic.json` 与 `pre-abc.json` 检查点。若在 ABC 阶段中断，可直接恢复：

```bash
python3 scripts/assess.py --scope cached --mode opt \
  --reuse-elaboration build/assessment/cached/opt/elaborated.json \
  --reuse-pre-abc build/assessment/cached/opt/pre-abc.json
```

结果写入 `build/assessment/<scope>/<mode>/`：

- `report.txt` / `report.json`：面积、最高频率、最小时钟周期、slack；
- `timing.rpt` / `critical_paths.json`：关键路径；
- `mapped.v` / `design.json`：映射后的电路；
- `constraints.sdc` / `timing_checks.rpt`：实际约束及覆盖检查；
- `ram/manifest.json`：SRAM 实例与模型；
- 上一级 `assessment-<mode>.json`：原始源码 SHA-256、转换方式与工具版本。

`opt` 是最终展平优化的 PPA 数值来源；`diagnose` 保留模块层次，输出每个模块
含子模块面积、直接面积及总面积占比。诊断模式关闭 Yosys `opt_hier`，以避免
跨层次端口优化；当前 ROB 输出默认赋零且 AGU 原始有效位端口已删除，未驱动
输出检查已通过。诊断报告适合定位热点，其总面积/频率会与展平 `opt` 不同。
由于层次诊断的 generic/pre-ABC 快照很大，运行 diagnose 时建议使用 `--no-checkpoints`。

## 转换和检查

当前 RTL 使用 package、packed struct/array、结构体赋值模式，先以 `sv2v`
转换。转换副本中为模块端口的结构体模式补上声明类型，并显式指定 PRF
ROB 年龄比较的零常量类型，以绕过 `sv2v 0.0.12` 的转换限制。
生成文件将 `always_comb` 降为 `always @*`，避免条件调用 helper 中的
自动局部变量导致工具报出无用临时锁存器；最终综合网表仍必须通过
课程脚本的无锁存器、无初始化属性、无未映射单元及连线检查。

工具默认直接在 `build/assessment/<scope>/` 工作，检查点可跨运行环境重启保存。
Yosys 使用相对路径读取 Unicode 工程目录中的文件，以绕过 JSON 前端对
Unicode 源路径属性的限制；`--work-dir` 可指定其他工作根目录。
工程 RTL 原文件不参与这些副本改写。

`python3 scripts/assessment_paths.py build/assessment/core/opt` 可将关键路径
与保留下来的 RTL 网络名及源码位置关联，并生成 `rtl-critical-path.txt`。

只准备转换文件、检查综合入口：

```bash
python3 scripts/assess.py --scope core --prepare-only
verilator --lint-only --top-module student_top -DSYNTHESIS \
  -Wno-fatal -Wno-WIDTH --unroll-count 1024 \
  build/assessment/core/converted.v
```

## 结果口径

沿用课程 ASAP7 RVT TT 库与 OpenSTA 约束：输入/输出预算各 0.2 ns，
时钟不确定度 0.05 ns，输入/时钟 transition 0.05 ns，输出负载 5 fF。
`--clock-period 2.0` 是 500 MHz 优化和检查目标，最高频率由关键路径分析求得。

本评估为理想时钟、无互连寄生参数的综合级估计，尚未包含 AXI 适配器、
总线仲裁、课程 MMIO 退出逻辑，以及布局布线后的影响。程序周期数和 IPC
由另一个仿真流程测量。
