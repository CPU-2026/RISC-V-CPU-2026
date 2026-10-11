# RTL 后端：重命名、保留站、执行、写回与提交

当前SPEC §63/64：七池实际消费/FU预算与SV目标补验通过；完整24镜像12667040
拍2872word三端無损逐拍/退休/内存全等。软件RV_INVALID按现有RTL真实元数据/
exception ready合同同步，正常周期golden保持；完整异常全域不据此宣称，README §56。

当前SPEC §62：冷复位boot1拍无正常事件；HALT提交/core停止与外层dirty drain DONE
分别观察。core不新增FU流水级，外层用既有dmem_backend。16程序9629/2872全等，
7源码负向及DONE保持16拍通过；计时从实际事件边界采样，入口sync/README §54。

当前SPEC §61：实际BRU/ALU请求n+1入队、n+2旧队列选最老广播；67真实三CPU
程序9001/2872严格一致，11实际源码负向有效。ROB/RAT/PRF/七RS与全部FU/LSQ
恢复同链，MUL三阶段/DIV四阶段及四路WB年轻过滤/更老保留均有实际覆盖。
raw观察读寄存valid而非已过滤输出。第18当前域完成，第19计时继续；README §53。

当前SPEC §60：真实jump CDB/BRU/早训练BTB竞争26程序6690/1848严格三端全等，
七软件/RTL功能负向有效。RAS13041/1848、控制1518/2230、访存4803/764与RTL16
回归通过。第17当前BPU域完成，下一第18多恢复请求/所有FU及LSQ全流水联动，
实际源码默认训练/退休/恢复行为保持。入口sync/README §52。

当前SPEC §59：JALR push/pop由rd/rs1是否link独立决定，双link含同寄存器先pop再push。
Issue保存pop元数据，提交/重放按raw指令同规则，实际JALR仍取旧rs1计算target及PC+4
link写回。33实际三CPU程序13041/1848严格同值，7实际软件/RTL功能负向有效，
提交/恢复同拍不重放两次，HALT pc元数据与软件对齐。当前报告README §51。

当前SPEC §58：core输出完整`imemCacheRequestOutput`及`imemRspReadyOutput/imemFlushOutput`，
可接真实公共SRAM I$，前端返回由FQ实际接受才释放，恢复逻辑取消。I$/IMEM2324/160、
真实前端2259/216四方全等，真实core/SRAM I$ Store/Load/branch/HALT与RTL16项通过。
旧PC与旧checkpoint-id独立连线，无新增流水级。后端4803/764严格回归保持，README §50。

当前SPEC §57：Store通过专用slot/epoch位图批量完成，ROB按旧有效Store/epoch及
恢复年龄核验，和普通完成汇总为每槽单点ready写入；下一拍才可退休。§56的Store
完成时刻差屏蔽已取消，当前764字段严格门禁和关联回归结果见sync/README §49。
默认ROB16采用常量逐槽mask位选，XML展开确认32个常量单bit选择；DEPTH8探针
保留公共tag高slot身份位。最终全链764严格/六负向、标准RTL15/15及core12/真Cache4通过。

最新SPEC §56：同一套RAT/PRF/ROB接实际四RS/ALU/AGU/LSU/D$，返回经过真实CDB
至退休，4803步28组763语义字段三端一致，420 rename状态交叉核验，独立参考343
语义字段。软件批量Store完成位/RTL单项报告原始差异另记诊断，实际SQ/退休严格比较。
遗漏Load PRF写口和错误owner实际负向造成架构失败；完整前端/所有FU联动另验，README §48。

最新SPEC §55：寄存器D$ READY/WAIT按软件逐拍实现，独立读/写及写完成端口，6378/
14真实Cache/DMEM三端全等。LSU单pending允许旧响应与新读同拍替换，仍按旧身份
处理返回并保留新owner；不增加当拍CDB依赖派发。真Cache4、标准RTL14及LSU/四路/
生命周期回归通过，完整整核共同轨迹另验，命令见sync/README §47。

最新SPEC §54：LSU(A)/事件资格及未知地址支配按软件统一，候选比最后未知项年轻
且完整覆盖、数据就绪才转发；未知项在候选之后仍阻塞。22 suite三端严格全等、架构
全正确，独立4993/323共30 suite、core12/12、五实际负向及四路/生命周期/RTL14通过。
此前§53残余组已闭合，完整Cache/前端整核另验；命令和报告见sync/README §46。

