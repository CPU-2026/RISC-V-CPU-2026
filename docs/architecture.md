# 默认架构与关键约定

更新至2026-11-13。本文集中维护当前HDL架构与参数用法；采用及指标见[历史记录](history.md)，验证和综合方法见[评估说明](assessment.md)。字段以[`rv32_pkg.sv`](../verilog/rtl/common/rv32_pkg.sv)和模块源码为准，旧配置的资格不自动覆盖当前源码。

## 默认配置

| 项目 | 默认值 |
|---|---|
| 取指／译码／顺序分配／提交 | 4 / 4 / 4 / 4 |
| FQ／IQ／ROB／PRF／checkpoint | 8 / 8 / 16 / 48 / 64 |
| Integer／Multiply／Divide／Branch／Load／StoreAddr／StoreValue RS | 4 / 1 / 1 / 4 / 2 / 2 / 2 |
| 执行与写回 | 双ALU、单AGU；ALU各一CDB，Load/MUL/DIV共享第三路 |
| LQ／SQ／Load运输owner | 各8项；运输ID为3 bit，MSHR ID另为2 bit |
| BPU | LHT256×1、localPHT256×3、global/chooser各256×2；GHR8、condSeen512、寄存器BTB32、RAS8 |

## 前端与预测

- I$命中从任意字位置连续取最多4条，**可跨16 B、不可跨64 B行**；遇最早B/JAL/JALR即截断，冷miss单取。仅该控制流查询单口BPU。
- 实际接受k条才分配k个连续CID，保存拍初预测上下文；FQ/IQ按指令计信用。旧IQ为空可整组旁路；旧FQ/IQ均空时新返回包可直通译码。旁路整组分配或整组入IQ，不做部分整组接受。
- redirect清逻辑请求及队列，物理迟到响应继续排空并鉴权。默认四取指恢复期间保守停取，不继承双取指专属安全预取扩展。
- Tournament按预测时的局部历史/GHR训练；checkpoint另存两分量预测，chooser按PC索引，仅原预测分歧时向正确者移动。不能由nextPC反推taken。
- BTB保存完整PC tag及对齐目标，tag/类型和target分槽仲裁。JALR的`pop = rs1Link && rd != rs1`、`push = rdLink`：同link只push，异link先pop后push；恢复完整RAS栈，不只恢复指针。SRAM BTB仅为独立实验。

## 分配、执行与恢复

- RAT/PRF/ROB/RS/LSQ共用连续前缀fire，年轻lane不能越过阻塞项。组内RAW指向最近实际写者，WAW年轻映射胜出，LINK可预置PC+4/ready；新项不当拍执行。
- PRF读旧自由队首，本拍回收下拍可用，P0不分配；值载荷采用47个1×32 bit SRAM（PRF48减去P0）。ROB载荷不复位，以逐行initialized屏蔽未初始化值，valid/ready/完整tag控制仍复位。
- Integer/Branch/Load/StoreAddr/StoreValue RS均关闭离站同拍分配复用：数值信用、Branch fit和allocator只读寄存busy，实际离站更新占用后下拍可分配。Integer/Branch/Load/StoreAddr保留原WB当拍派发，StoreValue保留原ALU旁路及最多两路数据交付；Load/StoreAddr共用AGU，只有实际接受的旧项离站。
- ALU单槽结果级可消费同拍重填；MUL为Booth→CSA→最终加法三级弹性流水，DIV为单上下文radix-4 SRT。共享CDB选最老合格结果，未授权结果保持；条件分支走BRU，JAL/JALR走ALU。
- 退休只认旧ready连续前缀，不旁路本拍WB；退出Store截断年轻lane。完整观察使用`retirementOutput[COMMIT_WIDTH]`，旧标量`commit*`仅lane0。
- Flush候选排队选最老，新请求不直通；取消严格年轻项，旧结果核验完整tag。循环年龄只用于合法在飞半环窗口。
- 恢复先同步读已提交RAT/RAS基线，再重放原ROB窗口：默认ROB16每拍4槽、最多4拍。RAT/RAS重放存活前缀，free list还遍历取消后缀回收物理号。重放暂停分配／执行／退休／CDB，LSU/Cache/AXI继续排空。

## 已采用的组合拓扑

