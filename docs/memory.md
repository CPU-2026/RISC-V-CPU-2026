# RTL 访存

源码：[`rv32_agu.sv`](../verilog/rtl/execute/rv32_agu.sv)、[`rv32_agu_unit.sv`](../verilog/rtl/execute/rv32_agu_unit.sv)、[`rv32_lsu.sv`](../verilog/rtl/memory/rv32_lsu.sv)。公共类型见 [package.md](package.md)，分配与提交见 [backend.md](backend.md)，行接口见 [cache.md](cache.md)。

```
单发射 ─► LQ/SQ 空槽分配 ─► 访存 RS(base,offset,槽号)
                                  │ 地址就绪
                        rv32_agu_unit 单槽 ─► LQ/SQ 地址
                                   SQ 数据 ◄── StoreValue RS（CDB寄存唤醒）
                             │                  │
        SQ 单源完整转发 ──────┤                  └── store ready → ROB
                             ▼
       最老可发 load / SQ 头 posted store ─► 32 位 dmem 请求 ─► DCache/核外内存
                    load 结果 ─► PRF/ROB           （核外行接口由 cache 负责）
```

LQ/SQ 各 8 槽，地址与数据独立就绪。LQ 用有效位找首个空槽，结果广播后保留到 ROB 提交。SQ 用 epoch 指针维护 FIFO，提交只置 committed，请求接受后才释放；已提交项跨 ROB 回绕和恢复保留。

## 1. `rv32_agu`：地址生成

| 方向 | 端口 | 含义 |
|---|---|---|
| 输入 | `addressInput: address_generation_input_t` | `baseAddress`（就绪源寄存器的 32 位值）和符号扩展 `offset`。 |
| 输出 | `addressOutput: address_generation_output_t` | `address = baseAddress + offset` 的 32 位**字节地址**。 |

AGU 无状态、无握手，计算 32 位模加法。core 通过结果级保存地址与身份，下拍交付 LSU。

### 1.1 `rv32_agu_unit`：单槽结果级

| 方向 | 端口 | 含义 |
|---|---|---|
| 输入 | `clkInput/rstNInput`, `flushInfoInput` | 时钟、复位、完整 ROB 恢复边界。 |
| 输入 | `executeInput: rs_issue_output_t`, `auxiliaryInput[3:0]` | 基址、偏移、ROB tag 与 `{isStore, LSQ_slot[2:0]}`。 |
| 输出 | `inReadyOutput` | 恒 1，发射时已预留 LSQ 槽。 |
| 输出 | `addressOutput: lsu_address_input_t`, `auxiliaryOutput[3:0]` | 寄存地址、类型、索引；valid 受恢复年龄门控。 |
| 输出 | `robTagOutput` | 寄存 ROB tag；有效交付通过 `addressOutput.valid` 表示。 |

n 拍计算并保存，n+1 拍交付、拍末置 LSU 地址 ready，n+2 拍可见。支持同拍交付和重填。LSU 索引必须接寄存 aux；地址载荷的完整 ROB tag 须匹配旧活动槽或同拍实际分配项。

## 2. `rv32_lsu`：队列及对外接口

参数：`LQ_DEPTH=8`、`SQ_DEPTH=8`、`STORE_DATA_LANES=1`；当前 core 将数据交付路数配置为 2。

