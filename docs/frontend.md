# RTL 前端：取指、指令队列、译码和分支预测

当前SPEC §63/64：完整活动18 ISA＋6 IPC在共同逻辑Memory的实际三CPU12667040
拍2872word無损逐拍、退休/最终128KiB/分段周期全等。错误路径非法opcode条目
元数据/异常ready已同步软件，恢复后不trap；课程AXI与未纳入异常另验，README §56。

当前SPEC §62：core bootDone门控复位释放后首拍请求/接受，保证无正常fetch/CID/
Issue/提交，之后PC0/CID0周期0。正常前端/执行流水保持；16真实程序9629/2872
与最终128KiB内存核验/7源码负向通过，HALT/core与最终dirty完成分段见README §54。

当前SPEC §61：真实请求检测→队列→最老广播与前端/BPU及全部后端67程序9001/
2872严格三端一致，11源码负向有效。前端恢复取消与GHR/CID/RAS内容同时检查，
本拍新请求不直通广播。第18当前对齐/共同逻辑存储域完成，第19计时继续；README §53。

当前SPEC §60：BTB tag/类型与target逐槽独立按fetch > jump CDB > taken BRU，
无静态target的JALR/RET早训练仍折叠解析target，无写者保持旧值，异槽独立，query
读旧态。26真实三CPU程序6690/1848全等，三类fetch/三源五种槽分组及七源码负向
通过。checkpoint32/联合64、RAS1..255所列边界、BTB2/8/16/64引脚合同和非法拒绝
通过；默认行为保持，第17当前域完成，第18全流水恢复继续。入口sync/README §52。

当前SPEC §59：用户JALR双link含同寄存器先pop再push；前端/Issue/提交/重放同规则，
checkpoint仍一次接受取指一次分配。完整实际三CPU33程序13041拍1848字段严格同值，
7真实源码功能负向核验栈内容恢复/同拍提交重放/优先级，报告README §51。

最新SPEC §58：真实SRAM I$／寄存器tag与软件形式前端已同步，I$/IMEM2324/160、
FetchUnit至decoded IQ2259/216四方严格全等，4＋3实际负向有效。预测/恢复输入是
该域给定边界，BPU内部闭环继续第17步。当前命令和报告见sync/README §50。

本文以 [`verilog/rtl/frontend/`](../verilog/rtl/frontend/) 和 [`verilog/rtl/predictor/`](../verilog/rtl/predictor/) 的 **SystemVerilog 模块端口**为准。端口使用的 `rv32_pkg` 结构体及字段见 [公共类型](package.md)；外部取指的两种连接方式见 [缓存](cache.md)。

```
查询 PC ──► rv32_predictor ──► 预测 nextPC / checkpointId
   ▲                                  │
   └── rv32_frontend ◄─ 指令响应 ◄────┘
          FQ → IQ ──► rv32_decoder ──► core 发射
                  解析跳转、训练预测器；冲刷重定向并丢弃错路响应
```

默认 FQ、IQ 各 **4 个有效槽**，使用 `rv32_epoch_fifo` 的3-bit epoch指针，不存独立count；
countOutput是tail-head派生值。3B共享FIFO满且真实pop时ready，无空队列直通或参数开关。
IQ满时可同拍出旧队首给Issue并补入旧FQ队首。前端保留4个已接受请求元数据，
按FIFO返回；准入按软件FQ.canAccept实际decode pop，I$返回保持到FQ真的接受。
预测PC/checkpoint随请求保存；每拍至多输出一条。时钟为上升沿，内部复位低有效异步。

§58取消未来FQ位置预留，返回有ready；真实消费可复用满I$请求槽。测试覆盖三级
队列满替换、FQ返回背压、HALT真正接收当拍停取与redirect逻辑取消/重启。

## 1. `rv32_frontend`：PC、FQ/IQ 与取指响应

源码：[`rv32_frontend.sv`](../verilog/rtl/frontend/rv32_frontend.sv)。参数 `FQ_DEPTH=4`、`IQ_DEPTH=4`、`REQUEST_DEPTH=4`、`RESET_PC=0`；count输出为组合占用，指针包含epoch。

