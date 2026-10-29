# 当前架构与关键约定

对应2026-10-29工作区。演进与取舍见 [process.md](process.md)，验证范围见 [course.md](course.md)；详细字段以 [`rv32_pkg.sv`](../verilog/rtl/common/rv32_pkg.sv) 和各模块源码为准。

## 配置

| 项目 | 默认值 |
|---|---|
| 取指 / 译码 / 顺序分配 / 提交 | 4 / 4 / 4 / 4 |
| FQ / IQ / ROB / PRF / checkpoint | 8 / 8 / 32 / 64 / 64 |
| Integer/Multiply/Divide/Branch/Load/StoreAddr/StoreValue RS | 4/1/1/4/2/2/2 |
| 执行与写回 | 双ALU、单AGU；ALU各一CDB，Load/MUL/DIV共享第三路 |
| LQ / SQ / Load运输owner | 各8项；运输ID为3 bit，MSHR ID另为2 bit |
| BPU | LHT256×1、localPHT256×3、global/chooser各256×2，GHR8、condSeen512、寄存器BTB32、RAS8 |

`CPU_FETCH_WIDTH/CPU_DECODE_WIDTH/CPU_ISSUE_WIDTH/CPU_COMMIT_WIDTH`均支持1/2/4；`CPU_ISSUE_WIDTH`表示顺序重命名/分配，不是执行口数。旧`CPU_RENAME_WIDTH`为兼容别名，两宏同时定义须相等。四取指要求四译码/分配。

issue1/2配ROB16/PRF48/CKPT32，issue4配ROB32/PRF64/CKPT64；完整ROB tag分别为5/6 bit。`CPU_ALU_UNITS`和`CPU_ALU_CDB_PORTS`支持1/2，独立双ALU CDB要求issue4。切换窄配置须同时选择匹配的宽度/ALU宏，所有RTL与package统一编译，不能仅覆盖实例参数。

FQ/IQ默认各为译码宽度两倍，可用`CPU_FQ_ENTRIES/CPU_IQ_ENTRIES`覆盖；checkpoint须覆盖ROB＋取指字信用＋FQ＋IQ，默认`32+8+8+8=56≤64`。

## 前端与预测

- I$命中最多取同一16 B包内四条，在最早B/JAL/JALR处截断；冷miss保守单取。仅该控制流查询单口BPU，不复制预测表。
- 实际接受k条才分配k个连续CID，保存拍初GHR/方向上下文；FQ/IQ按指令数计信用，空队列不直通，IQ只消费真实分配前缀。redirect清逻辑请求及队列，物理迟到返回排空。
- Tournament按预测时的局部历史/GHR索引训练，checkpoint另存local/global预测，合计11 bit/CID；chooser按PC索引，仅两分量原预测分歧时向正确者移动。不能由nextPC反推taken。
- BTB保存完整PC tag和对齐目标，tag/类型与target分别按fetch > jump > taken branch分槽仲裁。RAS双link先pop后push，空pop/满push保持；恢复完整栈内容，不只恢复指针。两种SRAM BTB仅为独立实验，不接活动core。

## 分配、执行与恢复

- RAT/PRF/ROB/RS/LSQ共用连续前缀fire；年轻lane不能越过阻塞项。组内RAW指向最近实际写者，WAW年轻映射胜出，LINK可预置PC+4/ready；新项不当拍执行。
- PRF读旧自由队首，本拍回收下拍可用，P0不分配。Integer/Branch/Load RS可用真实授权WB当拍派发并复用实际离站槽；Load/StoreAddr共享AGU，StoreValue最多两路交付数据。
- ALU单槽结果级可消费同拍重填；MUL为Booth→CSA→最终加法三级弹性流水；DIV为单上下文radix-4 SRT。共享CDB选最老合格结果，未授权结果保持。条件分支走BRU，JAL/JALR走ALU并受控制结果仲裁。
- 退休只认旧ready前缀，不旁路本拍WB；退出Store截断年轻lane。监视完整退休须用`retirementOutput[COMMIT_WIDTH]`，旧标量`commit*`仅lane0。
- Flush候选排队选最老，新请求不直通。恢复保留ROB边界、取消严格年轻项，所有旧结果核验完整tag；循环年龄仅用于合法在飞半环窗口。
- 广播拍同步读已提交RAT/RAS SRAM基线，随后重放原ROB窗口：ROB32每拍8槽、ROB16每拍4槽，实际1～4拍。RAT/RAS重放存活前缀，free list还须遍历取消后缀回收物理号。
- 重放暂停分配/执行/退休/CDB，LSU/Cache/AXI继续排空；默认四取指停取，仅旧双取指路径允许已知无控制流I$命中包预取。

## 访存与缓存

| 缓存 | SRAM布局与元数据 |
|---|---|
| I$：1 KiB，16组×1路×64 B | 数据16×512 bit、32 bit写粒度；tag/valid及行内控制流掩码为寄存器。默认2请求包、最多8字信用。 |
| D$：8 KiB，128组×2路×32 B | 每路8个128×32 bit字节写bank，共16个；每路128×21 bit tag/dirty SRAM，valid及PLRU独立寄存器。8请求、4 MSHR。 |

- LQ广播后保留至退休；SQ退休置committed、内存接受才释放，已提交项跨恢复保留。满队列不提前借用本拍释放容量，数据请求仍每拍一个、Store优先。
- Load仅从最年轻重叠且单源完整覆盖的就绪Store转发，不跳过年轻部分覆盖项、不拼多源字节。转发失败时，更老未知地址或任意字节重叠的未提交Store阻塞Cache准入。
- AGU寄存地址/tag/LSQ索引，已预留旧Load可在地址交付拍请求；合法Cache返回可当拍参加CDB，未授权则缓冲。LQ保存原始字，读出侧统一宽度/符号扩展。
- 运输owner冻结slot/tag/drop，取消后保留至确切响应；写LQ须同时满足活动、完整tag匹配、已发送、未READY，之后才可读取行内size/unsigned。
- D$写回/写分配、PLRU；独立接受顺序表，安全Load可hit-under-miss，同行Load首回填前可合并，同set锁至完整行发布。SRAM优先级Fill > Store > lookup。
- 一般Load接受后下一拍同步查询，再下一拍最早返回；旧请求/读级均空时，可接受沿启动同步读、下一拍hit返回。读身份与offset/size同沿保存，不增加组合请求→响应旁路。
- 完整行回复且脏写完成后，每拍回填两个bank、共四拍。首拍early restart只响应一次，末拍才发布tag/valid并释放MSHR；不支持AXI部分行critical-word早返回。
- SRAM不复位，以valid屏蔽旧内容；写/禁用周期读输出无效。AXI行运输、复位与MMIO退出见 [axi4-lite.md](axi4-lite.md)。

仅保证合法RV32IM、对齐控制转移的无异常输入域；旧异常字段/trap端口为兼容零值，不代表异常支持。接口以valid/ready判断事件，无效载荷不保证零。
