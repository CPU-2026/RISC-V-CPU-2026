# RTL 缓存与行接口

源码：[`memory/`](../verilog/rtl/memory/)。公共类型见 [package.md](package.md)，LSU 取消见 [memory.md](memory.md)，AXI/退出见 [course.md](course.md)。历史测量见 [experiments.md](experiments.md)。

## 几何与 SRAM

```text
frontend → I$：16 组 × 1 路 × 64 B = 1 KiB → AXIFetch
LSU      → D$：64 组 × 2 路 × 32 B = 4 KiB → AXIData → AXIBus
```

| 缓存 | 数据阵列 | 元数据 |
|---|---|---|
| I$ | 一个 16×512 bit `sram_fakeram`，32 bit 写粒度，1RW 同步读写 | 寄存器 tag/valid |
| D$ | 每路 8 个、共 16 个 64×32 bit `sram_fakeram`，8 bit 写粒度，1RW 同步读写 | 每路一个 64×22 bit `{dirty, tag[20:0]}` SRAM；128 个 valid、64 个 MRU/PLRU 状态寄存器 |

I$ 行为 512 bit、offset 6 bit、index 4 bit、tag 22 bit；D$ 行为 256 bit，地址拆分为
`[31:11] tag / [10:5] set / [4:2] word bank / [1:0] byte lane`。CPU 数据为 32 bit、Store strobe 为 4 bit。

复位只清 valid、替换和控制状态，不清 tag/dirty/data SRAM；无效行旧内容不得影响命中或脏逐出。
`initializedOutput = rstNInput` 仅为兼容观察，不存在 SRAM 扫描等待；core 另有 1 拍 boot。

## ICache

`rv32_icache` 默认 `SETS=16`、`REQUEST_DEPTH=8`，有序槽保存 PC/预测 PC/checkpoint/结果。
实际消费才释放，满槽可同拍替换；退出退休后 `freezeInput` 冻结控制和回填。

- **命中**：组合查旧 tag，接受沿发同步 SRAM 读；下一拍可旁路到匹配队首，否则保存原槽。禁用/写周期 SRAM 输出无效。
- **缺失**：每个已接受 miss 独立发一个行请求，同行不合并。行回复含 `valid/address/data`，匹配最老同行未就绪槽，且无待完成 SRAM 读，才以 `memRspReadyOutput` 消费。
- **回填**：写整行/tag，完成一个旧 miss；同拍同行新请求可从回填总线按 `PC[5:2]` 取指。回填写优先，异行 hit 停收一拍。
- **准入**：检查旧 IMEM 容量；同拍同行回填可旁路容量门控，一般返回消费不提供此旁路。
- **恢复**：`flushInput` 清逻辑请求/读身份，保留 Cache；`memFlushOutput` 取消 AXIFetch 逻辑请求，适配器排空旧物理返回。

## DCache：请求、MSHR 与回填

`rv32_dcache` 默认 `SETS=64`、`WAYS=2`，写回、写分配；支持 1/2/4 路 tree-PLRU。
最低编号 invalid 优先，否则 PLRU；命中及末拍回填更新替换状态，early restart 不单独更新。

### 准入与顺序

- **8 项总请求信用、4 MSHR**。旧 `count<8` 才接受，旧满不复用本拍完成信用；MSHR owner 保留至回填末拍。
- 活动请求独立释放，轮转分配；接受顺序由 8×8 位关系表维护，不能用已退休且可能回绕的 ROB tag 排序。
- n 拍接受，n+1 最早同步查询旧请求，n+2 最早返回 hit Load。安全年轻 Load 可 hit-under-miss；更老 Store 字节重叠阻塞 Load，年轻 miss 还须避开更老 Store 所需 set。
- Store 只在最老活动请求时实际写入并释放，不新增 D$ Store 转发。
- 4 MSHR 冻结 line/owner/victim/dirty/data，不同 set 可并发，同 set 锁至完整回填。同行 Load 在首拍前合并，Store owner 或存在更老同 set Store 时不合并。
- 同行首拍返回 owner，其他等待者 raw 保存后各自应答；每拍最多一个 Load 运输完成。

### 同步 SRAM 与回填

