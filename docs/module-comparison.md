# 模块对照：C++ 参考模型与 SystemVerilog RTL

当前SPEC §66：软件初始化/结束状态直接归CPU顶层，独立控制模块已删除；模板
Register单写/所有work后提交保持。四构建18＋6周期及统计保持，本轮RTL源码未改。

当前SPEC §63/64：第5/12/13补验收口；完整18 ISA＋6 IPC在共同逻辑Memory实际
三CPU12667040拍2872word无损逐拍、独立退休/最终128KiB/分段周期全等，活动
golden保持。软件非法opcode元数据/异常ready与RTL同步，年轻取消不trap；课程
AXI/综合STA与未纳入异常仍明确保留，命令及可追溯报告sync/README §55/56。

当前SPEC §62：boot隔离及HALT/core/drain/全dirty最终DONE统一，16真实程序9629/
2872三端全等，最终128KiB独立字节核验、DONE保持16拍及7源码负向有效。两软件
CPU顶层结束阶段/D$flush按RTL backend，core补boot门控；18＋6两树两构建strict新
total11973998/693042，core保持。第19当前域完成，第20继续，入口sync/README §54。

当前SPEC §61：真实请求检测/队列/年龄选择/广播与全部流水恢复67程序9001/2872
三端严格一致，11源码功能负向有效。七RS/MUL三阶段/DIV四阶段/四路WB/LSQ/
实际Cache联合，RTL LSU分配旁路P0资格遗漏已补；软件算法保持。第18当前域
完成，下一第19boot/HALT/drain计时，命令与准确范围sync/README §53。

当前SPEC §60：BTB26真实三CPU程序6690/1848严格一致，三类fetch/三源五种槽
分组完整，七实际RTL/两软件功能负向有效。默认字段仲裁保持，13合法/9非法
RTL参数与22软件编译约束通过。第17当前BPU域完成，第18全流水恢复继续，README §52。

当前SPEC §59：用户JALR双link（含同寄存器）先pop再push，真实三CPU33程序13041拍
1848字段严格同值，各程序周期同值；实际producer分类/退休/恢复及完整RAS/GHR/
PHT/BTB/checkpoint内容转移核验、7实际源码功能负向通过。不能只恢复depth，软件
旧提交基线＋含头/RTL提交后基线＋跳头等价，checkpoint一次取指一次ID。六IPC
新691640/ISA11967396，活动表留历史/严格门禁包括IPC，README §51。

最新SPEC §58：I$ data公共sram_fakeram真实宏接口16×512bit/32bit写粒度，tag为
16×22bit寄存器。实际Icache/IMEM2324/160、取指至decoded IQ2259/216四方严格全等，
4＋3功能负向检出，给定JAL预测/恢复、HALT/返回背压/三级满替换/checkpoint回绕通过。
真实core/SRAM I$ Store/Load/branch程序及RTL16项通过；BPU闭环继续第17步，README §50。

当前SPEC §57：三端Store按旧SQ的地址/数据齐且未提交资格构造slot/epoch位图，
ROB验证旧有效Store/epoch及恢复年龄，批量拍末置ready、下一拍才可退休。4803步
764字段正向严格全等；§56的Store ready时刻差屏蔽已删除，独立344字段含原始
Store ready。缩小DEPTH仍保留公共tag高slot位，身份探针通过；完整结果见README §49。

最新SPEC §56：不再只分别测LSU与D$，实际四RS→AGU→LSQ→D$/DMEM→CDB→共享
PRF/ROB→退休4803步28组763语义字段三端一致。导出另1原始Store ROB完成位诊断：
软件批量置位、RTL单项报告（step2796 mask30/2）；SQ就绪/实际退休严格相同，其余
rename状态直接交叉比较。独立343语义字段/四实际负向通过，前端/整核另验，README §48。

最新SPEC §55：D$按用户决定使用寄存器，组合旧态读取/拍末写、命中接受+1，正常
READY/WAIT及双端口实际DMEM6378步14字段三端/独立参考全等。身份/符号按真实握手
统一，元数据/有效数据按指纹比较；默认展开检查128×512bit时钟bank、无SRAM实例。
LSU旧响应/下一读同拍重填，真Cache4及恢复/排空三个负向、标准RTL14等通过。完整
CPU三端镜像轨迹/末尾排空口径和技术综合仍另验，当前命令见sync/README §47。