| 方向 | 端口 | 作用 |
|---|---|---|
| 输入 | `clkInput`, `rstNInput` | 时钟与异步低电平复位；PC 复位为 `RESET_PC`。 |
| 输出 | `predictorQueryOutput: fetch_query_output_t` | `programCounter` 给 BPU 组合预测；`accepted` **仅在** `imemRequestOutput.valid && imemReqReadyInput` 时置位，使 BPU 为实际发出的取指分配检查点。 |
| 输出 | `fetchProgramCounterOutput[31:0]` | 独立旧PC寄存器连线，用于BPU查询/I$端口准入；不经过含accepted的packed总线。 |
| 输入 | `predictionInput: prediction_output_t` | `nextProgramCounter/taken/checkpointId`；请求握手时锁存预测下一 PC、检查点并推进 PC。 |
| 输出 + 输入 | `imemRequestOutput: instruction_memory_request_output_t`, `imemReqReadyInput` | `valid/address/预测PC/checkpoint` 发出指令请求；按ready接受，地址为字节PC。 |
| 输入 + 输出 | `imemResponseInput: instruction_memory_response_input_t`, `imemRspReadyOutput` | 顺序返回valid/instruction，只有实际ready才消费/释放身份并进FQ。 |
| 输出 | `imemFlushOutput` | 逻辑请求取消，接I$/指令行环境flush；运输级旧事务由总线适配器排空。 |
| 输入 | `redirectInput: redirect_input_t` | 清FQ/IQ及请求身份，设置新PC，取消旧逻辑取指请求。 |
| 输出 + 输入 | `instructionOutput: fetch_queue_output_t`, `iqReadyInput` | IQ 队首 `valid/payload`；`valid && iqReadyInput` 才出队交后端，payload 含指令、PC、预测 PC、检查点。 |
| 输出 | `fetchInfoOutput: predictor_fetch_info_t` | 对**上一拍入 FQ**的 JAL/JALR 预译码：`isCall/isReturn`、静态 `jalTarget` 与 `jalTargetValid`，用于 BTB/RAS。 |
| 输出 | `fqCountOutput`, `iqCountOutput` | FQ/IQ 实际占用数，范围 `0..DEPTH`。 |

存活响应真实入FQ且为 `HALT_INSN=32'h0ff0_0513` 时锁存stopFetch，同拍禁止新请求；后续年轻响应
保持在I$中。redirect清FQ/IQ、清HALT/请求身份并通知逻辑取消；同拍旧响应不消费进FQ。
FQ非空且IQ可接收（含满时真实Issue）转移旧队首；硬件组合译码在IQ之后，软件decoded
IQ的共同载荷按实际译码值比较。HALT保留编码ADDI立即数255。

## 2. `rv32_decoder`：组合译码

源码：[`rv32_decoder.sv`](../verilog/rtl/frontend/rv32_decoder.sv)。**无时钟、无 ready**。

| 方向 | 端口 | 作用 |
|---|---|---|
| 输入 | `decodeContextInput: decode_context_t` | 指令字、当前 PC、预测下一 PC、检查点 ID。 |
| 输出 | `uopOutput: decoded_uop_t` | 指令类别/具体操作、寄存器号、源使用与写回位、符号扩展立即数、访存大小与无符号标志，以及原始预测上下文。 |

未知/不支持的编码默认 `illegal=1, uopClass=UOP_ILLEGAL`；停机字译为 `UOP_HALT`。后端只有在 `instructionOutput.valid` 时才消费组合译码输出；译码结果本身不表示 IQ 已握手。`JAL/JALR` 的分类信息沿 ALU/control 路径结算，条件分支走 BRU。

## 3. `rv32_predictor`：预测顶层

源码：[`rv32_predictor.sv`](../verilog/rtl/predictor/rv32_predictor.sv)。参数 `BHT_ENTRIES=256`、`BTB_ENTRIES=64`、`RAS_ENTRIES=32`、`CONDSEEN_ENTRIES=512`、`CKPT_ENTRIES=32`。