以下组合拓扑不增加流水级，也不改变实际grant、状态writer或完整身份校验。另已采用的old-row信用边界会改变分配周期；用户随后授权同步两软件，信用及槽选择均只用旧空位，保持原WB唤醒、实际离站与writer。默认四宽原六答案/退休/总周期及各374104条退休PC/周期匹配现存converted HDL；不扩大为全状态或软件九字段退休载荷等价。同步证据`sync/evidence/software-old-row-credit-sync-20261113-r01/synchronization.json`。

| 部位 | 当前实现与边界 |
|---|---|
| LSU相邻word查询 | 用分块比较组织相邻地址判断，保留无符号不回绕与字节覆盖；完整产数转发和原最老Load政策不变。 |
| Branch信用 | 旧空位形成需求fit谓词；当前关闭离站同拍复用，fit、数值信用和最低空槽分配统一使用寄存占用。 |
| PRF目的tag旁带 | 提前传递原物理目的号，真实写入仍由allocation fire授权；原顺序rank/free-list及writer优先级不变，非并行分配排名。 |
| 完整CDB包条件展开 | 已包含DCache响应预览与LSU提前完整鉴权；各route的valid/tag/destination/value在晚route选择前形成，再由原route/grant选择。含无效载荷，不能重复叠加响应预览。 |
| 双队列反向信用 | 仅FETCH/DECODE/ISSUE=4/4/4路径由旧FQ/IQ空位反推接收包所需的最小decode/issue数量，晚backend接受数只比阈值。FQ公开ready与真实push使用同一精确信用；实际pop仍由原decodeCount推进。非法占用保留原位宽模运算，两空队列旁路及其他宽度路径保持。 |

