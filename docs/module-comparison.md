# 模块级对比：C++ 参考模拟器 ↔ SystemVerilog RTL

## 范围与阅读方式

| 代号 | 目录 | 性质 |
| --- | --- | --- |
| **REF** | `../RV32IM_Simulator/RISC-V-Simulator-Template` | C++20 周期级 Tomasulo 模型（`Register`/`Wire`/`work()+sync()`） |
| **RTL** | `CPU-2026/rtl` | 可综合 SystemVerilog RV32IM 乱序核 |

两侧同源：RTL 的架构参考 REF，`docs/reference-analysis.md` 是 REF→RTL 的转换说明，本文是它的**逐模块展开版**：每个模块给出「职责 / 执行流程 / 调用关系 / 差异点」，最后按设计层、运行逻辑层、实现方式层分类收敛。REF 侧缺陷与 RTL 有意偏离见 §6。

阅读约定：**REF 的"周期"由 `work()` + 全局 `sync()` 表达**，跨模块读的是 `_M_old`（周期初旧值）；**RTL 的周期由 `posedge clk_i` 表达**，`always_ff` 天然读旧写新。下文说"同拍"指同一时钟边沿所在的这一拍。

---

## 1. 全局架构差异（先看这一节）

### 1.1 周期与调度

| 项 | REF | RTL |
| --- | --- | --- |
| 周期载体 | `CPU::run()` 循环：周期初采样判停 → `dcpu.run_once()`（按注册号顺序 `work()` → 全局 `sync()`）→ 判停 | 单时钟域；`always_ff` 为时序、`always_comb`/`assign` 为组合 |
| 模块枚举 | `CPU.hpp:31-66` 27 个模块成员，`CPU.cpp:51-77` 逐个 `dcpu.add_module(&X)` 按固定顺序注册 | `rv32_core.sv` 一处实例化 19 个模块（15 种，`rv32_rs` 参数化实例化 5 次；含 1 个 CLA 链接值加法器 `rv32_add`） |
| 跨模块通信 | 全 `Wire`（lazy lambda，每拍求值一次）；所有跨模块读经桥接访问器落到 `_M_old` → **work() 顺序结构无关**（`run_once_shuffle()` 验证） | 真实 net；由 RTL 单驱动语义保证，无顺序概念 |
| 复位 | 无复位信号：各模块用 `bootDone` 做"复位周期"在 `work()` 里写初值（`Register` 无法构造时设初值） | `rst_ni` 异步复位，`always_ff` 里逐表清零 |
| 顶层 | 单一 `CPU` | 两个：`cpu_top.sv`（32-bit IMEM/DMEM ready/valid 直连、无缓存）；`cpu_cached_top.sv`（128-bit 行接口 + I$/D$） |
| 判停 | `run()` 的 `finish` 条件：halt 已提交 ∧ FQ/IQ/ROB/SQ 空 ∧ DMEM 双口空闲 ∧ DCache 空闲 | `rv32_core` 的 `halted_q`（HALT 提交置位）；`cpu_cached_top` 额外要求 `dcache_flush_done` |

**差异**：REF 把"周期"做成软件循环、把"模块间连线"做成 lambda 引用；RTL 把两者交给时钟与网表。REF 的 27 个模块与 RTL 的 21 个不是一一映射（见 §2）。

### 1.2 数据流对照（同一条流水线，两种拆分）

```
REF:  BPU ──►FetchUnit──►ICache──►FQ──►DecodeUnit──►IssueArbiter ──►RS(7池)──►DispatchArbiter
        ▲        │                    (4)    (IQ 4)        │                            │
      IMEM      (512行)                                   RAT/PRF/ROB             ALU/MUL/DIV/BRU/AGU(4槽队列)
                                                                                        │
                              AluCDB / LqCDB / MulCDB / DivCDB ──► PRF / ROB / FlushArbiter
                              LQ+SQ+MemArbiter ──► DCache(2态) ──► DMEM(双口20拍)

RTL:  predictor ──►frontend(FQ4+IQ4, 取指控制一体)──►decoder ──►rv32_core 发射组合 ──►RS(5实例,自己选最老)
        ▲              │                                                       │
      icache        (参数化)                                          alu_unit/mul/div/bru_unit/agu(组合)
     /sram_1rw                                                                    │
      (顶层外主存)                          4 条直连写回通道 ──► PRF / RS / ROB / LSU
                                        lsu(LQ+SQ+字节转发+端口) ──► dcache(FSM) ──► sram_1rw
```

**结构差异归纳**（细节见 §3）：

1. REF 的**发射/派发是两个显式无状态仲裁器模块**；RTL 把它折叠成 `rv32_core` 的一段 `always_comb`（发射）+ 各 RS 的 `issue_valid_o` 与 FU 的 `in_ready_o` 握手（派发）。
2. REF 的**每条结果通路都有一个 CDB 模块**（承载 squash 门与打包）；RTL **没有 CDB 层**，`out_valid_o` 直连。
3. REF 的**执行单元带结果队列**（ALU/MUL/BRU/AGU 各 4 槽，DIV 1 表项），消费者轮询 head；RTL 的单元是**流水/单级寄存器 + `in_valid/in_ready` 握手**。
4. REF 的**访存子系统拆成 AGU(4 槽) + LQ + SQ + MemArbiter**；RTL 拆成**组合 AGU + 单个 `rv32_lsu`**（LQ/SQ/转发/端口都在里面）。
5. REF 的**主存（IMEM/DMEM）是核内模块**；RTL 把它移到**核外 ready/valid 端口**，由 testbench 提供延迟。

---

## 2. 模块对应关系总表

| 功能 | REF | RTL | 关系 |
| --- | --- | --- | --- |
| 取指控制 | `FetchUnit` | `rv32_frontend`（内） | 合并 |
| 取指队列 FQ | `InstructBuffer` | `rv32_frontend`（内） | 合并 |
| 解码队列 IQ | `DecodeUnit` | `rv32_frontend`（内） | 合并 |
| 译码 | `Decoder`（静态函数） | `rv32_decoder` | 1:1（输出结构不同） |
| 分支预测 | `BPU` | `rv32_predictor` | 1:1 |
| L1I | `ICache` | `rv32_icache` | 1:1（内部结构不同） |
| 指令主存 | `IMEM`（模块） | 核外端口 + tb | 移出核 |
| 重命名 | `RAT` | `rv32_rat` | 1:1 |
| 物理寄存器堆 | `PRF` | `rv32_prf` | 1:1（分配算法不同） |
| 重排序缓冲 | `ROB` | `rv32_rob` | 1:1（状态表示不同） |
| 保留站 | `RSUnit`（7 池） | `rv32_rs`×5 实例 | N:1 |
| 发射仲裁 | `IssueArbiter` | `rv32_core` 组合云 | 折叠 |
| 派发仲裁 | `DispatchArbiter` | `rv32_rs` 内部 + 握手 | 折叠 |
| 结果总线 | `AluCDB`/`LqCDB`/`MulCDB`/`DivCDB` | 无（直连） | 删除 |
| 整数执行 | `ALU`（4 槽队列） | `rv32_alu_unit`+`rv32_alu` | 1:1（缓冲方式不同） |
| 乘法 | `MUL`（Booth+CSA） | `rv32_mul`（Booth+CSA，3 级流水） | 1:1（实现细节不同） |
| 除法 | `DIV`（SRT radix-4） | `rv32_div`（restoring） | 1:1（**算法不同**） |
| 分支执行 | `BRU`（4 槽，不判错） | `rv32_bru_unit`+`rv32_bru` | 1:1（**判错归属不同**） |
| 地址生成 | `AGU`（4 槽队列） | `rv32_agu`（组合加法） | 1:1（**结构不同**） |
| 加载队列 | `LQ` | `rv32_lsu`（内） | 合并 |
| 存储队列 | `SQ` | `rv32_lsu`（内） | 合并 |
| 访存仲裁 | `MemArbiter` | `rv32_lsu` 请求生成 | 合并 |
| L1D | `DCache`（2 态） | `rv32_dcache`（FSM 多态） | 1:1（**FSM 不同**） |
| 数据主存 | `DMEM`（双口模块） | `rv32_sram_1rw` + 核外 | 拆开 |
| squash 排队 | `FlushArbiter`（4 槽，BRU/CDB 两来源） | `rv32_flush_arbiter`（4 槽，BRU/CDB 两来源） | 1:1 |
| 加法器 | 宿主 `+`（`evaluate()`） | `rv32_cla`（手写 CLA，2/4/8/16/32/64 位） | RTL 独有 |
| —— | `Memory`（基类，128 KiB） | 无（tb 提供） | RTL 无对应 |

---

## 3. 逐模块对比

### 3.1 取指控制：`FetchUnit` ↔ `rv32_frontend`（取指部分）

**REF**（`src/FetchUnit/FetchUnit.cpp`，模块仅 20 行）

- 职责：持有 `programCounter`、`haltFetched` 两个 `Register`，是前端唯一的架构 PC 源。
- 流程（`work()`，三段互斥）：① `needSquash` → `PC = SquashPC`、清 `haltFetched`；② `haltSignal` → `haltFetched = 1`；③ `FetchValid` → `PC = PredictPC`。
- 调用关系：读 `flushArbiter.needSquash/SquashPC`、`ICacheModule.isHaltSignal()`（组合谓词）、`BPU.outValid/outPredictedPC`（**预测由 BPU 组合给出的打包总线**，见 `CPU.cpp:87-99`）；写自身两个 Register；被 `BPU.fetchCtx.pc`、`FQ.haltFetched` 读。

**RTL**（`rv32_frontend.sv:47-53, 135-155, 189-288`）

- 职责：`pc_q` + `request_pending_q` + `request_drop_q` + `stop_fetch_q`，并把 FQ(4 槽) 与 IQ(4 槽) 一起实现。
- 流程：`imem_req_valid_o = (response_accept || !request_pending_q) && !halt_response && fire_space_ok && !stop_fetch_q && !redirect_valid_i`；`request_fire` 当拍更新 `pc_q <= predicted_next_pc_i`；`halt_response`（响应字 == `HALT_INSN`）当拍**即不再发请求**并置 `stop_fetch_q`。
- 调用关系：读顶层 `imem_req_ready_i/imem_rsp_*`、`predicted_next_pc_i/predicted_ckpt_id_i`、`redirect_valid_i/redirect_pc_i`；输出 `predictor_pc_o`、`predictor_accept_o`、`iq_*`、`fetch_info_*`。

**差异**

| # | 差异 | REF | RTL |
| --- | --- | --- | --- |
| 1 | halt 停取时机 | `haltSignal` 组合谓词 → 下一拍 latch `haltFetched`，之后 FQ 才拒收 | `halt_response` 当拍就不发下一请求，并置 `stop_fetch_q`（更早一拍） |
| 2 | 取指未完成度 | 无"请求在途"标记（ICache 队列承担） | 显式 `request_pending_q/request_drop_q`，**单 outstanding** |
| 3 | 同拍续发 | 由 ICache 的 4 项请求队列吸收 | `response_accept` 当拍允许发下一请求（README 记录的"命中 2 拍/条"优化） |
| 4 | PC 推进条件 | `FetchValid`（BPU `fetchAllowed()` 门控） | 自身组合门（halt/backpressure/redirect），预测值经 `predicted_next_pc_i` 直接传入 |
| 5 | FQ 满预留 | `FQ.isFull()` 参与 `fetchAllowed` | `fire_space_ok` 在响应当拍要求 `fq_count <= FQ_DEPTH-2`（给 pop 留位） |

### 3.2 取指队列 / 解码队列：`InstructBuffer`+`DecodeUnit` ↔ `rv32_frontend`（队列部分）

**REF**（`InstructBuffer.cpp`、`Decoder.cpp:99-137`）

- FQ：4 槽（`isFull` 保留一槽 → 3 可用），条目 `{raw, pc, predictedPC, ckptId}`，外加 `lastValid/lastRaw/lastPC`（预译码观察点）。流程：squash → `head=tail=0` 且 **`lastValid<=0`**；否则 push（`icacheReturnReady && !haltFetched && !isFull`）+ pop（`!isEmpty && !decodeFull`）。
- IQ：4 槽（3 可用），条目 13 个字段（type/opcode/funct3/funct7/rd/rs1/rs2/imm/pc/isHalt/allocDest/predictedPC/ckptId）。流程：squash → `head=tail=0`；否则 pop（`issueValid`）+ push（`!fqEmpty && !isFull` 时**当拍调用 `Decoder::decode`**）。

