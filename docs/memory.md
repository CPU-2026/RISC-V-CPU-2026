# RTL 访存队列

源码：[`rv32_lsu.sv`](../verilog/rtl/memory/rv32_lsu.sv)、[`rv32_agu.sv`](../verilog/rtl/execute/rv32_agu.sv)、[`rv32_agu_unit.sv`](../verilog/rtl/execute/rv32_agu_unit.sv)。容量见 [package.md](package.md)，缓存见 [cache.md](cache.md)。

```text
单发射 → 分配 LQ/SQ → Load/StoreAddr RS → 共享 AGU → 地址结果级
                         StoreValue RS ──────────────────► SQ 数据
SQ 单源完整转发 → LQ → Load 结果 → PRF/ROB
最老可发 Load / SQ 头已提交 Store → D$
```

## 地址交付

`rv32_agu` 无状态、无握手：`addressInput.{baseAddress,offset}` 组合相加，输出 32 位模加法字节地址。

`rv32_agu_unit` 接 `executeInput: rs_issue_output_t` 与 `auxiliaryInput={isStore,LSQ_slot[2:0]}`，恒 ready（发射时已预留 LSQ 槽）。n 拍保存地址和完整 ROB tag，n+1 以 `addressOutput.valid` 向 LSU 交付，拍末置地址 ready，n+2 可见；可交付同拍重填。索引须取寄存 aux，不能接当前派发项；有效性不能读取内部 `validInner` 代替接口。

## LSU 生命周期与接口

LQ 有效位分配首个空槽，广播后保留到 ROB 退休；SQ 以 epoch 指针维护 FIFO，地址/数据独立就绪，退休仅置 committed，内存请求接受才释放。已提交 SQ 跨 ROB 回绕和恢复保留。满队列不借用本拍释放容量。

| 接口 | 合同 |
|---|---|
| `loadAllocationInput` / `storeAllocationInput` | ready 握手分配，`loadAllocIndexOutput/storeAllocIndexOutput` 仅此时代表新身份。 |
| `addressInput/addressIndexInput` | 地址、类型和槽号；完整 tag 须匹配旧活动槽或同拍实际分配项，并核验恢复年龄。 |
| `storeDataInput/storeDataIndexInput` | 默认一 lane，core 配置两 lane；完整 tag 匹配后拍末置数据 ready。core 数组升序、LSU 端口降序，不能按同数字 lane 假定事件对应。 |
| `writebackInput[4]` | 非零 dataTag 可 CDB 唤醒、分配拍旁路；core 置 dataTag=0，改由 StoreValue 交付。 |
| `loadResultOutput/loadResultReadyInput` | 最老已完成且未广播 Load；握手只置已广播。 |
| `robRetireInput` | 实际退休释放匹配 LQ，或置 SQ committed。 |
| `storeCompleteOutput` | 拍初有效、未提交、地址/数据齐的 SQ ready/epoch 位图；ROB 拍末置 ready，下拍才退休。 |
| `storeCommitInput/storeCommitIndexInput/storeCommitReadyOutput` | ROB 头退休提议；身份、就绪和恢复资格匹配即 ready，不依赖 dmemReady。 |
| `storeRetirementOutput` | 独立退休载荷；valid 表示提议匹配，实际 commit 才使能跟踪。 |
| `dmemRequestOutput/dmemReqReadyInput` | 每拍至多一个 32 bit 请求，Store 优先；仅握手释放 SQ。 |
| `dmemResponseInput` / `dmemRspTransactionInput` | 按运输 ID 认领 Load 返回；无响应 ready。 |
| `dmemReqTransactionOutput` | 3 bit 运输 ID，与 LQ slot、ROB tag、MSHR ID 独立。 |
| `flushInfoInput` | 取消年轻 LQ/未提交 SQ，已发出且不具备严格更老资格的 Load owner 持久置 drop。 |
| `coreStoppedInput` | 课程退出退休后冻结 LQ、禁发新 Load，只推进已提交 SQ；控制流程见 [course.md](course.md)。 |
| `lqCountOutput/sqCountOutput` | 实际有效槽数。 |

## 转发、消歧与仲裁

Load 地址交付查询旧 SQ。Store 地址/数据通知使用新到字段与旧态另一字段，同起点、同宽度匹配；两个新字段不互相旁路。合格 LQ 可同拍拍末落值，下拍参与 CDB。

1. **转发**：找最年轻字节重叠 Store，须单源完整覆盖、数据就绪，且比最后未知地址 Store 年轻。不能跳过年轻部分覆盖项，不多源拼接、不与部分内存返回合并。已提交项按 SQ FIFO 次序参与，不用退休后的 ROB tag 排序。
2. **Cache 准入**：转发失败后，更老未提交 Store 地址未知或有任意字节重叠均阻塞 Load。按真实 1/2/4 B 宽度消歧，返回按冻结的宽度/符号扩展。
3. **发送**：SQ 头已提交或本拍实际退休时优先发送，否则选未阻塞 Load。Store 使用原始字节地址，strobe=`0001/0011/1111`，从该地址起排列。

## 运输身份与迟到返回

最多 8 个独立 owner，接受时冻结 LQ slot、完整 ROB tag、size、unsigned、drop。实际 cached 顶层 `TAGGED_DMEM=1`，允许乱序返回；`TAGGED_DMEM=0` 只兼容旧有序裸核。

- 旧满停收，不能先握手再丢请求；取消不提前复用 owner。
- 返回只释放对应 owner，写 LQ 须匹配活动、已发送且尚未 READY 的原身份。错路或已转发返回仅释放运输，不能污染复用槽，也不能从新槽读取旧事务宽度/符号。
- early restart 只完成一次 LSU 运输；Cache owner/MSHR 仍保留到完整行发布。后续 CDB、依赖派发、LQ 退休边界不变。

验证入口：`scripts/tests/test_lsu_tagged.py`；课程整核记录见 [course.md](course.md)。
