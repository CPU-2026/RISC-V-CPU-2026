# 原生 CPU 面积与时序基线

更新：2026-10-14（最终回归收口、模块面积重新综合）。流程和复现命令见 [assessment.md](assessment.md)。

## 2026-10-14 模块面积重新综合

当前源码新建持久工件，展平opt重新复现**24,361.816 μm²／59.3761 MHz**；保留层次
diagnose总面积**26,238.262 μm²**，各RTL模块/功能块的实际映射面积与组合/时序/SRAM
分项见[模块面积表](module-area-20261014.md)。两模式总量不能混用，不按比例猜测opt
模块面积。新网表、STA、原始输入摘要及CSV保存在`build/assessment/module-area-20261014/`。

> **旧临时工件可用性**：2026-10-14服务重启后`/tmp/opencode`已清空，下文临时路径
> 仅保留原运行定位。数值来自重启前实际综合与已返回的完成日志，不将恢复的摘要伪称
> 原始报告。上述模块统计重新生成了当前版本的持久网表/STA；旧临时路径不冒充新报告。

> **历史基线注意**：下文的 2026-10-13 valid仍在SRAM版本、2026-10-11
> 纯核心/寄存器DCache版本均不代表当前源码；只保留作旧版本对照。

## 当前合并版：RAS瘦身＋early restart（2026-10-13）

当前源码保留第一阶段RAS等价改写与第二阶段Load early restart，并将响应data选择
独立为`headNeedMemoryInner ? fillRawInner : hitRawInner`；响应valid仍用原hit/首拍资格。
有效hit不可能needMemory，有效miss响应必然needMemory，故有效载荷/响应拍数不变；
valid=0时载荷无约定。此改写避免把高扇出回填使能串入响应数据源选择，不加寄存级。

同约束core＋I$/D$比较：

| 配置 | 面积 μm² | 最小周期 ns | 估计Fmax MHz | 六例几何IPC |
|---|---:|---:|---:|---:|
| 原基线 | 24,550.131 | 19.9414 | 50.1469 | 0.543625029 |
| 仅RAS瘦身 | 24,312.317 | 16.6064 | 60.2176 | 0.543625029 |
| **仅early restart最终版（保留旧RAS）** | **24,589.410** | **23.1553** | **43.1867** | **0.547674361** |
| 仅early restart初版（历史） | 24,475.671 | 20.7266 | 48.2473 | 0.547674361 |
| 合并初版（历史） | 24,396.633 | 21.9082 | 45.6450 | 0.547674361 |
| **当前合并版（data mux解耦）** | **24,361.816** | **16.8418** | **59.3761** | **0.547674361** |

当前相对原基线面积**−0.7671%**、估计Fmax**＋18.4043%**，软件六例几何IPC
**＋0.7449%**。相对仅RAS版则面积＋0.2036%、Fmax−1.3974%；`Fmax×几何IPC`估计
吞吐代理比原基线＋19.2862%，但比仅RAS版**−0.6630%**。因此第二阶段虽提高IPC，
不意味着其独立提升物理吞吐，也不能声称优于第一阶段的全部指标。

单独early restart最终版相对原基线面积＋0.1600%、Fmax−13.8796%，最差仍为
Flush Arbiter→global flush→commitValid→旧RAS。因此第二阶段独立只证明IPC收益，
并非独立减面积或提频；合并结果也不能由两项独立PPA数值相加推算。

当前面积细分：组合14,385.138、时序6,773.314、SRAM3,203.364 μm²。2.0ns目标setup
slack **−14.8416ns**，仍未达标。全部工具/Liberty摘要、81个SRAM及理想时钟/无互连
寄生约束一致；完整输入因子审计原30项仅RAS/DCache不同，未增加false path。
这是ASAP7/FakeRAM综合估计，不是布局布线或实测频率。

初版合并的最差路径`_404786_/QN → _407273_/D`起于DCache，终于LSU；高扇出
698/972/525三级分别延迟4.7726/10.1556/4.9186ns。data选择解耦后不再为最差路径；
当前最差`_409219_/QN → _409057_/D`起止均为Flush Arbiter，经全局`imemFlushOutput`
控制，仍有497/805/530扇出，约11.83ns累计到达flush节点。未扩大到全局flush缓冲或
新增流水级改造。