最新SPEC §53：LSU按(A)单源完整覆盖，旧多源拼接/部分返回合并删除。Load地址交付
当拍查询旧SQ、拍末写LQ/下一拍CDB；StoreValue/Address通知同起点同宽度，批量
更新全部匹配LQ。准入独立检查更老未提交Store未知地址或任何重叠。22 suite21/22
三端逐拍一致、架构全正确，仅点②未知阻塞未统一。独立4818/323、core12/12、真
Cache4/4、四路3648/590、生命周期及RTL14/14通过；软件/golden保持，README §45。

最新§50把真实DCache/同步SRAM/行内存接入core整链，4正常程序和2真实负向通过。
core.haltedOutput只完成HALT及SQ接受排空，接rv32_dmem_backend.drainInput，外层
结束条件使用drainDoneOutput，确保最后已接受Store及dirty writeback真正完成。
LSU冻结读token后原4499事件整链、四路3648及RTL14项保持。软件源码只读。

RTL来源/转发后端已按软件事件发生拍验收（SPEC §47）：Store两RS和Load RS经实际
PRF唤醒、共享AGU交付，合格LQ项同拍末批量写结果、下一拍CDB；本拍CDB不会提前
唤醒本拍依赖，新RS仍下拍参与。4031步323字段22 suite独立时钟参考一致，正常
core四字节/偏移覆盖镜像、原14项和四路3648步三端回归通过。当前软件修复仍未闭合，
不把RTL后端通过称为完整三端Cache/课程整核周期一致；入口sync/README §39。

SQ已按软件统一Store退休/缓冲/发送（SPEC §45）。LSU ready不等内存接受，实际ROB
退休置committed，原SQ按独立FIFO发送、下游接受才释放；跨ROB回绕/恢复保留。
commitMem载荷读取ROB目标SQ项，与发送更老Store独立；HALT提交停issue、SQ接受
排空后才输出halted。SQ872步340字段三端/oracle一致，RTL14/14含真实整核来源/转发/
恢复/HALT；两软件18＋6严格基线保持。下面阶段记录以§45更新为准。

LQ回收已统一实际ROB提交同拍（SPEC §44）。core把真实commitFireOutput/commit tag
广播给LSU，LQ结果消费只置lqBroadcasted，提交才清valid；1432步816字段及RTL13项通过，
非队首写回保留/旧提交恢复并发正确。Store提交接收耦合仍待共同定版。

第11步四路实际生产者联合写回已验收（SPEC §41）：实际ALU/MUL/DIV、Load RS/AGU/LSU
返回共用PRF/ROB，3648步590字段四方一致，16种WB掩码覆盖；step162四WB/提交/issue、
step163依赖。正常JALR解析后的给定恢复广播覆盖更老3路写回和四路年轻raw全部过滤。
生产RTL未改，真实单PRF口负向仅在sync夹具。LSU消费释放与软件退休后释放差异由第12步定版。

第10步DIV合同及返回后端已验收（公共SPEC §40）：三端结果消费同拍接收、flush仅取消
严格年轻，边界及更老工作保留。边界结果flush无授权时保持，结果释放用实际输出握手或
严格年轻取消；不能仅由raw outReady释放。模块55256步28字段及真实返回链5000步500字段
四方一致。快速n+1 CDB，一般n+L+3/拍差3..19；RTL13/13通过，完整多生产者/整核联动另验。

第9步已统一三端MUL三级弹性合同（2026-10-08，公共SPEC §38）：软件MUL_CAP=1，
partial/CSA/result均按有效位、flush年龄及真实下游消费递推准入，关闭级整体保持。
RTL原弹性行为保持，内部组合信号统一为partialCanAcceptInner/CSACanAcceptInner/
resultCanAcceptInner。模块2207步21字段全suite、真实返回链2302步508字段四方一致；
n+3 CDB/n+4依赖派发。夹具可变outReady及给定合法ADD恢复边界，正式core专用MUL输出恒授权。