**RTL**（`rv32_frontend.sv:55-67, 245-287`）

- FQ/IQ 各 4 槽，条目 `{pc, instr, predicted_pc, ckpt_id}`；计数用 `fq_count_q/iq_count_q`（REF 用 head/tail 指针比较）。
- 流程：`fq_push = response_accept && !request_drop_q && !redirect_valid_i`；`fq_pop = (fq_count != 0) && (iq_count != IQ_DEPTH) && !redirect`；`iq_push = fq_pop`；`iq_pop = iq_valid_o && iq_ready_i`。`redirect_valid_i` 分支把 PC 与两队列的 head/tail/count **全部清零**。
- 预译码：`last_fq_push_q/last_fq_instr_q/last_fq_pc_q` 三个寄存器，组合展开成 `fetch_info_*`（`always_comb:164-187`）。

**差异**

1. **REF 是四个独立模块（FetchUnit / ICache / FQ / IQ），RTL 是一个 `rv32_frontend`**。REF 的 FQ 与 IQ 是"两个真队列 + 两次握手"，RTL 的 FQ→IQ 是**同拍直通**（`iq_push = fq_pop`，一拍搬一条）。
2. **编译器/译码器位置**：REF 把译码放在 `DecodeUnit::work()` 内（IQ push 时译码），RTL 把译码移到 `rv32_core` 的 `rv32_decoder`（纯组合，IQ 输出直接译码）。RTL 的 IQ 只存 `{pc, instr, predicted_pc, ckpt_id}` 原始信息。
3. REF 的 `lastValid` 在 squash 时显式清零（`InstructBuffer.cpp:11`，历史上踩过"早退不清 lastValid → 幽灵 RAS push/pop"）；RTL 的 `last_fq_push_q` 在 `redirect_valid_i` 分支里清（`rv32_frontend.sv:228`）。语义对齐但落点不同。
4. REF 的预译码由 CPU 侧 `scanJump()`（`CPU.cpp:14-44`）完成，且**每个 `fetchInfo.*` wire 各调用一次 `scanJump`（共 6 次重复求值）**；RTL 一次 `always_comb` 出全部 `fetch_info_*`。
5. 队列满判据：REF `(!(tail+1 & mask) == head)`（保留槽）；RTL `count_q == DEPTH`。

### 3.3 译码：`Decoder` ↔ `rv32_decoder`

**REF**（`Decoder.cpp:3-97`）：`static Uop decode(int32_t raw)`，纯函数，输出 `Uop{type, opcode, funct3, funct7, rd, rs1, rs2, imm, pc, isHalt, allocDest, predictedPC, ckptId}`。类型域 `RISC_V{R,I,M,Istar,S,B,U,J,RV_INVALID}`。**不判非法**——`0x13` 的移位立即数走 `Istar`，其它组合留给发射阶段。

**RTL**（`rv32_decoder.sv`）：纯组合，输出 `decoded_uop_t`，**含 `illegal` 位与 `uop_class`**（`UOP_ALU/MUL/DIV/BRANCH/LOAD/STORE/HALT/ILLEGAL`），并直接给出 `uses_rs1/uses_rs2/uses_imm/writes_rd/mem_size/mem_unsigned`。

**差异**

| # | 差异 | REF | RTL |
| --- | --- | --- | --- |
| 1 | 合法性判定时机 | **发射阶段**（`IssueArbiter::issueClass()` + `decodeOp()`，`StaticArbiter.cpp:371-408`） | **译码阶段**（`unique case` 逐 funct3/funct7 判） |
| 2 | 执行单元归类 | 由 `RISC_V::M` 类型 + `decodeOp` 结果在发射时判（M 的 funct3 0..3→mulRS，4..7→divRS） | 译码直接出 `uop_class` |
| 3 | 非法指令结果 | 无 `illegal`/trap；表现为 `RV_INVALID` 类型，可能造出永不完成的 ROB 项（REF 已知缺陷） | `illegal=1` → ROB 记 `exception` → `trap_o` |
| 4 | Istar 子类 | 有（`0x13` 的 SLL/SRL/SRA 立即数） | 无（用 funct7 检查直接判非法/合法） |
| 5 | 立即数生成 | `switch` + lambda `getImm` | `case` 内联位拼接 |
| 6 | `writes_rd` | `inst.rd != 0`（S/B 除外） | `rd != 0` 且仅在写 rd 的类里置位；`illegal` 时强制清 0 |

### 3.4 分支预测：`BPU` ↔ `rv32_predictor`

**REF**（`BPU.cpp`）

- 职责：Tournament 方向预测（localPHT/globalPHT/selector 各 256×2b + GHR8）+ 目标侧（BTB64 + RAS8{retPC,times9} + SARAS16{alignQueue} + condSeen512）；**同时是 checkpoint 状态的所有者**（`bpCkpt[32]` 存 GHR/alignTail/RAS_top，`nextCkptId`）。
- 预测路径：`predict(pc)` 组合：`p2=pc>>2`；`btbHit = BTB[p2&63].state && tag==pc>>8`；`taken = btbHit && (selector>=2 ? globalPHT : localPHT)`；BTB state==2 覆盖为 taken；`isRet && RAS_top==0` → 强制 `btbHit=taken=false`（野取指修复）；`predictPC = taken&&btbHit ? (isRet? RAS[top-1].retPC : BTB.target) : pc+4`。
- 输出：`outPredPC/outValid/outPC/outPacked`（packed 低位放 `shift/shiftValue` + ckptId）→ 被 `FetchUnit`、`ICache` 读。
- 训练：两个口——**BRU 口**（EX/投机：更新方向表、condSeen、BTB(条件 taken)、già 维护投机 GHR/RAS/bpCkpt）与 **CDB 口**（commit：只 `jumpWriteIntent`，恒不碰投机态）；BTB 三源写口仲裁 `fetch > cdb > bru`，line 与 target 分两组独立仲裁（`BPU.cpp:389-420`）；squash 优先级最高，从 `bpCkpt[ckpt]` 恢复 GHR/alignTail/RAS_top 并用 alignQueue 回卷 RAS 条目。
- 统计：`branchTotal/branchCorrect`。

**RTL**（`rv32_predictor.sv`）

- 职责与表结构同 REF（256×2b×3 + GHR8 + BTB64 + RAS8 + condSeen512 + 16 项 RAS journal + 32 检查点），README 与 `implementation-plan.md` 明确列出。
- 接口：`query_pc_i` → `predicted_next_pc_o/predicted_taken_o/predicted_ckpt_id_o`（**组合直通**，取指当拍出结果）；`fetch_accept_i`；训练口 `branch_*`（BRU）与 `jump_*`（ALU CDB）；`fetch_info_*`（预译码早训练）；`squash_valid_i/tag/ckpt_id`。

**差异**

1. **无结构性差异**：表容量、哈希、checkpoint、RAS journal、三源写口仲裁、squash 恢复流程逐项对应（REF 的 `bpCkpt[]` 状态复制 ↔ RTL 的 checkpoint 表）。
2. **checkpoint 载体**：REF 用 `BPUSnapshot{GHR_snapshot, alignTail, RAS_top}`（3 字段）；RTL 同 3 字段 + `predicted_ckpt_id` 作为取指侧输出。
3. **训练驱动的"来源模块"不同**：REF 的 BRU 口读 `bru.bruHeadPCResult/bruHeadPCFrom/headRobTag` 并由 BPU 自己与 ROB 的 `robPredictPC` 比较判对错；RTL 的 `branch_taken_i/branch_mispredict` 由 **BRU 单元直接给出**，BPU 只做训练（判错归属差异，见 §3.18）。
4. **GHR 移位门控**：两者都用 `btbHit || condSeen`（`BPU.cpp:79-81` ↔ RTL `fetch_info`/condSeen 逻辑）。
5. REF 的预测打包总线 `outPacked`（位域塞 `shift/shiftValue/ckptId`）是**软件侧的线宽压缩技巧**；RTL 用独立端口。

### 3.5 L1I：`ICache` ↔ `rv32_icache`

**REF**（`ICache.cpp` + `ICache.hpp`）

- 组织：512 行 × 16 B（8 KB），直接映射；`tag = addr>>13`（在 128 KiB 空间里 4 bit）；行内 4 个 32-bit 字。
- **额外带一个 4 项投机请求队列** `requestBuffer[4]`，每项 `{raw_inst, PC, predictPC, ckptId, valid, ready}`，`head` 2-bit；`occupancy()` 组合归约（不存计数器）。
- 流程（`work()`）：squash → 清队列 valid + `head=0`（**行阵保留**）；`popConsume` → 出队（自清自身状态）；`lineReturn.valid` → 填行 + **回填新 head 的占位**（`raw_inst ← data[(PC>>2)&3]`、`ready=1`）；`fetchValid` → 命中则 `ready=1` 且取字，缺失则放占位（`ready=0`）。
- 命中判定：`isReturnReady()` = 头槽 `valid && ready`；`isHaltSignal()` = 头槽指令 == `0x0ff00513`（**组合谓词，非寄存器**）。
- 统计：`statHits/statMisses`（push 时累加，不参与数据通路）。

**RTL**（`rv32_icache.sv`）

- 组织：`SETS=512` 行 × 16 B，直接映射；**FSM `IDLE`/`TAG_READ`**；CPU 侧 `cpu_req_valid/ready` 握手，`cpu_rsp_valid/data`；存储侧 `mem_req_valid/ready/addr` + `mem_rsp_valid/data`（16 B 行）。

**差异**

| # | 差异 | REF | RTL |
| --- | --- | --- | --- |
| 1 | 缓冲结构 | **4 项投机请求队列**（解耦取指与消费，容忍 4 笔在途） | 无队列，一次一个请求（`IDLE` 握手 → `TAG_READ` → 响应） |
| 2 | 命中延迟 | **0 拍**（push 当拍 `ready=1` 即可被 FQ 取走） | **2 拍/条**（README 记录：优化前 3 拍，现 `IDLE` 握手 + 读行） |
| 3 | 多 outstanding | 是（4 项） | 否（单 outstanding，缺失串行填充） |
| 4 | 占位/回填机制 | 显式 `valid`（占位）+ `ready`（可取走）双位，`lineReturn` 到达时按"post-pop 后的新 head"回填 | 由 `request_pending` 语义 + `cpu_rsp_valid` 表达 |
| 5 | halt 识别 | 头槽字比较（组合谓词） | 由 frontend 比较 `imem_rsp_data_i == HALT_INSN` |
| 6 | squash | 清请求队列，保留行阵 | 无内部 squash 端口（前端 `redirect` 自行丢弃） |
| 7 | 命中率统计 | `statHits/statMisses`（`VERBOSE=icache`） | 无（RTL 不在核内做统计，避免测试专用逻辑） |

### 3.6 指令主存：`IMEM` ↔ 核外端口

**REF**（`IMEM.cpp`）：核内模块。16 项请求队列，每项 `{Data[4]（4×32-bit 行）, lineAddr, remainCycle(6b), valid}`；`work()`：squash → 清全表 `valid` 并把 `remainCycle` 归零 + `head=0`；`lineConsumed` → 出队（清 valid 即占用递减，不存计数器）；`fetchValid` → claim（`remainCycle = MEM_LATENCY = 20`）；固定长度扫描递减，到 0 时 `read_word` 取 4 个字。`retValid/retLineAddr/retWord` 是**组合视图**（`remainCycle==0`），经 `LineReturn` 四字总线给 ICache（**不额外加流水级**）。

**RTL**：**没有 IMEM 模块**。`cpu_top` 直接导出 `imem_req_valid/ready/addr` + `imem_rsp_valid/data`（**32-bit 单字**）；`cpu_cached_top` 导出 128-bit 行接口。延迟由 `tb/core/tb_core_ipc.sv` 提供（固定 20 拍，且"每次读延迟都必须是 20 拍否则判失败"）。

**差异**：REF 把"主存 + 20 拍延迟 + 多 outstanding 队列"建模在核内（可独立多笔；ICache 缺失时仍能继续排队）；RTL 把它完全移出核，核只暴露握手端口，且 `rv32_frontend` 单 outstanding。**这一条是两侧"取指缺失吞吐"差距的主因之一**，也是 RTL 可综合/可换 SRAM 宏的设计前提。