反向信用涉及`rv32_prefix_fifo.sv`、`rv32_decode_issue_queue.sv`、`rv32_frontend.sv`。FIFO外部信用默认关闭，未启用实例接零；启用时断言与原容量方程恒等。推导及实测见[架构探索总结](架构探索总结.md#backward-credit)和[频率分析](频率分析.md)。

## 访存与缓存

| 缓存 | 布局与信用 |
|---|---|
| I$：1 KiB，16组×1路×64 B | 数据16×512 bit、32 bit写粒度；tag/valid/CFI mask为寄存器。2请求包槽、最多8字信用；工作树支持1/2/4路。 |
| D$：8 KiB，128组×2路×32 B | 每路8个128×32 bit字节写bank，每路128×21 bit tag/dirty SRAM；valid/PLRU独立寄存器。8请求、4 MSHR；Store命中位置表4项，非精确LRU。 |

- LQ广播后保留至退休；SQ退休置committed，内存实际接受才释放，已提交项跨恢复保留。满队列不借本拍释放容量，数据请求每拍一个。
- 原则上Store优先；旧已分配SQ≤4且运输owner=0时，原最老合法Load可越过全部字节不重叠的待发／同拍退休普通RAM Store一次，随后强制真实Store接受。债务跨flush保持，恢复冻结／冲刷／退出不新增让行。
- Load只从最年轻重叠且单源完整覆盖的就绪Store转发，不跳过年轻部分覆盖项、不拼多源字节；更老未知地址或重叠未提交Store阻塞Cache准入。保留Load地址查询SQ与Store数据通知，**无Store地址→Load数据通知**。
- SQ完成bitmap可由完整身份的真实地址／数据／匹配WB事件提前通知ROB置ready；退休仍读旧ready，不提前实际Store接受。LSU通知资格提前计算只改组合拓扑，不改事件或状态写入。
- AGU寄存地址/tag/LSQ索引；旧Load可在地址交付拍请求，合法Cache返回可当拍参加CDB，未授权则缓冲。LQ存原始字，读出侧统一扩展。
- 运输owner保存slot/tag/drop，取消后保留到确切响应；写LQ须同时满足活动、完整tag匹配、已发送、未READY，之后才读取size/unsigned。
- D$写回／写分配、PLRU，支持安全hit-under-miss及首回填前同行Load合并；同set锁至完整行发布，SRAM优先级Fill > Store > lookup。一般接受后下一拍查SRAM；旧请求／读级均空时可接受沿启动读、下一拍hit返回，无组合请求→响应旁路。
- 完整行回复且脏写完成后，每拍回填两个bank、共四拍；首拍early restart只响应一次，末拍发布tag/valid并释放MSHR。无AXI部分行critical-word早返回。
- 普通RAM Load实际接受可触发下一32 B行预取：4项源行去重、单pending、最多1个typed预取，共享原信用。需求优先，请求占用≤6／MSHR≤2时入槽；已占MSHR后保留写回与回填所有权，不向CPU产生预取返回，退出接受后停新预取。

SRAM不复位，以有效控制屏蔽旧内容；写／禁用沿不保证保留读输出，I$冻结时刷新未捕获命中读的原组／way。详细时序见 [sram.md](sram.md)，行运输与MMIO退出见 [axi4-lite.md](axi4-lite.md)。

**输入边界**：仅保证合法RV32IM、对齐控制转移的无异常输入；兼容trap零值不表示异常支持。事件按valid/ready判断，无效载荷不保证零。

## 编译参数

ROB/PRF参与公共tag、数组及恢复类型定义，**同次编译全部RTL必须统一传宏**，不能只覆盖某个实例。完整ROB tag宽度为`clog2(ROB_ENTRIES)+1`。

| 宏 | 默认值与约束 |
|---|---|
| `CPU_FETCH_WIDTH` / `CPU_DECODE_WIDTH` / `CPU_ISSUE_WIDTH` / `CPU_COMMIT_WIDTH` | 均4，支持1/2/4；四取指要求四译码/分配。ISSUE是顺序重命名/分配宽度，不是执行单元数量。 |
| `CPU_RENAME_WIDTH` | ISSUE旧兼容别名，同时定义须相等。 |
| `CPU_ALU_UNITS` / `CPU_ALU_CDB_PORTS` | 均2，支持1/2；独立双ALU CDB要求issue4。 |
| `CPU_FQ_ENTRIES` / `CPU_IQ_ENTRIES` | 默认各为译码宽度两倍，四宽各8项。 |
| `CPU_ROB_ENTRIES` | 16，至少16项的2次幂，覆盖分配/提交宽度。 |
| `CPU_PRF_ENTRIES` | 48，至少`32+ROB_ENTRIES`；允许48/80/96等非2次幂。扩ROB须另选足够大的PRF。 |
| `CPU_BPU_CKPT_ENTRIES` | 按总活跃身份预算向上取2次幂；显式覆盖也须满足预算。 |
| `CPU_ICACHE_SETS` / `CPU_ICACHE_WAYS` | 16/1；SETS至少2且为2次幂，表示每路组数；WAYS支持1/2/4。 |

checkpoint预算为`ROB+取指字信用+FQ+IQ`：默认`16+8+8+8=40≤64`；标准窄配置默认为ROB16/PRF48/checkpoint32。恢复宽度按ROB/4派生，自动扩checkpoint不改变预测/训练算法。重现旧四宽基线须显式指定ROB32/PRF64，而不是沿用当前默认。

例如四宽ROB64/PRF96、1 KiB四路I$的统一编译宏：

```text
-DCPU_FETCH_WIDTH=4 -DCPU_DECODE_WIDTH=4
-DCPU_ISSUE_WIDTH=4 -DCPU_COMMIT_WIDTH=4
-DCPU_ALU_UNITS=2 -DCPU_ALU_CDB_PORTS=2
-DCPU_ROB_ENTRIES=64 -DCPU_PRF_ENTRIES=96
-DCPU_ICACHE_SETS=4 -DCPU_ICACHE_WAYS=4
```

此组合checkpoint自动为128项。I$还通过`student_top.ICACHE_SETS/ICACHE_WAYS`向下传递，可在工具支持时覆盖顶层参数；ROB/PRF使用编译宏而非顶层`-G`，以保证类型一致。构建选项用法见原始[template.md](template.md)。

### I$参数行为

- 容量=`SETS×WAYS×64B`：16组1路、8组2路、4组4路均为1 KiB；只增加路数会同时扩容。
- 每路真实同步单端口SRAM；tag/valid/CFI按路保存，读取保存way、fill发布同一路。最低无效路优先，满组后2路反MRU、4路3bit树PLRU，非精确LRU。
- 参数变化不放宽最早CFI截断、cold单条、单预测、请求顺序、背压、flush/迟到响应鉴权或回填旁路合同。逻辑flush不清缓存，reset清valid。
- 冻结读刷新保持原组和原way，不新增数据副本，不授权新请求/回填。

编译可配置不等于任意组合已验证；历史有限矩阵和实验数表见[参数敏感度分析](参数敏感度分析.md#parameter-validation)，当前源码的验证范围见[评估说明](assessment.md#验证范围与测试入口)。
