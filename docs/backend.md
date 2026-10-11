# RTL 后端

源码：[`core/`](../verilog/rtl/core/)、[`backend/`](../verilog/rtl/backend/)、[`execute/`](../verilog/rtl/execute/)。公共类型见 [package.md](package.md)，访存与缓存见 [memory.md](memory.md)、[cache.md](cache.md)。

```
IQ ──译码/单发射──► RAT + PRF + ROB + 七个 RS 池
                     │              │
                     └──► ALU / MUL / DIV / BRU / AGU──► 4 路写回及 BRU 完成
                                     │                         │
            按序 ROB 提交 ◄───────────┘        flush arbiter ──► ROB/RS/LSU/BPU 恢复
```

默认 ROB 16 项、PRF 48 项。七个 RS 池容量依次为整数 4、乘法 2、除法 1、分支 4、Load 4、StoreAddr 4、StoreValue 4，共 23 槽。Load/StoreAddr 共用 AGU，StoreValue 独立向 LSU 交付数据。

## 1. 集成边界：`rv32_core`

`rv32_core` 连接前端、预测器和后端，参数 `RESET_PC=0`。imem/dmem 为 32 位处理器端口，Cache 的行接口为 512 位；课程 `student_top` 尚待封装。复位释放后首拍不取指、发射或提交。

| 方向 | 端口 | 硬件意义 |
|---|---|---|
| 输入 | `clkInput`, `rstNInput` | 时钟、异步低有效复位；取指 PC 初始化为 `RESET_PC`。 |
| 输出 / 输入 | `imemReqValidOutput`, `imemReqReadyInput` | 指令请求握手；同时成立时接受 `imemReqAddrOutput[31:0]` 的字节 PC。 |
| 输出 | `imemReqAddrOutput[31:0]` | 本次取指的 PC。 |
| 输入 / 输出 | `imemRspValidInput`, `imemRspDataInput[31:0]`, `imemRspReadyOutput` | 顺序返回指令，ready 表示 FQ 实际接收；受阻时保持。 |
| 输出 | `imemCacheRequestOutput: icache_cpu_request_input_t`, `imemFlushOutput` | 完整取指上下文及逻辑取消，直接连接 I$。 |
| 输出 / 输入 | `dmemReqValidOutput`, `dmemReqReadyInput` | load 或已提交 store 请求握手。 |
| 输出 | `dmemReqWriteOutput`, `dmemReqAddrOutput[31:0]` | 读/写选择（1=store）与字节地址。 |
| 输出 | `dmemReqWdataOutput[31:0]`, `dmemReqWstrbOutput[3:0]`, `dmemReqSizeOutput[1:0]` | store 数据、按地址起始字节排序的使能位、访问大小编码 `0/1/2=1/2/4B`。 |
| 输入 | `dmemRspValidInput`, `dmemRspRdataInput[31:0]` | Load 读取响应。 |
| 输出 | `commitValidOutput`, `commitPcOutput[31:0]`, `commitInstrOutput[31:0]` | 实际提交的指令及 PC。 |
| 输出 | `commitRdValidOutput`, `commitRdOutput[4:0]`, `commitRdValueOutput[31:0]` | 本次提交是否更新非零架构寄存器；目的寄存器号和来自 PRF 的值。 |
| 输出 | `commitMemValidOutput`, `commitMemAddrOutput[31:0]`, `commitMemDataOutput[31:0]`, `commitMemWstrbOutput[3:0]` | 退休 Store 的 SQ 载荷，独立于同拍内存发送请求。 |
| 输出 | `haltedOutput`, `trapOutput` | HALT 提交后停发射，SQ 请求排空后置 halted；异常提交置 trap。保持至复位，Cache 另行排空。 |

发射要求 IQ 有效、ROB/目标 RS/LSQ 可分配，且需要时 PRF 有空闲。四路写回来自 ALU/Load/MUL/DIV；BRU 和 Store 就绪只通知 ROB 完成。Store 提交只等目标地址/数据就绪，可先提交后发送。

