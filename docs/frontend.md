# RTL 前端

源码：[`frontend/`](../verilog/rtl/frontend/)、[`predictor/`](../verilog/rtl/predictor/)。公共类型见 [package.md](package.md)，I$ 接口见 [cache.md](cache.md)。

```
查询 PC ──► rv32_predictor ──► 预测 nextPC / checkpointId
   ▲                                  │
   └── rv32_frontend ◄─ 指令响应 ◄────┘
          FQ → IQ ──► rv32_decoder ──► core 发射
                  解析跳转、训练预测器；冲刷重定向并丢弃错路响应
```

FQ、IQ 和已接受请求各 4 槽，每拍至多输出一条。FQ/IQ 使用 epoch 指针，占用数由 tail-head 派生；满队列可同拍出旧项、补新项，空队列不直通。请求保存预测 PC/checkpoint，响应按 FIFO 顺序返回，实际进入 FQ 后才释放请求身份。

## 1. `rv32_frontend`：PC、FQ/IQ 与取指响应

源码：[`rv32_frontend.sv`](../verilog/rtl/frontend/rv32_frontend.sv)。参数 `FQ_DEPTH=4`、`IQ_DEPTH=4`、`REQUEST_DEPTH=4`、`RESET_PC=0`。

| 方向 | 端口 | 作用 |
|---|---|---|
| 输入 | `clkInput`, `rstNInput` | 时钟与异步低电平复位；PC 复位为 `RESET_PC`。 |
| 输出 | `predictorQueryOutput: fetch_query_output_t` | BPU 查询 PC；accepted 仅在取指请求握手时置位。 |
| 输出 | `fetchProgramCounterOutput[31:0]` | 独立旧 PC 连线，供 BPU/I$ 使用，避免依赖 accepted 总线。 |
| 输入 | `predictionInput: prediction_output_t` | `nextProgramCounter/taken/checkpointId`；请求握手时锁存预测下一 PC、检查点并推进 PC。 |
| 输出 / 输入 | `imemRequestOutput: instruction_memory_request_output_t`, `imemReqReadyInput` | 字节 PC 与预测上下文，请求按 ready 接受。 |
| 输入 / 输出 | `imemResponseInput: instruction_memory_response_input_t`, `imemRspReadyOutput` | 顺序返回指令，握手后进 FQ 并释放请求身份。 |
| 输出 | `imemFlushOutput` | 取消 I$/IMEM 逻辑请求；物理旧事务由总线适配器排空。 |
| 输入 | `redirectInput: redirect_input_t` | 清队列与请求身份，设置新 PC。 |
| 输出 / 输入 | `instructionOutput: fetch_queue_output_t`, `iqReadyInput` | IQ 队首及上下文，握手后交后端。 |
| 输出 | `fetchInfoOutput: predictor_fetch_info_t` | 上一拍 FQ 入队的跳转预译码，供 BTB/RAS 训练。 |
| 输出 | `fqCountOutput`, `iqCountOutput` | FQ/IQ 实际占用数，范围 `0..DEPTH`。 |

`HALT_INSN=32'h0ff0_0513` 实际进入 FQ 时锁存 `stopFetch`，同拍停止新请求。redirect 清除 FQ/IQ、HALT 和请求身份，并取消旧逻辑请求；同拍旧响应不入 FQ。FQ 向 IQ 转移旧队首，组合译码位于 IQ 之后。

## 2. `rv32_decoder`：组合译码

源码：[`rv32_decoder.sv`](../verilog/rtl/frontend/rv32_decoder.sv)。**无时钟、无 ready**。

| 方向 | 端口 | 作用 |
|---|---|---|
| 输入 | `decodeContextInput: decode_context_t` | 指令字、当前 PC、预测下一 PC、检查点 ID。 |
| 输出 | `uopOutput: decoded_uop_t` | 指令类别/具体操作、寄存器号、源使用与写回位、符号扩展立即数、访存大小与无符号标志，以及原始预测上下文。 |

未知编码译为 `UOP_ILLEGAL`，停机字译为 `UOP_HALT`。译码不另设流水级，实际发射仍需 IQ 握手。JAL/JALR 走 ALU 控制路径，条件分支走 BRU。

## 3. `rv32_predictor`：预测顶层

源码：[`rv32_predictor.sv`](../verilog/rtl/predictor/rv32_predictor.sv)。参数 `BHT_ENTRIES=256`、`BTB_ENTRIES=64`、`RAS_ENTRIES=32`、`CONDSEEN_ENTRIES=512`、`CKPT_ENTRIES=32`。

| 方向 | 端口 | 作用 |
|---|---|---|
| 输入 | `clkInput`, `rstNInput` | 预测表、历史和 RAS 状态的时钟/复位。 |
| 输入 / 输出 | `queryPcInput[31:0]`, `predictionOutput: prediction_output_t` | 组合返回 taken/nextPC/checkpoint；目标未命中时预测 PC+4。 |
| 输入 | `fetchAcceptInput` | 实际取指握手，推进 checkpoint 和投机历史。 |
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

源码：[`rv32_bpu_ras.sv`](../verilog/rtl/predictor/rv32_bpu_ras.sv)。参数 `RAS_ENTRIES=32`，非环形有界栈；满 push、空 pop 保持。

JALR 的 push=`rd∈{x1,x5}`、pop=`rs1∈{x1,x5}`，两标志独立；双 link 即使同寄存器也先 pop 后 push。JAL 仅按 rd 判断 push。容量检查使用 pop 后深度，查询读取旧栈顶。

恢复从完整已提交栈重放存活 ROB（含边界），优先于早期取指事件；同拍提交的头项不重复重放。checkpoint 只保存 GHR。

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
| 输出 | `nextCheckpointIdOutput: bpu_ckpt_id_t` | 独立旧 ID 连线，避免预测 ID 依赖 fetchAccepted 总线。 |

## 4. 对接与时序要点

- 方向训练使用 BRU 的真实 `taken`；目标恰为 PC+4 时仍可训练 taken=1，预测 PC 正确则不触发误预测恢复。
- BTB 的 tag/类型和 target 分别按槽仲裁，优先级为 fetch > jump > taken branch；无写者保持旧值，查询读取旧态。无静态目标的 JALR/RET 预译码可采用同拍解析目标。
- core 将 IQ payload 接译码器，`iqReadyInput` 接本拍发射成功信号。
- checkpoint 仅随实际取指握手推进；`fetchInfoOutput.valid` 表示上一拍 FQ 入队。
- 后端恢复见 [backend.md](backend.md)。指令返回时间由外部存储器决定。