### 3.7 发射：`IssueArbiter` ↔ `rv32_core` 组合发射

**REF**（`StaticArbiter.hpp:183-381` + `StaticArbiter.cpp:371-…`）

- 职责：每周期从 IQ 头最多选 1 条，分配全部资源并驱动 9 组 payload。
- 分类：`issueClass()` 返回 0..9（0 none / 1 INT / 2 HALT / 3 LOAD / 4 STORE / 5 BR / 6 UJ / 7 RV_INVALID / 8 MUL / 9 DIV）。
- 资源门（`wire_output()`）：ROB 不满、目标 RS 有空槽（first-fit 扫描）、`PRF.freeListEmpty == false`、LSQ 不满（`lqFull/sqFull`）。
- 输出：`core{valid,allocDest,phy,robTag,isLoad,isStore,isControl,nBytes,isUnsigned,pc}`、`select`（7 类 has + slot）、7 组 push payload、`robEntry{type,isCommitReady,dest,halt,isRet,ckptId,predictedPC,pc,lqTailSnapshot,sqTailSnapshot,newPhy,oldPhy}`。
- `resolveSrc(v)`：`v.ready` → `Operand{tag=InvalidPhy, imm=v.value}`（x0 常量零）；否则 `{tag=v.phy, imm=0}`。

**RTL**（`rv32_core.sv:343-387`）

- 单宽发射：`issue_fire = frontend_iq_valid && issue_resources_ready && !global_flush && !halted_q && !trap_q`；`frontend_iq_ready = issue_fire`。
- `target_rs_ready`：按 `decoded.uop_class` 选 `int_alloc_ready / mul_alloc_ready / div_alloc_ready / branch_alloc_ready / (mem_alloc_ready && lq/sq_alloc_ready)`。
- `issue_resources_ready = rob_alloc_ready && target_rs_ready && (!writes_rd || prf_alloc_ready)`。
- 操作数：**不由发射逻辑组装**，而是把 `rat_rs1_phy/rs2_phy` 与 `prf_src1_ready/value` 直接接给各 RS 的 `alloc_*` 端口，由 RS 自己决定捕获什么。

**差异**

| # | 差异 | REF | RTL |
| --- | --- | --- | --- |
| 1 | 形态 | 独立模块（`dark::Module<In,Out,Inner>`，`work()` 空、输出全 Wire） | `rv32_core` 内一段 `always_comb` |
| 2 | 操作数组装 | 发射器解析 `ready` → `Operand{tag,imm}`，并打包成 7 组 payload | RS 端口直连 RAT/PRF，**发射器不做 resolve** |
| 3 | 资源门语义 | 显式 4 项（ROB/RS/PRF/LSQ） | 同名信号的组合与（`rob_alloc_ready && …`） |
| 4 | slot 分配 | first-fit 扫描在发射器内做 | first-fit 在 RS 内做（`alloc_ready_o/alloc_index`） |
| 5 | LSQ 尾快照 | 发射器输出 `lqTailSnapshot/sqTailSnapshot`（**include-self**，`getTailSnapshot()`）写入 ROB 条目，squash 时用于回卷 LQ/SQ tail | **不存在**：ROB 无快照字段，LSU 用 `flush_tag` 年龄比较自行清项（见 §3.11、§3.20） |
| 6 | 非法指令 | `win=7 RV_INVALID` 生成一个"空"payload（历史缺陷：可造永不完成的 ROB 项） | `decoded.illegal` → ROB `exception` → `trap_o` |
| 7 | HALT | 作为独立 win 类（2）走 INT 池但 `allocDest=false` | `uop_class == UOP_HALT`，`rob.alloc_halt_i` 置 ready |

### 3.8 重命名：`RAT` ↔ `rv32_rat`

两侧都已**取消检查点阵列**：恢复 = 已提交基线 + **按 ROB 年龄重放存活条目的 rename**（squash 边界指令自身仍留在 ROB，故其 rename 也会被重放）。

**REF**（`RAT.cpp`）：`specRAT[32]` + `archRAT[32]`（均 `Register<PHY_TAG_WIDTH>`）+ `bootDone`。`readOperand(0) = {ready=true, phy=InvalidPhy}`；`readRAT_PRF(0) = specRAT[0] = 0`。
`work()`：`bootDone==0` → `specRAT[1..31] <= i`、`archRAT[1..31] <= i`、`bootDone<=1`（**一次性的"复位周期"，占用 cycle 0**）；否则逐槽单写口：`restore` → `specRAT[i]` 先取 `archRAT[i]`，再被**ROB 窗口重放**覆盖（窗口 = 自 `rob.head` 沿 `robNextTag` 走到 `SquashTag`（含），窗口内最后一个 `dest == i && newPhy != InvalidPhy` 的条目胜出）；`else if (issueHasDest && i == issueDest)` → `specRAT[i] <= issuePhy`；`commit`（`rob.willCommit`）→ `archRAT[headDest] <= headNewPhy`。`_DEBUG` 下另有"squash tag 必须落在存活 ROB 窗口内"的断言（host-only 守卫，不进硬件）。

**RTL**（`rv32_rat.sv`）：`map_q[32]` + `arch_q[32]`。复位写 `map_q[i]=i`、`arch_q[i]=i`。组合读口对 `arch==0` 直接返回 `'0`。组合块 `build_restore_map`：`restore_map[i] = arch_q[i]`，再按重放窗口逐条覆盖（`replay_arch_rd_i == i && != 0 && replay_new_phy_i != '0`）；`always_ff`：`restore_valid_i` → `map_q <= restore_map`（**整体恢复并丢弃本拍 rename**）；`else` → rename（`arch != 0`）；commit → `arch_q[commit_arch] <= commit_phy`。

**差异**

| # | 差异 | REF | RTL |
| --- | --- | --- | --- |
| 1 | 恢复机制 | `archRAT` 基线 + ROB 窗口重放，逐槽在 `work()` 内联扫窗口 | `arch_q` 基线 + `build_restore_map` 组合块扫窗口 |
| 2 | 窗口数据来源 | 直接读 `rob.dest[slot]` / `rob.newPhy[slot]`（Wire 视图） | `rv32_rob` 用 generate 块把"自 head 起 DEPTH 个槽"预展平为 `replay_tag_o / replay_arch_rd_o / replay_new_phy_o[16]`，RAT 只做 tag 匹配 |
| 3 | **恢复 vs 重命名同拍竞争** | `if (restore) … else if (issueHasDest…)` ⇒ restore 优先，rename 丢弃 | `restore_valid_i` 优先，rename 整体丢弃；另由 `issue_fire && !global_flush` 保证**结构上不同拍**（**已对齐**） |
| 4 | 初值机制 | `bootDone` 复位周期（cycle 0 占用） | `rst_ni` 复位 |
| 5 | arch reg 0 | 读口按 `regNum==0` 特判 `ready=true`；映射表里 0 槽是常量 0 | 读口按 `arch==0` 特判返回 `'0` |
| 6 | 检查点 | **不使用 `CKPT_CAP`**（该常量现仅由 BPU `bpCkpt[]` 消费） | **不使用 `BPU_CKPT_ENTRIES`** |
| 7 | 窗口边界守卫 | `_DEBUG` 断言 squash tag ∈ 存活 ROB 窗口 | 无（`replay_valid` 用"槽 tag == 游标"自守，异常窗口自动截断） |
| 8 | 重放取值顺序 | 逐槽覆盖局部变量，窗口内**最年轻**的匹配胜出 | 逐窗口覆盖 `restore_map`，同 |

### 3.9 物理寄存器堆：`PRF` ↔ `rv32_prf`

**两侧的 squash 恢复都统一为「ROB 窗口重放」**（与 §3.8 的 RAT 同源）：不再有 `PRFHeadCkpt[]` / `free_checkpoint_q[][]`。共用同一条不变量 —— 提交是顺序的、恒在 ROB 头部，而头部严格老于 squash 边界，所以在"边界被改名"到"冲刷发生"之间**不可能有被冲刷指令释放过寄存器**；于是

```
squash 后的空闲集合 = 当前空闲集合 ∪ { 窗口内严格年轻于边界的 newPhy }
```

与"回到边界时刻的空闲集合"完全等价。

**REF**（`PRF.cpp` + `PRF.hpp`）

- 状态：`PhysicalRegs[48]{value,ready}`、`freeList[48]`（`Register<PHY_TAG_WIDTH>` 的环形队列）、`headSeq/tailSeq`（packed seq = `{1-bit epoch, index}`，`PRF_SEQ_WIDTH=6`）。
- 复位周期（`bootDone`）：`P0..P31.ready <= 1`；`freeList[0..15] <= 32..47`；`tailSeq <= 16`；`headSeq <= 0`。
- 分配：phy 来自 `freeList[headSeq]`（发射器组合读 `getFreeListSlot(getHeadSeq())`）；`work()` 里**只在 `!needSquash` 的拍推进 `headSeq`**（源码头注释：`squash owns recovery; only a non-squash cycle can pop`）。
- pop 副作用：`issueIsCtrl` → `ready=1, value=issuePC+4`（链接值直写）；否则 `ready=0`。
- 写回：4 个 CDB 口，各 `(!needSquash || isOlder(tag,squashTag)) && newPhy != InvalidPhy`；ALU 口额外 `!cdbIsControl`。
- 释放：commit 时（`robWillCommit && !robHeadIsHalt && headType ∈ {REGISTER, LINK} && oldPhy != InvalidPhy`）→ 追加进本拍回收列表。
- squash：从 `robNextTag(squashTag)` 走到 `oldNext`（下一个空 ROB 标签），把窗口内每条 `robNewPhy` 收进 `recPhy[]`；被冲刷的 newPhy 在前、commit 的 `oldPhy` 最后，合并成**一次** `tailSeq` 推进（环尾批量回写）。

**RTL**（`rv32_prf.sv`）

- 状态：`value_q[48]`、`ready_q[48]`（位图）、`free_q[48]`（**位图，不是环形队列**）。**无检查点阵列**。
- 复位：`ready_q[0..31]=1`、`free_q[32..47]=1`。
- 分配：first-fit 扫描 `free_q` 从 index 1 起，`alloc_phy_o = 第一个空闲号`；`alloc_ready_o = !restore_valid_i && selected_valid`（对应 REF 的 `if (!needSquash)`）。`rv32_core` 的 `issue_fire` 另带 `!global_flush`，本地门控是同一不变量的第二道保险。
- 读口：3 个（`read1/read2` 给发射，`read3` 给提交读值），`phy==0` 返回 `ready=1, value=0`。
- 写回：4 个 `wb*`，`phy != 0` 才写。
- 释放：`free_valid_i/free_phy_i`（提交提供；`rv32_rob` 已在 squash 拍把 commit 放宽到"严格老于边界"）→ 置 1。
- squash：对与 `rv32_rat` **同一份** ROB 窗口（`rob_replay_tag`/`rob_replay_new_phy` + `restore_count_i`，由 `rv32_rob` 以 head 为基准预展平）逐项判「严格年轻于边界」，把命中项的 `new_phy` **或进** `free_q`。`restore_count_i` 把窗口界定在存活条目内，因此 ROB 尾之外的残留 tag 永远不会被重放。
  - 年龄判据写成**内联算术** `age = (replay_tag_i[j] - restore_tag_i) & ROB_AGE_MASK`，`age != 0 && age < ROB_HALF`，**而不是直接调用 `rv32_pkg::rob_is_younger`**：该函数内联进"读该窗口的 `always_comb`"会让 iverilog 在某一拍无限挂死（仿真时间冻结），而 Verilator 与定向 tb 均正常。两者**穷举等价**（32×32 对全部吻合；函数在 `age == ROB_HALF` 处返回 false，故上界取开区间；存活窗口最多 16 项，取不到该值）。
  - 同一条论证也解释了 `rv32_rat` 为何能用 tag 连续链而不是年龄比较：RAT 只需要"到边界为止"的窗口，PRF 需要"边界之后到 ROB 尾"那一段。

**差异**