## 2. 重命名状态：`rv32_rat` / `rv32_prf`

### `rv32_rat`

源码：[`rv32_rat.sv`](../verilog/rtl/backend/rv32_rat.sv)。组合读映射；有投机映射 `mapInner` 和提交映射 `archInner`。

| 方向 | 端口 | 含义 |
|---|---|---|
| 输入 | `clkInput`, `rstNInput` | 状态时钟/复位；复位后架构号映射到相同物理号。 |
| 输入 / 输出 | `readInput: rat_read_input_t`, `readOutput: rat_read_output_t` | 两个源架构寄存器 → 物理标签；`x0` 返回 0。 |
| 输入 / 输出 | `renameInput: rat_rename_input_t`, `renameOutput: rat_rename_output_t` | `valid` 时为 `architecturalRegister` 建立 `physicalRegister` 映射；组合返回被覆盖的旧物理标签供 ROB 记录。 |
| 输入 | `restoreInput: rat_restore_input_t`, `replayInput[ROB_ENTRIES]: rob_replay_entry_t` | `squashTag/headTag` 指定存活窗口；以提交映射为起点重放 ROB 中到边界为止的改名。 |
| 输入 | `commitInput: rat_commit_input_t` | 提交时更新架构态映射。 |

### `rv32_prf`

源码：[`rv32_prf.sv`](../verilog/rtl/backend/rv32_prf.sv)。参数 `PRF_DEPTH=48`、`ROB_DEPTH=16`；FIFO 分配，三组合读口、四写回口。

自由队列复位为 P32..P47，使用 epoch+slot 指针绕过填充编码。分配读取旧队首，本拍回收项下拍可用。恢复时停止分配，按 ROB 年龄从旧到新回收年轻项的 `newPhy`，最后追加同拍提交释放的 `oldPhy`。P0 不分配、不回收。

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

源码：[`rv32_rob.sv`](../verilog/rtl/backend/rv32_rob.sv)，参数 `DEPTH=16`。保存指令、改名、访存和预测元数据，只有就绪头项可提交。表中数组括号表示元素数。

| 方向 | 端口 | 含义 |
|---|---|---|
| 输入 | `clkInput`, `rstNInput` | 状态时钟和异步低有效复位。 |
| 输入 / 输出 | `allocInput: rob_allocation_input_t`, `allocReadyOutput`, `allocTagOutput: rob_tag_t` | 分配整条 ROB 元数据，`valid && allocReady` 写入尾项；输出将分配的完整循环标签。 |
| 输入 | `completionInput[6]: rob_completion_t` | 完整 tag 完成事件，来自 ALU/Load/MUL/DIV/BRU/零；异常只接受 0/4 号口。 |
| 输入 | `storeReadyInput: store_completion_output_t` | Store 批量完成位图，核验旧有效 Store、slot 和 epoch；恢复拍只接受严格更老项。 |
| 输入 | `flushInput: rob_flush_input_t` | 清除严格年轻条目，尾指针回到边界后一项；边界保留，同时更老头项可提交。 |
| 输入 / 输出 | `lookupInput[5]: rob_lookup_input_t`, `lookupOutput[5]: rob_lookup_output_t` | 根据完整 tag 查存活身份；前两路还输出 PC、预测 PC、checkpoint、return 标记用于控制流解析，所有路的 `valid` 均做完整 tag 匹配。 |
| 输出 | `commitOutput: rob_commit_output_t`, `commitStoreOutput` | 就绪的 ROB 头元数据、是否 store；头项未完成时 `commitOutput.valid=0`。 |
| 输入 / 输出 | `commitReadyInput`, `commitFireOutput` | 提交握手；Store 由 LSU 的 `storeCommitReadyOutput` 门控。 |
| 输出 | `statusOutput: rob_status_output_t`, `countOutput[$clog2(DEPTH+1)-1:0]` | 空/满/头标签和有效条目数。 |
| 输出 | `replayOutput[DEPTH]: rob_replay_entry_t` | 按当前 head 顺序读取整个窗口，供 RAT/PRF/RAS 恢复；消费侧须按存活计数和 tag 验证。 |