接口事实来源：[`verilog/rtl/core/`](../verilog/rtl/core/)、[`backend/`](../verilog/rtl/backend/) 与 [`execute/`](../verilog/rtl/execute/)。本文讨论现有 SystemVerilog 实现，结构体逐字段定义见 [package.md](package.md)；取指、访存队列和缓存分别见 [frontend.md](frontend.md)、[memory.md](memory.md)、[cache.md](cache.md)。

```
IQ ──译码/单发射──► RAT + PRF + ROB + 七个 RS 池
                     │              │
                     └──► ALU / MUL / DIV / BRU / AGU──► 4 路写回及 BRU 完成
                                     │                         │
            按序 ROB 提交 ◄───────────┘        flush arbiter ──► ROB/RS/LSU/BPU 恢复
```

默认 ROB16/PRF48，RS七池：整数4、乘法2、除法1、分支4、Load4、StoreAddr4、StoreValue4，
共23槽。Load/StoreAddr竞争一个AGU，StoreValue独立向LSU交付数据。输入按valid/ready
握手，内部时钟上升沿、低有效复位；ROB tag5位、phy tag6位，保留恢复边界及更老项。

## 1. 集成边界：`rv32_core`

`rv32_core`连接前端/预测器、RAT/PRF/ROB、七池RS、执行单元及LSU，参数RESET_PC=0。
以下端口表适用于core；原cpu_top/cpu_cached_top已删除，student_top课程封装尚待实现。
imem/dmem为32位处理器端口，Cache独立模块的512位行接口见缓存文档。

| 方向 | 端口 | 硬件意义 |
|---|---|---|
| 输入 | `clkInput`, `rstNInput` | 时钟、异步低有效复位；取指 PC 初始化为 `RESET_PC`。 |
| 输出 / 输入 | `imemReqValidOutput`, `imemReqReadyInput` | 指令请求握手；同时成立时接受 `imemReqAddrOutput[31:0]` 的字节 PC。 |
| 输出 | `imemReqAddrOutput[31:0]` | 本次取指的 PC。 |
| 输入 / 输出 | `imemRspValidInput`, `imemRspDataInput[31:0]`, `imemRspReadyOutput` | 按接受顺序返回32位指令，ready表示真实FQ接收；受阻返回保持。 |
| 输出 | `imemCacheRequestOutput: icache_cpu_request_input_t`, `imemFlushOutput` | 完整PC/预测PC/checkpoint请求直接接I$，逻辑取消接I$/IMEM；旧运输响应由适配器丢弃/排空。 |
| 输出 / 输入 | `dmemReqValidOutput`, `dmemReqReadyInput` | load 或已提交 store 请求握手。 |
| 输出 | `dmemReqWriteOutput`, `dmemReqAddrOutput[31:0]` | 读/写选择（1=store）与字节地址。 |
| 输出 | `dmemReqWdataOutput[31:0]`, `dmemReqWstrbOutput[3:0]`, `dmemReqSizeOutput[1:0]` | store 数据、按地址起始字节排序的使能位、访问大小编码 `0/1/2=1/2/4B`。 |
| 输入 | `dmemRspValidInput`, `dmemRspRdataInput[31:0]` | Load读取响应；Store退休只等地址/数据，不等待请求接受或写响应。 |
| 输出 | `commitValidOutput`, `commitPcOutput[31:0]`, `commitInstrOutput[31:0]` | ROB 头**实际提交**的单条指令及其 PC/原始机器码。 |
| 输出 | `commitRdValidOutput`, `commitRdOutput[4:0]`, `commitRdValueOutput[31:0]` | 本次提交是否更新非零架构寄存器；目的寄存器号和来自 PRF 的值。 |
| 输出 | `commitMemValidOutput`, `commitMemAddrOutput[31:0]`, `commitMemDataOutput[31:0]`, `commitMemWstrbOutput[3:0]` | 本次实际退休Store的SQ目标载荷，来自storeRetirementOutput；不取同拍发送旧Store的内存请求。 |
| 输出 | `haltedOutput`, `trapOutput` | HALT提交闩锁停issue，SQ写请求全部接受后输出halted；异常提交闩锁trap。复位清除。外层Cache另负责其排空。 |