独立DCache最终mux版：**4,699.229 μm²、9.9102ns、100.9066MHz**、2.0ns slack
−7.9098ns；组合1,252.276、时序587.574、SRAM2,859.378 μm²。比DCache原基线
面积＋0.01738%、Fmax＋30.3311%，65个SRAM保持；这些单模块数值不冒充整机结果。

当前报告：`/tmp/opencode/dcache-early-restart/final/cached/opt/`；最初全量综合在
`response-mux-candidate/cached/opt/`。生产源码重新sv2v转换后确认backend输入逐byte
完全一致，再复制其已完成报告（**没有冒称又做一次综合**）；原始生产摘要位于
`final/cached/assessment-opt.json`，复用证据为`verified-report-reuse.json`。关键路径
已按生产清单重新映射。初版矩阵/报告保留在`factorial-ppa-v1.json`、`early-only/`、
`combined/`，不覆盖旧证据。
最终四组合原始输入/工具/Liberty/SRAM独立审计已通过，摘要为
`/tmp/opencode/dcache-early-restart/factorial-ppa-final.json`；仅early restart最终整机
报告在`early-only-final/cached/opt/`，DCache单模块在`dcache-early-final/dcache/opt/`。

功能/周期证据：early restart初版完整三CPU24镜像13,848,612拍/27,697,224个70项
pre/post点严格一致，独立退休与实际DMEM/有效Cache比较通过，四软件构建新golden
strict通过。当前mux源码模块15,435拍一致、完整RTL20/20与转换6/6（13,487拍/822请求）
通过，实际七个early restart程序及33个RAS程序三端逐拍通过；最终mux版六IPC三端
默认strict（不放开周期）无损pre/post、退休、实际内存再次通过，报告
`/tmp/opencode/sync-sram-cpu-wb0_n_zw/report.json`；最终mux版完整24镜像默认strict
重编长跑已由补发的完成通知确认**24/24通过**，原目录`sync-sram-cpu-6efx_20o/`，
13,848,612拍／27,697,224个70项pre/post点、退休流与实际DMEM／有效Cache逐项一致，
全部新golden周期严格匹配。源码／构建记录独立于初版；未取得SAT正式等价证明。

## 第二阶段初版独立 DCache early restart（2026-10-13，历史）

第二阶段同步两软件与RTL：缺失Load在首个合格回填拍从旧512bit完整回复取字节，
按队首记录`loadResponded`，至第8拍才释放队首/消费行回复；dirty写实际完成资格保持。
首拍覆写清valid，末拍更新tag/dirty并置valid。每个Load恰好一次运输完成，取消身份
由LSU冻结owner处理；不改Store响应、ALU依赖派发、立即HALT，也不增加回填行缓冲。

独立DCache范围排除RAS变化，前后全量重建（仅DCache原始源码摘要不同），同工具/库
摘要、目标2.0ns、65个SRAM宏及拓扑；修改前数值重现valid寄存器历史报告。

| 指标 | 无early restart | 当前early restart |
|---|---:|---:|
| 总面积 | 4,698.412 μm² | **4,699.316 μm²（＋0.01924%）** |
| 组合逻辑面积 | 1,251.839 μm² | 1,252.364 μm² |
| 时序逻辑面积 | 587.195 μm² | 587.574 μm² |
| SRAM宏面积 | 2,859.378 μm² | 2,859.378 μm² |
| 估计Fmax | 77.4233 MHz | **109.5539 MHz（＋41.4999%）** |
| 最小周期 | 12.9160 ns | **9.1279 ns** |
| 2.0ns setup slack | −10.9158 ns | −7.1271 ns |

增加1个response-sent触发器，模块面积净增0.904 μm²，不能称第二阶段自身减面积。
频率改善包含响应/valid使能改写后的全局映射变化，是单模块结果，不直接当作整机频率。
理想时钟、无互连寄生、FakeRAM拟合约束保持，2.0ns仍未达成。

