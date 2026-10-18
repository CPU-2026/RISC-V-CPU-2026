# RTL 前端与预测

源码：[`frontend/`](../verilog/rtl/frontend/)、[`predictor/`](../verilog/rtl/predictor/)。容量与公共约定见 [package.md](package.md)，取指存储接口见 [cache.md](cache.md)。

```text
PC ─┬─► I$ ───────────► FQ → IQ → 组合译码 → 后端
    └─► 寄存器 BTB / 方向表 / RAS
实际取指握手：保存预测上下文，推进 PC、GHR、checkpoint
redirect：清逻辑请求与队列，恢复预测状态
```

## 取指与译码

[`rv32_frontend`](../verilog/rtl/frontend/rv32_frontend.sv) 每拍最多接受一条取指，FQ/IQ 空队列不直通。

| 接口 | 合同 |
|---|---|
| `predictorQueryOutput` / `fetchProgramCounterOutput` | 当前查询 PC；独立 PC 连线不依赖 accepted 总线。 |
| `predictionInput` | 组合预测，实际请求接受沿保存 nextPC/checkpoint 并推进 PC。 |
| `imemRequestOutput` / `imemReqReadyInput` | 字节 PC 与预测上下文；ready 握手接受。 |
| `imemResponseInput` / `imemRspReadyOutput` | 顺序返回；FQ 实际接收才释放请求身份，满请求槽可同拍替换。 |
| `instructionOutput` / `iqReadyInput` | IQ 队首上下文；ready 接后端本拍发射成功。 |
| `fetchInfoOutput` | 上一拍进入 FQ 的跳转预译码，直接训练 BTB/RAS。 |
| `redirectInput` / `imemFlushOutput` | 清 FQ/IQ、停取状态与请求身份，设置新 PC；同拍旧响应不入 FQ。物理旧事务由适配器排空。 |
| `freezeInput` | 冻结前端状态；课程退出控制见 [course.md](course.md)。 |
| `fqCountOutput` / `iqCountOutput` | 实际占用数，范围 `0..DEPTH`。 |

[`rv32_decoder`](../verilog/rtl/frontend/rv32_decoder.sv) 无时钟、无 ready、无新增流水级：`decodeContextInput` 组合生成 `uopOutput`，实际发射仍需 IQ 握手。未知编码译为 `UOP_ILLEGAL`；JAL/JALR 走 ALU，条件分支走 BRU。

`RESET_PC=0`、`LEGACY_HALT=0`。仅显式开启旧 HALT 时，停机字进入 FQ 才锁存 `stopFetch`，译码为 `UOP_HALT`。

## 预测顶层

[`rv32_predictor`](../verilog/rtl/predictor/rv32_predictor.sv) 组合查询旧表，无查询等待级、训练 FIFO 或训练信用背压。

| 接口 | 合同 |
|---|---|
| `queryPcInput` / `predictionOutput` | 输出预测 nextPC 和旧 checkpoint ID；未命中预测 PC+4。 |
| `fetchAcceptInput` | 实际取指握手；同沿保存旧 GHR/checkpoint，按预测移位 GHR。 |
| `fetchInfoInput` / `branchInput` / `jumpInput` | 预译码、BRU、ALU 三源训练；分支/跳转须 `valid && robEntryLive`，冲刷拍须严格更老。 |
| `squashInput` / `robInput` | 恢复 GHR、RAS、checkpoint 序号；ROB 提供提交信息与存活窗口。 |
| `freezeInput` | 冻结表、历史、RAS 和 checkpoint。 |

### 方向表与 BTB

- [`rv32_bpu_direction`](../verilog/rtl/predictor/rv32_bpu_direction.sv)：localPHT、globalPHT、selector 各 256×2 bit；全局/选择表用 `PC xor GHR` 索引，另有 condSeen 位图。
- BRU 按检查点 GHR 和真实 `taken` 更新饱和计数器，两路预测不同时更新 chooser。不能以 `nextPC != PC+4` 反推方向；目标恰为 PC+4 时也可 taken=1。
- [`rv32_bpu_btb`](../verilog/rtl/predictor/rv32_bpu_btb.sv)：64 项，默认索引 `PC[7:2]`，保存上位 PC tag、`target[31:2]` 及 invalid/conditional/unconditional/return 类型。目标低两位补零。
- tag/类型与 target 分别按槽仲裁：fetch > jump > taken branch；无写者保持旧值，无静态目标的 JALR/RET 可采用同拍解析目标。拍末训练，下拍查询可见。
- 条件 taken 还须 BTB 命中，无条件项强制 taken；空 RAS 不采纳 return。

两种 SRAM BTB 不接活动 core、不进课程 filelist；接口和测量见 [实验记录](experiments.md#3-两种-sram-btb)。

### RAS 与 checkpoint

[`rv32_bpu_ras`](../verilog/rtl/predictor/rv32_bpu_ras.sv) 为非环形有界栈：空 pop、满 push 保持。JALR 的 push=`rd∈{x1,x5}`、pop=`rs1∈{x1,x5}`，双 link 含同寄存器均先 pop 后 push；JAL 仅按 rd 判断 push。容量检查使用 pop 后深度，查询读取旧栈顶，空栈目标为 0。

内部深度为 `$clog2(RAS_ENTRIES+1)` 位，公开 16 位深度输出补零。已提交栈为同步 SRAM、深度为寄存器；恢复从已提交完整内容重放存活 ROB，不只恢复栈指针。布局、四拍重放及暂停范围统一见 [backend.md](backend.md#已提交-sram-与四拍重放)。

[`rv32_bpu_checkpoint`](../verilog/rtl/predictor/rv32_bpu_checkpoint.sv) 只保存 **8 位 GHR**，不保存 RAS。`checkpointInput` 负责取指写入、分支历史查询与恢复；`checkpointOutput` 返回历史和下一个 ID。独立 `nextCheckpointIdOutput` 避免 ID 依赖 fetchAccepted 总线。恢复仲裁时序见 [backend.md](backend.md)。
