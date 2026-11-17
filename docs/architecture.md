# 处理器架构

SystemVerilog RV32IM 乱序核，顺序重命名和分配，乱序执行，按序退休。支持对齐控制转移的合法无异常程序，不实现 CSR 和系统异常处理。

## 默认配置

| 项目 | 默认值 |
|---|---|
| 取指／译码／顺序分配／提交 | 4 / 4 / 4 / 4 |
| FQ／IQ／ROB／PRF | 8 / 8 / 16 / 48 项 |
| Integer／Multiply／Divide／Branch／Load／StoreAddr／StoreValue RS | 4 / 1 / 1 / 4 / 2 / 2 / 2 |
| 执行与写回 | 双 ALU、单 AGU；四路 CDB：两个 ALU 各一路，MUL/DIV 共享一路，Load 独占一路 |
| LQ／SQ／Load 运输 owner | 各 8 项 |
| 分支预测 | Tournament、BTB 32 项、RAS 8 项、checkpoint 64 项 |
| 恢复 | 先同步读取已提交基线，再每拍重放 4 个 ROB 槽，最多 4 拍重放 |

## 前端与预测

- I$ 命中可连续取 4 条指令，跨 16 B 但不跨 64 B 缓存行；遇本组首条分支或跳转即截断，只查询一次 BPU。冷未命中只取一条。
- FQ/IQ 按指令计信用，空队列支持整组旁路。默认四宽路径由旧空位反推接受本包所需的译码和分配数量。重定向清逻辑队列，迟到响应仍须匹配请求身份。
- Tournament 用预测时的局部／全局历史训练；仅两分量预测分歧时更新 chooser。JALR 使用 x1/x5 识别链接寄存器：`pop = rs1Link && rd != rs1`、`push = rdLink`，先 pop 后 push。

## 分配、执行与恢复

- RAT/PRF/ROB/RS/LSQ 共用连续分配前缀；组内 RAW 取最近的实际写者，WAW 取年轻映射。新分配项不当拍执行，回收的物理寄存器下一拍可用。
- Integer、Branch、Load、StoreAddr、StoreValue RS 只按拍初空位分配，不借当拍离站释放的槽。Load 与 StoreAddr 共用 AGU，采用选择性晚唤醒；Branch 保留完整写回捕获，但不以 Load 当拍旁路派发，仍可用 ALU 和 MUL/DIV 当拍结果。
- MUL/DIV 共享写回按最老合格结果仲裁，未获准者保留。条件分支走 BRU，JAL/JALR 走 ALU。退休只认拍初 ready 的连续前缀；`retirementOutput` 覆盖全部退休通道，旧标量 `commit*` 只覆盖通道 0。
- Flush 选最老候选，取消严格年轻项。恢复时 RAT/RAS 重放存活前缀，自由队列另外遍历取消项以回收物理号；分配、执行、退休和 CDB 暂停，LSU/Cache/AXI 继续排空。
- [RAS](../verilog/rtl/predictor/rv32_bpu_ras.sv)按 ROB 顺序重放存活的调用和返回，恢复完整栈，而非只恢复栈顶。

## 访存与缓存

| 缓存 | 布局与信用 |
|---|---|
| I$：1 KiB，16 组 × 1 路 × 64 B | 同步 SRAM，2 个请求包槽、最多 8 字信用 |
| D$：8 KiB，128 组 × 2 路 × 32 B | 写回／写分配、PLRU，8 个请求槽、4 个 MSHR |

- LQ 广播后保留至退休，SQ 退休后保留至内存实际接受。Load 只从最年轻的重叠 Store 转发，要求该 Store 就绪且单独覆盖全部字节；未知地址或未解决的重叠会阻塞缓存请求。
- 数据请求每拍至多一个，通常 Store 优先。SQ 拍初占用不超过 4 且无在途 Load 时，合格 Load 可越过不重叠的普通 RAM Store 一次，随后须先接受 Store。
- 已发出的 Load 被取消时保留运输身份至响应返回。D$ 支持安全的 hit-under-miss、同行 Load 合并和下一行预取（需求优先）。首批 SRAM 回填可返回请求字，但不从 AXI 的部分行数据提前返回。
- SRAM 数据不复位，以有效控制屏蔽旧内容。读写边界见 [SRAM 模型](sram.md)，行运输与 MMIO 退出见 [AXI4-Lite 协议](axi4-lite.md)。

## 编译参数

容量会改变公共类型，同次编译须给所有 RTL 统一传宏。定义见 [`rv32_pkg.sv`](../verilog/rtl/common/rv32_pkg.sv)。

| 宏 | 默认值与约束 |
|---|---|
| `CPU_FETCH_WIDTH` / `CPU_DECODE_WIDTH` / `CPU_ISSUE_WIDTH` / `CPU_COMMIT_WIDTH` | 默认 4，支持 1/2/4；四取指要求四译码和四分配。`CPU_RENAME_WIDTH` 是分配宽度的兼容别名，两者同时指定须相等。 |
| `CPU_ALU_UNITS` / `CPU_ALU_CDB_PORTS` | 默认 2/2，支持 1/2；双 ALU 写回要求双 ALU 和四分配。CDB 总数为 ALU 写回路数加 2。 |
| `CPU_FQ_ENTRIES` / `CPU_IQ_ENTRIES` | 各为译码宽度的 2 倍，可显式覆盖。 |
| `CPU_ROB_ENTRIES` / `CPU_PRF_ENTRIES` | 默认 16/48；ROB 至少 16 且为 2 的幂，PRF 至少 `32 + ROB_ENTRIES`。 |
| `CPU_BPU_CKPT_ENTRIES` | 2 的幂，且覆盖 `ROB + 取指字信用 + FQ + IQ`，默认向上取整为 64。 |
| `CPU_ICACHE_SETS` / `CPU_ICACHE_WAYS` | 默认 16/1；组数为至少 2 的 2 次幂，可选 1/2/4 路。容量为 `SETS × WAYS × 64 B`。 |

每拍重放槽数按 `ceil(ROB_ENTRIES / 4)` 派生。构建见[课程用法](template.md)，历史配置矩阵见[参数实验](参数敏感度分析.md#parameter-validation)。