报告在`/tmp/opencode/dcache-early-restart/{dcache-baseline,dcache-early}/dcache/opt/`：
`report.json`、`timing.rpt`、`rtl-critical-path.txt`；原始输入及转换摘要在上一级
`assessment-opt.json`。当前模块最差路径为`_36973_/QN → responseDataOutput[30]`。

六IPC三CPU70项pre/post/退休/实际内存严格全等，几何IPC
**0.543625028725→0.547674360731（＋0.7448759%）**，五项改善、towers不变；
18 ISA＋6 IPC四软件构建均结果/退休/周期/共有统计一致，周期合计13,009,100/839,512。
模块普通/非零SRAM各15,435拍一致，新LSU＋DCache整链及七个真实CPU专项通过，九种
实际RTL负向均检出。完整24镜像三端与整机“独立early restart/合并”综合分别记录，
不能用模块频率或局部功能门禁代替整机结论，详细入口见共同父目录`sync/README.md`。

## 第一阶段单独 RAS等价瘦身 core + I$/D$（2026-10-13）

第一阶段仅修改`rv32_bpu_ras.sv`，两软件生产源码与Cache不变。内部depth由16bit收紧为
`$clog2(RAS_ENTRIES+1)`，默认16项为5bit；公开16bit端口补零。恢复从旧architectural
RAS重放存活ROB含头/边界，候选不读取提交下一态，也不受flush/commit使能控制；架构
提交与普通投机更新独立，最后按flush选择，不增加寄存级或恢复周期。

修改前源码先转换保存，再对前后两个输入分别全量综合。Yosys0.63/ABC、sv2v0.0.12、
ASAP7 RVT TT、OpenSTA3.1.0，展平opt、目标2.0ns；原始输入仅RAS文件摘要不同，工具
版本、Liberty摘要、约束及81个SRAM叶宏完全一致。新建基线重现旧报告全部PPA数值。

| 指标 | 修改前重建基线 | 当前RAS瘦身 |
|---|---:|---:|
| 总面积 | 24,550.131 μm² | **24,312.317 μm²（−0.9687%）** |
| 组合逻辑面积 | 14,565.493 μm² | 14,336.018 μm² |
| 时序逻辑面积 | 6,781.275 μm² | 6,772.935 μm² |
| SRAM宏面积 | 3,203.364 μm² | 3,203.364 μm² |
| 估计最高频率 | 50.1469 MHz | **60.2176 MHz（＋20.0823%）** |
| 最小时钟周期 | 19.9414 ns | **16.6064 ns** |
| 2.0ns目标下setup slack | −17.9404 ns | −14.6058 ns |
| RAS归属触发器数 | 1,056 | **1,034** |

面积减少237.814 μm²；22个depth触发器减少8.340 μm²，其余是组合逻辑及全局映射变化，
不能将全部面积差直接归属某一种优化。2.0ns目标仍未达成；结果为理想时钟、无互连
寄生的FakeRAM综合级估计，不是布局布线实测。

新的最差路径`_404568_/QN → _401816_/D`起于`rv32_rob`，经ROB指令读取选择网络
（保留别名`commitInstrOutput[13]`）及RAS重放，终于`rv32_bpu_ras`。它不再是旧的
Flush Arbiter→全局flush→commitValid→RAS路径，但一处NAND2节点仍有961扇出、
5.5993ns单级延迟，ROB读选择负载与RAS串联深度仍是瓶颈。

报告（前后均已映射回原始RTL）：

- `/tmp/opencode/ras-slim-phase1/baseline/cached/opt/report.json`
- `/tmp/opencode/ras-slim-phase1/candidate/cached/opt/report.json`
- 两目录下`timing.rpt`、`rtl-critical-path.txt`、`register-area-by-module.json`
- 两目录上一级`assessment-opt.json`原始输入/转换SHA-256清单

