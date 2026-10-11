# RTL 访存：AGU、LSU 和处理器侧数据请求

当前SPEC §63/64：第12/13补验真实满LQ/SQ、SV目标/批量ready、地址/数据先后/
跨Cache字节与恢复通过。消费event要按LSU descending实际输入匹配，不能直接
配core ascending同数字lane。完整24镜像无损逐拍/最终128KiB全等，README §56。

当前SPEC §62：core halted仅表示HALT提交且SQ已接受完，最终完成归外层backend；
它等旧Cache/外存结束、扫描全部dirty并等最后真实写完成。16程序9629/2872及
最终128KiB核验/DONE保持16拍/7负向通过，core/IPC与drain分段见sync/README §54。

当前SPEC §61：真实全流水恢复67程序9001/2872三端严格一致，11源码负向有效。
LSU Store分配旁路仅允许非零dataTag匹配WB；core的dataTag0表示等待StoreValue，
不能由NOP/P0写回提前置dataReady。旧源码负向step30 ready1/正确0，已修复。
已提交SQ保留/迟到取消Load排空与复用通过；后端4803/764保持，README §53。

当前SPEC §60：BTB实际26程序6690/1848及参数合同通过，关联访存后端4803/764
与六实际源码负向、RTL16项重新通过。下一第18步多恢复请求/所有FU及LSQ联合
取消、迟到结果与复用验证，入口sync/README §52。

当前SPEC §59：真实CPU/RAS/checkpoint13,041拍1848字段三端严格同值，实际取指/
IMEM/公共SRAM I$提供身份，GHR32槽CID一次接受一次分配，年轻取消及完整栈内容
恢复通过。访存后端4803/764＋六负向/RTL16项保持；IPC新691640，README §51。

最新SPEC §58：I$ data使用公共真实SRAM、tag寄存器，实际IMEM16槽/20拍逻辑行环境
与两软件/RTL2324步160字段全等；前端2259/216严格、真实core/SRAM I$程序通过。
指令恢复清逻辑队列并保持Cache，物理已接受运输的丢弃/排空仍由总线适配器处理。
D$后端4803/764严格回归保持，软件/golden不改，入口README §50。

最新SPEC §56：实际四RS/ALU/AGU/LSU/寄存器D$/DMEM/共享RAT/PRF/ROB/退休联合
4803步28组，763语义字段三端一致，原始Store完成位编码差另记诊断。47返回/下一读、
满队列/ROB回绕、实际已接受错路miss/旧响应丢弃/复用及四实际RTL负向通过。正常
运行至退休的访存后端已联合验收，不含完整前端/最终全dirty flush，入口README §48。

最新SPEC §55：D$改为寄存器、命中一拍响应，双读写接口与实际软件DMEM时序一致，
6378/14模块对拍通过。LSU先消费旧响应，再捕获同拍新读，pending描述符不会被旧
响应清掉；取消旧响应仍消费、tag/宽度/符号仍冻结。真实Cache4组中full实际12次
同拍owner重填，旧气泡实际负向拒绝；下方旧单pending气泡/部分拼接是历史，README §47。

最新SPEC §54：RTL查询未知地址规则已按软件统一，最年轻完整覆盖候选可支配更老
未知写，但候选之后的未知写仍阻塞。Cache准入仍独立保守检查未知地址及任何未提交
字节重叠。22 suite2443/323三端严格全等、架构正确；独立4993步30 suite、五个实际
负向、core12/12、真Cache4及生命周期/四路/RTL14通过。LSU后端当前范围已同步，
完整三端Cache/整核周期仍另验。下方§53的唯一差异属于历史，入口sync/README §46。

最新SPEC §53：RTL已按(A)改为最年轻字节重叠来源必须独自完整覆盖，不再逐字节拼接
或保存部分转发掩码合并返回。查询转发与Cache准入分开，部分覆盖等Store实际接受后
读Cache。Load地址交付查旧SQ；Store通知同起点同宽度、旧另一字段就绪，并保留软件
年轻同word/未知项守卫。所有匹配LQ并行落值，无双新字段旁路或稳态扫描fallback。
22 suite三端21/22逐拍一致，唯一剩余为未知地址阻塞点②；架构全正确。独立4818/
323共29 suite、12镜像、Cache4组、四路3648、LQ1432/SQ872及RTL14项通过。
下方拼接/部分合并和旧架构错值是历史版本记录，当前以§53及sync/README §45为准。