| 方向 | 端口 | 作用 |
|---|---|---|
| 输入 | `clkInput`, `rstNInput` | 预测表、历史和 RAS 状态的时钟/复位。 |
| 输入 + 输出 | `queryPcInput[31:0]`, `predictionOutput: prediction_output_t` | 组合查询当前 PC，返回 `taken/nextProgramCounter/checkpointId`；未命中目标时顺序 PC+4。 |
| 输入 | `fetchAcceptInput` | 取指**实际握手**信号；推进 checkpoint ID 和投机历史，而非单纯的查询有效。 |
| 输入 | `fetchInfoInput: predictor_fetch_info_t` | 前端对已取到的跳转做预译码，训练 BTB/推送或弹出投机 RAS。 |
| 输入 | `branchInput: branch_result_input_t` | BRU 条件分支结算；更新方向表与目标表，并使用对应检查点中的 GHR。 |
| 输入 | `jumpInput: jump_result_input_t` | ALU 侧 JAL/JALR 结算；训练跳转目标，不更新条件分支方向表。 |
| 输入 | `squashInput: squash_input_t` | 仲裁后的恢复边界、重定向 PC 和检查点；恢复 GHR / RAS 及检查点序号。 |
| 输入 | `robInput: rob_predictor_input_t` | ROB 头提交及存活窗口条目，供 RAS 的已提交态更新/恢复重放。 |

分支/跳转训练需要 `valid && robEntryLive`，且冲刷周期必须严格早于冲刷标签。方向预测的 taken 还需 BTB 命中；BTB 标记无条件时强制 taken。return 预测使用 RAS 栈顶；栈空时不采纳返回预测。

### 3.1 `rv32_bpu_direction`：方向表和 GHR

源码：[`rv32_bpu_direction.sv`](../verilog/rtl/predictor/rv32_bpu_direction.sv)。参数 `BHT_ENTRIES=256`、`CONDSEEN_ENTRIES=512`。

| 方向 | 端口 | 作用 |
|---|---|---|
| 输入 | `clkInput`, `rstNInput` | 三张方向表、condSeen 位图和 8 位 GHR 状态。 |
| 输入 | `queryPcInput[31:0]` | 查询 localPHT、`PC xor GHR` 索引的 globalPHT/selector、condSeen。 |
| 输入 | `branchInput: branch_training_input_t` | 按分支 PC、实际 taken 和该分支的检查点 GHR 更新两个 2-bit 饱和计数器；两路预测不同时更新 chooser。 |
| 输入 | `historyInput: direction_history_input_t` | `fetchAccepted/queryShift/queryShiftValue` 控制预测 GHR 移位；`squashValid/recoveryHistory` 在恢复时优先覆盖。 |
| 输出 | `predictionOutput: direction_prediction_output_t` | 条件分支方向、选全局位、已见条件分支位及当前 GHR。 |

### 3.2 `rv32_bpu_btb`：目标缓存

源码：[`rv32_bpu_btb.sv`](../verilog/rtl/predictor/rv32_bpu_btb.sv)。参数 `BTB_ENTRIES=64`，默认以 `PC[7:2]` 索引，表项保存上位 PC tag、`target[31:2]` 和 invalid/conditional/unconditional/return 状态；目标低两位还原为零。

| 方向 | 端口 | 作用 |
|---|---|---|
| 输入 | `clkInput`, `rstNInput` | 表项寄存器的时钟与复位。 |
| 输入 | `queryPcInput[31:0]` | 查索引/比较 tag。 |
| 输出 | `lookupOutput: btb_lookup_output_t` | `hit/unconditional/isReturn/target`；使用目标时须结合 `hit`。 |
| 输入 | `trainingInput: btb_training_input_t` | 前端静态 JAL/JALR 类型、执行阶段跳转目标、条件分支目标；同项写入按 fetch > jump > branch 仲裁。 |

### 3.3 `rv32_bpu_ras`：返回地址栈