| # | 差异 | REF | RTL |
| --- | --- | --- | --- |
| 1 | 空闲资源表示 | 环形 FIFO 列表 `freeList[48]` + `headSeq/tailSeq`（顺序分配、顺序回收） | 空闲位图 `free_q[48]` + first-fit 扫描（顺序无关） |
| 2 | 分配出的 phy 号 | 由 `headSeq` 决定的 FIFO 顺序 | 恒为"当前最小空闲号" |
| 3 | squash 恢复载荷 | 窗口内 `robNewPhy` + commit `oldPhy` 批量 push 到环尾 | 窗口内 `new_phy` 的位集 OR 进位图 |
| 4 | 窗口的界定方式 | `robNextTag` 链走到 `oldNext` | `rob_is_younger` 年龄比较 + `restore_count_i` 上界 |
| 5 | 复位依赖 | 需要 `bootDone` 复位周期建立 32..47 的环内容 | 复位一棵位图即可 |
| 6 | 安全性断言 | `assert(prfSeqDistance(...) <= PRF_CAP)` 与 `popPhy == issuePhyVal` | 无（依赖位图自洽 + `alloc_ready_o` 本地门控） |
| 7 | 链接值直写 | `issueIsCtrl` 时写 `issuePC+4`（PRF 自己算） | `alloc_value_valid_i/alloc_value_i`，**由 `rv32_core` 算好 `issue_link_value = decoded.pc + 4`** |
| 8 | `free_count_o` | 无（用 `headSeq==tailSeq` 判空） | 组合 popcount 输出（供调试/门控） |

> 语义影响：两者算出的**物理寄存器编号序列不同**（位图法取最小空闲号，FIFO 法按环序），但重命名映射本身是任意的，不改变架构结果；恢复后的空闲**集合**相同，因此本次对齐不改变 RTL 的分配序列。这是**运行逻辑（时序边角）差异**，不是功能差异。


### 3.10 重排序缓冲：`ROB` ↔ `rv32_rob`

**REF**（`ROB.cpp` + `ROB.hpp`）

- 状态：`ROBqueue[16]`，条目字段 `tag/type/isCommitReady/dest/halt/isRet/ckptId/predictedPC/pc/**lqTailSnapshot/sqTailSnapshot**/newPhy/oldPhy`；指针 `robHead/next`；`robHaltCommitted/robHaltRd`。**无 valid 位图、无计数器**。
- 判据：`isEmpty = head==next`；`isFull = robSlot(next)==robSlot(head) && next!=head`；`isOlder/isYounger` 用 `{epoch,slot}` 拆解比较（等价于 `(b-a) mod 32 ∈ (0,16]` 的模年龄规则）。
- `work()`：① push（`issueValid`）写全字段；② `markReady(tag)` 经 `matchesEffectiveTag`（**对"含本拍 push 后"的行 tag 认证**，且 `slot < ROB_CAP`）→ 汇总到**单一写口** `readyWrite[]/readyData[]`；就绪来源 = BRU 头 + SQ 扫描（`MEMQ_SCAN_WINDOW=8`）+ 4 条 CDB；③ `next` 推进（push 优先，squash 时 `robNextTag(squashTag)`）；④ `willCommitNow`（`isCommitReady && (!squash || isOlder(head,squashTag))`）→ head 前进 + 记录 halt。
- 组合视图 `headView{head,isEmpty,isHeadCommitReady,isHeadHalt,headType}` 与 `entry.*[16]` 全量字段 Wire，供 BPU/FlushArbiter/PRF/IssueArbiter 直接读。

**RTL**（`rv32_rob.sv`）

- 状态：`valid_q[16]` 位图 + `tag_q/pc_q/instr_q/writes_rd_q/arch_rd_q/new_phy_q/old_phy_q/store_q/**sq_index_q**/halt_q/**exception_q**/predicted_pc_q/predictor_ckpt_id_q/is_ret_q`；`head_q/tail_q/**count_q**`。
- 组合：`alloc_ready_o = !flush_i && !full_o`；`lookup0..lookup4` 对完整 tag 做 live 匹配，分别供控制流与 4 条结果通道认证；commit 在普通拍允许 ready head，在 squash 拍只允许**严格老于边界**的 ready head。
- **RAT 重放窗口出口**（`rv32_rat` 的唯一窗口数据来源）：generate 块按 `head_q` 起 `DEPTH` 个槽预展平 `replay_tag_o / replay_arch_rd_o / replay_new_phy_o[16]`——把"沿 ROB 年龄走窗口"从 RAT 内侧移到了 ROB 侧的静态并行读，RAT 只保留 tag 游标匹配。
- `always_ff`：6 个 complete 端口都先校验 `valid_q[slot] && tag_q[slot] == complete_tag`，squash 拍还要求结果严格老于边界；flush 将 tail 设为 `flush_tag+1`、清年轻项，并把同拍 older commit 合并进 head/count 更新；非 flush 拍再处理普通 commit/alloc。
- **无快照字段**；`sq_index_q` 存 store 的 SQ 槽号供 LSU 提交。

**差异**

| # | 差异 | REF | RTL |
| --- | --- | --- | --- |
| 1 | **满/空表示** | 指针比较 `head==next`（无 valid 数组、无计数器） | `count_q` 计数器 + `valid_q` 位图 |
| 2 | **squash 恢复机制** | ROB 条目携带 `lqTailSnapshot/sqTailSnapshot`（发射时 include-self），squash 由 **LQ/SQ 读快照回卷自己的 tail** | **无快照**；由 **LSU 按 `flush_tag` 年龄比较清年轻条目**，tail 由 valid 位图自然推进 |
| 3 | commit 与 squash 同拍 | `willCommitNow` 独立于 squash，边界严格更老的 head 可提交 | **已对齐**：squash 拍只允许严格更老的 ready head 提交 |
| 4 | complete 端口的 tag 认证 | `matchesEffectiveTag` 逐端口校验（防陈旧 tag 写活新槽） | **已对齐**：valid + 完整 `{epoch,slot}` tag + squash 年龄认证 |
| 5 | 就绪来源 | BRU 头 + SQ 扫描窗口(8) + 4 CDB → 收敛到单写口 | 6 个 complete 端口（CDB×4 + BRU 条件分支 + store complete）直接写 |
| 6 | 异常/trap | 无异常通路 | `exception_q` + `commit_exception_o` + `trap_o` + `complete*_exception_i` |
| 7 | store 提交 | SQ→ROB 位图（`sqValid/sqReadyToCommit/sqCommitted/sqRobTag`）+ ROB 扫描 | `sq_index_q` 供 LSU 按槽提交；ROB 只提供 `rob_commit_store/rob_commit_sq_index` |
| 8 | 对外查询 | 暴露 `entry.*[16]` 全量字段（消费者自扫） | 5 个专用 lookup 组合端口；1 个取控制元数据、4 个认证结果 tag |
| 9 | 年龄比较实现 | `{epoch,slot}` 拆解（`ROB.cpp:6-11`） | `rob_is_younger()` 包函数，**用 CLA 加法树做无借位比较**（`rv32_pkg.sv:108-145`）——语义同"模 32 距离 < 16"，但用结构化的位并行实现替代了"拆位比较" |
| 10 | HALT 记录 | `robHaltCommitted/robHaltRd`（供 `run()` 输出 x10） | `halted_q`（core 内）+ `commit_arch_rd_o/commit_rd_value_o` 提交跟踪端口 |

> **§3.2 差异 3 的连带影响**：REF 的"尾快照"机制让 LQ/SQ 的 squash 恢复**与发射顺序强耦合**（`lqTailSnapshot` 是 include-self 边界，历史上踩过 off-by-one 死循环）；RTL 换成"按年龄清项"后，squash 语义与发射顺序解耦，但也失去了"精确恢复到发射点"的能力——它靠"清掉所有比边界年轻的项"达到等价效果。

### 3.11 保留站：`RSUnit` ↔ `rv32_rs`

**REF**（`RS.hpp` + `RS.cpp`）

- **7 个独立池**：`integerRS[4]`、`loadRS[4]`、`storeAddressRS[4]`、`storeValueRS[4]`、`branchRS[4]`、`multiplyRS[2]`、`divideRS[1]`。
- **去值化**：每槽只存 `Operand{tag, imm}`（+ op/robTag/memIndex），**不存值、不存 ready 位**。就绪性完全由 `DispatchArbiter` 读 `PRF.isReady(bitmap)` 组合判定。
- `work()`：逐池逐槽三路单写口 —— `pushHit`（`hasX && slot==i`）/ `relHit`（dispatch 授权）/ `flushHit`（`needSquash && busyOld && ROB::isOlder(sqTag, tagOld)`）。`storeValueRS` 的释放是 `busyOld && prf.svReady[i]`（**无 tag 守卫**，所以 release 与 flush 收敛到同一个 else-if）。

**RTL**（`rv32_rs.sv`）：**一个参数化模块，5 个实例**

| 实例 | DEPTH | AUX_W | 服务对象 |
| --- | --- | --- | --- |
| `u_int_rs` | 4 | 1 | ALU（aux = is_jump） |
| `u_mul_rs` | 2 | 1 | MUL |
| `u_div_rs` | 1 | 1 | DIV |
| `u_branch_rs` | 4 | 3 | BRU（aux = {0, is_return, is_call}） |
| `u_mem_rs` | 4 | 4 | LOAD **和** STORE（aux = {is_store, index[2:0]}） |

- **数据捕获式**：每槽存 `op/rob_tag/dest_phy/src1_ready+src1_tag+src1_value/src2_*/imm/pc/predicted_pc/use_imm/aux`。
- 分配：`alloc_ready_o` = first-fit 找周期初 `!busy_q`；与 REF 一样，不把本拍 issue 的槽提前视为空闲。分配时用 `alloc_src1_ready_resolved` —— **组合 snoop 4 条写回总线**补值（同拍可见）。
- 唤醒：`always_ff` 里对每个非就绪源 snoop `wb0..wb3`，写 `ready/value`（**下一拍可见**）。
- 选择：`always_comb` 扫描 `busy && src1_ready && src2_ready`，用本地函数 `rs_is_older` 挑最老 → `issue_valid_o = issue_found && !flush_i`；同时驱动 12 个 issue 输出端口。
- squash：`flush_i && busy_q && rob_is_younger(rob_tag, flush_tag)` → 清 busy（**写回唤醒仍照常执行**——README 记录此处曾是死锁 bug）。

**差异**

| # | 差异 | REF | RTL |
| --- | --- | --- | --- |
| 1 | **数据与就绪位** | 完全不存（"去值化"），就绪性由 PRF 位图判定 | **存值 + 存 ready 位 + snoop 4 条写回总线**（经典数据捕获式） |
| 2 | **最老就绪选择** | 在独立的 `DispatchArbiter` 里做（读 RS 槽 tag + PRF 位图） | 在 **RS 自己** 里做（`rs_is_older`） |
| 3 | 池的划分 | 7 池：int4 + load4 + sa4 + **sv4** + br4 + mul2 + div1 = **23 槽** | 5 池：int4 + **mem4（load/store 共用）** + br4 + mul2 + div1 = **15 槽** |
| 4 | store 数据源 | 专门的 `storeValueRS[4]` | 合并进 `u_mem_rs` 的 src2 + `rv32_lsu` 的 `sq_data_ready_q/sq_data_q` |
| 5 | 写回端口 | RS 无写回端口（不存值） | 每池 4 个 `wb*` 端口（值 + phy 广播） |
| 6 | 同拍复用 | 发射器选周期初已空闲槽 | **已对齐**：满池时不复用本拍 issue 槽 |
| 7 | 分配时的新鲜度 | 读 PRF `_M_old`（本拍写回不可见） | `alloc_*_resolved` 组合 snoop（**本拍写回可见**） |
| 8 | squash 语义 | `ROB::isOlder(squashTag, tagOld)`（squash 点比该项更老 → 清） | `rob_is_younger(tag, flush_tag)`（等价） |
| 9 | 释放（release）触发 | `DispatchArbiter` 的 grant（4+1 路） | 同（`dispatch.*Valid/Idx`） |
| 10 | `storeValue` 释放 | `busyOld && prf.svReady[i]`（PRF 就绪，无 tag 守卫） | 无独立池；等价语义落在 `rv32_lsu` 分配时的 `store_alloc_data_ready_resolved` |

