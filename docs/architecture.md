# 默认架构与关键约定

更新至2026-11-07。描述跨16B四取指及当前工作树结构；当前生产已采用ROB16／PRF48；此配置面积／Fmax／评分未测，不继承旧生产PPA。配置方法见[参数化配置](parameterized-configuration.md)，验证边界见 [course.md](course.md)，字段以 [`rv32_pkg.sv`](../verilog/rtl/common/rv32_pkg.sv) 和模块源码为准。

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
- 非MUL/DIV RS支持实际离站信用复用；Integer/Branch/Load及StoreAddr可使用已授权WB当拍派发，StoreValue保留原ALU数据旁路。Load/StoreAddr共用AGU，只有真正获接受才返还信用；StoreValue最多两路交付数据。
- ALU单槽结果级可消费同拍重填；MUL为Booth→CSA→最终加法三级弹性流水，DIV为单上下文radix-4 SRT。共享CDB选最老合格结果，未授权结果保持；条件分支走BRU，JAL/JALR走ALU。
- 退休只认旧ready连续前缀，不旁路本拍WB；退出Store截断年轻lane。完整观察使用`retirementOutput[COMMIT_WIDTH]`，旧标量`commit*`仅lane0。
- Flush候选排队选最老，新请求不直通；取消严格年轻项，旧结果核验完整tag。循环年龄只用于合法在飞半环窗口。
- 恢复先同步读已提交RAT/RAS基线，再重放原ROB窗口：默认ROB16每拍4槽、最多4拍。RAT/RAS重放存活前缀，free list还遍历取消后缀回收物理号。重放暂停分配／执行／退休／CDB，LSU/Cache/AXI继续排空。

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
