# RTL 公共类型与信号约定：`rv32_pkg`

源码：[`verilog/rtl/common/rv32_pkg.sv`](../verilog/rtl/common/rv32_pkg.sv)。这是 SystemVerilog **package**，不实例化、没有 Input/Output 端口；各模块用 `rv32_pkg::类型名` 引用它。本文说明类型的**电路含义**，具体连线和握手见 [前端](frontend.md)、[后端](backend.md)、[访存](memory.md) 和 [缓存](cache.md)。

## 1. 常量、宽度和身份

SPEC §60参数合同：checkpoint局部容量须等于package容量/派生CID宽度，覆盖当前
ROB＋I$＋FQ4＋IQ4预算28且≤64；只改局部数组不能改变身份域。默认32及联合
package64引脚测试通过。RAS合法1..255（非2次幂也允许），BTB合法2次幂且≥2、
必须保留PC tag。13合法/9明确非法RTL cases与22软件编译约束见sync/README §52；
可选参数引脚验证不等于这些容量的完整CPU周期验收。

| 定义 | 当前值 | 硬件含义 |
|---|---:|---|
| `XLEN` / `ARCH_REGS` | 32 / 32 | 数据位宽 / 架构寄存器数，`x0` 恒为零。 |
| `ROB_ENTRIES` / `ROB_TAG_W` | 16 / 5 | ROB 槽数 / 完整循环标签宽度；`rob_tag_t` 是 5 位，不能只用槽号认证结果。 |
| `PRF_ENTRIES` / `PHY_TAG_W` | 48 / 6 | PRF 条目数 / `phy_tag_t` 宽度；物理标签 0 表示 `x0`，不参与分配。 |
| `LQ_ENTRIES` / `SQ_ENTRIES` | 8 / 8 | load/store 队列默认槽数。 |
| `BPU_CKPT_ENTRIES` / `BPU_CKPT_ID_W` | 32 / 5 | 预测历史检查点数 / `bpu_ckpt_id_t` 宽度。 |
| `FETCH_REQUEST_ENTRIES` / `RAS_ENTRIES` | 4 / 32 | I$请求预算、前端事务身份容量 / 返回栈深度。 |
| `CACHE_LINE_BYTES` / `CACHE_LINE_BITS` | 64 / 512 | 两Cache整行载荷和字节掩码几何。 |
| `ICACHE_SETS` / `DCACHE_SETS` / `DCACHE_WAYS` | 16 / 128 / 1 | I$1 KiB、D$8 KiB，均直接映射。 |
| RS容量 | 4/2/1/4/4/4/4 | Integer/Multiply/Divide/Branch/Load/StoreAddr/StoreValue七池23槽。 |
| `HALT_INSN` | `32'h0ff0_0513` | 特定停机指令字。 |

`OPCODE_*` 是译码器使用的 RV32I 主 opcode。`uop_class_e` 把译码结果分为 `UOP_ALU/MUL/DIV/BRANCH/LOAD/STORE/HALT/ILLEGAL`（另有 `UOP_NONE`）；`operation_e` 细分整数、跳转、分支和 RV32M 运算；`mem_size_e` 为 `MEM_BYTE=0`、`MEM_HALF=1`、`MEM_WORD=2`，分别对应 1/2/4 字节。内存请求中的 `size` 同样采用这组编码（有的端口声明为 2 位 `logic`）。

**通用约定**：结构体中 `valid=0` 时，其余载荷不能视为一次有效事务；同步模块以 `clkInput` 上升沿更新，`rstNInput` 是低有效异步复位。请求端的 `valid && ready` 才表示被接收；只有 `valid`、没有 ready 的响应/训练载荷按各生产者和消费者的时序使用。分支冲刷边界为 `robTag`：边界本身和更老的指令保留，严格更年轻的指令失效。

## 2. 取指、译码和预测载荷

