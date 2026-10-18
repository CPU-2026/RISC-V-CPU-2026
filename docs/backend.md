# RTL 后端与执行

源码：[`core/`](../verilog/rtl/core/)、[`backend/`](../verilog/rtl/backend/)、[`execute/`](../verilog/rtl/execute/)。容量见 [package.md](package.md)，访存见 [memory.md](memory.md)。

```text
IQ → 译码/单发射 → RAT + PRF + ROB + 七池 RS
                                  ↓
                   ALU / MUL / DIV / BRU / AGU
                     ↓ 两路写回       ↓ 恢复候选
                 PRF/ROB/RS       Flush Arbiter
                     ↓               ↓
                 按序提交       全流水年龄门控与恢复
```

## Core 集成边界

[`rv32_core`](../verilog/rtl/core/rv32_core.sv) 参数 `RESET_PC=0`、`LEGACY_HALT=0`。复位释放首拍独立 boot，不取指、发射或提交。课程顶层和退出控制见 [course.md](course.md)。

| 接口组 | 含义 |
|---|---|
| `imemReqValid/Ready/Addr`、`imemRspValid/Data/Ready` | 32 bit 指令端口，字节地址、顺序返回、受阻保持。 |
| `imemCacheRequestOutput` / `imemFlushOutput` | 带预测上下文的完整 I$ 请求与逻辑取消。 |
| `dmemReqValid/Ready/Write/Addr/Wdata/Wstrb/Size` | 32 bit Load 或已提交 Store；字节使能从原始地址起排列。 |
| `dmemRspValid/Rdata` | Load 返回；带 ID 运输规则见 [memory.md](memory.md)。 |
| `commitValid/Pc/Instr`、`commitRdValid/Rd/RdValue` | 实际退休及非零架构寄存器更新，值来自 PRF。 |
| `commitMemValid/Addr/Data/Wstrb` | 退休 Store 的 SQ 载荷，独立于同拍内存发送请求。 |
| `haltedOutput` / `trapOutput` | 退出退休冻结核心；异常实际提交置 trap。 |

表中接口组省略 `Input/Output` 后缀，完整名称以源码为准。

发射须 IQ 有效、ROB/目标 RS/LSQ 可分配，写寄存器时还须 PRF 有空闲。每拍至多发射、提交各一条，七池独立派发；两路 CDB 仲裁见执行时序，BRU 和 Store ready 仅通知 ROB 完成。

## 重命名与提交

| 模块 | 接口与状态 |
|---|---|
| [`rv32_rat`](../verilog/rtl/backend/rv32_rat.sv) | `readInput/readOutput` 组合查两源映射；`renameInput/renameOutput` 建新映射并返回旧物理号；`commitInput` 更新提交映射。复位架构号映射到同号物理寄存器，x0 恒为 0。 |
| [`rv32_prf`](../verilog/rtl/backend/rv32_prf.sv) | 三组合读口、core 配置两写回口（模块默认四口）；`allocationInput/allocReadyOutput/allocPhyOutput` 分配，`freeInput` 回收。`valueValid/value` 可在分配时预置跳转链接值。 |
| [`rv32_rob`](../verilog/rtl/backend/rv32_rob.sv) | `allocInput` 保存指令、改名、访存及预测元数据；只有就绪头项可经 `commitReadyInput/commitFireOutput` 退休。六个完成槽中 core 接 ALU/共享结果/BRU，其余接零，异常仅接受 0/4 号口；`storeReadyInput` 为 SQ ready/epoch 位图。 |

PRF 自由队列复位为 P32..P47，FIFO 使用 epoch+slot 并跳过填充编码。分配读旧队首，本拍回收下拍可用，P0 不分配/回收。恢复停分配和退休，四拍按 ROB 年龄回收年轻 `newPhy`；正常退休的 `oldPhy` 回收不与恢复并发。

ROB 的 `lookupInput[5]/lookupOutput[5]` 都验证完整 tag，前两路另供控制流上下文。`replayOutput` 不再按 head 旋转 16 项，而是直出两路窄窗：`replayNarrowWindow`（`robTag/archRd/newPhy`，16 bit×4）供 RAT/PRF，`replayRasWindow`（`robTag/PC/opcode/rd/funct3/rs1`，57 bit×4）供 RAS；消费者按 beat 装载，须结合存活计数和 tag 验证；RAT 从提交映射重放至恢复边界。ROB 在广播拍清严格年轻项、尾指针回到边界后一项；读取基线及四拍重放期间不退休，payload 保持以供 free list 读取已取消后缀。Store 就绪核验旧有效 Store、slot/epoch；退休只等 SQ 地址/数据就绪，不等内存接受。

### 已提交 SRAM 与四拍重放