- SRAM 端口优先级：回填 > Store > lookup；miss 早响应优先于同拍 hit，hit 结果可保存。
- 查询同步读全部路 data/metadata；miss 冻结 victim 身份及完整旧数据。分配时使 victim 无效，末拍才发布新行。
- 脏 victim 读/写可并发，必须等实际脏写完成才回填。读/写分别挑最老未发送 MSHR，完成核对 ID 与原地址。
- 每拍写 victim 路两个相邻 32 bit bank，游标 0、2、4、6，共 4 拍。回复可首拍直通，之后必须保持到末拍消费。
- **early restart**：完整 256 bit 回复和脏写完成均就绪，首个合格回填拍按原地址/宽度提取 Load 字节，即使目标在最后一对 bank。响应只发生一次，释放 LSU 运输 owner，但不释放 Cache owner/MSHR，也不消费行回复。
- 前 3 拍不安装 tag/dirty、不释放 owner；第 4 拍写最后一对 bank、更新 metadata/valid/PLRU，消费回复并释放 owner。Store miss 字节在对应 bank 拍合并，不推迟到末拍，Store 不形成 Load 响应。
- Store hit 只写对应路和实际触及的 bank/字节并置 dirty；写/禁用周期旧 SRAM 输出不作为新查询。
- 响应数据源按已选请求 `needMemory` 选择整行回复或命中 SRAM，不将高扇出 fill 资格串入数据选择；valid=0 时 readData 无约定。返回 raw 字节，符号扩展由 LSU 冻结身份完成。

### 三种身份

| 身份 | 位宽 / 生命周期 |
|---|---|
| CPU 运输 ID | 3 bit；LSU 8 项 owner 冻结 LQ slot、ROB tag、宽度、符号、drop；D$ 原样返回 |
| MSHR ID | 2 bit；行读/写请求、回复与写完成；完整运输和行发布后才复用 |
| 行执行器物理 slot | 4 bit；验证环境 `rv32_dmem` 的 16 项混合 FIFO，不是上述事务 ID |

LSU 的 owner 冻结、drop 与乱序返回认证见 [memory.md](memory.md#运输身份与迟到返回)。

## Backend、MMIO 与 AXI

`rv32_dmem_backend` 内含 DCache，接口如下：

| 接口 | 端口 |
|---|---|
| CPU 请求/响应 | `cpuRequestInput/cpuReqReadyOutput/cpuResponseOutput` |
| 行请求/响应 | `memRequestOutput/memResponseInput` |
| 行接受/带 ID 写完成 | `memReadReadyInput/memWriteReadyInput/memWriteResponseInput` |
| 回复消费 | `memRspReadyOutput/memWriteRspReadyOutput` |
| MMIO 旁路 | `exitValidOutput/exitValueOutput/exitReadyInput` |
| 复位释放兼容观察 | `initializedOutput = rstNInput` |

行接口含读/写各自 ID、返回地址/ID 与独立消费握手；intent 仅在 `valid && ready` 接受后标记 sent，
回复保持到实际消费，不使用旧式无 ID 单拍脉冲。`idleOutput` 不是课程退出条件。

MMIO 不查询/分配 Cache 行；旁路排序与退出完成条件见 [course.md](course.md#退出与复位)。

独立 assessment 的旧 HALT 边界见 [assessment.md](assessment.md#课程顶层与独立范围)；未落外存的 dirty 行不能冒充已完成写回。

## 验证用行执行器 `rv32_dmem`

`DEPTH=16`、`LATENCY=20`，用于独立数据侧环境，不在课程活动 filelist 中；不把 128 KiB 宿主内存综合进 CPU。
一个混合 FIFO，每项复用一份 32 B 载荷存写数据或读结果；每拍最多一写一读，双接受先写，最后旧信用归写。
旧满即停收；所有旧请求独立递减，接受拍不递减。到期读采样旧阵列，写在沿上落阵列；旧读背压不阻止后续执行。
读/写各选本类型最老未消费项，写完成可越过未消费读以避免脏回填死锁；只回收连续已消费前缀。
复位不清外部持久字节阵列，旧 HALT 环境不额外 drain。

## 验证入口与边界

```bash
python3 -B -m unittest discover -s scripts/tests -p 'test_sv_frontend.py' -v
python3 -B -m unittest discover -s scripts/tests -p 'test_lsu_tagged.py' -v
python3 -B scripts/check_dcache_sync.py
```

前端/转换测试比较原始与转换 RTL 的两路 SRAM、valid、PLRU 和接口，并用独立字节参考核验 Load。
数据侧对拍只读同级软件源码，包含满 16 信用、写完成越过旧读、4 MSHR、同行合并、hit-under-miss 与乱序返回。
当前整核验证见 [course.md](course.md#当前验证记录)，历史 4 请求槽数据侧报告见 [experiments.md](experiments.md#4-四-mshr-数据侧快照2026-10-16早于当前课程顶层)。