| 类型 | 关键字段及方向上的意义 |
|---|---|
| `decode_context_t` | `{instruction, programCounter, predictedNextProgramCounter, predictorCheckpointId}`：进入组合译码器的指令及预测上下文。 |
| `decoded_uop_t` | `valid/illegal/halt`、`uopClass/operation`、`rd/rs1/rs2`、`usesRs1/usesRs2/usesImmediate/writesRd`、`immediate`、`programCounter/instruction/predictedNextProgramCounter/predictorCheckpointId`、`memorySize/memoryUnsigned`：发射、寄存器分配和异常处理所需字段。 |
| `fetch_query_output_t` | `programCounter` 是当前查询 PC；`accepted` 表示本拍取指请求与存储器 `ready` 握手，预测器才分配检查点。 |
| `prediction_output_t` | `nextProgramCounter/taken/checkpointId`：本次取指的预测结果。 |
| `instruction_memory_request_output_t` / `instruction_memory_response_input_t` | 请求为`valid/address/predictedProgramCounter/predictorCheckpointId`；顺序返回`valid/instruction`，由response-ready确认消费，flush逻辑取消。 |
| `fetch_queue_output_t` | `{valid,payload: decode_context_t}`：前端 IQ 对后端的队首载荷。 |
| `redirect_input_t` | `{valid,programCounter}`：冲刷后的新 PC。 |
| `predictor_fetch_info_t` | 前一拍实际FQ入队的valid/isCall/isReturn/jalTargetValid/PC/target。用户JALR规则的call/push与return/pop独立，双link含同寄存器可同时真，执行pop后push；JAL只push。 |
| `branch_result_input_t` | `valid/robTag/robEntryLive/programCounter/nextProgramCounter/taken/checkpointId`：条件分支训练；`robEntryLive` 和年龄门控防止错路训练。 |
| `jump_result_input_t` | `valid/robTag/robEntryLive/programCounter/target/isReturn`：JAL/JALR 目标训练。 |
| `flush_candidate_input_t` / `squash_input_t` | 均携带 `valid/robTag/programCounter/checkpointId`；前者是候选误预测，后者是仲裁选出的全局冲刷。 |
| `branch_training_input_t` | `valid/programCounter/nextProgramCounter/taken/globalHistory`：方向预测器训练时采用的历史快照。 |
| `direction_history_input_t` / `direction_prediction_output_t` | 取指移位与冲刷恢复控制；输出 `directionTaken/useGlobal/conditionalSeen/globalHistory`。 |
| `btb_lookup_output_t` / `btb_training_input_t` | 查询结果 `hit/unconditional/isReturn/target`；训练载荷组合前端预译码、分支和跳转三个来源。 |
| `checkpoint_input_t` / `checkpoint_output_t` | 接受取指、冲刷、分支检查点 ID 与 GHR；输出分支历史、恢复历史和下一个 ID。 |
| `rob_predictor_input_t` | `willCommit/headTag/isHeadCall/isHeadReturn/headProgramCounter/replayEntries`：RAS 的已提交态更新及冲刷时 ROB 窗口重放。 |

## 3. 发射、执行、恢复与提交载荷

| 类型 | 关键字段及方向上的意义 |
|---|---|
| `rat_read_input_t` / `rat_read_output_t` | 两个源架构寄存器号 `source1Arch/source2Arch` → 当前映射 `source1Phy/source2Phy`；额外debug读口已清理。 |
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
| `rob_retirement_input_t` | `{valid,robTag}`实际ROB提交广播：匹配LQ项回收；匹配Store退休提议时置SQ committed，发送接受才释放（SPEC §44/45）。 |
| `rob_replay_entry_t` | `robTag/programCounter/instruction/archRd/newPhy`：按 ROB 头起的顺序给 RAT、PRF、RAS 做恢复重放。 |
| `alu_operation_input_t` / `alu_operation_output_t` | `operation/leftOperand/rightOperand/immediate/programCounter/useImmediate` → `value`（组合）。 |
| `branch_operation_input_t` / `branch_operation_output_t` | 分支操作、源值、偏移、PC 和预测 PC → `taken/target/nextProgramCounter/linkValue/mispredict/targetMisaligned`（组合）。 |
| `execute_request_input_t` | `valid/operation/source1/source2/immediate/PC/predictedNextProgramCounter/useImmediate/robTag/destinationPhy/isControl/isCall/isReturn`。 |
| `execute_value_output_t` / `alu_execute_output_t` | 均带 `valid/value/robTag/destinationPhy`；ALU 另带 `isControl/controlMisaligned`。 |
| `bru_execute_output_t` | `valid/robTag/PC/target/nextProgramCounter/returnAddress/taken/conditional/mispredict/misaligned/isCall/isReturn`。 |