## 4. 保留站：`rv32_rs`

源码：[`rv32_rs.sv`](../verilog/rtl/backend/rv32_rs.sv)。保存源值与 ready，按 ROB 年龄选择最老就绪项。写回拍捕获，下拍才能派发依赖项。恢复时禁止分配，保留边界、取消年轻项；严格更老的就绪项仍可派发。

| 方向 | 端口 | 含义 |
|---|---|---|
| 输入 | `clkInput`, `rstNInput`, `flushInfoInput: rob_flush_input_t` | 时钟/复位，冲刷时删除年轻项并停发新项。 |
| 输入 / 输出 | `allocInput: rs_allocation_input_t`, `allocReadyOutput`, `allocAuxInput[AUX_W-1:0]` | 发射时携带操作、两个源 `Ready/Tag/Value`、目的标签及 PC；`valid && allocReady` 占槽，辅助位保存控制流类型或访存槽号。 |
| 输入 | `writebackInput[4]: cdb_result_t` | 用有效写回的物理标签/值旁路并唤醒源操作数。 |
| 输出 / 输入 | `issueOutput: rs_issue_output_t`, `issueReadyInput` | 最老的源就绪项及实际操作数；`valid && ready` 出槽。 |
| 输出 | `issueAuxOutput[AUX_W-1:0]`, `occupancyOutput[$clog2(DEPTH+1)-1:0]` | 被选项附加位和当前占槽数。 |
| 输出 | `issueLaneValidOutput`, `issueLaneOutput[ISSUE_WIDTH]`, `issueLaneAuxOutput[ISSUE_WIDTH]` | 多路派发接口；StoreValue 配置 `ISSUE_WIDTH=4`，同拍交付全部就绪项。 |

Load/StoreAddr 的 aux 保存类别与 LSQ 槽号；StoreValue 保存 SQ 槽号，通过 `storeDataInput/storeDataIndexInput` 交付数据并核验完整 ROB tag。core 设置 `dataTag=0`，禁用 SQ 直接 CDB 唤醒。

## 5. 执行模块接口

`execute_request_input_t` 携带操作数、操作码、PC 和 ROB/物理目的标签。以 `valid && ready` 接收或消费；组合原语无握手。core 将 ALU/MUL/DIV 的 `outReadyInput` 固定为 1，写回仍须核验完整 ROB tag 和恢复年龄。