发射只有在IQ有效、ROB/目标RS/LSQ可分配且需要时PRF有空闲才发生。四路写回对应
ALU/Load/MUL/DIV，BRU和SQ就绪只占ROB完成口。Store的commitReady受LSU目标就绪
门控，不再受dmemReady门控；提交和发送可同拍，也可在背压下先提交后发送。

## 2. 重命名状态：`rv32_rat` / `rv32_prf`

第4步基础重命名/提交/恢复域已与两软件树按FIFO策略对齐：三端与独立oracle
1293步/2586点、420字段全部一致，包含48项自由队列顺序和全部32个ROB tag查询。
RTL容量/集成10/10通过；STORE/LINK/HALT及异常的专门三端刺激按后续步骤扩展。

### `rv32_rat`

源码：[`rv32_rat.sv`](../verilog/rtl/backend/rv32_rat.sv)。组合读映射；有投机映射 `mapInner` 和提交映射 `archInner`。

| 方向 | 端口 | 含义 |
|---|---|---|
| 输入 | `clkInput`, `rstNInput` | 状态时钟/复位；复位后架构号映射到相同物理号。 |
| 输入 / 输出 | `readInput: rat_read_input_t`, `readOutput: rat_read_output_t` | 两个源架构寄存器 → 对应物理标签；`x0` 强制返回 0。额外debug读口已清理。 |
| 输入 / 输出 | `renameInput: rat_rename_input_t`, `renameOutput: rat_rename_output_t` | `valid` 时为 `architecturalRegister` 建立 `physicalRegister` 映射；组合返回被覆盖的旧物理标签供 ROB 记录。 |
| 输入 | `restoreInput: rat_restore_input_t`, `replayInput[ROB_ENTRIES]: rob_replay_entry_t` | `squashTag/headTag` 指定存活窗口；以提交映射为起点重放 ROB 中到边界为止的改名。 |
| 输入 | `commitInput: rat_commit_input_t` | 提交时更新架构态映射。 |

### `rv32_prf`

源码：[`rv32_prf.sv`](../verilog/rtl/backend/rv32_prf.sv)。参数 `PRF_DEPTH=48`、`ROB_DEPTH=16`；从**FIFO自由队列队首**选物理号，0不分配，三组合读口、四写回口。

复位时队列为P32..P47；7-bit epoch+slot序号在物理槽47后翻转epoch并回到槽0，
跳过48..63的填充编码。freeCount由实际48槽环的距离派生。成员集合仅在非综合
时钟断言内局部推导，不保留组合观察bitmap。分配读取旧队首，本拍新回收项
下一拍参与分配。squash阻止分配，并按ROB年龄从旧到新追加边界之后的newPhy；
同拍提交释放的oldPhy最后追加。P0、重复释放、越界及队列溢出由仿真断言检查。

| 方向 | 端口 | 含义 |
|---|---|---|
| 输入 | `clkInput`, `rstNInput` | 值/就绪/FIFO自由队列的时钟和异步复位。 |
| 输入 / 输出 | `allocationInput: prf_allocation_input_t`, `allocReadyOutput`, `allocPhyOutput: phy_tag_t` | `valid` 消耗当前可分配物理号；`valueValid/value` 允许跳转链接值在分配时即就绪；恢复时 `allocReady=0`。 |
| 输入 | `freeInput: prf_free_input_t` | ROB 提交后释放旧物理标签（0 不释放）。 |
| 输入 | `restoreInput: prf_restore_input_t`, `restoreCountInput[$clog2(ROB_DEPTH+1)-1:0]`, `replayInput[ROB_DEPTH]: rob_replay_entry_t` | 冲刷时从有界存活 ROB 窗口找出年轻项的新物理号回收，不回收边界本身。 |
| 输入 / 输出 | `readInput[3]: prf_read_input_t`, `readOutput[3]: prf_read_output_t` | 每个端口给物理号、组合返回 `ready/value`；物理 0 恒就绪且值为零。 |
| 输入 | `writebackInput[4]: cdb_result_t` | 4 路有效广播写入数据并置就绪；core 对失效/错路结果先做认证与门控。 |
| 输出 | `readyVectorOutput[PRF_DEPTH-1:0]`, `freeCountOutput[$clog2(PRF_DEPTH+1)-1:0]` | 每个物理寄存器就绪位及当前空闲数。 |

