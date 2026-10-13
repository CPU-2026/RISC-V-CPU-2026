# RTL 公共类型：`rv32_pkg`

源码：[`rv32_pkg.sv`](../verilog/rtl/common/rv32_pkg.sv)。包定义常量、类型和函数，无模块端口；通过 `rv32_pkg::类型名` 引用。模块接口见 [前端](frontend.md)、[后端](backend.md)、[访存](memory.md)、[缓存](cache.md)。

## 1. 常量、宽度和身份

checkpoint 容量须与包定义及 ID 宽度一致，覆盖 ROB+I$+FQ+IQ 的当前预算 24，且不超过 64。RAS 深度允许 1..255；BTB 项数须为不小于 2 的二次幂，并保留 PC tag。

| 定义 | 当前值 | 硬件含义 |
|---|---:|---|
| `XLEN` / `ARCH_REGS` | 32 / 32 | 数据位宽 / 架构寄存器数，`x0` 恒为零。 |
| `ROB_ENTRIES` / `ROB_TAG_W` | 16 / 5 | ROB 槽数 / 完整循环标签宽度。 |
| `PRF_ENTRIES` / `PHY_TAG_W` | 48 / 6 | PRF 条目数 / 物理标签宽度；P0 对应 `x0`，不分配。 |
| `FQ_ENTRIES` / `IQ_ENTRIES` | 2 / 2 | 当前取指和译码队列深度。 |
| `LQ_ENTRIES` / `SQ_ENTRIES` | 8 / 8 | load/store 队列默认槽数。 |
| `BPU_CKPT_ENTRIES` / `BPU_CKPT_ID_W` | 32 / 5 | 预测历史检查点数 / `bpu_ckpt_id_t` 宽度。 |
| `FETCH_REQUEST_ENTRIES` / `RAS_ENTRIES` | 4 / 16 | 取指请求容量 / 返回栈深度。 |
| `CACHE_LINE_BYTES` / `CACHE_LINE_BITS` | 64 / 512 | Cache 行字节数 / 数据位宽。 |
| `ICACHE_SETS` / `DCACHE_SETS` / `DCACHE_WAYS` | 16 / 128 / 1 | I$ 1 KiB、D$ 8 KiB，均直接映射。 |
| RS 容量 | 2/1/1/2/2/2/2 | Integer/Multiply/Divide/Branch/Load/StoreAddr/StoreValue，共 12 槽。 |
| `HALT_INSN` | `32'h0ff0_0513` | 特定停机指令字。 |

`OPCODE_*` 定义 RV32I 主 opcode；`uop_class_e` 定义指令类别，`operation_e` 定义具体运算。`mem_size_e` 与请求 `size` 统一为 `MEM_BYTE/HALF/WORD=0/1/2`，对应 1/2/4 B。

通用约定：

- 上升沿更新，`rstNInput` 为低有效异步复位。
- `valid=0` 无有效事务；有 ready 的接口以 `valid && ready` 握手，无 ready 的载荷按模块时序消费。
- 用完整 ROB tag 认证身份。ROB/队列恢复保留边界及更老项，取消严格年轻项；执行结果的年龄门控见 [backend.md](backend.md)。

## 2. 取指、译码和预测载荷