最新SPEC §54：LSU后端当前合同已同步：软件/RTL采用(A)单源完整覆盖、同起点同宽度
通知及未知地址支配；Cache准入独立保守检查。2443步323字段22 suite全部pre/post
三端严格一致，最后一组READY486/CDB487/commit503、无读。独立4993步30 suite及
五实际负向/core12/真Cache4/生命周期/四路/RTL14通过。完整三端Cache与整核另验，
下方21/22或更早结果为历史，入口sync/README §46。

最新SPEC §53：软件与RTL查询均为(A)最年轻字节重叠候选、单源完整覆盖；RTL通知
对齐软件同起点同宽度/年轻项守卫，独立Cache准入阻塞未知地址或任何重叠。22 suite
2443/323三端21/22逐拍一致、架构全正确；仅older_unknown_overwritten的未知地址
转发阻塞仍不同，当前软件READY486、RTL539，不沿用旧14拍差。独立4818步29 suite、
core12、Cache4、四路/生命周期/RTL14及实际负向通过。下方为历史版本，README §45。

最新§50为RTL真实Cache接入与结束边界验收：core/七池RS/FU/LSU/同步SRAM DCache/
64B行内存四组正常程序通过、两个实际RTL负向被拒绝，独立检查全行/最终64KiB内存
及读响应拍。读token在接受时冻结，外层drain先完成在途事务再写回dirty；原4499/
四路3648/RTL14通过。当前不是完整三端Cache FSM周期等价，软件源码保持用户版本。

最新§48：用户主树Release/_DEBUG及原SB/数据后到偏移反例已修，地址广播宽度已填。
扩展三端2020步18 suite仍有地址通知旧基准、查询漏年轻偏移、反向宽度覆盖四个
主树错值，模板九个错值；软件保持用户版本。RTL独立4395步323字段25 suite全等，
正常core6/6、四路3648步及RTL14/14通过。具体路径与正常完整CPU反例见公共SPEC §48。

2026-10-09最新（SPEC §47）：RTL按已确认的软件三个事件时序做并行转发，4031步
323字段22 suite与独立时钟模型全等；晚扫描/错误同拍旁路两个实际RTL负向有效。
core4/4、RTL14/14和四路3648步回归通过。用户主树原SB三错值已修，但偏移SW/SH/LW
仍错、地址广播漏宽度；模板未同步。本轮只改RTL/sync及公共/RTL文档，软件源码摘要
复核不变。资格差异和fallback、完整Cache周期仍按验收范围追踪，下面是各阶段历史。

最新Store来源/Load转发观察（SPEC §46）：1338步323字段两软件全等，4个内存
对照suite三端全等、8个转发suite不同。软件word转发提前、notify可同拍更新多Load，
RTL每拍扫描一项并对未知更老Store全阻塞；按起始地址/字节范围匹配也不同。
SB/LBU/LB/LW字节错值在正常DIVU两软件整核复现，RTL相同指令流3/3正确；默认观察0、
严格1，具体例子sync/STORE-FORWARD-DIFFERENCES.md。生产和活动golden保持。

当前SQ已按软件统一退休/缓冲/发送（SPEC §45），不另设Buffer。RTL同一SQ保留
committed项至下游实际接受，独立FIFO epoch顺序维护跨ROB回绕/恢复及转发新旧选择；
退休载荷与发送载荷分离。LQ1432步816字段、SQ872步340字段四方一致，整体严格模式
返回0；RTL14/14含整核背压/四Load/实际恢复/HALT。18＋6活动clock保持11,967,396/
690,814。以下§42～44是阶段记录，完整跨Cache及三端Store来源时序另验。

当前LQ已三端统一实际ROB提交同拍回收（SPEC §44），CDB只标记已广播；1432步816字段
全suite四方一致，满时15写回/16提交释放/17新分配。RTL不再在结果消费时清valid，软件
不再等下一拍观察head。余下SQ Store提交接收策略仍不同，ISA/IPC新clock11,967,396/690,814。

第一项主树LQ错值已用初始化后置修复（公共SPEC §43），当前三端新分配/旧响应竞争
均写回/提交正确值，临时旧顺序实际编译负向仍错。整体生命周期仍因LQ释放/Store提交
合同不同而不等价（§42），后续策略待定版。

