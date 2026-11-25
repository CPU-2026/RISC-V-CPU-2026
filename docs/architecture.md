# 处理器架构

SystemVerilog RV32IM 乱序核，顺序重命名和分配，乱序执行，按序退休。支持对齐控制转移的合法无异常程序，不实现 CSR 和系统异常处理。

## 默认配置

| 项目 | 默认值 |
|---|---|
| 取指／译码／顺序分配／提交 | 4 / 4 / 4 / 4 |
| FQ／IQ／ROB／PRF | 8 / 8 / 16 / 48 项 |
| Integer／Multiply／Divide／Branch／Load／StoreAddr／StoreValue RS | 4 / 1 / 1 / 4 / 2 / 2 / 2 |
| 执行与写回 | 双 ALU、单 AGU；四路 CDB：两个 ALU 各一路，MUL/DIV 共享一路，Load 独占一路 |
| LQ／SQ／Load 运输 owner | 4 / 4 / 8 项 |
| 分支预测 | Tournament、BTB 32 项、RAS 3 项、checkpoint 64 项 |
| 恢复 | 先同步读取已提交基线，再每拍重放 8 个 ROB 槽，最多 2 拍重放 |

## 前端与预测

- I$ 命中可连续取 4 条指令，跨 16 B 但不跨 64 B 缓存行；遇本组首条分支或跳转即截断，只查询一次 BPU。冷未命中只取一条。
- FQ/IQ 按指令计信用，空队列支持整组旁路。默认四宽路径由旧空位反推接受本包所需的译码和分配数量。重定向清逻辑队列，迟到响应仍须匹配请求身份。
- Tournament 用预测时的局部／全局历史训练；仅两分量预测分歧时更新 chooser。JALR 使用 x1/x5 识别链接寄存器：`pop = rs1Link && rd != rs1`、`push = rdLink`，先 pop 后 push。

## 分配、执行与恢复

- RAT/PRF/ROB/RS/LSQ 共用连续分配前缀；组内 RAW 取最近的实际写者，WAW 取年轻映射。新分配项不当拍执行，回收的物理寄存器下一拍可用。
- Integer、Branch、Load、StoreAddr、StoreValue RS 只按拍初空位分配，不借当拍离站释放的槽。Load 与 StoreAddr 共用 AGU，采用选择性晚唤醒；Branch 保留完整写回捕获，但不以 Load 当拍旁路派发，仍可用 ALU 和 MUL/DIV 当拍结果。
- MUL/DIV 共享写回按最老合格结果仲裁，未获准者保留。条件分支走 BRU，JAL/JALR 走 ALU。ROB 在各 bank 预译码退休行，窄退休资格读取与宽跟踪载荷分开；各通道共用从队首计算的 flush 距离，仍只退休拍初 ready 的连续前缀。`retirementOutput` 覆盖全部退休通道，旧标量 `commit*` 只覆盖通道 0。
- Flush 选最老候选，取消严格年轻项。四分配路径在 flush 拍保存原 ROB 的可回收窗口和完整 tag；恢复时 RAT/RAS 重放存活前缀，PRF 仅在回收窗口、完整 tag 匹配且目的物理号非零时，按 ROB 顺序归还自由队列。重放拍数不变；分配、执行、退休和 CDB 暂停，LSU/Cache/AXI 继续排空。
- [RAS 恢复](../verilog/rtl/predictor/rv32_bpu_ras.sv)从已提交栈重建完整投机栈。默认深度为 3，每拍仍按程序顺序处理最多 8 个 ROB 槽；仅恢复宽度和栈深均为 8 时选用独热深度重放。

## 访存与缓存

| 缓存 | 布局与信用 |
|---|---|
| I$：1 KiB，16 组 × 1 路 × 64 B | 同步 SRAM，2 个请求包槽、最多 8 字信用 |
| D$：8 KiB，128 组 × 2 路 × 32 B | 写回／写分配、PLRU，8 个请求槽、4 个 MSHR |