最新§50将真实DCache同步SRAM与行内存接入core功能整链，4组正常程序及2真实
负向通过。LSU读token在接受时冻结tag/size/unsigned；外层rv32_dmem_backend先
完成最后Cache事务，再写回脏行，最终结束看drainDone而非裸core halted。
原4499独立时钟模型/8镜像、四路3648和RTL14项保持通过，软件源码只读。

最新§49将正常core扩展到偏移半字和不重叠字节，共8/8正确；RTL4499步323字段
26 suite独立参考全等。软件同word查询只能筛候选，不能替代字节覆盖和数据偏移，
当前主树该版本仍有5个架构错值；三端共同范围未闭合，证据见README §41。

扩展整链§48已验证地址后到、查询旧SQ和反向宽度覆盖等新增路径：RTL4395步323
字段25 suite全等，正常core地址/查询镜像扩展后6/6正确。用户主树地址通知宽度和
_DEBUG已修，仍有旧地址覆盖判定与起始地址筛选的实际错值，不能以RTL验收代替
三端共同闭合；README §40保留当前评估命令与产物。

当前RTL事件转发整链已验收（2026-10-09，SPEC §47）：Load地址交付查询拍初SQ、
Store数据/地址通知要求拍初另一字段已就绪，同拍末更新所有合格LQ项，最早下一拍
CDB。保持字节覆盖/扩展/合并、未知地址阻塞及旧态扫描fallback；禁止两个新字段
同拍互相旁路。4031步323字段22 suite独立参考全等，core4/4、RTL14/14及四路链
通过。主树原SB已由用户修复，仍有偏移覆盖/地址通知宽度问题；下面§46为历史观察。

最新Store/Load转发现状见SPEC §46：真实来源链1338步323字段两软件全等，RTL在
word转发拍、逐Load扫描、更老未知地址阻塞和字节范围上不同。正常DIVU→SB→
LBU/LB/LW两完整软件CPU提交错值，RTL相同七指令3/3正确；软件缺少覆盖/扩展/合并。
本轮仅观察，SQ退休合同保持§45；具体例子sync/STORE-FORWARD-DIFFERENCES.md，
不能因该字节功能例正确就称完整三端Cache/转发周期等价。

SQ已按软件统一posted Store合同（SPEC §45）：原SQ保存committed项，ROB退休不等
内存ready，SQ队首实际请求接受才释放；独立epoch头尾维护顺序及恢复前缀，已提交项
跨ROB回绕/恢复保留。storeRetirementOutput独立提供ROB队首载荷，core提交跟踪不再
取实时发送请求。LQ1432步816字段、SQ872步340字段四方一致，RTL14/14含真实整核
背压、四Load转发、回绕/恢复、退休发送身份及HALT等待SQ接受；完整Cache/字节共同域另验。

以下§42～46开头记录为阶段历史，当前SQ生命周期见§45，RTL事件转发见§47。

当前LQ已三端统一ROB实际提交同拍释放（公共SPEC §44）。CDB消费设置lqBroadcasted，
保留条目但不重复结果；新增robRetireInput接实际ROB提交valid/tag回收匹配活动项。
满队列实测CDB15、commit/release16、下一分配17，1432步816字段四方一致；Store策略待定。

主树LQ第一项旧响应覆盖新分配已修复（公共SPEC §43）：初始化后置，三端正确数据
及实际旧源码负向通过，RTL无需修改。LQ释放/Store提交接收两项合同差异仍在§42待定版。

历史第12步生命周期观察（公共SPEC §42）：LQ1365步816字段、SQ565步272字段。RTL Load
消费时释放，比软件满队列早2拍腾位；Store提交绑定下游接收，软件可先提交并缓冲。
主树同拍分配/旧返回错误写架构x20，模板/RTL正确。本轮未改生产RTL，策略仍待共同定版。

源码：[`rv32_agu.sv`](../verilog/rtl/execute/rv32_agu.sv)、[`rv32_agu_unit.sv`](../verilog/rtl/execute/rv32_agu_unit.sv)、[`rv32_lsu.sv`](../verilog/rtl/memory/rv32_lsu.sv)。公共结构体的字段/大小编码见 [package.md](package.md)；ROB 和访存 RS 的分配、store 提交来自 [后端](backend.md)，核外行级请求及 D$ FSM 见 [缓存](cache.md)。

```
单发射 ─► LQ/SQ 空槽分配 ─► 访存 RS(base,offset,槽号)
                                  │ 地址就绪
                        rv32_agu_unit 单槽 ─► LQ/SQ 地址
                                   SQ 数据 ◄── StoreValue RS（CDB寄存唤醒）
                             │                  │
        SQ 逐字节转发 ────────┤                  └── store ready → ROB
                             ▼
       最老可发 load / SQ 头 posted store ─► 32 位 dmem 请求 ─► DCache/核外内存
                    load 结果 ─► PRF/ROB           （核外行接口由 cache 负责）
```

