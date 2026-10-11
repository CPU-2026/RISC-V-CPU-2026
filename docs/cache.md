# RTL 缓存

容量以共同父目录 `CPU-SYNC-SPEC.md` 为准。core 使用 32 位处理器端口，Cache 使用 512 位整行端口；核外延迟由环境的 ready/valid 决定。

```text
frontend → I$：16组 × 1路 × 64 B = 1 KiB → 512-bit 整行读
LSU      → D$：128组 × 1路 × 64 B = 8 KiB → 512-bit 整行读/写
```

## 公共几何与 SRAM

每行 64 B，行载荷 512 位，地址按 64 B 对齐。offset 为 6 位；I$/D$ 的 index 为 4/7 位，tag 为 22/19 位。CPU 数据为 32 位，Store strobe 为 4 位。

| 缓存 | 数据阵列 | 元数据 |
|---|---|---|
| I$ | 公共 `sram_fakeram`，16×512 bit，32 bit 写粒度，1RW 同步读写 | 寄存器 tag/valid |
| D$ | 128×512 bit 寄存器，组合读、时钟沿按字节写 | 寄存器 tag/valid/dirty |

I$ 整行回填写掩码全 1；D$ 复位只清元数据。常量及接口类型见 [package.md](package.md)。

## ICache

`rv32_icache` 为 1 KiB 直接映射缓存，`REQUEST_DEPTH=4`。有序请求槽保存 PC、预测 PC、checkpoint 和结果；实际消费响应后释放，满时可同拍替换。

- 命中：组合查旧 tag，接受沿发 SRAM 读；下一拍可旁路到匹配队首，否则保存到原槽。禁用或写周期的 SRAM 输出无效。
- 缺失：每个已接受 miss 独立发一个行请求，同行请求不合并。行返回携带 `valid/address/data`，只接受匹配最老同行未就绪槽且无待完成 SRAM 读的返回，以 `memRspReadyOutput` 确认。
- 回填：写整行和 tag，完成一个旧 miss。同拍同行新请求可按 `PC[5:2]` 从回填总线取指；回填写优先，异行 hit 停收一拍。
- 准入：检查旧 IMEM 容量；同拍同行回填可旁路容量门控，一般返回消费不提供此旁路。
- 恢复：`flushInput` 清逻辑请求与读身份，保留 Cache；`memFlushOutput` 取消逻辑 IMEM 队列。总线适配器负责识别并丢弃已取消的物理返回。

core 的 `imemCacheRequestOutput` 接 CPU 请求，Cache ready 接 core 请求 ready；响应 valid/instruction 接 core 返回，`imemRspReadyOutput/imemFlushOutput` 分别接消费与恢复。

## DCache

`rv32_dcache` 默认 `SETS=128`、`WAYS=1`，写回、写分配；直接映射固定 way0，另保留可选 `WAYS=4`。way 位宽至少为 1。

- 命中：READY 且未 flush 时接受请求。Load 拍末登记、下一拍响应；Store 按字节写入并置 dirty，不产生读响应。命中可连续每拍接受。
- 缺失：保存请求和 victim，WAIT_FILL 独立发回填读与脏行写回，两通道分别握手。读先返回可暂存，须等写完成后回填，再合并 Store 或返回 Load。
- 排空：`flushInput` 停收新请求，FLUSH_SCAN 逐行登记脏写回，FLUSH_WAIT 等写完成后清 dirty、推进；结束置 `flushDoneOutput`。
- 空闲：`idleOutput` 表示 READY 且无待发或在途行命令。

## `rv32_dmem_backend`：处理器接口和最终排空

内部实例化 DCache，接口类型与位宽相同：

| 接口 | 端口 |
|---|---|
| CPU 请求/响应 | `cpuRequestInput/cpuReqReadyOutput/cpuResponseOutput` |
| 行请求/响应 | `memRequestOutput/memResponseInput` |
| 行接受/写完成 | `memReadReadyInput/memWriteReadyInput/memWriteDoneInput` |
| 最终排空 | `drainInput/drainDoneOutput` |

core 的 `haltedOutput` 表示 HALT 已提交且 SQ 写请求全部接受，接 `drainInput`。backend 按 RUN → WAIT_IDLE → WRITEBACK → DONE 排空：停收新请求，等待旧事务与读响应，再写回全部脏行。DONE 保持到复位，系统以 `drainDoneOutput` 判定最终结束。请求接受与写完成是独立事件。

## 已验证

共同父目录下的验证入口：

- `python3 sync/run_capacity.py`：请求预算、顺序响应、容量冲突、字节掩码、脏写回与 flush。
- `python3 -B sync/run_cached_rtl_chain.py`：真实 D$ 整链、独立通道背压、响应时序及最终内存。
- `sync/README.md` §56：24 镜像在共同逻辑 Memory 下逐拍一致，最终 128 KiB 内存逐字节核验；课程 AXI/STA 另验。