功能验证：8种深度共29,271拍，旧RTL＋独立旧顺序参考的全部槽位内容/查询逐拍一致，
三种实际RTL负向均检出；当前真实SRAM三CPU的33个RAS程序13,074拍/70项pre/post严格
一致，独立退休及实际内存/Cache检查通过；完整RTL容量/接口/整链19/19及native lint通过。
完整18 ISA＋6 IPC回归结果见`sync/README.md`的RAS第一阶段条目，未实施early restart。

## early restart前 valid 寄存器版本 DCache（2026-10-13历史基线）

`scripts/assess.py --scope dcache --mode opt --clock-period 2.0 --no-checkpoints`：
sv2v 0.0.12、Yosys 0.63/ABC、ASAP7 RVT TT、OpenSTA 3.1.0。
范围为 DCache 四项队列、16×128×32 data bank、128×20 tag/dirty SRAM 和128个
可复位valid寄存器；外存仅为顶层端口。8 bit 写粒度映射为64个 `128×8` 叶宏和
1个 `128×20` 叶宏，valid计入时序逻辑，不进入SRAM。

| 指标 | 当前 DCache |
|---|---:|
| 总面积 | **4,698.412 μm²** |
| 组合逻辑面积 | 1,251.839 μm² |
| 时序逻辑面积 | 587.195 μm² |
| SRAM 宏面积 | 2,859.378 μm² |
| 估计最高频率 | **77.423 MHz** |
| 最小时钟周期 | 12.9160 ns |
| 2.0 ns 目标下最差 setup slack | −10.9158 ns |

相比valid仍在SRAM版本，DCache面积增加96.889 μm²，周期缩短2.4189 ns；
取消128拍metadata清零扫描，三端均仅保留core的1拍boot。未新增STA false path。
最差路径为DCache控制寄存器到 `responseDataOutput[4]`，包含扇出1,030/505/522的
选择网络，不是被删除的初始化释放网。2.0 ns目标仍未达成。

报告：`/tmp/opencode/dcache-valid-registers/dcache/opt/report.json`、`timing.rpt`、
`rtl-critical-path.txt`。展开网表已核对128个valid bit均由异步复位触发器承载，
SRAM配置/叶宏数量及原始源码SHA-256均匹配。模型仍为FakeRAM拟合、理想时钟、
无互连寄生的综合级估计，不是布局布线或工艺厂SRAM实测。

当前版本检查：前端回归6/6通过（原始/转换DCache端口、128项valid与全部SRAM行
逐拍一致，含再次复位）；完整容量/接口回归19/19通过；DCache四方15,435拍/19字段
一致；七项故障注入均检出，其中新增valid未清零、忽略valid命中和提前置valid三项。
复位专项检查非零初始SRAM、全部128项valid、脏行内容保留，以及半途回填/待消费命中
复位，不以清零SRAM掩盖无效行访问。cached转换RTL的Verilator lint通过。

两软件随后也同步为128项valid寄存器与20bit tag/dirty SRAM；普通及非零SRAM初态
（tag=0/dirty=1/data=0xA5）均与RTL、独立参考15,435拍/19字段全等。两树Release/
`_DEBUG`四构建各18 ISA＋6 IPC严格匹配golden，13,041,323/844,639周期与退休/统计不变。
软件改动不影响本文RTL综合输入；新的三端24镜像整核回归另行记录，不复用旧软件验收。

## RAS瘦身前 valid 寄存器版本 core + I$/D$（2026-10-13历史基线）

`scripts/assess.py --scope cached --mode opt --clock-period 2.0 --no-checkpoints`，
与DCache单模块相同工具、库和约束。范围包含当前容量core、1 KiB ICache、8 KiB
DCache；外存留作端口，无从机、AXI适配器或HALT排空FSM，提交跟踪输出保留。
全部81个叶SRAM为64×`128×8`、1×`128×20`、16×`16×32`，总SRAM面积含I$/D$。

| 指标 | 当前 core + I$/D$ |
|---|---:|
| 总面积 | **24,550.131 μm²** |
| 组合逻辑面积 | 14,565.493 μm² |
| 时序逻辑面积 | 6,781.275 μm² |
| SRAM 宏面积 | 3,203.364 μm² |
| 估计最高频率 | **50.147 MHz** |
| 最小时钟周期 | 19.9414 ns |
| 2.0 ns 目标下最差 setup slack | −17.9404 ns |