## 3. ROB：`rv32_rob`

源码：[`rv32_rob.sv`](../verilog/rtl/backend/rv32_rob.sv)，参数 `DEPTH=16`。按序提交的持久条目保存原始指令、PC、新旧物理目的、store 槽、异常、预测 PC 和检查点等；只有头项完成才能提交。下表 `数组[数量]` 表示该模块端口一次接收/输出的 packed 数组元素数。

| 方向 | 端口 | 含义 |
|---|---|---|
| 输入 | `clkInput`, `rstNInput` | 状态时钟和异步低有效复位。 |
| 输入 / 输出 | `allocInput: rob_allocation_input_t`, `allocReadyOutput`, `allocTagOutput: rob_tag_t` | 分配整条 ROB 元数据，`valid && allocReady` 写入尾项；输出将分配的完整循环标签。 |
| 输入 | `completionInput[6]: rob_completion_t` | 普通完整tag完成事件；core依次为ALU、load、MUL、DIV、BRU、零。异常仍只接受0/4号口。 |
| 输入 | `storeReadyInput: store_completion_output_t` | `readyMask/epochMask`批量Store完成；按公共tag完整slot索引，验证旧有效Store和epoch，flush仅严格更老。 |
| 输入 | `flushInput: rob_flush_input_t` | 清除严格年轻条目，尾指针回到边界后一项；边界保留，同时更老头项可提交。 |
| 输入 / 输出 | `lookupInput[5]: rob_lookup_input_t`, `lookupOutput[5]: rob_lookup_output_t` | 根据完整 tag 查存活身份；前两路还输出 PC、预测 PC、checkpoint、return 标记用于控制流解析，所有路的 `valid` 均做完整 tag 匹配。 |
| 输出 | `commitOutput: rob_commit_output_t`, `commitStoreOutput` | 就绪的 ROB 头元数据、是否 store；头项未完成时 `commitOutput.valid=0`。 |
| 输入 / 输出 | `commitReadyInput`, `commitFireOutput` | 提交握手 `commitOutput.valid && commitReadyInput`；store 由 LSU 请求 ready 门控。 |
| 输出 | `statusOutput: rob_status_output_t`, `countOutput[$clog2(DEPTH+1)-1:0]` | 空/满/头标签和有效条目数。 |
| 输出 | `replayOutput[DEPTH]: rob_replay_entry_t` | 按当前 head 顺序读取整个窗口，供 RAT/PRF/RAS 恢复；消费侧须按存活计数和 tag 验证。 |

## 4. 保留站：`rv32_rs`

第5步flush策略已按用户决定统一：严格更老且已就绪者在执行端ready时可派发，
边界保留但不派发、年轻者取消，新分配禁止；flush时接受的槽同样释放。1131步/
2262点Integer三端正常操作数/flush域通过。执行端ALU/MUL/DIV/BRU同时捕获更老
输入，受阻更老输出保留；core AGU/StoreValue按年龄放行，LSU接收更老地址/数据。
真实RS→ALU及执行端/LSU恢复接收测试、RTL11/11通过，见sync/README.md第17节。

源码：[`rv32_rs.sv`](../verilog/rtl/backend/rv32_rs.sv)。core实例化七份并按公共包容量配置。
RTL保存源值/ready；写回拍捕获、下一拍可派发，不提供广播拍依赖派发。最老ready按ROB年龄选择。

| 方向 | 端口 | 含义 |
|---|---|---|
| 输入 | `clkInput`, `rstNInput`, `flushInfoInput: rob_flush_input_t` | 时钟/复位，冲刷时删除年轻项并停发新项。 |
| 输入 / 输出 | `allocInput: rs_allocation_input_t`, `allocReadyOutput`, `allocAuxInput[AUX_W-1:0]` | 发射时携带操作、两个源 `Ready/Tag/Value`、目的标签及 PC；`valid && allocReady` 占槽，辅助位保存控制流类型或访存槽号。 |
| 输入 | `writebackInput[4]: cdb_result_t` | 用有效写回的物理标签/值旁路并唤醒源操作数。 |
| 输出 / 输入 | `issueOutput: rs_issue_output_t`, `issueReadyInput` | 最老的源就绪项及实际操作数；`valid && ready` 出槽。 |
| 输出 | `issueAuxOutput[AUX_W-1:0]`, `occupancyOutput[$clog2(DEPTH+1)-1:0]` | 被选项附加位和当前占槽数。 |