| 方向 | 端口 | 含义与有效条件 |
|---|---|---|
| 输入 | `clkInput`, `rstNInput`, `flushInfoInput: rob_flush_input_t` | 时钟/复位；`valid/robTag` 使年轻 LQ/SQ 项无效，并将已发出的错路 load 响应标记为待丢弃。 |
| 输入 / 输出 | `loadAllocationInput: load_allocation_input_t`, `loadAllocReadyOutput`, `loadAllocIndexOutput[$clog2(LQ_DEPTH)-1:0]` | `valid && ready` 分配 LQ 槽；载荷为 `robTag/destinationPhy/size/isUnsigned`。索引交访存 RS，用于之后写地址。 |
| 输入 / 输出 | `storeAllocationInput: store_allocation_input_t`, `storeAllocReadyOutput`, `storeAllocIndexOutput[$clog2(SQ_DEPTH)-1:0]` | `valid && ready` 分配 SQ 槽；携带 store 大小以及 `dataReady/dataTag/dataValue`。 |
| 输入 | `storeDataInput[STORE_DATA_LANES]: store_data_input_t`, `storeDataIndexInput[STORE_DATA_LANES]` | StoreValue RS 最多两路并行交付数据与 SQ 索引，完整 tag 匹配后拍末置数据就绪。 |
| 输入 | `addressInput: lsu_address_input_t`, `addressIndexInput[max($clog2(LQ_DEPTH),$clog2(SQ_DEPTH))-1:0]` | 地址与槽号定位目标，须核验完整 tag 和恢复年龄。 |
| 输入 | `writebackInput[4]: cdb_result_t` | 非零 `dataTag` 匹配时唤醒 SQ 数据，也可在分配拍旁路；core 的 `dataTag=0` 表示等待 StoreValue。 |
| 输出 / 输入 | `loadResultOutput: load_result_output_t`, `loadResultReadyInput` | 最老已完成、未广播的 Load；握手后标记已广播，不释放 LQ。 |
| 输入 | `robRetireInput: rob_retirement_input_t` | 实际提交，回收匹配 LQ 或置 SQ committed。 |
| 输出 | `storeCompleteOutput: store_completion_output_t` | 拍初有效、未提交且地址/数据齐的 Store 完成位图，供 ROB 批量置 ready。 |
| 输入 / 输出 | `storeCommitInput: store_commit_input_t`, `storeCommitIndexInput[$clog2(SQ_DEPTH)-1:0]`, `storeCommitReadyOutput` | ROB 头 Store 退休提议；目标身份、就绪和恢复资格匹配即 ready，不依赖 dmemReady。 |
| 输出 | `storeRetirementOutput: data_memory_request_output_t` | ROB 头目标的独立退休载荷，valid 为提议匹配；实际 commit 才使能跟踪。 |
| 输出 / 输入 | `dmemRequestOutput: data_memory_request_output_t`, `dmemReqReadyInput` | 至多一个 32 位处理器侧请求；`valid && ready` 被内存系统接受，store 优先于 load。 |
| 输入 | `dmemResponseInput: data_memory_response_input_t` | 有序 Load 运输完成；四项FIFO冻结每个owner的身份/宽度/符号/取消位，错路返回仍消费但不写LQ。 |
| 输出 | `lqCountOutput[$clog2(LQ_DEPTH+1)-1:0]`, `sqCountOutput[$clog2(SQ_DEPTH+1)-1:0]` | 各自当前有效槽数，容量上限即参数指定深度。 |

`loadAllocIndexOutput/storeAllocIndexOutput` 仅在分配握手时代表新身份。StoreValue 的 core 数组为升序、LSU 端口为降序，核验交付事件应按实际连线匹配，不能直接对应同数字 lane。

## 3. 字节转发、消歧与请求仲裁

Load 地址交付查询旧 SQ；Store 地址/数据通知使用新到达字段和旧态另一字段，同起点、同宽度匹配。所有合格 LQ 可同拍拍末落值，下拍参与 CDB；两个新字段不互相旁路。

1. **转发**：选择最年轻的字节重叠 Store，必须单源完整覆盖、数据就绪且比最后未知地址项年轻。不能跳过年轻部分覆盖项，也不多源拼接或合并部分内存返回。已提交 Store 按 SQ FIFO 次序参与，不用已退休 ROB tag 比较。
2. **Cache 准入**：转发失败时，更老未提交 Store 地址未知或有任意字节重叠都会阻塞读。按实际 1/2/4 B 消歧，返回按宽度和 `isUnsigned` 扩展。
3. **发送**：SQ 头已提交或本拍实际退休时优先发写，否则选择未阻塞 Load。只有请求握手才释放 SQ；满队列本拍不因发送提前接收分配。Store 使用原始字节地址，strobe 为 `0001/0011/1111`，从原始地址起排列。
4. **返回身份**：最多四个Load在D$排队；接受时逐项冻结 slot/tag/size/unsigned，恢复对旧owner持久置drop（包括边界，按软件严格更老资格）。返回消费FIFO旧头，须匹配活动且已发送、尚未READY的LQ槽。已转发或错路返回只出队；同时返回/接受时head/tail/count统一更新。队列满时不接受新Load，不能先握手后因FIFO满吞掉请求。不能从复用槽读取旧事务的宽度/符号。

`storeCompleteOutput` 只表示地址/数据齐，ROB 批量置 ready 后下拍才可退休。HALT实际提交立即结束，SQ/D$/外存可仍有Store；不排空、不写回所有dirty。正常脏逐出及实际运输完成协议保留，见 [cache.md](cache.md)。