相对valid仍在SRAM版本，面积增加663.949 μm²；该差值包含全局逻辑重构和技术映射，
不能只归因于valid触发器。初始化状态驱动的内部复位已删除，`coreResetNInner = !reset`；
最低周期由258.0547 ns降至19.9414 ns，未新增false path。2.0 ns目标仍未达成。
新的最差路径为 `_413940_/QN → _407688_/D`：起点属于 `rv32_flush_arbiter`
（D别名 `validNext[0]`），经过全局 `imemFlushOutput`、`commitValidOutput` 和
RAS恢复/更新选择网络，终点属于 `rv32_bpu_ras`，不再经过DCache初始化状态。
flush网单个INV节点的STA扇出973、延迟8.0021 ns；仍有明显高扇出及RAS组合深度瓶颈。
结果仍是无寄生、FakeRAM估计口径，非物理实现。

报告：`/tmp/opencode/cached-valid-registers/cached/opt/report.json`、`timing.rpt`、
`rtl-critical-path.txt`；
转换和输入身份清单为 `/tmp/opencode/cached-valid-registers/cached/assessment-opt.json`。
已核对叶宏配置、数量及原始RTL/转换结果/综合报告之间的SHA-256一致性；综合无残留
锁存器、初始化属性和未映射单元，STA约束覆盖检查无错误。

## valid仍在SRAM时的 DCache 单模块基线（2026-10-13，改造前）

`scripts/assess.py --scope dcache --mode opt --clock-period 2.0`，sv2v 0.0.12、
Yosys/ABC、ASAP7 RVT TT、OpenSTA。范围仅含当时 RTL DCache、四项请求队列和 17 个
SRAM 原语（16×128×32 data、1×128×21 metadata）；8 bit 写粒度将其映射为
64 个 `128×8` 叶 SRAM 与 1 个 `128×21` 叶 SRAM；行存储器由顶层接口代表。
SRAM 面积/时序采用课程 FakeRAM 拟合模型，结果是无互连寄生的综合级估计。

| 指标 | DCache 单模块结果 |
|---|---:|
| 总面积 | **4,601.523 μm²** |
| 组合逻辑面积 | 1,195.443 μm² |
| 时序逻辑面积 | 541.326 μm² |
| SRAM 宏面积 | 2,864.753 μm² |
| 估计最高频率 | **65.21 MHz** |
| 最小时钟周期 | 15.3350 ns |
| 2.0 ns 目标下最差 setup slack | −13.3341 ns |

结论只用于 DCache 模块级定位，不代表整核最高频率。关键路径落在 DCache 时序块，
含扇出约 1,000 的选择/控制网络；核心与 Cache 的联合 PPA 需另按当前 RTL 综合。
历史报告：`/tmp/opencode/dcache-frontend-fixed/dcache/opt/report.txt`、
`report.json`、`timing.rpt`；本地完整命令见 [assessment.md](assessment.md)。

## valid仍在SRAM时的 core + I$/D$ 基线（2026-10-13，改造前）

当时容量与 SRAM RTL 的 `cached` scope，展平 opt；Yosys 0.63、ABC、ASAP7 RVT TT、
OpenSTA 3.1.0，目标周期 2.0 ns。外存留作顶层接口，I$/D$ 均使用 FakeRAM 拟合宏，
提交跟踪端口保留。

| 指标 | 改造前 core + I$/D$ |
|---|---:|
| 总面积 | **23,886.182 μm²** |
| 组合逻辑面积 | 13,942.038 μm² |
| 时序逻辑面积 | 6,735.406 μm² |
| SRAM 宏面积 | 3,208.738 μm²（81 个叶宏） |
| STA 全路径估计最高频率 | 3.875 MHz |
| 最小时钟周期 | 258.0547 ns |
| 2.0 ns 目标下最差 setup slack | −256.0540 ns |

