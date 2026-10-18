# 架构实验记录（历史快照）

记录容量、Cache、BTB 和恢复协议的功能/IPC 对照；决策脉络见 [process.md](process.md)，完整课程顶层 PPA 见 [assessment-results.md](assessment-results.md)。各节注明实验边界，不同 Cache、预测管线、退出方式或外存模型不得混作单变量对照。原始报告位于未纳入 Git 的 `build/`，不保证随克隆提供。

## 1. 核心容量软件消融

固定 ROB16、PRF48、LQ/SQ8、DIV RS1 与当时 Cache 几何，以软件状态对象 `sizeof` 之和为容量代理，**不是 ASIC 面积**。
在同级软件主树/模板私有副本筛选后同步了紧凑容量，18 ISA＋6 IPC 结果/退休数及两树周期一致；周期不要求等于旧基线。

| 容量方案 | 主树代理 | 模板代理 | 六项几何 IPC（两树相同） |
|---|---:|---:|---:|
| FQ/IQ4，RAS32，RS=4/2/1/4/4/4/4 | 4,732 B | 21,208 B | 0.635113 |
| RS 半容量：2/1/1/2/2/2/2 | 4,432 B | 20,080 B | 0.612731 |
| 再改 RAS16、FQ/IQ2 | 4,176 B | 19,640 B | 0.612678 |

状态代理下降 11.75% / 7.39%。主树 BPU/RS/FQ/IQ 分别 −128/−300/−32/−96 B；
模板分别 −256/−456/−56/−128 B，另有 LQ/SQ 通知载荷 −672 B（队列容量没有缩减）。
median/multiply/qsort/rsort/towers/vvadd 的 IPC 分别从
0.555985/0.812140/0.451291/0.566837/0.722468/0.786460 变为
0.544360/0.810503/0.446948/0.519797/0.675761/0.763603。
几何平均高于当时 0.6 筛选门槛，不表示所有单例达标，也不是课程 AXI 镜像性能。

## 2. 4 KiB DCache 几何扫描

固定数据容量 4096 B，扫描行长 32/64/128 B、相联度 1/2/4，评分为 `Fmax × 六例几何 IPC / core＋Cache 面积`。
多路均为 tree-PLRU，先选最小 invalid；2 路 1 bit，4 路 3 bit（bit2 根、bit1 左、bit0 右，1 表示右子树 MRU）。
触碰 hit 与末拍回填更新 PLRU，early restart 不更新；I$ 保持 1 KiB/64 B。

| 行长 | 1 路组数 | 2 路组数 | 4 路组数 | bank/路 | 回填拍数 |
|---|---:|---:|---:|---:|---:|
| 32 B | 128 | 64 | 32 | 8 | 4 |
| 64 B | 64 | 32 | 16 | 16 | 8 |
| 128 B | 32 | 16 | 8 | 32 | 16 |

当时为 4 请求信用、单 miss、有序运输 owner、立即 HALT；外存独立 20 拍整行读写，**没有随行长增加串行带宽成本**。
所有 9 配置都比较真实 SRAM D$/DMEM 的两软件、RTL 与独立周期/字节参考，并运行两软件 18 ISA＋6 IPC。
综合范围为 core＋I$/D$，ASAP7/FakeRAM、opt、2 ns、理想时钟/无寄生；不能用独立 Cache PPA 代替整核。

32 B/1 路候选相对旧 8 KiB 合并版：面积 −8.5153%、Fmax＋18.0748%、几何 IPC −7.3753%、密度评分＋19.5461%。
六例几何 IPC 为 **0.5072817116894153**，并非 IPC 最优。9 配置完整 PPA 排名当时未形成，不能宣称该候选全局最优。
后来活动几何变为 32 B/2 路，不能沿用此候选排名或逐拍结果。

工件：`build/dcache-sweep-20261015/`，各配置含 PASS 日志/转换快照/STA，审计表为 `audited-ranking.json/csv`。
早期临时统计 JSON 丢失时，从持久 PASS 日志恢复周期并明确标注来源，不冒充原统计文件。
同级 `sync/` 的复现工具不在本仓库：

```bash
# 在共同父目录执行；只适用于匹配当时软件/RTL摘要的实验副本
python3 -B sync/dcache_sweep.py --reuse --synth-jobs 3
python3 -B sync/report_dcache_sweep.py RISC-V-CPU-2026/build/dcache-sweep-20261015
```

历史覆盖：9 配置模块/软件通过；32 B/1 路非零 SRAM 测试 13,596 拍、471 次回填、290 次早响应、125 次并行脏缺失。
该候选完整三 CPU 24/24、14,287,667 拍/28,575,334 个 exact 70 项 pre/post 点一致（ISA 13,354,791、IPC 932,876）。
8 KiB 默认对照 24/24、13,848,612 拍 strict 一致，但为指纹验证，不能冒称 exact trace。
9 种实际 RTL 故障注入检出；软件 bounded hit/victim helper 整理穷举 9/9、四实现共 50,460 项等价，旧源码摘要与新 helper 证据分开保留。