> §3.11 差异 1 是两侧**最本质的微架构分歧**：REF 选择"用 PRF 位图换掉 RS 的值存储"（省面积、加大组合路径），RTL 选择"取值化"（面积大、时序好）。这也直接决定了差异 2（选择逻辑归属）：取值化后只有 RS 自己知道"我这条能不能发"。

### 3.12 派发：`DispatchArbiter` ↔ RS 内部选择 + 握手

**REF**（`StaticArbiter.hpp:91-168`，`StaticArbiter.cpp:83-…`）

- 4 个独立 grant（`alu/bru/mul/div`，各 `DispArbOutInfo{valid,rsIndex,robTag}`）+ 1 个 `agu`（多带 `rsType`）。
- 选择：`selectOldest(busy, src1Tag, src2Tag, tags)` —— `req = busy[i] && readyOf(src1Tag[i]) && readyOf(src2Tag[i])`（`readyOf(tag) = (tag==InvalidPhy) || prdReady[tag]`），折返优先级链，**严格更老替换**。门：`!destFull`；squash 只压 `valid`，`idx/tag` 仍驱动（消费者 gate on valid）。
- `aguSelect()`：`load[0..3] ++ sa[0..7]` **拼接成单次 12 槽扫描**（保留软件双循环的迭代顺序）。
- 消费者：`RS.dispatch.*`（释放槽）、`ALU/MUL/DIV/BRU/AGU.dispatchValid + 操作数取用`。

**RTL**：**没有 DispatchArbiter**。派发 = `rv32_rs.issue_valid_o`（最老就绪）与 FU `in_ready_o` 的握手；`rv32_core` 只做连线（如 `.in_ready_o(int_issue_ready)`、`.in_valid_i(int_issue_valid)`）。

**差异**

1. REF 是"**中心化挑槽 + 把该槽的操作数取出来发给 FU**"（FU 通过 `DispatchArbiterModule.alu.rsIndex` 反向索引 RS 槽，见 `CPU.cpp:476-498`）；RTL 是"**RS 自己报 valid + 数据**，FU 回 ready"（RS 直接把 `issue_*_value_o` 交给 FU）。前者是 N:1 集中仲裁，后者是 1:1 本地握手。
2. REF 的 agu 池是 `load ++ sa` 的 12 槽集中扫描；RTL 的 mem RS 是**单一 4 槽池**，且 load/store 共用（aux 区分），地址送出后由 LSU 按 `address_is_store_i/address_index_i` 分流。
3. **每 FU 每拍发射能力**：REF 每通道 1 条（4 通道 = ALU/MUL/DIV/BRU）+ AGU 1 条；RTL 同（5 个 RS 各 1 条，`in_ready` 门控）。这一项一致。
4. REF 的 `dest_isFull` 门（`aluFull/aguFull/bruFull/mulFull/divAccept`）对应 RTL 的 `*_alloc_ready_o`（RS 空槽）——**语义移位**：REF 门的是"执行单元结果队列是否满"，RTL 门的是"RS 是否有空槽"。

### 3.13 结果总线：`AluCDB`/`LqCDB`/`MulCDB`/`DivCDB` ↔ 直连写回

**REF**（`CDB.hpp` + `CDB.cpp`）

- 4 个无状态模块，各承载**唯一候选**（对应单元的最老结果）：`aluEmpty/aluValue/aluRobTag/aluIsControl` → `valid/value/robTag/isControl`；`LqCDB` 多带 `memIndex`；`DivCDB` 是 DIV 的 `isReady/getValue/getResultRobtag` 直连（**无输出缓冲**）。
- 生效门 `*Live() = !empty && (!squashNeed || ROB::isOlder(tag, squashTag))` —— **squash 门在 CDB 里**，输出 `valid/value/robTag` 全被 `*Live()` 门控。
- 消费者：`PRF.cdbOfALU/LQ/MUL/DIV`（写回 + `cdbNewPhy` 从 ROB 查）、`ROB.cdbOfALU/LQ/MUL/DIV`（markReady）、`FlushArbiter.cdb`（JALR 误预测检测）、`BPU.cdb`（commit 训练，只接 ALU 口）。
- 面积优化点（`CPU.cpp:1580-1594, 1658-1672`）：FlushArbiter 与 BPU 只接 ALU 总线（load 不产生 control），省端口。

**RTL**：**无独立 CDB 模块**。4 条写回候选由单元 `out_valid_o` 送到 core：
`alu_unit.out_*` → `wb_alu_*`；`lsu.load_result_*` → `wb_load_*`；`mul.out_*` → `wb_mul_*`；`div.out_*` → `wb_div_*`。
core 先用 ROB lookup 做完整 tag live 认证和 squash 严格年龄门控，再把统一后的 `wb_*_valid` 送给 `rv32_prf`、各 `rv32_rs`、`rv32_rob` 与 `rv32_lsu`。

**差异**

| # | 差异 | REF | RTL |
| --- | --- | --- | --- |
| 1 | 是否有 CDB 层 | 有（4 个模块） | **无**（直连） |
| 2 | squash 门位置 | **在 CDB 的 `*Live()`**（广播前统一门控） | **已等价集中在 core**：ROB live lookup + squash 严格年龄门控，消费者另保留防御性门控 |
| 3 | `cdbNewPhy` 解析 | CDB 输出 `newPhy` 由 **CPU 侧 lambda 从 ROB 查**（`ROBModule.entry.newPhy[robSlot(tag)]`，并要求 `ROBModule.matchesTag(tag)` 才放行，`CPU.cpp:690-762`） | 结果仍携带 `dest_phy_i`，但广播前会反查 ROB 认证完整 tag；无需从 ROB 再取 newPhy |
| 4 | 广播宽度 | `{value, robTag, isControl?, memIndex?}` 打包 + valid | 4 组独立 `valid/phy/value/tag`（无 isControl 线：ALU 用 `alu_cdb_is_control` 单独拉出） |
| 5 | 提交级 ROI | ROB 的 `complete` 端口 = 4 条 CDB | 6 个 complete 端口（CDB×4 + BRU 条件分支 + store complete） |

> 差异 3 值得单独强调：REF 靠 robTag 反查 ROB 同时取得 newPhy 与认证存活；RTL 把 `dest_phy` 随流水传递，只用 ROB lookup 认证 tag 存活。两者都能拦住复用槽上的陈旧结果，但 RTL 不需要从 ROB 读取 newPhy。

### 3.14 整数执行：`ALU` ↔ `rv32_alu_unit`

**REF**（`ALU.cpp`）：`ALU_CAP=4` 结果槽（`value/robTag/isControl`）+ `slotValid[4]`；`work()`：flush → 清年轻有效位；移除 head（被 AluCDB 取走）；填入新结果。`evaluate(op, op1, op2)` 是纯组合（含 `SL/SRL/SRA/SLT/SLTU/XOR/OR/AND/ADD/SUB/AUIPC/LUI` + `JALR` 控制类，`isControl = (op == JALR)`，JALR 结果 `(op1+op2) & 0xFFFFFFFE`）。消费者读 `headValue/headRobTag/headIsControl`。

**RTL**（`rv32_alu_unit.sv` + `rv32_alu.sv`）：`rv32_alu_unit` 有 `in_valid_i/in_ready_o` + 内部寄存器级，输出 `out_valid_o/result_o/rob_tag_o/dest_phy_o/is_control_o/control_misaligned_o`；`rv32_alu` 是纯组合单元，用 **`rv32_add`/`rv32_sub`（手写 CLA）** 实例算 `add/sub/auipc`，其余用运算符；`JALR` 结果 `sum_add & 32'hffff_fffe`。

**差异**

| # | 差异 | REF | RTL |
| --- | --- | --- | --- |
| 1 | 结果缓冲 | **4 槽队列 + head 轮询** | `in_ready/out_valid` 握手（无多槽队列） |
| 2 | 加法器 | 宿主 `+`/`-` | **手写 CLA 系列 `rv32_cla`**（2/4/8/16/32/64 位），按操作数位宽选用 |
| 3 | 输出打包 | `isControl` 搭在 ALU 结果槽里传给 CDB | 独立 `is_control_o` + **`control_misaligned_o`**（RTL 独有，用于 JALR 目标未对齐 trap） |
| 4 | `dest_phy` | 不携带（写回时反查 ROB） | 随结果携带 `dest_phy_o` |
| 5 | flush 语义 | 清"年轻于 squash 点"的槽 | `flush_i + flush_tag_i` 同（清年轻项） |

### 3.15 乘法：`MUL` ↔ `rv32_mul`

**REF**（`MUL.cpp`）：**Booth radix-4 + 3:2 CSA 压缩树**，与宿主 `*` 完全无关。
- 3 级：① Booth：把乘数按 radix-4 展开成 **19 行** `Row64{lo,hi}`（含无符号修正）；② SC：**3:2 压缩**（`for i<19`）；③ MulRes：重新拼接 carry-save 对出最终值。
- 状态：`partialRes{rows[19],op,robTag,valid}`、`scRes{S_lo,S_hi,C_lo,C_hi,op,robTag,valid}` —— 即**两个寄存器级 = 3 拍延迟**。
- 输出：`MulOutput{slots[4], slotValid[4]}`（4 槽结果队列）；专用 `mulCDB`。
- `uint64_t` 局部量只用于 Booth 行生成/压缩/重拼接。

**RTL**（`rv32_mul.sv`）：**真正的 3 级计算流水**，全数据通路不使用 `*`：①按 `MULH/MULHSU/MULHU` 选择符号扩展，radix-4 Booth 生成 17 行部分积和 1 行共享补偿，再经三级 CSA 压到 6 行并寄存；②再经三级 CSA 压到 carry-save 两行并寄存；③用 64 位 `rv32_add` 完成唯一一次进位传播加法，选择低/高 32 位并寄存输出。`valid_q[0..2]` 与逐级 ready 链构成可回压的 elastic pipeline，可维持每拍一条吞吐。

**差异**：算法一致，部分积表示、流水切分和输出缓冲方式不同。

| # | 差异 | REF | RTL |
| --- | --- | --- | --- |
| 1 | 算法 | Booth radix-4 部分积 + CSA 压缩树（**不落地到 `*`**） | Booth radix-4 部分积 + CSA 压缩树（**不落地到 `*`**） |
| 2 | 部分积表示 | 19 行 `Row64` lo/hi 对（含无符号修正） | 17 行原生 64 位部分积 + 1 行共享补偿 |
| 3 | 流水切分 | Booth 行寄存 → CSA 对寄存 → 最终结果 | Booth+CSA 压至 6 行 → CSA 压至 2 行 → 64 位 CLA |
| 4 | 输出缓冲 | 4 槽结果队列 | 无队列（流水级即缓冲） |
| 5 | 回压 | 无（结果槽满时 `isFull` 阻塞发射） | 有 `in_ready_o`（下游 ready 逐级反向传播） |
| 6 | 定宽表示 | 框架单 `Register` ≤32 bit，64 位量拆 lo/hi | 原生 `logic [63:0]` |

> 两侧乘法现在都显式实现 Booth/CSA；除法仍保持 REF SRT radix-4、RTL radix-2 restoring 的算法差异。

### 3.16 除法：`DIV` ↔ `rv32_div`

**REF**（`DIV.cpp`，387 行）：**SRT radix-4**。
- 4 个阶段函数：`receive()`（特例直出：除零、有符号溢出、`|x|<=|d|`；否则算 `clzD/clzX`、`D_dp`、`shiftD`）/ `prepare()`（把 `|x|` 左移到工作域）/ `loop()`（迭代体：9-bit slice 估商 `dSlice`、`dSlice3`、CSA 更新 `regS/regC`（**36 位 P 域拆 lo/hi**，`join36()` 重拼）、**on-the-fly 商转换 `regA`/`regB`**）/ `calculateResult()`（后处理符号）。
- 状态位：`shiftD/fullAdderValid/loopValid/prepareValid/operationType/robTag/remain/quotient/dSlice/dSlice3/regA/regB/regS*Lo/Hi/regC*Lo/Hi/loopTimes/clzD/clzX/isDividendNegative/isResultNegative/unsignedDivisorLo/Hi/unsignedDividend`。
- **无输出缓冲**：`canAccept() = 全部 valid 位为 0`；`isReady() = resultValid`；`getValue()` 对 `operationType` 失配 **throw `std::runtime_error`**（`DIV.hpp:63-93`）。
- 延迟：`3 + ceil(有效位差/2)` 量级（非固定）。