默认LQ/SQ各8槽全部可用。LQ以有效位/first-free找空位，SQ以4-bit epoch头尾指针
维护FIFO，已提交Store仍占用原槽。未提交身份使用完整ROB tag和物理槽，已提交项
顺序不依赖ROB年龄窗口；地址和数据独立就绪。LSU上升沿更新、异步低有效复位，AGU原语纯组合。

## 1. `rv32_agu`：地址生成

| 方向 | 端口 | 含义 |
|---|---|---|
| 输入 | `addressInput: address_generation_input_t` | `baseAddress`（就绪源寄存器的 32 位值）和符号扩展 `offset`。 |
| 输出 | `addressOutput: address_generation_output_t` | `address = baseAddress + offset` 的 32 位**字节地址**。 |

该原语无状态、无valid/ready，仅计算32-bit模加法。core通过下面的结果级登记地址与身份，
下一拍交付LSU；不再由当前RS派发的组合地址直接更新LSU。

### 1.1 `rv32_agu_unit`：单槽结果级

| 方向 | 端口 | 含义 |
|---|---|---|
| 输入 | `clkInput/rstNInput`, `flushInfoInput` | 时钟、低有效复位、完整ROB恢复边界。 |
| 输入 | `executeInput: rs_issue_output_t`, `auxiliaryInput[3:0]` | 就绪基址/偏移/ROB tag，及`{isStore, LSQ_slot[2:0]}`。 |
| 输出 | `inReadyOutput` | 恒1：issue已经预留LSQ槽，旧地址每拍交付或取消，不因LQ/SQ满停收。 |
| 输出 | `addressOutput: lsu_address_input_t`, `auxiliaryOutput[3:0]` | 寄存地址/类型/索引；valid按寄存ROB tag通过flush年龄门。 |
| 输出 | `robTagOutput`, `resultValidOutput` | 保存的ROB tag与原始槽有效位，后者不等同于flush门控后的交付有效位。 |

n拍组合加法并在拍末保存，n+1拍交付/拍末更新LSU地址ready，n+2拍可见。一槽支持同拍
交付重填；旧年轻结果取消不得覆盖新更老结果。core的LSU地址索引接寄存aux，不能接当前
RS的aux。`run_agu.py`模块3182步四方一致；`tb_agu_lsu`验证满队列与16目标的真实接收。
共享RS→AGU→LSQ地址整链1195步/2390点200字段已四方一致；地址载荷新增寄存生产者robTag，
LSU接收匹配旧活动槽或本拍实际分配的同槽同tag，错身份不写地址/ready。WB及StoreValue为
上游输入，consumer提交/内存返回不在此链驱动域；完整生命周期按第12～15步追踪（SPEC §33）。

## 2. `rv32_lsu`：队列及对外接口

参数：`LQ_DEPTH=rv32_pkg::LQ_ENTRIES`、`SQ_DEPTH=rv32_pkg::SQ_ENTRIES`，默认均为 8。