源码：[`rv32_bpu_ras.sv`](../verilog/rtl/predictor/rv32_bpu_ras.sv)。参数 `RAS_ENTRIES=32`，
非环形有界depth，满push和空pop保持；投机、提交和重放三条路径都遵守边界。

用户JALR矩阵：push=rd属于x1/x5，pop=rs1属于x1/x5，两标志独立，双link即使相同
寄存器都pop后push。JAL只有rd，不读立即数字段为rs1。容量检查用pop后的depth，
满时双动作保持32并替换顶；查询读old顶。checkpoint只存GHR，RAS恢复完整提交
内容＋存活ROB含边界，不能只恢复depth。RTL先提交再跳过重放头项，恢复高于早事件。

| 方向 | 端口 | 作用 |
|---|---|---|
| 输入 | `clkInput`, `rstNInput` | 投机栈、已提交栈的时钟/复位。 |
| 输入 | `fetchInfoInput: predictor_fetch_info_t` | 两个独立动作：return先pop，call后push PC+4；双link标志可同时真。 |
| 输入 | `squashInput: squash_input_t` | 错路恢复：从已提交栈重建并重放存活 ROB 窗口。 |
| 输入 | `robInput: rob_predictor_input_t` | 提交的 call/return 更新架构栈；提供按序 ROB 指令用于重放。 |
| 输出 | `rasTopOutput[15:0]`, `queryRetTargetOutput[31:0]` | 投机栈深度/栈顶返回地址；栈空目标为 0。 |

### 3.4 `rv32_bpu_checkpoint`：取指历史快照

源码：[`rv32_bpu_checkpoint.sv`](../verilog/rtl/predictor/rv32_bpu_checkpoint.sv)。参数 `CKPT_ENTRIES=32`。这里只保存 **8 位 GHR** 快照；RAS 用已提交栈和 ROB 重放恢复。

| 方向 | 端口 | 作用 |
|---|---|---|
| 输入 | `clkInput`, `rstNInput` | 快照表和下一个 checkpoint ID 的时钟/复位。 |
| 输入 | `checkpointInput: checkpoint_input_t` | `fetchAccepted/globalHistory` 写当前 ID；`branchCheckpointId` 查训练历史；`squash.checkpointId` 查恢复历史并重置 ID 指针。 |
| 输出 | `checkpointOutput: checkpoint_output_t` | `branchHistory/recoveryHistory/nextCheckpointId`。 |
| 输出 | `nextCheckpointIdOutput: bpu_ckpt_id_t` | 独立旧ID寄存器连线，父模块预测ID不依赖含fetchAccepted的packed输入/lookup报文。 |

## 4. 对接与时序要点

第8步方向差异已修正：两软件BRU保存真实actualTaken并用于训练，与RTL BRU.taken一致；
taken-to-PC4仍训练1，地址正确不产生该分支的误预测恢复。控制/BPU全链1518步2230字段
包括全方向表/BTB/GHR/checkpoint一致。取指预测历史/checkpoint保持现有契约，RAS/前端另验。

第8步现状观察复现：实际BRU.taken在条件真且offset=4时为1，而软件BPU以nextPC!=PC+4
推断训练0。预测PC正确不代表训练方向相同；BPU表/历史状态尚未纳入该观察域。
按软件基线规范化effective_taken的消费者边界建议见公共SPEC §34.4，尚未实施。

- `rv32_core` 把 `instructionOutput.payload` 喂给组合 `rv32_decoder`，把 `iqReadyInput` 接到本拍发射成功信号；FQ/IQ 是**真正的时序队列**，译码器不是另一条带握手的流水级。
- 预测查询是组合路径；checkpoint 仅在取指请求握手时推进。预译码的 `fetchInfoOutput.valid` 对应上一拍实际 FQ 入队，不应当被理解为预测查询有效。
- 全局冲刷来源与 ROB/RAT/PRF 恢复见 [后端](backend.md)；I$ 的同步读、缺失和核外整行请求见 [缓存](cache.md)。RTL 未内置“主存固定 20 拍”的时延保证，返回时间取决于外部存储器。