| 模块 | 输入端口 | 输出端口 | 功能与时序 |
|---|---|---|---|
| [`rv32_alu`](../verilog/rtl/execute/rv32_alu.sv) | `aluInput: alu_operation_input_t` | `aluOutput: alu_operation_output_t` | 组合整数、移位、比较及跳转目标运算；JALR 清目标 bit0，加减法复用 CLA 原语。 |
| [`rv32_alu_unit`](../verilog/rtl/execute/rv32_alu_unit.sv) | `clkInput`, `rstNInput`, `flushInfoInput`, `executeInput`, `outReadyInput` | `inReadyOutput`, `executeOutput: alu_execute_output_t`, `occupancyOutput` | 单槽结果级，消费或取消时可同拍重填，一条/拍。 |
| [`rv32_agu_unit`](../verilog/rtl/execute/rv32_agu_unit.sv) | `clkInput/rstNInput`, `flushInfoInput`, `executeInput: rs_issue_output_t`, `auxiliaryInput[3:0]` | `inReadyOutput`, `addressOutput`, `auxiliaryOutput`, `robTagOutput` | 单槽地址结果级，次拍向 LSU 交付地址与身份，一条/拍。内部 `validInner` 仅供模块内部状态使用；有效交付由 `addressOutput.valid` 表示。 |
| [`rv32_bru`](../verilog/rtl/execute/rv32_bru.sv) | `branchInput: branch_operation_input_t` | `branchOutput: branch_operation_output_t` | 组合条件比较、实际 nextPC、链接值、误预测/目标未对齐检测。 |
| [`rv32_bru_unit`](../verilog/rtl/execute/rv32_bru_unit.sv) | `clkInput`, `rstNInput`, `flushInput/flushTagInput`, `executeInput: execute_request_input_t` | `inReadyOutput`, `executeOutput: bru_execute_output_t` | 一拍登记分支结果，无输出 ready；恢复拍只接受和输出严格更老项。 |
| [`rv32_mul`](../verilog/rtl/execute/rv32_mul.sv) | `clkInput`, `rstNInput`, `flushInfoInput`, `executeInput`, `outReadyInput` | `inReadyOutput`, `executeOutput: execute_value_output_t` | radix-4 Booth + CSA + 最终加法，三级弹性流水；MUL 取低 32 位，其余乘法取高 32 位。 |
| [`rv32_div`](../verilog/rtl/execute/rv32_div.sv) | `clkInput`, `rstNInput`, `flushInfoInput`, `executeInput`, `outReadyInput` | `inReadyOutput`, `executeOutput: execute_value_output_t` | 单上下文 radix-4 SRT，PREP/LOOP/FINISH；忙或结果受阻时停收，除零、溢出及简单比较走短路径。 |

- ALU 在派发后下一拍上 CDB；MUL 经 partial/CSA/result 三级，n 拍接收、n+3 拍上 CDB，依赖项最早 n+4 拍派发。
- MUL 恢复时取消边界及年轻结果；DIV 仅取消严格年轻工作，边界结果暂不输出且在未握手时保持。更老工作可继续完成。
- BRU 不写 PRF，结果用于 ROB 完成、恢复仲裁和预测器训练。JAL/JALR 走 ALU 控制路径，发射时可预置链接值 `PC+4`。

## 6. 恢复仲裁：`rv32_flush_arbiter`

源码：[`rv32_flush_arbiter.sv`](../verilog/rtl/core/rv32_flush_arbiter.sv)，参数 `DEPTH=4`。记录分支与跳转误预测候选，按 ROB 年龄选最老请求广播。

| 方向 | 端口 | 含义 |
|---|---|---|
| 输入 | `clkInput`, `rstNInput` | 候选队列时钟和复位。 |
| 输入 | `branchInput: flush_candidate_input_t`, `jumpInput: flush_candidate_input_t` | BRU/ALU 检出的误预测或未对齐候选，包含 `valid/robTag/programCounter/checkpointId`。 |
| 输出 | `squashOutput: squash_input_t` | 已排队的最老候选：ROB 边界标签、重取 PC、预测检查点。 |

仲裁读取旧队列，新候选不当拍直通：n 拍执行，n+1 拍候选入队，n+2 拍最早广播。恢复丢弃边界及年轻候选，前端按 `programCounter` 重定向，预测器按 `checkpointId` 恢复。

## 7. 接口检查点

- 每拍至多发射一条、提交一条；七个 RS 池独立寻找就绪项，执行结果可并行写回。
- 恢复、CDB 与 ROB 查询都要保留 **完整 tag 身份**；仅靠低位槽号可能误认复用槽的旧结果。
- `rv32_agu` 的组合地址接口及 `rv32_lsu` 的 LQ/SQ、存储器握手在 [访存](memory.md) 说明；缓存命中和脏行写回在 [缓存](cache.md) 说明。

验收记录见共同父目录 `sync/README.md` §56：24 个镜像在共同逻辑 Memory 下逐拍、退休及最终内存一致；完整异常域另验。