| 方向 | 端口 | 含义与有效条件 |
|---|---|---|
| 输入 | `clkInput`, `rstNInput`, `flushInfoInput: rob_flush_input_t` | 时钟/复位；`valid/robTag` 使年轻 LQ/SQ 项无效，并将已发出的错路 load 响应标记为待丢弃。 |
| 输入 / 输出 | `loadAllocationInput: load_allocation_input_t`, `loadAllocReadyOutput`, `loadAllocIndexOutput[$clog2(LQ_DEPTH)-1:0]` | `valid && ready` 分配 LQ 槽；载荷为 `robTag/destinationPhy/size/isUnsigned`。索引交访存 RS，用于之后写地址。 |
| 输入 / 输出 | `storeAllocationInput: store_allocation_input_t`, `storeAllocReadyOutput`, `storeAllocIndexOutput[$clog2(SQ_DEPTH)-1:0]` | `valid && ready` 分配 SQ 槽；携带 store 大小以及 `dataReady/dataTag/dataValue`。 |
| 输入 | `storeDataInput: store_data_input_t`, `storeDataIndexInput` | 独立StoreValue RS的valid/robTag/value与SQ索引，完整tag匹配后拍末写数据就绪。 |
| 输入 | `addressInput: lsu_address_input_t`, `addressIndexInput[max($clog2(LQ_DEPTH),$clog2(SQ_DEPTH))-1:0]` | `valid/isStore/robTag/address`与槽号定位目标；匹配旧存活条目或同拍实际匹配分配，flush按生产者tag过年龄门。 |
| 输入 | `writebackInput[4]: cdb_result_t` | 以物理标签比较唤醒尚未就绪的 SQ 数据；分配拍也可旁路同拍写回值。 |
| 输出 / 输入 | `loadResultOutput: load_result_output_t`, `loadResultReadyInput` | 最老的已完成且未广播load；`valid && ready`标记已广播并写PRF/ROB，不回收LQ。 |
| 输入 | `robRetireInput: rob_retirement_input_t` | 实际ROB提交`valid/robTag`，回收匹配LQ项；匹配Store退休提议时置SQ committed，不释放SQ。 |
| 输出 | `storeCompleteOutput: store_completion_output_t` | 所有拍初有效、地址/数据齐且未提交Store译码为`readyMask/epochMask`；ROB鉴权后同拍末批量置ready，无reported寄存器。这不是D$写接受确认。 |
| 输入 / 输出 | `storeCommitInput: store_commit_input_t`, `storeCommitIndexInput[$clog2(SQ_DEPTH)-1:0]`, `storeCommitReadyOutput` | ROB队首Store退休提议；活动未提交目标、完整tag、地址/数据和恢复资格匹配即ready，与dmemReady无关。实际robRetireInput才置committed。 |
| 输出 | `storeRetirementOutput: data_memory_request_output_t` | ROB队首目标的退休载荷，valid表示提议匹配；core用实际commitFire使能跟踪，地址/数据/strobe与发送旧Store独立。 |
| 输出 / 输入 | `dmemRequestOutput: data_memory_request_output_t`, `dmemReqReadyInput` | 至多一个 32 位处理器侧请求；`valid && ready` 被内存系统接受，store 优先于 load。 |
| 输入 | `dmemResponseInput: data_memory_response_input_t` | 已发 load 的 `valid/readData`；只有一个待返回 load，错路返回须消费但不写入 LQ。 |
| 输出 | `lqCountOutput[$clog2(LQ_DEPTH+1)-1:0]`, `sqCountOutput[$clog2(SQ_DEPTH+1)-1:0]` | 各自当前有效槽数，容量上限即参数指定深度。 |

端口上的 packed 数组 `writebackInput[3:0]` 在 core 中依次对应 ALU、load、MUL、DIV。`loadAllocIndexOutput` / `storeAllocIndexOutput` 是空槽候选索引，仅在相应分配握手时才代表新条目身份。

## 3. 字节转发、消歧与请求仲裁

事件路径先并行评估每个LQ活动项，完整覆盖才写READY；新Load地址查旧SQ，Store
通知使用当前到达的一个字段和旧态的另一字段。多个项可同拍得到注册结果，CDB只
选旧READY项；未转发的读按独立Cache准入规则发送，不锁存部分覆盖掩码。
已有READY结果丢弃迟到读载荷，已接受读的pending无论恢复/已转发都必须消费清除。

1. Load地址查询选择最年轻的实际字节重叠Store；该单一来源必须完整覆盖且数据就绪，不能跳过年轻部分覆盖项找老完整来源。候选须比最后未知地址项年轻。
2. 已提交Store始终作为更老项参与，按SQ FIFO位置选最新来源；不能用已退休ROB tag比较。采用(A)单源完整覆盖，不多源拼接或部分内存合并。
3. 转发失败后，更老未提交Store地址未知或任意字节重叠都会阻塞Cache请求；准入用实际1/2/4B。返回按`MEM_BYTE/HALF/WORD`与`isUnsigned`扩展；`writeStrobe`按原始地址起始字节排列。
4. SQ队首已提交或本拍实际退休时优先发写；否则选择未阻塞Load。ROB退休不等请求接受，`valid && dmemReqReadyInput`才清SQ队首并推进head。可同拍退休/发送；满时仍旧full拒收，下拍受理。Store载荷含原始字节地址、数据、1/2/4B和`0001/0011/1111`使能。
5. LSU内pendingInner限制为一个在途Load；接受时冻结slot/tag/size/unsigned。
   恢复按冻结tag判定旧事务，返回按冻结宽度/符号解释，并验证活动槽完整tag匹配且未
   READY才写结果。错路响应也消费清pending，不能用被复用的当前槽内容重解释旧读。

`storeCompleteOutput`只意味着地址/数据已齐；对外Store在退休同拍或之后按SQ顺序握手。当前裸core
32位端口可接rv32_dmem_backend的真实DCache接口；旧包装已删除。容量统一没有改变
单pending。§50真实Cache整链和排空已通过，完整三端Cache FSM周期仍待对应专项。
