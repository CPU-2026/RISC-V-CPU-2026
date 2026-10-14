# 当前RTL模块面积（2026-10-14重新综合）

范围为当前RAS瘦身＋DCache early restart版本的core＋1 KiB ICache＋8 KiB DCache；
外存为接口，不包含外存从机、AXI/MMIO适配器。ASAP7 RVT TT，sv2v 0.0.12、Yosys
0.63/ABC、OpenSTA 3.1.0，目标周期2.0 ns。SRAM为FakeRAM拟合估计，非工艺厂宏实测。
本次没有修改生产RTL。

## 两种综合口径

| 指标 | 保留层次diagnose | 展平优化opt |
|---|---:|---:|
| 总面积 μm² | **26,238.262** | **24,361.816** |
| 组合逻辑 μm² | 15,730.114 | 14,385.138 |
| 时序逻辑 μm² | 7,304.784 | 6,773.314 |
| SRAM μm² | 3,203.364 | 3,203.364 |
| 估计Fmax MHz | 53.5145 | 59.3761 |
| 最小周期 ns | 18.6865 | 16.8418 |

展平opt重新复现上一轮合并版面积及关键路径，是最终总面积口径。下表来自保留层次
的**实际映射网表**，不能按比例缩放到opt总面积。两次原始RTL摘要、转换结果、工具、
库摘要、2.0 ns目标及81个SRAM叶宏一致；输入/输出保留、没有新增false path。
结果为理想时钟、无互连寄生的综合级估计，不是布局布线面积。

## 功能模块面积

单位μm²。各行是互斥的功能块；执行单元/ROB包含其内部加减法器，前端包含FQ/IQ，
Cache包含SRAM及接口门。BPU分成五项，没有再把BPU总量加入表中。显示保留三位小数，
校验使用未舍入值，所有行严格覆盖完整diagnose网表。

| 功能模块 | 面积 | 占总面积 |
|---|---:|---:|
| DCache（含SRAM） | 4,635.995 | 17.67% |
| BTB | 3,067.078 | 11.69% |
| LSU（LQ/SQ/转发及请求仲裁） | 3,042.584 | 11.60% |
| ROB（含计数/Tag加法器） | 2,724.463 | 10.38% |
| PRF | 2,722.013 | 10.37% |
| 七池RS合计 | 2,307.518 | 8.79% |
| RAS | 1,735.574 | 6.61% |
| 方向预测器 | 1,463.701 | 5.58% |
| ICache（含SRAM） | 1,142.211 | 4.35% |
| RAT | 777.201 | 2.96% |
| MUL（含末级加法器） | 741.189 | 2.82% |
| 前端（含FQ/IQ） | 473.952 | 1.81% |
| DIV（含取负加法器） | 461.734 | 1.76% |
| Flush Arbiter | 216.061 | 0.82% |
| BRU及结果级 | 195.445 | 0.74% |
| GHR Checkpoint | 186.172 | 0.71% |
| ALU及结果级 | 173.269 | 0.66% |
| 顶层/core自有控制＋link PC+4加法器 | 93.939 | 0.36% |
| AGU及结果级 | 48.376 | 0.18% |
| 预测器公共选择逻辑 | 16.534 | 0.06% |
| Decoder | 13.253 | 0.05% |
| **合计** | **26,238.262** | **100%** |

BPU五项合计**6,469.059 μm²（24.66%）**。core（含BPU/后端/执行）整体
20,459.750 μm²；它与上表的core子块有重叠，仅作为层次总量，不再相加。

### 七池RS及前端细分

| RS池 | 槽数 | 面积 μm² |
|---|---:|---:|
| StoreValue | 2 | 407.919 |
| Load | 2 | 373.962 |
| StoreAddr | 2 | 373.962 |
| Branch | 2 | 371.644 |
| Integer | 2 | 371.615 |
| DIV | 1 | 204.207 |
| MUL | 1 | 204.207 |

前端自有控制251.082 μm²，FQ和IQ各111.435 μm²，合计473.952 μm²。Cache中的SRAM
分别为DCache 2,859.378 μm²、ICache 343.985 μm²，已经计入表中的Cache总面积。

## 原始报告及完整CSV

所有路径相对仓库根目录`RISC-V-CPU-2026/`，本次工件保存在构建目录，不依赖/tmp：

- [功能块CSV](../build/assessment/module-area-20261014/summary/functional-blocks.csv)：按实例选取互斥功能块，保留组合/时序/SRAM细分。
- [全部RTL模块类型CSV](../build/assessment/module-area-20261014/summary/module-area-direct.csv)：34种模块自有面积，所有参数版本/实例合计；其他RTL子模块分开列，SRAM包装归所属Cache。
- [完整实例层次CSV](../build/assessment/module-area-20261014/summary/module-area-hierarchy.csv)：每个实例的自有/含子模块面积；inclusive列不能把父子一起相加。
- [模块JSON](../build/assessment/module-area-20261014/summary/module-area.json)及[完整表](../build/assessment/module-area-20261014/summary/module-area.md)。
- [层次综合report.json](../build/assessment/module-area-20261014/hierarchical/cached/diagnose/report.json)及同目录`mapped.v`、`design.json`、`stat.json`、`timing.rpt`。
- [展平综合report.json](../build/assessment/module-area-20261014/flattened/cached/opt/report.json)及同目录网表/STA文件。
- 两目录上一级`assessment-*.json`保存30项原始输入SHA-256。

复现：

```bash
python3 scripts/assess.py --scope cached --mode diagnose --clock-period 2.0 --no-checkpoints \
  --out build/assessment/module-area-20261014/hierarchical
python3 scripts/assess.py --scope cached --mode opt --clock-period 2.0 --no-checkpoints \
  --out build/assessment/module-area-20261014/flattened
python3 scripts/module_area.py \
  build/assessment/module-area-20261014/hierarchical/cached/diagnose/report.json \
  --flat-report build/assessment/module-area-20261014/flattened/cached/opt/report.json \
  --out build/assessment/module-area-20261014/summary
```

导出器的求和、SRAM归属、重复实例、功能块及错误口径检查6/6通过，实际网表总量校验也通过。