第12步最新观察（公共SPEC §42）：LQ释放/满时准入差2拍，Store提交与发送接收耦合不同。
恢复后旧tag4响应与新tag5分配同拍，主树架构x20取旧地址0x500的值，模板/RTL正确。
当前三端不等价；普通SQ ready/环回/写数据与满SQ下一拍替换一致，生产修复及合同定版待续。

最新第11步当前四路专用CDB/word-load联合域已验收（公共SPEC §41）：实际四生产者/RS/
AGU/内存返回共享PRF/ROB，3648步590字段四方一致，16种WB掩码及正常JALR恢复通过。
无新生产写回分歧；软件LQ退休后释放与RTL消费释放的生命周期、满队列/Store/Cache仍按第12～15步验收。

本文对比历史 C++ 周期模型（REF，`../RV32IM_Simulator/RISC-V-Simulator-Template`）和 `verilog/rtl/` 中的原生接口实现（RTL）。REF 的 `work()` 读取周期初状态、由 `sync()` 统一提交；RTL 用组合逻辑和 `always_ff` 实现相应行为。模块名称和周期数不必一一对应。

最新同步状态以公共`CPU-SYNC-PLAN.md`/`CPU-SYNC-SPEC.md`为准。第9步三端MUL已收敛为
三级弹性/单槽结果，模块2207步21字段及真实返回链2302步508字段四方一致（SPEC §38），
n+3实际CDB/n+4依赖派发；下方旧容量/实现差异表是历史对照，不能用来判定本步未完成。

第10步DIV/REM已验收（SPEC §40）：三端radix-4 SRT、结果消费同拍接收、严格年轻flush/
边界保留，边界结果无授权时保持。模块55256步28字段、真实返回后端5000步500字段四方
一致；一般CDB拍差3..19、快速1拍，整核多生产者/完整恢复联动另验。下方restoring及旧
消费/取消差异描述仅属历史。两软件18 ISA新clock总和11,967,406，六IPC仍690,826。

## 模块映射

| 功能 | REF | RTL | 主要区别 |
| --- | --- | --- | --- |
| 取指、FQ/IQ、译码 | `FetchUnit`、`InstructBuffer`、`DecodeUnit`、`Decoder` | `rv32_frontend`、`rv32_decoder` | RTL 合并取指与两级队列，译码在队列输出后进行；非法指令在译码时标记。 |
| 分支预测 | `BPU` | `rv32_predictor` | 表结构与恢复思路相近；REF 在冲刷仲裁器判分支误预测，RTL 在 BRU 判定。 |
| 重命名、物理寄存器 | `RAT`、`PRF` | `rv32_rat`、`rv32_prf` | 三端均用提交映射 + ROB 窗口重放恢复；PRF均采用FIFO自由队列，按年龄回收年轻newPhy后追加提交oldPhy，基础域逐拍对齐。 |
| ROB | `ROB` | `rv32_rob` | REF 用指针及 LQ/SQ 尾快照；RTL 用计数/有效位，访存队列按 ROB 年龄冲刷。 |
| 发射、保留站 | `IssueArbiter`、`RSUnit`×7、`DispatchArbiter` | `rv32_core` 发射逻辑、`rv32_rs`×5 | REF 由 PRF 判就绪、集中选择；RTL 的 RS 存操作数及 ready 位，内部选最老可发项。 |
| 执行与写回 | `ALU/MUL/DIV/BRU`、四个 CDB | `rv32_alu_unit/rv32_mul/rv32_div/rv32_bru_unit`、四条直连写回通道 | REF 多用结果队列，RTL 多用流水/握手；RTL 在 core 通过 ROB 完整 tag 认证结果。 |
| 地址与访存 | 单槽`AGU`、`LQ`、`SQ`、`MemArbiter` | `rv32_agu_unit`（内含组合`rv32_agu`）、`rv32_lsu` | 三端AGU均单槽同拍交付重填；RTL LSU统一处理队列、逐字节转发与请求，完整访存生命周期仍待同步。 |
| 缓存与主存 | `ICache/DCache/IMEM/DMEM` | `rv32_icache/rv32_dcache`、核外握手端口 | REF 在核内模拟主存延迟；RTL 把主存移到核外，缓存以 FSM 和行接口工作。 |
| 冲刷、结束 | `FlushArbiter`、HALT 后等待队列空闲 | `rv32_flush_arbiter`、HALT 后 D$ 主动排空 | 两边均有 4 项冲刷仲裁；RTL 须处理在途响应和脏行写回。 |