该全路径频率由**启动复位释放网络**主导，而非稳定运行的整数/Cache 数据通路：
DCache `initialized` 释放 `coreResetNInner`，再驱动 LSU 下一状态逻辑，综合网表中
该复位使能网扇出约 16,064，该综合级报告没有布局布线的复位缓冲树。这是当时
约束下的保守 worst-path 结果；在解释稳态 IPC/时钟能力前，应单独评估启动复位网的
扇出/缓冲实现，不能把 3.875 MHz 误读成 DCache 本体频率（DCache 单模块为 65.21 MHz）。

历史 core+I$/D$ 报告：`/tmp/opencode/cached-sv2v/cached/opt/report.txt`、
`report.json`、`timing.rpt`；输入源码与 sv2v 转换清单在
`/tmp/opencode/cached-sv2v/cached/assessment-opt.json`。

## 已完成的纯核心结果

`rv32_core` 独立综合，访存输入保持为外部端口，提交跟踪输出保留。
Yosys 0.63、ABC、ASAP7 RVT TT、OpenSTA 3.1.0；展平 `opt`，目标周期 2.0 ns。

| 指标 | 实测综合/STA结果 |
|---|---:|
| 核心总面积 | 22,079.223 μm² |
| 组合逻辑面积 | 15,169.149 μm² |
| 时序逻辑面积 | 6,910.074 μm² |
| SRAM 宏面积 | 0 μm²（核心不含 Cache） |
| 估计最高频率 | 43.93 MHz |
| 最小时钟周期 | 22.765625 ns |
| 2.0 ns 目标下最差 setup slack | −20.764692 ns |

报告：`build/assessment/core/opt/report.txt`、`report.json`、`timing.rpt`。
原始源码校验：`build/assessment/core/assessment-opt.json`。

## 纯核心关键路径

STA 最差路径为 `_423125_/QN → _412937_/D`。映射回源码：

- 起点来自 `rv32_flush_arbiter` 的有效状态寄存器，对应 `validNext[0]`。
- 路径经过全局 flush 控制（映射网络与 `imemFlushOutput` 互为反相）。
- 终点来自 `rv32_bpu_direction` 的时序更新块。

关键节点的扇出为 541、1,284、639，单个 OAI311 节点延迟约 12.164 ns。
该基线显示 flush/预测器更新控制的高扇出负载是当前主要频率瓶颈。
课程流程未执行布局布线、互连寄生提取或物理缓冲树优化。

`rtl-critical-path.txt` 中保留了门级节点和源码位置关联。

## 校验

- 纯核心、带缓存两种转换后的评估入口均通过 Verilator lint。
- 转换后的纯核心通过现有 `sync/core_icache_tb.sv` 测试：20 周期行返回、
  实际重命名、Store/Load、分支恢复、HALT、取指元数据与响应握手。
- 原生 RTL 的 `sync/core_dcache_chain_tb.sv` 通过 4/4 核心/DCache/行内存链：
  mixed、partial fallback、recovery、full SQ 和最终 dirty drain。
- 核心综合通过连线检查、无残留锁存器/初始化属性检查及全映射检查；STA 完成。

## 带缓存评估

带缓存范围包括原生核心、1 KiB ICache、8 KiB 寄存器 DCache 及最终排空控制。
展平 opt 已产出最终 PPA 面积/频率。此前层次综合报 AGU 空连接端口不匹配，
以及 ROB packed lookup 未驱动；删除冗余 AGU 输出端口并为 ROB lookup 加组合默认值后，
层次诊断已成功完成，端口和未驱动检查通过。

环境重启后已从工程内的展开快照恢复；新的综合会在工程目录持久保存
通用网表及 pre-ABC 检查点。包含 SRAM 的小电路已验证完整综合与 pre-ABC
恢复流程，两次面积及频率完全一致。

| 指标 | 核心 + I$/D$ + 排空控制 |
|---|---:|
| 总面积 | **68,597.748 μm²** |
| 组合逻辑面积 | 40,530.563 μm² |
| 时序逻辑面积 | 27,723.199 μm² |
| I$ SRAM 宏面积 | 343.985 μm² |
| 估计最高频率 | **33.015218 MHz** |
| 最小时钟周期 | 30.2890625 ns |
| 2.0 ns 目标下最差 setup slack | −28.288780 ns |
| 映射后叶单元数 | 624,112 |