## 3. 两种 SRAM BTB

以下模块仅供独立实验，不接当前 core：

- [`rv32_bpu_btb_sram.sv`](../verilog/rtl/predictor/rv32_bpu_btb_sram.sv)：单 SRAM naive 版。
- [`rv32_bpu_btb_sram4.sv`](../verilog/rtl/predictor/rv32_bpu_btb_sram4.sv)：4-bank、tag/target 分离版。

### 单 SRAM 合同

- 默认 64×56，表项 `{PC[31:8], target[31:2], state[1:0]}`；一个公共 1RW `sram_fakeram`，整字写，无复制、banking、shadow、旁路或内部训练 FIFO。
- `queryValidInput/queryReadyOutput` 接受 PC 并同步读；读沿后 `responseValidOutput` 有效、`responsePcOutput` 回显已接受 PC，`lookupOutput` 含 hit/type/target，类型与 target 不因 tag miss 清零。
- `responseValidOutput/responseReadyInput` 消费前保持 PC/lookup；背压时锁存读出，不能依赖写/禁用周期无效 SRAM 输出。最小查询启动间隔 2 拍。
- `trainingValidInput/trainingReadyOutput` 接受完整三源批次，忙时必须保持重试；`trainingDoneOutput` 才表示全部写入完成。空闲训练优先，可使查询饥饿；持有未消费查询回复时也不接受训练。
- 接受后顺序处理 fetch/jump/branch，通常第 3 沿完成；fetch 无任何新 target 时同步读改写驻留 target，第 4 沿完成，换 tag 也保留旧 target；空批次仍第 3 沿确认。
- 同槽 tag/state 按 fetch > jump > branch；target 按静态 fetch > jump > taken branch，各不同索引均保留。只有 taken branch 分配；ROB 存活/年龄筛选由调用方完成。
- 低有效复位取消在途控制，SRAM 本体不复位；释放后扫描恰好 `BTB_ENTRIES` 沿清零，随后 `initializedOutput=1`。

### 4-bank 合同

默认 64 项直接映射，不是 4 路相联：bank=`PC[3:2]`，row=`PC[7:4]`；
metadata 为 4×16×26（tag/type）、target 为 4×16×30，另有 64 valid＋64 targetValid 可复位寄存器，总 SRAM 3584 bit。

- 复位只清 valid/targetValid/控制，`initializedOutput=rstNInput`，无扫描。metadata-only 首次分配 target=0，替换已有行不写 target；reset 后不得复活旧 target。
- 保留相同查询/回复、训练批次握手及优先级，每批最多 3 个不同索引 intent；每 bank 每拍写最老 intent，不同 bank 并行。
- 查询仅等待本 bank 已接纳的较老 intent，其他 bank 可继续训练；新批次与查询同沿接受时 read-before-write。
- 回复背压锁存 metadata/target，训练仍推进；一次只接纳一个活动批次，批次间仍可能队首阻塞。没有 pending FIFO 全旁路，也不是四组独立训练 FIFO。

### 验证与历史整核适配

旧整核中 I$/BTB 成对启动、pending 汇合指令/预测，只有一个未采纳预测；保存方向/RAS 快照，完整预测采纳才推进 PC/GHR，取指接受分配 checkpoint。redirect 以持久 killed 排空旧预测（同 PC 也不可复活）。4 项批次训练 FIFO 不跨拍合并，执行/预译码预留 credit，保持 `FIFO占用＋未兑现预留≤4`，并按 ROB 身份/年龄筛选。该适配已退役，下列仅为仍有效的独立入口：

```bash
python3 -B -m unittest discover -s scripts/tests -p 'test_btb_sram.py' -v
python3 -B -m unittest discover -s scripts/tests -p 'test_btb_sram4.py' -v
make synth FILELIST=verilog/assessment/btb_sram.f SYNTH_OUT=build/synth/btb-unit MODE=opt
make synth FILELIST=verilog/assessment/btb_sram4.f SYNTH_OUT=build/synth/btb4-unit MODE=opt
```

naive 2/16/64 项共 5,832/6,182/7,240 拍，banked 4/16/64 项均原始/转换 RTL 对照寄存器参考通过；
覆盖三源别名、target 保留、背压、非零 SRAM、复位取消。非法 3/12 项均先编译成功再被运行期断言拒绝。
banked 另含三 bank 写＋第四 bank 查、同 bank 串行、read-before-write、metadata-only 不访问 target。
历史整核两版均原始/转换各 57 例通过；banked 观察到 631 拍查训重叠、167 拍多 bank 写，FIFO 最高 3，不冒称满 4 覆盖。