Load/StoreAddr的aux保存类别与LSQ槽号；StoreValue的aux保存SQ槽号，其就绪数据通过
`storeDataInput/storeDataIndexInput`送LSU，按完整ROB tag认证。SQ直接CDB路径仅供独立
LSU接口使用，core的StoreValue路径以dataTag=0禁用该直接唤醒。

## 5. 执行模块接口

第9步MUL现状模块对拍1919步/3838点19字段，正常恒授权核域1877步三端一致；三级
对应n拍partial、n+1 CSA、n+2 CPA结果、n+3 CDB。软件4输出槽及等边界取消语义与RTL
弹性保持不同，背压下软件有在途槽溢出；当前core outReady=1，不能把诊断当正常核错误。
完整返回链/缓冲准入合同待定，见公共SPEC §37；本轮生产RTL未改。

第8步当前对齐控制链已验收：软件BRU结果显式actualTaken，RTL保留真实条件结果语义，
真实RS/RAT/PRF/ROB/执行/BPU/提交恢复1518步2230字段一致；用户排除misAlign。当前无call/return
RAS及前端Cache，边界见公共SPEC §35。仿真须展开256/512项NBA复位循环以获得正确PHT初值。

第8步现状入口run_control_observe.py观察真实BRU/控制ALU/PRF/FlushArbiter，2374步/
4748点56字段；对齐PC结果及n/n+1/n+2一致，PC+4分支训练方向与软件不同，未对齐目标
恢复PC/资格也不同。目标草案见公共SPEC §34，单槽BRU与训练输入建议尚未改变生产实现。

AGU地址载荷已包含其寄存robTag，core直送LSU用于目标身份匹配；共享地址整链1195步/
2390点200字段与两软件及独立参考一致。consumer提交、StoreValue生产及Cache返回按后续步骤验收。

`execute_request_input_t` 携带 `valid/operation/source1/source2/immediate/programCounter/predictedNextProgramCounter/useImmediate/robTag/destinationPhy/isControl/isCall/isReturn`。单元以 `executeInput.valid && inReadyOutput` 接收；带 `outReadyInput` 的结果在 `executeOutput.valid && outReadyInput` 时被消费。core 当前把 ALU/MUL/DIV 的 `outReadyInput` 固定为 1，仍以完整 ROB 标签和 flush 年龄门控写回。组合原语没有 valid/ready；它们的结果只在外层单元请求有效时有事务意义。