**RTL**（`rv32_div.sv`）：**逐位试减（restoring）除法**。
- **无 FSM 枚举**：只有 `busy_q` + `count_q`（6 bit，`rv32_add` 递增）。`in_valid && in_ready` 当拍接收；`busy_q` 期间每拍做 `{remainder<<1, dividend[31]}` 与 33-bit 试减（`rv32_sub #(33)`），商 `{quotient[30:0], ge}`，`dividend_q` 左移；`count_q == 6'd31` 那拍置 `result_valid_q`。
- 握手：`in_ready_o = !busy_q && (!result_valid_q || out_ready_i)`；`out_valid_o = result_valid_q`。
- **延迟**：一般情形**接收后 32 拍迭代 + 1 拍出结果（约 33 拍）**；`divisor == 0`、`(-2^31)/(-1)` 与 `|x|<=|d|` 特例**当拍直出**（`busy_q` 保持 0）。

**差异**：**算法级分歧**。

| # | 差异 | REF | RTL |
| --- | --- | --- | --- |
| 1 | 算法 | SRT radix-4（QDS 估商、CSA、on-the-fly 商转换） | radix-2 restoring（移位 + 试减） |
| 2 | 迭代拍数 | 每拍出 2 位商（`ceil(位差/2)`，约 3..19 拍），随操作数变化 | 一般路径固定 32 拍迭代；除零/溢出/`|x|<=|d|` 特例已对齐为当拍直出 |
| 3 | 面积结构 | `regA/regB` + 36-bit CSA lo/hi 拆分 + 3×dSlice 比较 | 单余数寄存器 + 33-bit 减法 |
| 4 | 输出缓冲 | 无缓冲，`canAccept()` 门控；`getValue()` 会 throw | 无缓冲，`in_ready` 门控 |
| 5 | 延迟可预测性 | 变长（依赖前导零差） | 定长（简化时序收敛） |
| 6 | 代码形态 | 手工 `slice` 估商 + `& 0x1FF` 有符号截断（`DIV.cpp:214-218`） | 标准移位-试减循环 |

### 3.17 分支执行：`BRU` ↔ `rv32_bru_unit` + `rv32_bru`

**REF**（`BRU.cpp`）：`BRU_CAP=4` 结果槽，条目 `{pcFrom, pcResult, robTag}`；`branchTaken(op,op1,op2)` 纯组合判条件；`pcResult` = taken 时 `pcFrom+imm`，否则 `pcFrom+4`。**不做预测对错判定**（无 `predictedPC` 输入、无 mispredict 输出）；判定在 `FlushArbiter` 的 stage 2（比较 `bruHeadPCResult` 与 `ROB.robPredictPC[...]`）。

**RTL**（`rv32_bru_unit.sv` + `rv32_bru.sv`）：`rv32_bru` 是纯组合，输入含 **`predicted_next_pc_i`**，输出 `taken/target/next_pc/link_value/**mispredict**/**target_misaligned**`；`rv32_bru_unit` 是**单级寄存器**（`valid_q` + 全部输出字段寄存），`in_ready_o = !flush_i`。输出给 `rv32_core` 的 `bru_valid/bru_*`。

**差异**

| # | 差异 | REF | RTL |
| --- | --- | --- | --- |
| 1 | **判错归属** | **FlushArbiter**（读 BRU 结果 + ROB 预测值比较） | **BRU 内部**（`rv32_bru` 拿 `predicted_next_pc_i` 直接出 `mispredict`） |
| 2 | 结果缓冲 | 4 槽队列 | 单级寄存器（无队列，`!flush_i` 即 ready） |
| 3 | 输出集合 | `pcFrom/pcResult/robTag`（3 个） | `taken/conditional/mispredict/misaligned/call/return/pc/target/next_pc/return_address`（10 个） |
| 4 | 未对齐检查 | 无 | `target_misaligned`（bit1 检查）→ ROB `complete4_exception` → trap |
| 5 | call/return 标记 | 由 FQ 预译码在 BPU 侧处理 | `is_call_i/is_return_i` 进 RS aux，再由 BRU 输出 `out_call_o/out_return_o` |
| 6 | 统计口径 | BPU 里 `branchTotal/branchCorrect`（含 CDB 的 JAL/JALR） | testbench 对条件分支、JAL、JALR 各解决事件分别计数 |

### 3.18 地址生成：`AGU` ↔ `rv32_agu`

**REF**（`AGU.cpp` + `AGU.hpp`）：`AGU_CAP=4` **结果槽**，`AGUEntry{value, robTag, memIndex}` + `slotValid[4]`；`isEmpty/isFull/headValue/headRobTag/headMemIndex` 是**最老有效项的组合视图**；`work()`：dispatch（`agu.valid`）填入 → 保持 → 被消费者取走（不显式移除，靠 lqCDB/memDispatch 消费语义）。LQ/SQ/MemArbiter/FlushArbiter 全部轮询 AGU 的 head。

**RTL**（`rv32_agu.sv`，**277 字节**）：`assign address_o = base_i + offset_i;` —— **纯组合加法器，零状态**。`rv32_core` 里 `rv32_agu u_agu(.base_i(mem_issue_s1), .offset_i(mem_issue_imm), .address_o(mem_address))`，且 `assign mem_issue_ready = !global_flush;`。

**差异**

| # | 差异 | REF | RTL |
| --- | --- | --- | --- |
| 1 | 状态 | **4 槽结果队列**（地址结果滞留排队，消费者按 head 顺序取） | **零状态组合加法器** |
| 2 | 地址生效时机 | 填入槽后，**下一拍起**被 LQ/SQ/MemArbiter 观察（队列 head） | 发射当拍写入 LSU 的 `lq_address_q/sq_address_q`（`address_valid_i = mem_issue_valid && mem_issue_ready`） |
| 3 | 地址事件的耦合 | AGU head 是**全局串行点**：store 地址与 load 地址共用一个 head，互相阻塞 | 无串行点，每拍最多一条 mem 指令（由 mem RS 单端口决定） |
| 4 | 面积 | 4×(32+tag+memIndex) 寄存器 | ≈0 |

> 这是 REF→RTL **周期差异的主要结构性来源**：REF 的 AGU 队列会给访存加 1..4 拍排队延迟，且 store/load 地址事件共享 head 顺序；RTL 的地址在发射拍就位。这也解释了为什么 RTL 能在访存路径上取得更少的固定开销。

### 3.19 访存子系统：`LQ`+`SQ`+`MemArbiter` ↔ `rv32_lsu`

**REF**

- `LQ`（8 槽，7 可用）：字段 `robTag/n_bytes/isUnsigned/address/isAddressReady/**valueState ∈ {NOTREADY, FETCHING, READY}**/value/isCDBBroadcast`。
  - `LoadDetect()`：最老"地址就绪 + NOTREADY"→ 给 MemArbiter；
  - `CDBDetect()`：最老"地址就绪 + READY + 未广播"→ 给 LqCDB；
  - 转发：`applyStoreForward(notify)`（读 `storeNotifies[4]` 数据事件 + `addrNotify` 地址事件），按 `ROB::isOlder(storeTag, loadTag)` 与 `knownSameAddressOldestTag/unknownOldestTag` 阻塞项判定；
  - 应答接收：仅当周期初已是 `FETCHING` 且 tag/memIndex 匹配、本拍 `stateAfter(idx)` 仍为 FETCHING；
  - squash：`tail <= rob.squashLQTailSnapshot`（**尾快照回卷**）。
- `SQ`（8 槽，7 可用）：`isAddressReady/isValueReady/**isCommitted**`；四个查询：`planDataForward`（StoreValue RS 数据就绪广播）、`planAddressForward`（AGU 地址广播）、`replyToLoadRequest`（地址解析当拍安全转发）、`canDispatchLoad`（阻塞已知同址更老 store）；`isCommitted` 由 ROB `storeWillCommit` 置位；squash 用 `rob.squashSQTailSnapshot` 回卷 tail。
- `MemArbiter`（无状态）：每拍 1 个请求；`storeSelected()`（`sqHeadCommitted || (robStoreWillCommit && sqHeadRobTag == robHeadTag)`）优先；`loadSelected()`（`loadCanDispatch && isOlder(loadRobTag, squashTag)`）；`dmemBusy` 停发；输出 `{op,value,address,isSigned,nEnc,robTag,memIndex}`，`memIndex` 高位 `MEM_STORE_BIT=0x40` 区分 store。

**RTL**（`rv32_lsu.sv`，一个模块装下全部）

- LQ 槽：`valid/tag/dest/size/unsigned/address_ready/address/**sent**/**result_ready**/result` —— **用 `sent`+`result_ready` 两位替代 REF 的三态 `valueState`**。
- SQ 槽：`valid/tag/size/address_ready/address/data_ready/data_tag/data/**reported**`。
- **字节精确转发**（核心差异）：选出最老可发 load（`load_select_found`）后，扫描**所有更老的 SQ**（`rob_is_older(sq_tag, lq_tag)`）：
  - 若更老 store 地址未就绪 → `load_blocked = 1`；
  - 否则对 load 的每个字节（`comb_j < selected_load_bytes`）判断地址重叠，命中则按"**最年轻的覆盖该字节的 store**"（`rob_is_younger`）写入 `forward_byte_valid/tag/data`；
  - 汇总成 `load_forward_mask/load_forward_data`；`load_fully_forwarded = 掩码覆盖全部字节`；`load_needs_memory = !fully_forwarded && !pending_q`。
  - 部分转发时：缺失字节由 `pending_forward_mask_q/pending_forward_data_q` 记忆，响应回来后在 `merged_response` 里**逐字节合并**。
- 单 outstanding：`pending_q`（在途）+ `pending_drop_q`（flush 丢弃）。
- 结果：`result_select_found` = 最老 `lq_result_ready` → `load_result_valid_o/ready` **握手**（REF 是 lqCDB 无条件广播）。
- store 完成：`store_complete_found` = 最老 `address_ready && data_ready && !reported` → `store_complete_valid_o/rob_tag_o` → ROB `complete5`。
- **提交写内存（RTL 独有路径）**：`store_commit_match` 要求 tag/地址/数据匹配；squash 拍仅严格老于边界的 store 可继续提交并生成写请求。`store_commit_ready_o = match && dmem_req_ready`，ROB 收到 ready 才 `commit_fire`。REF 是把 store 交给 DCache（命中当拍改行、缺失进 park）。

**差异（本对比第二重要的结构差异）**

| # | 差异 | REF | RTL |
| --- | --- | --- | --- |
| 1 | 模块划分 | `LQ` + `SQ` + `MemArbiter` + `AGU(队列)` + `DCache` | **单个 `rv32_lsu`（LQ+SQ+转发+端口）+ 组合 AGU** |
| 2 | **转发粒度** | **整字**：`SQ::replyToLoadRequest` 比较起始地址相等，转发**未掩码的整 32 位**，**漏掉部分重叠** | **字节精确**：逐字节地址重叠判定 + 逐字节取最年轻覆盖 store + 掩码并集 |
| 3 | **未知地址 store** | **保守阻塞**：更老 store 地址未知时 load 不准入 | **保守阻塞**：`load_blocked` 阻止 load 越过更老地址未知 store；两侧均无 MDP 恢复 |
| 4 | load 值状态表示 | 三态枚举 `NOTREADY/FETCHING/READY` | `lq_sent_q` + `lq_result_ready_q` 两位 + `pending_q` |
| 5 | 请求准入 | `MemArbiter` 无状态仲裁器模块，`store 优先 + DCache busy 停发 + canDispatchLoad 消歧` | LSU 内 `if (store_commit_match) {...} else if (load_needs_memory) {...}` 二选一，直接生成 `dmem_req` |
| 6 | store 提交路径 | MemArbiter 选中 SQ head → DCache（命中当拍写行 / 缺失 park） | **提交拍直发 DMEM 写请求**（不经 DCache，除非换成 `cpu_cached_top`） |
| 7 | store 提交判定 | `sqHeadCommitted`（ROB 显式置位）+ SQ 扫描窗口（8 项） | ROB 带 `sq_index_q` 精确索引 + `store_commit_match` 的 tag/ready 全匹配 |
| 8 | squash 恢复 | `tail <= squashLQTailSnapshot/squashSQTailSnapshot`（**快照回卷**） | 逐项 `rob_is_younger(tag, flush_tag)` 清 valid；`pending_q` 加 `pending_drop_q` 处理在途应答 |
| 9 | load 完成握手 | lqCDB 广播（不需 ready） | `load_result_valid_o/ready_i` 显式握手 |
| 10 | flush 当拍的响应处理 | 无此问题（DRAM 应答走 CDB 语义） | **必须把响应处理移出 flush 分支**（README 记录：否则 `pending_q` 永置位、永久停摆） |
| 11 | 存储带宽 | 每拍 1 访存请求 | 同（store 提交优先于 load 发请求） |