- LQ 广播后保留至退休，SQ 退休后保留至内存实际接受。Load 只从最年轻的重叠 Store 转发，要求该 Store 就绪且单独覆盖全部字节；未知地址或未解决的重叠会阻塞缓存请求。
- 数据请求每拍至多一个，通常 Store 优先。SQ 拍初占用不超过 4 且无在途 Load 时，合格 Load 可越过不重叠的普通 RAM Store 一次，随后须先接受 Store。
- 已发出的 Load 被取消时保留运输身份至响应返回。D$ 支持 hit-under-miss、同行 Load 合并和下一行预取（需求优先）。完整行到达后，可在 SRAM 填充结束前应答 Load；默认也允许通过身份、地址和 Store 冲突检查的逐字 AXI 回包应答 Load。逐字应答不提前发布缓存行，也不提前释放该缺失槽。
- D$ 对物理请求槽并行比较命中标签；查询胜者直接选择 SRAM 的 set，槽号另路编码。默认按 set 高位分成 2×64 组采样读掩码：由候选槽提前取掩码，沿后按 set 高位选择；只有实际发读才使用结果。退出地址匹配在请求入槽时保存。Store 仍由原仲裁授权写入。
- I$ 将 SRAM 的写使能与逻辑握手分开，片选和读写优先级不变。AXI 读、写队首切换时同拍保存各自的缺失号；写侧另存应答地址，外部 AXI 握手不变。
- 默认 LSU 按在途返回槽提前生成 Load 候选，包括身份、转发与写回优先级。只有实际有效回包才能选通对应候选，保留同拍 Load 写回／唤醒，不增加流水拍。
- ROB 寄存完整 tag 的有效位图，与原 ROB 状态同沿更新。LSU 在仲裁期间并行预查各行身份，最后只取原胜者的资格；失败不改选次名，flush 和恢复边界保持。
- SRAM 数据不复位，以有效控制屏蔽旧内容。读写边界见 [SRAM 模型](sram.md)，行运输与 MMIO 退出见 [AXI4-Lite 协议](axi4-lite.md)。

## 编译参数

容量会改变公共类型。宏在**导出时**对[全部源 RTL](../verilog/rtl_sources.f)统一生效，例如 `python3 verilog/export_rtl.py -D CPU_ROB_ENTRIES=32 --output /path/to/experiment.sv`；不传 `-D` 则生成默认提交配置。定义见 [`rv32_pkg.sv`](../verilog/rtl/common/rv32_pkg.sv)。

| 宏 | 默认值与约束 |
|---|---|
| `CPU_FETCH_WIDTH` / `CPU_DECODE_WIDTH` / `CPU_ISSUE_WIDTH` / `CPU_COMMIT_WIDTH` | 默认 4，支持 1/2/4；四取指要求四译码和四分配。`CPU_RENAME_WIDTH` 是分配宽度的兼容别名，两者同时指定须相等。 |
| `CPU_ALU_UNITS` / `CPU_ALU_CDB_PORTS` | 默认 2/2，支持 1/2；双 ALU 写回要求双 ALU 和四分配。CDB 总数为 ALU 写回路数加 2。 |
| `CPU_FQ_ENTRIES` / `CPU_IQ_ENTRIES` | 各为译码宽度的 2 倍，可显式覆盖。 |
| `CPU_ROB_ENTRIES` / `CPU_PRF_ENTRIES` | 默认 16/48；ROB 至少 16 且为 2 的幂，PRF 至少 `32 + ROB_ENTRIES`。 |
| `CPU_BPU_CKPT_ENTRIES` | 2 的幂，且覆盖 `ROB + 取指字信用 + FQ + IQ`，默认向上取整为 64。 |
| `CPU_ICACHE_SETS` / `CPU_ICACHE_WAYS` | 默认 16/1；组数为至少 2 的 2 次幂，可选 1/2/4 路。容量为 `SETS × WAYS × 64 B`。 |

只有 ROB16 四分配配置最多重放 2 拍；其他配置按最多 4 拍派生每拍重放槽数。构建见[课程用法](template.md)，历史配置矩阵见[参数实验](参数敏感度分析.md#parameter-validation)。