| 模块 | 输入端口 | 输出端口 | 功能与时序 |
|---|---|---|---|
| [`rv32_alu`](../verilog/rtl/execute/rv32_alu.sv) | `aluInput: alu_operation_input_t` | `aluOutput: alu_operation_output_t` | 组合整数运算、移位、比较及 JAL/JALR 目标；JALR 清目标 bit0。加减法使用 `rv32_add`/`rv32_sub`；后者复用前者，底层逐级组合 `rv32_cla2`、`rv32_cla4`、`rv32_cla8`、`rv32_cla16`、`rv32_cla32`、`rv32_cla64`。 |
| [`rv32_alu_unit`](../verilog/rtl/execute/rv32_alu_unit.sv) | `clkInput`, `rstNInput`, `flushInfoInput: rob_flush_input_t`, `executeInput: execute_request_input_t`, `outReadyInput` | `inReadyOutput`, `executeOutput: alu_execute_output_t`, `occupancyOutput` | 封装组合 ALU 的**单槽同拍腾位**结果寄存器：一次拍运算、次拍上 CDB，本拍被授权/冲刷释放的槽**当拍**即可复用（drain-and-refill），因此 `inReady = !valid || outReady || flushed`、一条/拍无需多槽。返回数值、ROB/物理目的标签、`isControl/controlMisaligned`。历史负向延迟释放开关已删除。 |
| [`rv32_agu_unit`](../verilog/rtl/execute/rv32_agu_unit.sv) | `clkInput/rstNInput`, `flushInfoInput`, `executeInput: rs_issue_output_t`, `auxiliaryInput[3:0]` | `inReadyOutput`, `addressOutput`, `auxiliaryOutput`, `robTagOutput`, `resultValidOutput` | 单槽地址结果级：派发拍32-bit加法/拍末保存，次拍向LSU交付地址与寄存类型/槽号；已有LSQ槽的地址更新无容量背压，一条/拍。旧/新tag分别判断flush资格。 |
| [`rv32_bru`](../verilog/rtl/execute/rv32_bru.sv) | `branchInput: branch_operation_input_t` | `branchOutput: branch_operation_output_t` | 组合条件比较、实际 nextPC、链接值、误预测/目标未对齐检测。 |
| [`rv32_bru_unit`](../verilog/rtl/execute/rv32_bru_unit.sv) | `clkInput`, `rstNInput`, `flushInput`, `executeInput: execute_request_input_t` | `inReadyOutput`, `executeOutput: bru_execute_output_t` | 一拍登记 BRU 结果；`inReady=!flushInput`，输出含 PC/目标/taken/条件分支/预测错误/未对齐/call/return，无独立输出 ready。 |
| [`rv32_mul`](../verilog/rtl/execute/rv32_mul.sv) | `clkInput`, `rstNInput`, `flushInfoInput: rob_flush_input_t`, `executeInput: execute_request_input_t`, `outReadyInput` | `inReadyOutput`, `executeOutput: execute_value_output_t` | radix-4 Booth + CSA + 最终加法，三级可背压流水；低 32 位给 `MUL`，高 32 位给 `MULH/MULHSU/MULHU`。`inReady` 由三级空闲/下游 ready 连锁决定。 |
| [`rv32_div`](../verilog/rtl/execute/rv32_div.sv) | `clkInput`, `rstNInput`, `flushInfoInput: rob_flush_input_t`, `executeInput: execute_request_input_t`, `outReadyInput` | `inReadyOutput`, `executeOutput: execute_value_output_t` | 单上下文 radix-4 SRT 迭代除法；`PH_PREP/PH_LOOP/PH_FINISH`，busy 或未消费的结果阻止新请求；除零、溢出及简单比较走短路径。 |

`rv32_mul` 和 `rv32_div` 的结果都携带完整 `robTag/destinationPhy`；冲刷时年轻/边界指令的结果失效，存活老指令可继续完成。BRU 条件结果不直接写 PRF，而是供 ROB 完成、误预测仲裁和预测器训练；JAL/JALR 走 ALU 控制路径，PRF 在发射时可预置链接地址 `PC+4`。

## 6. 恢复仲裁：`rv32_flush_arbiter`

源码：[`rv32_flush_arbiter.sv`](../verilog/rtl/core/rv32_flush_arbiter.sv)，参数 `DEPTH=4`。记录分支与跳转误预测候选，按 ROB 年龄选最老请求广播。

| 方向 | 端口 | 含义 |
|---|---|---|
| 输入 | `clkInput`, `rstNInput` | 候选队列时钟和复位。 |
| 输入 | `branchInput: flush_candidate_input_t`, `jumpInput: flush_candidate_input_t` | BRU/ALU 检出的误预测或未对齐候选，包含 `valid/robTag/programCounter/checkpointId`。 |
| 输出 | `squashOutput: squash_input_t` | 已排队的最老候选：ROB 边界标签、重取 PC、预测检查点。 |

仲裁器输出来自队列中的旧状态；新候选在时钟沿入队，不要把检测候选当拍误读为当拍立刻输出。广播恢复会丢弃边界及更年轻的待处理候选，同时各单元以自身的 flush 输入清理错路状态；前端根据 `programCounter` 重定向，预测器根据 `checkpointId` 恢复历史。

## 7. 接口检查点

- 同一周期至多发射一条、ROB 至多提交一条；五类 RS 能各自寻找就绪执行项，执行完成可经多路总线并行写回。
- 恢复、CDB 与 ROB 查询都要保留 **完整 tag 身份**；仅靠低位槽号可能误认复用槽的旧结果。
- `rv32_agu` 的组合地址接口及 `rv32_lsu` 的 LQ/SQ、存储器握手在 [访存](memory.md) 说明；缓存命中和脏行写回在 [缓存](cache.md) 说明。