| 类型 | 字段与用途 |
|---|---|
| `decode_context_t` | `{instruction, programCounter, predictedNextProgramCounter, predictorCheckpointId}`：进入组合译码器的指令及预测上下文。 |
| `decoded_uop_t` | `valid/illegal/halt`、`uopClass/operation`、`rd/rs1/rs2`、`usesRs1/usesRs2/usesImmediate/writesRd`、`immediate`、`programCounter/instruction/predictedNextProgramCounter/predictorCheckpointId`、`memorySize/memoryUnsigned`：发射、寄存器分配和异常处理所需字段。 |
| `fetch_query_output_t` | `programCounter` 是当前查询 PC；`accepted` 表示本拍取指请求与存储器 `ready` 握手，预测器才分配检查点。 |
| `prediction_output_t` | `nextProgramCounter/taken/checkpointId`：本次取指的预测结果。 |
| `instruction_memory_request_output_t` / `instruction_memory_response_input_t` | 请求为`valid/address/predictedProgramCounter/predictorCheckpointId`；顺序返回`valid/instruction`，由response-ready确认消费，flush逻辑取消。 |
| `fetch_queue_output_t` | `{valid,payload: decode_context_t}`：前端 IQ 对后端的队首载荷。 |
| `redirect_input_t` | `{valid,programCounter}`：冲刷后的新 PC。 |
| `predictor_fetch_info_t` | 前一拍 FQ 入队的 `valid/isCall/isReturn/jalTargetValid/PC/target`；call/return 独立，双 link 先 pop 后 push，JAL 仅 push。 |
| `branch_result_input_t` | `valid/robTag/robEntryLive/programCounter/nextProgramCounter/taken/checkpointId`：条件分支训练；`robEntryLive` 和年龄门控防止错路训练。 |
| `jump_result_input_t` | `valid/robTag/robEntryLive/programCounter/target/isReturn`：JAL/JALR 目标训练。 |
| `flush_candidate_input_t` / `squash_input_t` | 均携带 `valid/robTag/programCounter/checkpointId`；前者是候选误预测，后者是仲裁选出的全局冲刷。 |
| `branch_training_input_t` | `valid/programCounter/nextProgramCounter/taken/globalHistory`：方向预测器训练时采用的历史快照。 |
| `direction_history_input_t` / `direction_prediction_output_t` | 取指移位与冲刷恢复控制；输出 `directionTaken/useGlobal/conditionalSeen/globalHistory`。 |
| `btb_lookup_output_t` / `btb_training_input_t` | 查询结果 `hit/unconditional/isReturn/target`；训练载荷组合前端预译码、分支和跳转三个来源。 |
| `checkpoint_input_t` / `checkpoint_output_t` | 接受取指、冲刷、分支检查点 ID 与 GHR；输出分支历史、恢复历史和下一个 ID。 |
| `rob_predictor_input_t` | `willCommit/headTag/isHeadCall/isHeadReturn/headProgramCounter/replayEntries`：RAS 的已提交态更新及冲刷时 ROB 窗口重放。 |

## 3. 发射、执行、恢复与提交载荷

| 类型 | 字段与用途 |
|---|---|
| `rat_read_input_t` / `rat_read_output_t` | `source1Arch/source2Arch` → 当前映射 `source1Phy/source2Phy`。 |
| `rat_rename_input_t` / `rat_rename_output_t` | `valid/architecturalRegister/physicalRegister` 建新映射；输出 `previousPhysicalRegister` 供 ROB 保存旧映射。 |
| `rat_restore_input_t` / `rat_commit_input_t` | `{valid,squashTag,headTag}` 指示从已提交映射重放存活窗口；`{valid,architecturalRegister,physicalRegister}` 更新已提交映射。 |
| `prf_allocation_input_t` / `prf_free_input_t` | 分配时 `valid/valueValid/value`（可为链接地址预置就绪值）；释放时 `valid/physicalRegister`。 |
| `prf_restore_input_t` / `prf_read_input_t` / `prf_read_output_t` | `{valid,squashTag}` 回收年轻分配；`physicalRegister` 查询得到 `ready/value`。 |
| `cdb_result_t` | `{valid,phyTag,value}`：执行结果广播给 PRF、RS 和 SQ；固定 4 路在 core 中依次来自 ALU、load、MUL、DIV。 |
| `rs_allocation_input_t` | `valid/operation/robTag/destinationPhy`，两个源的 `Ready/Tag/Value`，`immediate/programCounter/predictedProgramCounter/useImmediate`：保留站存下操作数及身份。 |
| `rs_issue_output_t` | `valid/operation/robTag/destinationPhy/source1Value/source2Value/immediate/programCounter/predictedProgramCounter/useImmediate`：源操作数就绪后交执行单元。 |
| `rob_allocation_input_t` | `valid/PC/instruction`、架构和新旧物理目的寄存器、`ready/isStore/storeQueueIndex/isHalt/hasException`、预测 PC/检查点/返回类型。 |
| `rob_completion_t` / `rob_flush_input_t` | `{valid,robTag,exception}` 标记完成；`{valid,robTag}` 是保留该边界、清除年轻项的冲刷。 |
| `rob_lookup_input_t` / `rob_lookup_output_t` | 完整 `robTag` 查询；输出 `valid/PC/predictedProgramCounter/predictorCheckpointId/isReturn`，`valid` 包含完整标签匹配。 |
| `rob_commit_output_t` / `rob_status_output_t` | 就绪的 ROB 头及目的寄存器、store 槽、HALT/异常信息；状态输出 `empty/full/headTag`。 |
| `rob_retirement_input_t` | `{valid,robTag}`：实际提交广播，回收 LQ 或置 SQ committed；SQ 仍等发送接受才释放。 |
| `rob_replay_entry_t` | `robTag/programCounter/instruction/archRd/newPhy`：按 ROB 头起的顺序给 RAT、PRF、RAS 做恢复重放。 |
| `alu_operation_input_t` / `alu_operation_output_t` | `operation/leftOperand/rightOperand/immediate/programCounter/useImmediate` → `value`（组合）。 |
| `branch_operation_input_t` / `branch_operation_output_t` | 分支操作、源值、偏移、PC 和预测 PC → `taken/target/nextProgramCounter/linkValue/mispredict/targetMisaligned`（组合）。 |
| `execute_request_input_t` | `valid/operation/source1/source2/immediate/PC/predictedNextProgramCounter/useImmediate/robTag/destinationPhy/isControl/isCall/isReturn`。 |
| `execute_value_output_t` / `alu_execute_output_t` | 均带 `valid/value/robTag/destinationPhy`；ALU 另带 `isControl/controlMisaligned`。 |
| `bru_execute_output_t` | `valid/robTag/PC/target/nextProgramCounter/returnAddress/taken/conditional/mispredict/misaligned/isCall/isReturn`。 |