### 3.20 L1D：`DCache` ↔ `rv32_dcache`

**REF**（`DCache.cpp` + `DCache.hpp`）：64 KB = 1024 组 × 4 路 × 16 B；tree-PLRU（每组 3 bit）。
- **两态 FSM**：`phase ∈ {READY=0, WAIT=1}` + `busy`。
- `READY` 拍组合求值：`probe(addr)` 命中 → load **1 拍自答**（填 `lbValid/lbValue/lbMemIndex/lbRobTag`，下一拍 `loadResp` 组合可见）；store 命中 → **当场写行 + 置脏**（不产生主存流量）；命中/填行都更新 PLRU。缺失 → `park` 整条决策（`parkOp/parkValue/parkAddr/parkIsSigned/parkNBytes/parkRobTag/parkMemIndex/**parkTargetWay**`）+ 脉冲 `rqReadValid`（回填读）与 `rqWriteValid`（**脏 victim 写回**，地址由 **victim 自身 tag 重建**）+ `busy=1, phase=WAIT`。
- `WAIT` 拍：清请求脉冲；`done = dmemReplyReady && !dmemWriteBusy` → 填行（`valid/tag/dirty`、PLRU）→ 服务 park（load 提字节+符号扩展 / store 逐字节落行+置脏）→ `busy=0, phase=READY`。
- 统计：`statHits/statMisses/statWritebacks`。调试断言：请求不得跨行、`decValid` 时 DMEM 双口必须已排空。

**RTL**（`rv32_dcache.sv`）：参数 `SETS`（默认 1024）/`WAYS`（默认 4），16 B 行；每组 `plru_q[2:0]` 使用与 REF 相同的 4-way tree-PLRU，命中与填行都更新访问路径。行内读取按完整 4-bit byte offset 提取，支持不跨 16 B 行的非对齐 word。
- **FSM 八态**（`typedef enum logic [2:0]`，`rv32_dcache.sv:33-43`）：`IDLE` → `TAG_READ`（命中响应 / 缺失转 `REFILL_REQUEST`）→ `WRITEBACK_REQUEST`（脏 victim 写回）→ `REFILL_WAIT` → 回 `IDLE`；另有 HALT 排空三态 **`FLUSH_SCAN` / `FLUSH_READ` / `FLUSH_WRITEBACK`**（主动扫全表写回脏行）。
- CPU 侧握手：`cpu_req_valid/ready`、`cpu_rsp_valid/data`；存储侧 `mem_req_*`（128-bit 行）。
- 脏行写回地址用 victim 自身 tag（agent 复核为 v2 已修）。

**差异**

| # | 差异 | REF | RTL |
| --- | --- | --- | --- |
| 1 | FSM 规模 | **2 态**（READY/WAIT）+ park 决策寄存器 | **8 态**（`IDLE`/`TAG_READ`/`WRITEBACK_REQUEST`/`REFILL_REQUEST`/`REFILL_WAIT` + HALT 排空 3 态） |
| 1b | **替换策略** | **tree-PLRU**：每组 3 bit（root + 两叶），命中/填行更新访问路径 | **已对齐**：每组 `plru_q[2:0]`，victim 选择和访问更新同构 |
| 2 | **命中延迟** | load **1 拍自答**；store 命中**当拍**写行 | 接受请求（`IDLE` 握手）→ `TAG_READ` → 响应；load 命中 **2 拍** |
| 3 | 缺失处理 | park 单条决策 + 双通道脉冲（读+脏写并行） | 多态 FSM 分离 refill / writeback / store-wb 阶段 |
| 4 | **HALT 排空** | **无主动 flush**：`run()` 的 `finish` 只等"DCache 空闲"，脏行只在后续 miss 被替换时写回 | `flush_i = core_halted` 触发 **FLUSH_SCAN 全表扫脏行 → FLUSH_READ/WRITEBACK 逐行写回**，完成后 `flush_done_o` → `halted_o` |
| 5 | 存储接口 | 16×(8-bit) 行（`dmemLineData[16]`，每个 `Wire<8>`） | **128-bit 单数据总线**（`mem_req_wdata[127:0]`/`mem_rsp_data[127:0]`） |
| 6 | 与下一级的耦合 | 与 DMEM 模块直连（DCache 是 DMEM 唯一客户） | 与 `rv32_sram_1rw` 或外部行端口直连 |
| 7 | 命中率统计 | `statHits/statMisses/statWritebacks`（`VERBOSE=dcache`） | 无核内统计 |
| 8 | 跨行保护 | 代码 + `_DEBUG` 断言（**仅调试构建**） | README 明确"数据访问不得跨行"作为接口契约 |
| 9 | 命中自答 vs 握手 | `loadResp` 是组合脉冲（消费者 LQ 直接采） | `cpu_rsp_valid/data` 与 LSU 的 `pending_q` 握手 |

### 3.21 数据主存：`DMEM` ↔ `rv32_sram_1rw` + 核外

**REF**（`DMEM.cpp` + `DMEM.hpp`）：核内双口模块，**只接受 DCache 转发的行级请求**（16 B 读/写）。
- 两个独立执行管线：`readBusy/execReadRemainCycle/execReadAddress` 与 `writeBusy/execWriteRemainCycle/execWriteAddress/execWriteLineData`，各装 `MEM_LATENCY = 20`；完成时读端口 `read_data` 填 `replyLineData[16]`、写端口 `writeLine` 更新阵列；`replyValid` 一格，`readDone` 当拍不 pull（下一拍才可能被取走）。
- 双口**完全独立**：脏写回与回填读可同时在飞（这是"脏 victim miss 与 clean miss 同代价"的前提）。
- `Memory` 基类：128 KiB 字节阵列 + `load_ins()`（Verilog hex 镜像解析，支持 `@addr` 段头）+ `read_data/write_data`（越界静默）。

**RTL**：`rv32_sram_1rw.sv` 是**单读/写端口 SRAM 原语**（1RW）；`cpu_top` 把 DMEM 请求暴露成 32-bit ready/valid 端口；`cpu_cached_top` 暴露 128-bit 行接口。IPC 测试里 IMEM/DMEM 是**两块独立的 256 KiB 字节阵列**，取指端口与数据端口互不争用，行读固定 20 拍返回、行写立即接收。

**差异**

| # | 差异 | REF | RTL |
| --- | --- | --- | --- |
| 1 | 端口数/粒度 | **双口（读+写独立在飞）**，16 B 行 | `rv32_sram_1rw` 是 1RW；缓存顶层把行读/行写拆成独立握手通道 |
| 2 | 延迟归属 | 模块内 `MEM_LATENCY=20` 常量 + 倒计时寄存器 | 核外（tb 提供；IPC 测试强制 20 拍） |
| 3 | 容量 | 128 KiB（`MEM_SIZE = 128<<10`） | 测试 256 KiB × 2 | 
| 4 | 镜像加载 | 核内 `Memory::load_ins()` 从 stdin 解析 Verilog hex | 由 tb 预装载 `$readmemh` |
| 5 | 越界行为 | 静默（读返 0、写忽略） | README 记录"两侧都做地址范围检查"，越界即判失败 |
| 6 | 写回可见性 | `writeLine` 直接写阵列，后续 `read_data` 看到新值 | 同（SRAM 写即生效） |

### 3.22 冲刷仲裁：`FlushArbiter` ↔ `rv32_flush_arbiter`

**REF**（`DynamicArbiter.hpp` + 对应 `.cpp`）与 **RTL**（`rv32_flush_arbiter.sv`）都维护 4 项 oldest-first 队列，只接收 BRU 条件分支与 ALU CDB JAL/JALR 的恢复请求。两边对已有 squash 都仅允许严格更老的控制事件继续训练或恢复；地址未知的 store 由 load admission 保守处理，不存在 MDP 请求源。

| # | 差异 | REF | RTL |
| --- | --- | --- | --- |
| 1 | 检测逻辑位置 | FlushArbiter 读取 BRU/CDB/ROB 后比较 predicted PC | `rv32_core` 组合生成 branch/jump candidate，仲裁器只收事件 |
| 2 | 误预测判据 | 比较 `pcResult` 与 `ROB.predictedPC` | BRU 直接产生 `bru_mispredict`；JAL/JALR 比较 `wb_alu_value` 与 `jump_rob_predicted_pc` |
| 3 | squash 边界 | 分支/JALR 都取自身 tag | 分支取 `bru_tag`，jump 取 `wb_alu_tag` |
| 4 | 队列实现 | 4 槽 oldest-first | 4 槽 oldest-first，压缩后按年龄插入 |
| 5 | 未对齐异常 | 无 | `bru_misaligned`/`alu_cdb_misaligned` 同时进入 ROB exception → trap |

---

## 4. 差异点分类汇总

### 4.1 模块设计层（模块边界与职责划分）

| # | REF | RTL | 影响 |
| --- | --- | --- | --- |
| D1 | 前端 4 模块（FetchUnit/ICache/FQ/IQ） | 前端 1 模块（`rv32_frontend` 含 FQ+IQ）+ `rv32_decoder` | 模块粒度 |
| D2 | RS 7 池（int/load/sa/sv/br/mul/div = 23 槽） | RS 5 实例（int/mem/br/mul/div = 15 槽），load+store 共用 | 容量与面积 |
| D3 | 发射/派发是 2 个显式无状态仲裁器模块 | 折叠进 `rv32_core` 组合云 + RS 内部选择 + 握手 | 无独立可综合块 |
| D4 | 4 个 CDB 模块（承载 squash 门与打包） | 无（直连写回） | 少一层组合 |
| D5 | AGU 是 4 槽结果队列 | AGU 是组合加法器 | 访存路径延迟 |
| D6 | 访存子系统 4 模块（AGU/LQ/SQ/MemArbiter） | 1 模块（`rv32_lsu`） | 模块粒度 |
| D7 | IMEM/DMEM 是核内模块（含延迟建模） | 移到核外端口 + `rv32_sram_1rw` | 可综合/可换宏 |
| D8 | 主存 20 拍延迟是模块常量 | 延迟由 tb/外部提供 | 测试契约 |
| D9 | 单一顶层 `CPU` | `cpu_top`（无缓存）+ `cpu_cached_top`（I$/D$） | 可配置性 |
| D10 | 无异常通路 | `illegal`/`exception_q`/`trap_o` + 未对齐检查 | ISA 完整性 |

### 4.2 运行逻辑层（同一条流水线，行为不同）