## 会改变行为或性能的差异

| 主题 | 对照结论 |
| --- | --- |
| 前端吞吐 | REF 的 I$ 有 4 项投机请求队列，命中可直接供指令；RTL 前端单在途请求，I$ 经 `TAG_READ`，命中约 2 拍。FQ/IQ 均为 4 槽，但队列组织不同。 |
| RS 与执行单元 | REF 是 7 池约 23 槽的去值化 RS，执行结果多用 4 槽队列；RTL 是 5 池 15 槽的取值化 RS，写回可唤醒操作数，FU 用 ready/valid 握手。两侧的背压与发射时序不能按拍照搬。 |
| AGU 与访存 | 地址结果边界及共享RS→LSQ地址链已同步：n拍计算/保存，n+1交付，n+2地址ready可见；模块3182步、地址链1195步四方一致，目标身份及Store地址广播鉴权通过。两边均阻止load越过地址未知的更老store；REF按整字同起始地址转发，RTL按字节选择最近更老store，数据返回完整专项待验。 |
| 恢复与写回 | REF 的 LQ/SQ 用 ROB 尾快照回卷，RTL 按 `flush_tag` 清年轻项并丢弃错路响应；两侧 RAT/PRF 都依赖 ROB 窗口重放。RTL 的直连写回必须先验证完整 tag、存活与冲刷年龄，避免旧结果写入复用槽。 |
| 缓存与结束 | REF 的 D$ 命中可快速自答，脏行仅在替换时写回；RTL 命中经 `TAG_READ`，HALT 时主动扫描并排空脏行。两侧均用 4 路 tree-PLRU，命中延迟和收尾周期却不同。 |
| 算术与异常 | 乘法两侧均用 Booth radix-4 + CSA；除法 REF 为 SRT radix-4，RTL 为逐位 restoring。RTL 另有非法指令、未对齐目标的异常路径；JALR 目标清 bit 0。 |

默认规模：ROB16、PRF48、FQ/IQ 各 4、LQ/SQ 各 8、I$ 8 KiB 直接映射、D$ 64 KiB 四路（16 B 行）。预测器采用三张 256×2 bit 方向表、BTB64、RAS8、SARAS16、32 项取指检查点。以上是对照用的原生接口配置，具体参数与后续改造以源码和 [`plan.md`](plan.md) 为准。

## 验证口径

MUL三级弹性及真实返回后端已验收（SPEC §38）：两软件MUL_CAP=1，三个CanAccept方法
从真实授权/取消释放递推；全部模块suite四方一致，旧4槽/无stall溢出记录归历史§37。
真实链包含两池RS、ALU源生产、重命名、MUL、CDB目的、PRF/ROB、提交恢复；outReady合成背压，
恢复为给定合法ADD边界。完整前端/Cache、四路生产者并发及真实分支触发恢复依对应步骤验收。

当前§35已修正下方历史方向差异：软件显式actualTaken，控制/BPU后端全链1518步/3036点
2230字段四方一致；用户排除misAlign，对齐非call/return域完成。完整前端/RAS/Cache整核仍待验证。

第8步控制现状观察2374步/4748点56字段：对齐PC结果域一致，结果→请求→广播时序
为n/n+1/n+2；但条件真且目标PC+4的训练方向、未对齐恢复PC/候选资格仍不一致。
报告passed_observation=true且three_way_equivalent=false；完整控制链/BPU状态仍待验收。

- REF 的主存延迟由模型内部设定（旧环境为 20 拍），按 HALT 和队列排空结束；历史 RTL 测试环境也以 HALT 及自有计时区间统计 IPC。两侧 benchmark、存储器和计时边界不同，旧 IPC 数值不能直接比较。
- 当前课程以 `student_top`、AXI4-Lite、`sram_fakeram` 及 `testcases/` 子模块为准：19 项正确性、6 项性能测试；向 `0x80000000` 写全字（`WSTRB=4'hf`）后以 B 通道握手作为退出边界。官方 IPC、面积、频率应使用课程 `make test`、`make perf`、`make synth MODE=opt` 重新测量，不以历史对照文档中的结果代替。