## 4. 访存、缓存和 SRAM 边界

| 类型 | 字段与用途 |
|---|---|
| `load_allocation_input_t` | `valid/robTag/destinationPhy/size/isUnsigned`：LQ 分配。 |
| `store_allocation_input_t` | `valid/robTag/size/dataReady/dataTag/dataValue`：SQ 分配；非零 dataTag 可由 CDB 唤醒，0 表示等待 StoreValue。 |
| `store_data_input_t` | `valid/robTag/value`：StoreValue 数据交付，另有 SQ 槽索引；当前 core 使用 2 路。 |
| `lsu_address_input_t` | `valid/isStore/robTag/address`：配合槽号定位 LQ/SQ，须匹配旧活动项或同拍分配的完整 tag。 |
| `store_commit_input_t` | `valid/robTag`：ROB 头 Store 退休提议；ready 只等目标就绪，实际退休由 `rob_retirement_input_t` 确认。 |
| `store_completion_output_t` | `readyMask/epochMask` 各 `ROB_ENTRIES` 位：旧有效、未提交且地址/数据齐的 Store 批量完成，ROB 核验身份与恢复年龄后置 ready。 |
| `load_result_output_t` | `valid/robTag/destinationPhy/value`：load 的写回结果。 |
| `data_memory_request_output_t` | `valid/write/address/writeData/writeStrobe/size`：处理器侧字节地址、32 位数据、4 位字节使能及宽度。 |
| LSU `storeRetirementOutput`（同上类型） | ROB 头 Store 的退休载荷，valid 表示提议匹配；提交跟踪由实际 commit 使能，与内存发送载荷独立。 |
| `data_memory_response_input_t` | `valid/readData`：load 的 32 位读取结果，无响应 ready。 |
| `address_generation_input_t` / `address_generation_output_t` | `baseAddress/offset` → `address`，纯组合。 |
| `icache_cpu_request_input_t` / `icache_cpu_response_output_t` | 请求携带 `valid/字节PC/预测PC/checkpoint`；响应携带同一身份及 32 位 instruction，保持到 `cpuRspReady`。 |
| `icache_line_response_input_t` | `valid/address/data[511:0]`：I$ 行返回身份，`memRspReady` 确认接受，`memFlush` 取消逻辑请求。 |
| `dcache_cpu_request_input_t` / `dcache_cpu_response_output_t` | `valid/write/address/writeData/writeStrobe/size` 的处理器访问、`valid/readData` 的 load 应答；store 无读响应。 |
| `cache_line_request_output_t` / `cache_line_response_input_t` | I$整行接口：`valid/write/address/writeData[511:0]` 请求、`valid/data[511:0]` 回填。 |
| `dcache_line_request_output_t` / `cache_line_response_input_t` | 独立 `readValid/readAddress` 与 `writeValid/writeAddress/writeData[511:0]`，分别握手；写完成用 `memWriteDoneInput`，读返回为 `valid/data[511:0]`。 |

包内函数 `rob_is_younger/rob_is_older` 比较循环 ROB tag 的相对年龄，仅用于有效在飞窗口；`mem_bytes(size)` 返回 1/2/4 字节。
