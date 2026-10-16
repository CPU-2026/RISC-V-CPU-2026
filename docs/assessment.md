# 综合、面积与时序评估

评估入口：`scripts/assess.py`、`verilog/assessment/student_top.sv`；D$ 单模块使用
`verilog/assessment/dcache_top.sv`。

## 课程顶层与独立范围

`make synth` 默认使用课程 `verilog/filelist.f`，评估当前 `student_top` 的 core＋I$/D$＋AXI 主机/MMIO 路径，不含外部从机。
`scripts/assess.py` 则替换为独立 assessment 顶层，用于剥离总线后的模块诊断；两者边界与可观察端口不同，不能混用结果。

```bash
make synth MODE=opt CLOCK_PERIOD_NS=2.0
make synth MODE=diagnose
make synth ABC_DRIVING_CELL=BUFx2_ASAP7_75t_R ABC_LOAD_FF=1.0
```

课程综合输出 `SYNTH_OUT/MODE/`（默认 `build/synth/opt/`），包含 `report.txt/json`、`area.json`、`timing.json`、
`timing.rpt`、`abc.constr` 和 `constraints.sdc`。默认 ABC 驱动 `INVx1_ASAP7_75t_R`、负载 5 fF；
使用驱动/负载约束并进行缓冲插入与单元尺寸优化。2 ns 是优化/检查目标，不是达标声明；slack≥0 才满足该目标。

独立 `assess.py` 范围如下，几何以当前常量为准：

| `--scope` | 电路范围 | 外部接口 |
|---|---|---|
| `core` | `rv32_core`，含预测器、前后端、执行单元和 LSU | 32 bit 逻辑取指/访存；数据放在行数据端口的低 32 bit |
| `cached` | core + I$/D$；显式 `LEGACY_HALT=1`，HALT 退休立即结束、不排空 | I$/D$ 行接口；D$ 带地址/ID 的读写独立完成 |
| `dcache` | 仅 D$ | CPU 请求/响应；独立行读/写请求、回复及写完成 |

所有内存响应及 ready 均保留为顶层输入，没有常量化。从机不进入网表。
`core/cached` 顶层保留全部提交跟踪输出，面积和接口时序包含这些可观察输出的开销。
复位为高有效 `reset`，连接到内部低有效复位；STA 设置 `reset=0`。

阵列配置见 [cache.md](cache.md#几何与-sram)：SRAM 使用课程 `sram_fakeram` 面积/时序模型，valid 寄存器计入时序面积；不得将阵列降为触发器或使用零面积 blackbox。FakeRAM 为拟合估计，不是工艺厂 SRAM 编译器结果。

旧 HALT 评估中 `drainDoneOutput=haltedOutput` 仅为兼容观察，`total=core`、`drain=0`，外存不保证包含全部退休 Store。

## 运行

在仓库根目录执行，需要 `sv2v` 和课程 AppImage：

```bash
python3 scripts/assess.py --scope core --mode opt --clock-period 2.0
python3 scripts/assess.py --scope cached --mode opt --clock-period 2.0
python3 scripts/assess.py --scope cached --mode diagnose --clock-period 2.0 --no-checkpoints
python3 scripts/assess.py --scope dcache --mode opt --clock-period 2.0 --no-checkpoints
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
含子模块面积、直接面积及总面积占比。独立 `assess.py` 诊断模式关闭 Yosys `opt_hier`，以避免
跨层次端口优化；诊断报告适合定位热点，其总面积/频率会与展平 `opt` 不同。
`Area` 含所有子模块，`Direct` 仅为实例自身；父子 inclusive 面积不可相加。
由于层次诊断的 generic/pre-ABC 快照很大，运行 diagnose 时建议使用 `--no-checkpoints`。

### 导出不重复计数的模块面积

```bash
python3 scripts/module_area.py build/assessment/cached/diagnose/report.json \
  --flat-report build/assessment/cached/opt/report.json
```

生成`module-area.md/json`、`module-area-direct.csv`、`module-area-hierarchy.csv`及
`functional-blocks.csv`（互斥功能块，包含其内部加法器/FIFO）。
direct表按原RTL模块类型合并所有参数版本/实例，仅计算各自映射单元，不包含其他RTL
子模块；SRAM宏和生成包装的接口门归入所属Cache，因此各行组合＋时序＋SRAM面积
之和严格等于diagnose总面积。hierarchy表另保留每个实例的自有/含子模块面积，不能
把其中父子inclusive列相加。可选opt比较必须具有相同源码/库摘要、工具及目标周期。
展平后的跨模块共享无法唯一分归原模块，工具不按比例将diagnose表缩放到opt总面积。

## 转换和检查

当前 RTL 使用 package、packed struct/array、结构体赋值模式，先以 `sv2v`
转换。转换副本中为模块端口的结构体模式补上声明类型，并显式指定 PRF
ROB 年龄比较的零常量类型，以绕过 `sv2v 0.0.12` 的转换限制。
生成文件将 `always_comb` 降为 `always @*`，避免条件调用 helper 中的
自动局部变量导致工具报出无用临时锁存器；最终综合网表仍必须通过
课程脚本的无锁存器、无初始化属性、无未映射单元及连线检查。

Yosys 使用相对路径读取 Unicode 工程目录中的文件，以绕过 JSON 前端对
Unicode 源路径属性的限制；`--work-dir` 可指定其他工作根目录。
工程 RTL 原文件不参与这些副本改写。

普通 `scripts/synth.py` / `make synth` 也使用同一 `scripts/sv_frontend.py`：
默认 `--frontend auto` 在 `.sv` 输入且存在 `sv2v` 时自动转换；纯 `.v` 输入保持
Yosys 原生路径。可用 `--frontend sv2v --sv2v /path/to/sv2v` 强制转换，或
`--frontend yosys` 明确选择原生解析器。Make 转发 `SV2V`；当前 Makefile 虽声明
`SYNTH_FRONTEND`，尚未将其传给脚本，强制选择解析器时直接调用 `scripts/synth.py --frontend ...`。
无 `sv2v` 时 auto 回到原生解析器，但旧 Yosys 不能处理本工程的 `import`、
结构体赋值及动态结构体数组下标；此时应安装/指定 `sv2v`，而不是手改队列 RTL。
普通综合的 `report.json` 中 `frontend` 记录转换命令、版本和生成文件 SHA-256。

前端回归含原始/转换 D$ 逐半拍端口、valid寄存器及 SRAM 全 bank 内容对拍与再次复位；综合报告的
`ram/manifest.json`、`area.sram_instances` 另验证宏配置和映射数量：

```bash
python3 -B -m unittest discover -s scripts/tests -v
```

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

STA 对顶层 `reset` 采用 `reset=0`。当前 `coreResetNInner = !reset`，不再由
DCache 初始化状态驱动；valid移至寄存器后已删除内部初始化释放网络。
旧版本由启动复位高扇出支配的 PPA 仅作历史基线；不使用新增 false path 掩盖该路径。

本评估为理想时钟、无互连寄生的综合级估计，不含布局布线影响。IPC 另由仿真测量，见 [course.md](course.md)；历史数值见 [assessment-results.md](assessment-results.md) 与 [experiments.md](experiments.md)。