### PPA 与六例原生 HALT IPC

三版共同 D$ 为 **4 KiB/32 B/单路、单 miss**，边界为 core＋I$/D$，不含课程 AXI/MMIO；opt、2 ns、INVx1/5 fF。
独立 BTB：naive 面积 375.273（组合 116.742 / 时序 108.038 / SRAM 150.494）μm²，Fmax 1,494.89 MHz、周期 0.6689 ns、slack＋1.3317 ns；
banked 面积 582.426（276.131 / 155.802 / 150.494），Fmax 1,075.63 MHz、周期 0.9297 ns、slack＋1.0705 ns。
独立模块频率不是整核频率；bank 外围与 valid 有真实成本，FakeRAM 按 bit 线性估计不能代表真实 SRAM 编译器外围。

| 整核指标 | 寄存器 BTB | 单 SRAM naive | 4-bank split |
|---|---:|---:|---:|
| 总面积 μm² | 24,234.267 | 21,638.851 | 21,879.902 |
| 组合 μm² | 15,819.971 | 14,014.034 | 14,206.562 |
| 时序 μm² | 6,581.499 | 5,641.527 | 5,690.049 |
| SRAM μm² | 1,832.797 | 1,983.291 | 1,983.291 |
| Fmax MHz | 244.45 | 232.30 | 241.05 |
| 最小周期 ns | 4.0908 | 4.3047 | 4.1484 |
| 2 ns slack ns | −2.0908 | −2.3038 | −2.1484 |
| 六例几何 IPC | 0.5072817116894153 | 0.25469159844304246 | 0.28214547598717016 |

naive 网表 50 个 SRAM 叶宏，其中一个 64×56；banked 57 个，其中 4 个 16×26＋4 个 16×30，无残留 64×56。
面积含适配/训练 FIFO/credit，不能直接用独立 BTB 面积替换旧整核模块。

IPC 使用同级 `RV32IM_Simulator/data/testcases_ipc/` HALT 镜像，128 KiB 内存、IMEM 容量 16、固定 20 拍外存，无随机 ready/延迟。
排除共同 1 boot 拍，其余 BTB 初始化计入；HALT 提交拍计时、不计 HALT 退休、不排空。
旧版六例周期先在共同计时器复现，三版独立 ISA 逐条核验退休 PC/指令/写回/Store，退休总数 364,790、完整 x10 均为 0。

| 用例 | 退休数 | 寄存器周期 | naive 周期 | 4-bank 周期 |
|---|---:|---:|---:|---:|
| median | 7,056 | 15,583 | 29,399 | 26,425 |
| multiply | 21,715 | 27,338 | 89,238 | 75,513 |
| qsort | 139,893 | 356,680 | 641,263 | 564,684 |
| rsort | 187,520 | 518,391 | 702,182 | 691,836 |
| towers | 4,087 | 7,161 | 14,709 | 13,554 |
| vvadd | 4,519 | 7,723 | 15,652 | 13,927 |
| 合计 | 364,790 | 932,876 | 1,492,443 | 1,385,939 |

按未舍入 `retired/ipc_cycles` 取几何平均：banked 比 naive IPC＋10.779263%，仍比寄存器低 44.380909%；
相对寄存器面积 −9.715024%、Fmax −1.388889%，不能因此声称吞吐/综合评分改善。三版均未达 2 ns。
初始化差额不能解释主要稳态损失，训练冲突/前端气泡各占比尚未独立归因。

工件定位：`build/btb-sram{,4}-integration-20261016/`、`build/btb-sram{,4}-ipc-20261016/`；
`build/synth/btb-sram-naive-20261016/opt/`、`btb-sram4-unit-20261016/opt/`、
`btb-sram-integrated-20261016/cached/opt/`、`btb-sram4-integrated-20261016/cached/opt/`。
`report.json`、`comparison.json`、`banked-comparison.json`、`banked-run.json` 保留未舍入数值及来源摘要。

## 4. 四 MSHR 数据侧快照（2026-10-16，早于当前课程顶层）

该轮只同步硬件数据侧：D$ 4 KiB/64 组×2 路×32 B、4 请求信用/4 MSHR、LSU 2 bit/4 owner，仍为 4-bank SRAM BTB。
当前数据侧见 [cache.md](cache.md)，此轮 PPA/验收不适用于后续课程顶层。

历史数据侧 35,000 拍：7,324 请求、5,547 Load、53 次合并、2,779 次 miss 在途 Load 返回、365 拍四 MSHR、2,030 次非队首 Load 返回。
原始/转换 828 请求比较与 LSU 取消/符号/迟到响应/LQ 复用通过；历史整核原始/转换各 72 例独立 ISA 通过，IMEM 1/7/20 拍，DMEM 固定 20 拍。
报告：`build/dcache-mshr-sync-20261016/report.json`、`build/dcache-mshr-integration-20261016/`；不是当前完整软硬件逐拍等价。

