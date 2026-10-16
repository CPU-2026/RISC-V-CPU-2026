# RTL 公共类型：`rv32_pkg`

源码：[`rv32_pkg.sv`](../verilog/rtl/common/rv32_pkg.sv)。本文集中记录当前容量和跨模块载荷；端口行为见 [前端](frontend.md)、[后端](backend.md)、[访存](memory.md)、[缓存](cache.md)。

## 1. 常量、宽度和身份

checkpoint容量须与包定义及ID宽度一致，当前预算ROB16+I$8+FQ2+IQ2=28≤32。AXIFetch只持行地址/数据，不额外持checkpoint。RAS深度允许1..255；BTB项数须为不小于2的二次幂，并保留PC tag。

| 定义 | 当前值 | 硬件含义 |
|---|---:|---|
| `XLEN` / `ARCH_REGS` | 32 / 32 | 数据位宽 / 架构寄存器数，`x0` 恒为零。 |
| `ROB_ENTRIES` / `ROB_TAG_W` | 16 / 5 | ROB 槽数 / 完整循环标签宽度。 |
| `PRF_ENTRIES` / `PHY_TAG_W` | 48 / 6 | PRF 条目数 / 物理标签宽度；P0 对应 `x0`，不分配。 |
| `FQ_ENTRIES` / `IQ_ENTRIES` | 2 / 2 | 当前取指和译码队列深度。 |
| `LQ_ENTRIES` / `SQ_ENTRIES` | 8 / 8 | load/store 队列默认槽数。 |
| `BPU_CKPT_ENTRIES` / `BPU_CKPT_ID_W` | 32 / 5 | 预测历史检查点数 / `bpu_ckpt_id_t` 宽度。 |
| `FETCH_REQUEST_ENTRIES` / `RAS_ENTRIES` | 8 / 16 | 取指请求容量 / 返回栈深度。 |
| `AXI_FETCH_LINE_ENTRIES` | 16 | 独立AXIFetch行运输队列，不是I$请求槽数。 |
| `DATA_REQUEST_ENTRIES` / `DATA_TRANSACTION_W` | 8 / 3 | D$请求/LSU运输owner容量与CPU运输ID宽度。 |
| `CACHE_LINE_BYTES` / `CACHE_LINE_BITS` | 64 / 512 | I$行字节数 / 数据位宽。 |
| `DCACHE_LINE_BYTES` / `DCACHE_LINE_BITS` | 32 / 256 | D$行宽，独立于I$。 |
| `ICACHE_SETS` / `DCACHE_SETS` / `DCACHE_WAYS` | 16 / 64 / 2 | I$ 1 KiB直接映射；D$ 4 KiB、32 B行、两路组相联。 |
| RS 容量 | 2/1/1/2/2/2/2 | Integer/Multiply/Divide/Branch/Load/StoreAddr/StoreValue，共 12 槽。 |
| `HALT_INSN` / `AXI_EXIT_ADDR` | `32'h0ff0_0513` / `32'h8000_0000` | 旧标记仅LEGACY_HALT开启；课程退出为完整32bit MMIO Store。 |

`OPCODE_*` 定义 RV32I 主 opcode；`uop_class_e` 定义指令类别，`operation_e` 定义具体运算。`mem_size_e` 与请求 `size` 统一为 `MEM_BYTE/HALF/WORD=0/1/2`，对应 1/2/4 B。

通用约定：

- 上升沿更新，`rstNInput` 为低有效异步复位。
- `valid=0` 无有效事务；有 ready 的接口以 `valid && ready` 握手，无 ready 的载荷按模块时序消费。
- 用完整 ROB tag 认证身份。ROB/队列恢复保留边界及更老项，取消严格年轻项；执行结果的年龄门控见 [backend.md](backend.md)。

## 2. 类型索引

字段定义以源码为准，下面按职责定位，避免重复抄录各模块接口。

| 类型族 | 用途 / 行为说明 |
|---|---|
| `decode_context_t`、`decoded_uop_t`、`fetch_queue_output_t` | 指令、PC、预测 PC、checkpoint 及译码结果；见 [frontend.md](frontend.md)。 |
| `fetch_query_output_t`、`prediction_output_t`、`instruction_memory_*`、`redirect_input_t` | 取指查询/响应及重定向。 |
| `predictor_fetch_info_t`、`branch_result_input_t`、`jump_result_input_t` | 三源训练；分支载荷含真实 taken 与 checkpoint。 |
| `direction_*`、`branch_training_input_t`、`btb_*`、`checkpoint_*`、`rob_predictor_input_t` | 方向历史、目标、快照及 RAS 重放。 |
| `rat_*`、`prf_*`、`rs_*` | 改名、物理寄存器及保留站；见 [backend.md](backend.md)。 |
| `cdb_result_t` | `{valid,phyTag,value}`，执行结果广播。 |
| `rob_*`、`flush_candidate_input_t`、`squash_input_t` | 分配、完成、提交、存活查询与恢复；replay 携带 `robTag/PC/instruction/archRd/newPhy`。 |
| `alu_operation_*`、`branch_operation_*`、`execute_*`、`alu_execute_output_t`、`bru_execute_output_t` | 组合运算与带身份执行结果。 |
| `load_allocation_input_t`、`store_allocation_input_t`、`store_data_input_t`、`lsu_address_input_t` | LSQ 分配、数据及带完整 tag 的地址交付；见 [memory.md](memory.md)。 |
| `store_commit_input_t`、`store_completion_output_t`、`load_result_output_t` | Store 退休提议、ready/epoch 位图及 Load 写回。 |
| `address_generation_*`、`data_memory_*` | 字节地址运算、32 bit 处理器访存。 |
| `icache_cpu_*`、`icache_line_response_input_t`、`cache_line_*` | I$ 请求上下文与 512 bit 行；见 [cache.md](cache.md)。 |
| `dcache_cpu_*` | 32 bit CPU 访问/Load 应答，均带 3 bit `transaction`。 |
| `dcache_line_request_output_t` | 读/写各自的 valid、地址、2 bit MSHR ID；写载荷为 256 bit。 |
| `dcache_line_response_input_t`、`dcache_write_response_input_t` | 读回复与独立写完成，均含原地址/ID；回复保持至消费。 |
| `axi_master_t`、`axi_slave_t` | 五通道聚合；外部协议见 [axi4-lite.md](axi4-lite.md)。 |

包内函数 `rob_is_younger/rob_is_older` 比较循环 ROB tag 的相对年龄，仅用于有效在飞窗口；`mem_bytes(size)` 返回 1/2/4 字节。