| # | 项 | REF | RTL | 是否影响架构结果 |
| --- | --- | --- | --- | --- |
| L1 | **store→load 转发** | 整字、起始地址相等、**漏部分重叠** | **字节精确 + 掩码并集 + 逐字节取最年轻** | **是**（REF 会产生错误值，见 §6） |
| L2 | **未知地址 store** | load admission 保守阻塞 | `load_blocked` 保守阻塞 | 否（两侧都无 MDP 恢复） |
| L3 | **squash 恢复 LQ/SQ** | ROB 内 `lq/sqTailSnapshot`（include-self）回卷 tail | 逐项 `rob_is_younger(tag,flush_tag)` 清 valid | 否 |
| L4 | **PRF 空闲资源** | 环形 FIFO free-list + head/tail 指针 | 空闲位图 + first-fit 扫描 | 否（编号序列不同） |
| L5 | **PRF squash 恢复** | ROB 窗口重放：`robNewPhy`/`oldPhy` 批量 push 到环尾 | ROB 窗口重放：窗口内 `new_phy` 位集 OR 进位图 | 否（**已对齐**，恢复集合相同） |
| L6 | **ROB 满/空** | 指针比较 | 计数器 + valid 位图 | 否 |
| L7 | **ROB commit 与 squash 同拍** | 严格更老 head 可提交 | **已对齐** | 否 |
| L8 | **ROB complete 的 tag 认证** | `matchesEffectiveTag` 逐端口校验 | **已对齐**：完整 tag + valid + squash 年龄 | 否 |
| L9 | **RS 唤醒时序** | 就绪性 = PRF 位图（组合读 `_M_old`，**同拍写回不可见**） | 本地 ready 位 + snoop 写回（下一拍可见）；**分配路径组合 snoop（同拍可见）** | 可能 1 拍边角 |
| L10 | **执行单元输出** | 4 槽结果队列 + head 轮询 | `in_ready/out_valid` 握手 | 可能 1..4 拍 |
| L11 | **AGU 生效时机** | 入队后下一拍起（队列 head 串行） | 发射当拍 | 可能 1..4 拍 |
| L12 | **I$ 命中延迟** | 0 拍（push 当拍 ready） | 2 拍/条 | **是**（吞吐上限 0.5 IPC） |
| L13 | **I$ 请求缓冲** | 4 项投机队列 | 无队列、单 outstanding | 缺失吞吐 |
| L14 | **D$ 命中延迟** | load 1 拍自答 / store 当拍 | 2 拍（握手 + TAG_READ） | 是 |
| L15 | **HALT 排空** | 只等"队列空 + DMEM/Cache 空闲"，脏行留在缓存 | **主动 FLUSH_SCAN 全表写回**后才 `halted_o` | 是（收尾周期） |
| L16 | **store 提交路径** | 经 DCache（命中当拍改行） | 直发 DMEM 写请求（缓存顶层除外） | 是（周期） |
| L17 | **load 完成握手** | lqCDB 广播 | `valid/ready` 握手 | 否 |
| L18 | **mispredict 判定归属** | FlushArbiter | BRU 单元 | 否 |
| L19 | **flush 当拍的访存响应** | 无此路径 | 必须移出 `else` 分支（曾有死锁 bug） | 否（修复项） |
| L20 | **halt 停取时机** | 闩锁后下一拍 | 响应当拍 | 可能 1 拍 |

### 4.3 实现方式层（同一语义，两种写法）

| # | 项 | REF | RTL |
| --- | --- | --- | --- |
| I1 | 时序状态 | `Register<N>`（old/new 双缓冲，`sync()` 提交） | `always_ff` 寄存器 |
| I2 | 组合连线 | `Wire<N>`（lazy lambda，一次性接线） | `always_comb` / `assign` |
| I3 | 复位 | `bootDone` 复位周期（占 cycle 0） | `rst_ni` 异步复位 |
| I4 | 定宽容器 | `std::array` + 编译期 `static_assert` | 定宽数组 + `localparam` |
| I5 | 位宽 | `Register`/`Wire` 上限 32 bit → 64 位量拆 lo/hi 对（`Row64`、`join36()`） | 原生 `logic [63:0]` / `[65:0]` |
| I6 | 年龄比较 | `{epoch,slot}` 拆位比较（ROB/RAT 域） | `rob_is_younger()` **CLA 位并行**比较 |
| I7 | 乘法 | Booth radix-4 + CSA（禁 `*`） | Booth radix-4 + CSA（禁 `*`） |
| I8 | 除法 | SRT radix-4（禁 `/`） | radix-2 restoring |
| I9 | 加法 | 宿主 `+` | 手写 CLA 系列 `rv32_cla` |
| I10 | 非法/异常 | 无（`RV_INVALID` 类型） | `illegal` 位 + `trap` |
| I11 | 调试 | `VERBOSE=...` 主题 + `debug::print`（stderr）/ `_DEBUG` 断言 | 无核内打印（README 明确"核心 RTL 无延迟、文件 I/O、DPI、force/release 或测试专用逻辑"） |
| I12 | 统计 | `statHits/statMisses/statWritebacks`（DCache/ICache）、`branchTotal/branchCorrect` | 由 tb 统计（IPC 测试输出 `IPC_RESULT`） |
| I13 | 循环纪律 | 定长循环禁 `break/return`（found/blocked 标志），但允许 lambda/异常/虚函数/动态内存 | RTL 语义天然无 `break` |
| I14 | 内存越界 | 静默（读 0 / 写忽略） | 范围检查（越界判失败） |

---

## 5. 参数对照表

| 项 | REF 常量 | RTL 参数 | 值 |
| --- | --- | --- | --- |
| ROB | `ROB_CAP` | `ROB_ENTRIES` / `ROB_TAG_W` | 16 / 5 bit |
| PRF | `PRF_CAP = ROB_CAP + 32` | `PRF_ENTRIES` / `PHY_TAG_W` | 48 / 6 bit |
| 物理 tag 宽 | `PHY_TAG_WIDTH = bit_width(47)` | `PHY_TAG_W` | 6 |
| RAT | `REGISTER_CAP=32`（`specRAT/archRAT`，**无检查点**） | `ARCH_REGS=32`（`map_q/arch_q`，**无检查点**） | 32 |
| 检查点 | `CKPT_CAP=32`（仅 BPU `bpCkpt[]` 消费） | `BPU_CKPT_ENTRIES=32`（**仅预测器**；RAT/PRF 均改用 ROB 窗口重放） | 32 |
| FQ / IQ | `FQ_CAP/IQ_CAP` | `FQ_DEPTH/IQ_DEPTH` | 4 / 4 |
| LQ / SQ | `LQ_CAP/SQ_CAP` | `LQ_ENTRIES/SQ_ENTRIES` | 8 / 8 |
| RS | `INTEGERRS/LD/ST/BR/MUL/DIV` | `rv32_rs` DEPTH | 4/4/4/4/4/2/1 → 4/4/4/2/1 + 合并 mem |
| ALU/MUL/BRU/AGU 结果槽 | `ALU_CAP/MUL_CAP/BRU_CAP/AGU_CAP` | — | 4 / 4 / 4 / 4（RTL 无此结构） |
| flush 队列 | `FLUSHARBITER_CAP` | `DEPTH` | 4 |
| I$ | `CACHE_CAP=512`，16 B 行，+4 项请求 | `SETS=512`，16 B 行 | 8 KiB 直接映射 |
| D$ | `NUM_OF_SETS=1024`/`NUM_OF_WAYS=4`，16 B 行，**tree-PLRU** | `SETS=1024`/`WAYS=4`，16 B 行，**tree-PLRU** | 均 64 KiB 4 路 |
| 主存延迟 | `MEM_LATENCY=20` | tb 提供 | 20 |
| 预测器（方向） | Tournament：localPHT / globalPHT 各 256×2b + selector 256×2b + GHR 8 | 256×2b ×3 + GHR 8 | 对齐 |
| 预测器（目标） | `BTB_CAP=64`、`RAS_CAP=8`、`ALIGNQ_CAP=16`、`CONDSEEN_CAP=512`、`RAS_TIMES_WIDTH=9` | BTB64 / RAS8 / RAS journal16 / condSeen512 | 对齐 |
| HALT 标记 | `0x0ff00513` | `HALT_INSN = 32'h0ff0_0513` | 相同 |

---

## 6. REF 已知缺陷与 RTL 的有意偏离

`docs/reference-analysis.md` 列出 REF 的"未复现缺陷"，下表把它们映射到本文对应小节：

| REF 缺陷 | 本文对应差异 | RTL 的处置 |
| --- | --- | --- |
| JALR 未清除目标地址第 0 位 | §3.14 差异 3 | RTL `rv32_alu` 对 JALR 做 `& 32'hffff_fffe`（与 REF 现行 `evaluate()` 一致），并追加 `target_misaligned` 未对齐检查 |
| 混合宽度 store-to-load 转发实现差异 | §3.19 差异 2 | RTL 使用字节精确转发；active qsort golden 在两侧均为 `x10=0` |
| HALT 与非法指令可发射进入满 ROB | §3.7 差异 6、§3.10 差异 6 | `alloc_ready_i = decoded.halt \|\| decoded.illegal`；非法 → `exception` → `trap` |
| 未知操作码可创建永不完成的 ROB 项 | §3.5 差异 3 | `illegal` 归类（译码阶段） |
| 有符号 C++ 加法/取负可能触发宿主未定义行为 | I5 | RTL 定点位宽运算无 UB |
| 跨行数据访问仅在调试构建中断言 | §3.20 差异 8 | README 把"数据访问不得跨行"定为**接口契约**（`cpu_cached_top` 行对齐） |
| LQ/SQ 恢复载体不同 | §3.10 差异 2、§3.22 | REF 使用尾快照；RTL 按年龄清年轻项，两边对未知 store 都保守阻塞 |

---

## 7. 验证口径对照（为什么两侧数字不能直接比）

| 项 | REF | RTL |
| --- | --- | --- |
| 判停/计时间隔 | `run()` 的 `finish`（halt 提交 ∧ 全队列空 ∧ 主存空闲） | IPC：复位释放 → **架构 HALT 提交当拍（含）**；HALT 后的 D$ 排空不计入 |
| 指标 | 完整 x10（`RESULT_FULL=1`）+ `clock` + `retired/ipc-cycles` + 可选 `VERBOSE=cftrace,profile` | 完整 x10 + `retired/cycles` + 逐控制事件 `branches/mispredicts` + `+CF_TRACE=1` |
| 退出条件 | 顶层无最大周期限制（缺 HALT 不自动结束） | trap / 超时 / 地址范围 / x10 / 排空**五道检查全过**才输出 `IPC_RESULT` |
| 基准差异 | 18 个 RV32IM 用例（`data/testcases/`） | 6 个 IPC 基准（median/multiply/qsort/rsort/towers/vvadd） |
| 已知偏离 | — | 无 active qsort 偏离；历史 `243` 不再用于回归 |
| 当前性能 | 几何平均 IPC **0.395250**（模板树，按 `benchmarks.md` 现行 18 用例表逐例 `retired / ipc-cycles` 几何平均；分支正确率 93.8356%，见 2026-09-21 保守 load 一行） | 几何平均 IPC **0.399396**（README 当日实测 6 例几何平均；合计 retired=364790、cycles=829570 仅作参考总量） |

> 结论：**两侧的 cycle 数字不具备直接可比性**（不同的判停边界、不同的缓存/主存建模、不同的 DRAM 延迟来源）。可比的是**同一侧内部的 A/B**，以及"RTL 是否复现 REF 的架构结果（x10）"。

---

## 8. 一页速览：最重要的 10 条不一致

1. **保留站范式相反**：REF 去值化（只存 `Operand{tag,imm}`，就绪性由 PRF 位图判定）；RTL 取值化（存值 + ready 位 + snoop 4 条写回）。
2. **执行单元形态相反**：REF 是"4 槽结果队列 + head 轮询"；RTL 是"流水/单级寄存器 + in_ready/out_valid 握手"。
3. **AGU**：REF 4 槽队列（地址事件串行）；RTL 组合加法器（发射当拍生效）。
4. **CDB 层**：REF 有 4 个 CDB 模块（squash 门 + `cdbNewPhy` 反查 ROB）；RTL 无 CDB（`dest_phy` 随指令流水携带）。
5. **发射/派发**：REF 两个显式仲裁器；RTL 折叠进 core 组合云 + RS 内部最老选择。
6. **转发与 load admission**：REF 与 RTL 都不让 load 越过地址未知的更老 store；RTL 的逐字节转发粒度更细。
7. **squash 恢复**：REF 用 ROB 内 LQ/SQ 尾快照回卷；RTL 用 `flush_tag` 年龄比较清年轻项。
8. **PRF 空闲资源**：REF 环形 free-list；RTL 空闲位图 + first-fit（分配出的 phy 编号序列不同）；**squash 恢复两侧均为 ROB 窗口重放**，只是载荷形式不同（批量 push vs 位集 OR）。
9. **乘除法算法**：乘法均为 Booth radix-4 + CSA（禁 `*`）；除法为 REF SRT radix-4、RTL radix-2 restoring。
10. **缓存与主存**：REF I$ 带 4 项请求队列、命中 0 拍，D$ 两态 park + tree-PLRU、无 HALT 主动排空，主存是核内模块；RTL I$ 无队列、命中 2 拍，D$ 8 态 FSM + 已对齐的 tree-PLRU + HALT 主动 FLUSH_SCAN，主存移到核外。