该快照 core＋I$＋D$ 综合（不含 DMEM 执行器/宿主阵列/课程 AXI）：

| 指标 | 数值 |
|---|---:|
| 总面积 μm² | 24,213.382 |
| 组合 / 时序 / SRAM μm² | 16,196.528 / 6,028.188 / 1,988.665 |
| Fmax MHz | 238.973 |
| 最小周期 ns | 4.1845703125 |
| 2 ns slack ns | −2.183790 |

Yosys 0.63 / OpenSTA 3.1.0，原 ASAP7 库摘要、opt、2 ns、INVx1/5 fF、STA 边界约束不变，无新增 false path；IPC 未重测。
90 个叶宏：BTB 4×16×26＋4×16×30，D$ 64×64×8＋2×64×22，I$ 16×16×32。
相对旧 banked 单路/单 miss 面积＋10.665%、Fmax −0.863%，同时改变几何/MSHR/运输接口，不能解释为单变量收益。
为节省资源分阶段续跑、JSON 改 RTLIL 导入；43 模块往返结构检查摘要
`faa39fa91078ccc554dc862178e0ec7defeaf7bc35766de34f40dc74043e48c1`，输入/库摘要前后相同。
报告：`build/synth/btb-sram4-mshr4-20261016-final/cached/opt/`；大型工件原保存在
`/home/hhslx/.cache/opencode-synth/btb4-mshr4-persistent-20261016/cached/opt/`。

<a id="recovery4"></a>

## 5. 已提交 SRAM＋四拍恢复（2026-10-17）

实现布局、游标与暂停范围统一见 [backend.md](backend.md#已提交-sram-与四拍重放)，PPA 及关键路径只保留在 [assessment-results.md](assessment-results.md#course-ppa)。

初始实验只改 RTL，不改两软件及 golden；基线是开始实验时含未提交改动的实际工作区快照，不是 Git HEAD。**后续两软件同步已完成**：四构建 25/25，且各自对真实 RTL 的 25 例逐拍/独立 ISA 通过，共同 golden 为不含 boot 15,541,955 拍、退休 7,303,489。记录在父工作区 `sync/RECOVERY4-SYNC-20261017.md`，不再将“未同步软件”作为当前结论。

### 定向与课程验收

```bash
python3 -m unittest scripts.tests.test_recovery4 scripts.tests.test_predictor_register -v
```

- 20 组模块用例：SRAM 复位屏蔽、完整 RAS 内容、空/满栈、pop-push、四拍游标回绕/暂停、RAT 最年轻映射、free list 逐拍回收及 FIFO 顺序。
- 真实核心：更老 Load 在恢复第 2 拍返回，7 条正确退休、1 次重定向、4 个重放周期，结果保持且错路退出 Store 未退休；寄存器 BTB/方向预测专项通过。
- AppImage Yosys 0.33 展开及 FakeRAM 替换识别 `fakeram_asap7_1x6` / `fakeram_asap7_1x32`，不是提交内容退化成触发器。初始产物 `elaboration-final/core/ram/` 仅为宏识别验收，后续完整映射/STA 见 PPA 记录。
- 初始 `--assert` 课程回归 25/25 输出正确（19 correctness＋6 perf），含 boot 总周期 15,541,980；改前实测 14,827,179→15,541,980（＋4.82%）。初始输出验收不等于后续逐拍验收，二者证据分开。

### 六项课程性能对照

相同课程镜像、外存延迟 10 拍、均校验输出；IPC 分子来自课程 `metrics.json`，周期为框架总周期而非 core 周期。

| 用例 | 单拍恢复 cycles | SRAM＋四拍恢复 cycles |
|---|---:|---:|
| median | 14,519 | 16,386 |
| multiply | 27,468 | 30,374 |
| qsort | 267,430 | 310,181 |
| rsort | 331,437 | 331,560 |
| towers | 9,729 | 10,464 |
| vvadd | 6,858 | 6,877 |
| **合计** | **657,441** | **705,842（＋7.36%）** |
| **几何平均 IPC** | **0.5893803** | **0.5471766（−7.16%）** |

结论：恢复 SRAM 化改善面积，但固定四拍重放损失 IPC，不能称全面性能改善。宽字小容量宏仍为 FakeRAM 拟合，不是实际工艺宏签核。

源码/摘要、初始构建/测试、`final-course-report.json`、`comparison.json` 及性能原始输出在 `/tmp/opencode/recovery4-20261017/`；完整综合、源快照、路径核验与对照在父工作区 `build/recovery4-ppa-20261017/`，定向回归再次 3/3 通过。