## 4. 访存、缓存和 SRAM 边界

| 类型 | 关键字段及方向上的意义 |
|---|---|
| `load_allocation_input_t` | `valid/robTag/destinationPhy/size/isUnsigned`：LQ 分配。 |
| `store_allocation_input_t` | `valid/robTag/size/dataReady/dataTag/dataValue`：SQ 分配，数据可后续经 CDB 唤醒。 |
| `store_data_input_t` | `valid/robTag/value`：独立StoreValue RS交付；另有物理SQ槽索引端口。 |
| `lsu_address_input_t` | `valid/isStore/robTag/address`：与独立槽号端口定位LQ/SQ，完整生产者tag必须匹配存活目标或本拍匹配分配。 |
| `store_commit_input_t` / `store_completion_output_t` | 前者`valid/robTag`表示ROB队首Store退休提议，ready不依赖内存接受；后者是两份`ROB_ENTRIES`位`readyMask/epochMask`，旧有效未提交SQ项地址/数据齐才参与，ROB按有效Store/epoch及恢复年龄批量置ready。实际退休另由rob_retirement_input_t确认。 |
| `load_result_output_t` | `valid/robTag/destinationPhy/value`：load 的写回结果。 |
| `data_memory_request_output_t` | `valid/write/address/writeData/writeStrobe/size`：处理器侧字节地址、32 位数据、4 位字节使能及宽度。 |
| LSU `storeRetirementOutput`（同上类型） | ROB队首Store目标的独立退休载荷；valid为提议匹配，core实际提交使能跟踪，与dmemRequestOutput选择的旧Store独立（SPEC §45）。 |
| `data_memory_response_input_t` | `valid/readData`：load 的 32 位读取结果，无响应 ready。 |
| `address_generation_input_t` / `address_generation_output_t` | `baseAddress/offset` → `address`，纯组合。 |
| `icache_cpu_request_input_t` / `icache_cpu_response_output_t` | 请求携带valid/字节PC/预测PC/checkpoint，响应携带同一身份及32-bit instruction，保持到cpuRspReady；data为公共同步SRAM，tag为寄存器。 |
| `icache_line_response_input_t` | I$指令行返回`valid/address/data[511:0]`，明确旧line身份；memRspReady表示匹配活动miss并实际接受，memFlush取消配套逻辑请求。 |
| `dcache_cpu_request_input_t` / `dcache_cpu_response_output_t` | `valid/write/address/writeData/writeStrobe/size` 的处理器访问、`valid/readData` 的 load 应答；store 无读响应。 |
| `cache_line_request_output_t` / `cache_line_response_input_t` | I$整行接口：`valid/write/address/writeData[511:0]` 请求、`valid/data[511:0]` 回填。 |
| `dcache_line_request_output_t` / `cache_line_response_input_t` | D$独立`readValid/readAddress`和`writeValid/writeAddress/writeData[511:0]`，各自ready；写完成另用memWriteDoneInput。脏缺失可并行回填读/写回，64B对齐，见SPEC §55。 |

`rv32_pkg` 中 `rob_is_younger(candidate, boundary)` / `rob_is_older(candidate, reference)` 比较循环 ROB 标签的相对年龄，只在有效在飞窗口中使用；`mem_bytes(size)` 把访存枚举译为 1/2/4 字节。这些是包内函数，不是时钟模块或独立总线。