报告：`build/assessment/cached/opt/report.txt`、`report.json`、`timing.rpt`。
源码及快照校验：`build/assessment/cached/assessment-opt.json`。

层次诊断报告：`build/assessment/cached/diagnose/report.txt`、`report.json`、
`timing.rpt`。它保留层次并关闭跨层次 `opt_hier`；表中的 `Area` 含子模块，
`Direct` 只计当前模块本身。

| 层次模块 | 面积（含子模块） | 占层次总面积 | 直接面积 |
|---|---:|---:|---:|
| `u_dmem_backend/cache`（DCache） | 45,755.087 μm² | 64.03% | 45,749.022 μm² |
| `u_core` | 24,558.523 μm² | 34.37% | 73.017 μm² |
| `u_core/u_predictor` | 8,187.807 μm² | 11.46% | 16.534 μm² |
| `u_core/u_lsu` | 3,336.939 μm² | 4.67% | 3,336.939 μm² |
| `u_core/u_prf` | 2,748.345 μm² | 3.85% | 2,748.345 μm² |
| `u_core/u_rob` | 2,724.594 μm² | 3.81% | 2,686.321 μm² |
| `u_core/u_predictor/u_ras` | 3,454.323 μm² | 4.83% | 3,454.323 μm² |
| `u_core/u_predictor/u_btb` | 3,067.078 μm² | 4.29% | 3,067.078 μm² |
| `u_core/u_predictor/u_direction` | 1,463.701 μm² | 2.05% | 1,463.701 μm² |
| `u_core/u_mul_unit` | 741.189 μm² | 1.04% | 699.257 μm² |
| `u_core/u_agu_unit` | 48.376 μm² | 0.07% | 27.454 μm² |

层次诊断合计 71,458.562 μm²、25.21 MHz；与展平 opt 的 68,597.748 μm²、
33.02 MHz 不同。保留模块边界改变了跨模块共享和逻辑重构，因此层次表用于
定位模块热点，最终 PPA 仍以展平 opt 报告为准。

相对纯核心，总面积增加 **46,518.524 μm²**。该差值包括缓存、排空控制及
跨模块优化变化，不等于 DCache 的独立模块面积。按寄存器原始源码归属统计，
DCache 有 69,388 个触发器、20,570.514 μm² 的触发器面积，占带缓存设计
时序逻辑面积约 74.2%；这是时序部分的归属统计，尚未包含 DCache 组合逻辑。
额外的触发器归属统计见 `register-area-by-module.json`。

### 带缓存关键路径

最差路径为 `_1216488_/QN → _1135829_/D`，对应：

```text
Flush Arbiter 有效位
  → 全局 flush 控制
  → 访存请求/缓存控制逻辑
  → DCache 写回地址寄存器 writeAddressInner[6]
```

- 起点的 D 输入保留了 `u_core.u_flush_arbiter.validNext[0]` 名称。
- 全局 flush 网络（顶层别名 `imemFlushOutput`）的 STA 扇出为 **1,325**，
  驱动它的 INV 单元延迟为 **14.7238 ns**。
- 后续一处扇出 **1,076** 的控制节点延迟为 **6.0526 ns**。
- 终点属于 `rv32_dcache` 的时序块，反相 Q 与 `dmemWriteAddrOutput[6]` 对应。

核心及带缓存两份结果均显示全局 flush 的高扇出是优先时序优化点。
当前 2.0 ns 目标未达成；带缓存总面积也高于计划中的 36,000 μm² 目标。
后续优化可优先分析 flush 广播负载及 DCache 的寄存器写入/选择网络。

### 最终检查

带缓存综合已通过无残留锁存器/初始化属性、连线及全标准单元映射检查；
OpenSTA 完成约束覆盖检查和最小时钟周期搜索，生成五条关键路径。
`timing_checks.rpt` 无约束错误；setup slack 为负表示未达到目标周期。