- 已提交 RAT：`sram_fakeram DEPTH=1, WIDTH=192, WRITE_GRANULARITY=6`，一个宽字容纳全部 32 项；正常退休只写一个 lane。已提交 RAS：`DEPTH=1, WIDTH=512, WRITE_GRANULARITY=32`，正常 call 只写一个 lane。投机 RAT/RAS 和 free list 仍为寄存器。
- SRAM 无复位；RAT 每项 valid 为零时提供初始同号映射，RAS 每项 valid 为零时提供零内容；栈深保留为寄存器。不是将普通 32×6／16×32 单端口 SRAM 当成多读口。
- 广播拍 **R**：禁止提交以避免单端口 SRAM 读写冲突，启动同步基线读；ROB/RS/FU/LSU 按原年龄规则取消错路项。`rv32_recovery_cursor` 保存原始 ROB 占用、边界、完整 `nextTag` 与窗口 offset。
- **R+1..R+4**：RAT、RAS、free list 共用游标，每拍最多处理 4 条（默认 ROB16），第一拍直接从 SRAM 输出起算，不额外插入基线复制拍。RAT/RAS 重放 head 至边界（含两端），free list 遍历原始窗口并只回收严格年轻的 `newPhy`；后续拍从上一拍恢复态继续，游标推进到下一待处理 tag。不足 16 条仍固定四拍。
- 四拍期间冻结取指、RS/FU、ROB，禁止发射、退休和 CDB 消费；暂停 flush 队列广播，完成后可处理更老的待决恢复。LSU/Cache/AXI **不冻结**：已提交 Store 及在途 Load 返回继续推进，Load 结果留在 LQ 等待授权。前端在广播拍重定向，恢复结束后重新取指。
- 小容量宽字布局只使用 FakeRAM 拟合，不代表已验证真实工艺宏。该协议改变周期，后续两软件同步已完成；定向测试、功能/IPC 及同步证据见[实验记录](experiments.md#recovery4)，面积/STA 见 [assessment-results.md](assessment-results.md)，不沿用旧单拍恢复验收。

## 保留站

[`rv32_rs`](../verilog/rtl/backend/rv32_rs.sv) 保存两个源的 ready/tag/value，按 ROB 年龄选择最老就绪项。`allocInput/allocAuxInput` 分配，`writebackInput[WRITEBACK_PORTS]` 捕获唤醒（默认四口、core 两口），`issueOutput/issueReadyInput` 实际派发。写回拍捕获，**下拍才可派发依赖项**。

恢复广播拍禁止新分配，边界保留但不派发，年轻项取消，严格更老项可继续派发；随后四拍重放冻结全部 RS/FU。Load/StoreAddr 共用 AGU，aux 保存类别和 LSQ 槽；StoreValue 设置 `ISSUE_WIDTH=2`，最多同拍交付两份数据。core 的 SQ `dataTag=0`，禁用 SQ 直接 CDB 唤醒。

## 执行时序

`execute_request_input_t` 携带操作数、操作码、PC、ROB/物理标签。ALU独占CDB0；
MUL/DIV/LQ经过完整ROB活动身份与恢复资格检查后，由
[`rv32_cdb_arbiter`](../verilog/rtl/backend/rv32_cdb_arbiter.sv)组合选择最老者共用CDB1。
按ROB模年龄比较，不能按tag数值大小排序；有效tag含epoch，平局防御顺序为MUL/DIV/LQ。
ALU输出ready仍为1，MUL/DIV的outReady及LSU的loadResultReady分别接实际源授权。
未授权结果保持、MUL逐级反压，LQ获授权才标记已广播、真实ROB退休才释放。
PRF、七池RS及LSU在core中均实例化`WRITEBACK_PORTS=2`；模块默认四口只兼容旧独立夹具。
ROB只接ALU、共享结果和独立BRU完成事件，其余旧完成槽接零。不新增结果级，
无争用写回及下拍依赖派发边界不变，争用失败者等待后续拍。

| 模块 | 功能与边界 |
|---|---|
| [`rv32_alu`](../verilog/rtl/execute/rv32_alu.sv) / [`rv32_alu_unit`](../verilog/rtl/execute/rv32_alu_unit.sv) | 组合整数、移位、比较与跳转运算，加减复用 CLA；JALR 清 bit0。单槽结果级消费/取消时可重填，一条/拍，派发后下一拍 CDB。JAL/JALR 分配时可预置 PC+4。 |
| [`rv32_bru`](../verilog/rtl/execute/rv32_bru.sv) / [`rv32_bru_unit`](../verilog/rtl/execute/rv32_bru_unit.sv) | 条件比较、真实 taken/nextPC、误预测和目标未对齐检测；一拍登记结果，无输出 ready，不写 PRF。恢复拍只接收/输出严格更老项。 |
| [`rv32_mul`](../verilog/rtl/execute/rv32_mul.sv) | radix-4 Booth → CSA → 最终加法，三级弹性流水；n 拍接收、n+3 CDB、依赖最早 n+4 派发。MUL 取低 32 位，其余乘法取高位。恢复取消边界及年轻结果。 |
| [`rv32_div`](../verilog/rtl/execute/rv32_div.sv) | 单上下文 radix-4 SRT，PREP/LOOP/FINISH；除零、溢出和简单比较走短路径。消费同拍可接收；只取消严格年轻工作，边界结果不输出且未握手时保持。 |
| [`rv32_agu_unit`](../verilog/rtl/execute/rv32_agu_unit.sv) | 单槽地址结果级；完整接口、LSQ 身份及 n/n+1/n+2 边界见 [memory.md](memory.md)。 |

## 恢复仲裁

[`rv32_flush_arbiter`](../verilog/rtl/core/rv32_flush_arbiter.sv) 为 4 项候选队列。`branchInput/jumpInput` 收 BRU/ALU 的误预测或未对齐候选，`squashOutput` 广播旧队列中 ROB 年龄最老者。

新候选不直通：n 拍执行，n+1 入队，n+2 最早广播。恢复删除边界及年轻候选，前端按 PC 重定向，预测器按 checkpoint 恢复。队列恢复保留边界与执行结果可否输出是不同规则，不可仅用低位槽号认证旧结果。
