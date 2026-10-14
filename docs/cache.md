# RTL 缓存

> **4 KiB几何扫描**：RTL现支持1/2/4路tree-PLRU及独立32/64/128 B D$行；
> 默认仍为下文8 KiB/64 B/1路，I$行保持64 B。多路同步读所有路，命中写对应路，
> invalid优先/否则PLRU，miss冻结victim身份。几何、评分及验证见[扫描说明](dcache-4k-sweep.md)。
> 扫描不更新活动golden；下文固定16 bank/8拍/512bit数字仅描述默认配置。

当前 D$ 周期合同与 2026-10-13 软件 SRAM 实现一致；RTL 的 valid 独立为寄存器，取消 SRAM 初始化扫描。共同父目录旧 §55/62 的寄存器 D$/停机排空记录是历史。core 使用 32 位处理器端口，外存仍传 512 位整行；Cache data 拆为 16 个同步 32 位 word bank，核外延迟由环境 ready/valid 决定。

```text
frontend → I$：16组 × 1路 × 64 B = 1 KiB → 512-bit 整行读
LSU      → D$：128组 × 1路 × 64 B = 8 KiB → 16 × (128×32-bit) data bank
```

## 公共几何与 SRAM

每行 64 B，外存载荷 512 位，地址按 64 B 对齐。offset 为 6 位；I$/D$ 的 index 为 4/7 位，tag 为 22/19 位。D$ 地址拆分为 `[31:13] tag / [12:6] set / [5:2] word bank / [1:0] byte lane`。CPU 数据为 32 位，Store strobe 为 4 位。

| 缓存 | 数据阵列 | 元数据 |
|---|---|---|
| I$ | 公共 `sram_fakeram`，16×512 bit，32 bit 写粒度，1RW 同步读写 | 寄存器 tag/valid |
| D$ | 16 个公共 `sram_fakeram`，每个128×32 bit、8 bit写粒度、1RW同步读写 | 公共 SRAM，128×20 bit，`{dirty, tag[18:0]}`；另有128个可复位 valid 寄存器 |

I$ 整行回填写掩码全 1。D$ 复位只清 valid 寄存器及控制状态，tag/dirty/data SRAM 保留原内容，冷启动和再次复位均不清 SRAM。valid=0 时不使用旧 tag/dirty 判断命中或脏逐出。`initializedOutput` 仅兼容观察复位释放（等于 `rstNInput`），core 不再等待 D$ 扫描；三端仅保留 core 的1拍 boot，不计入正常 core/total 周期。常量及接口类型见 [package.md](package.md)。

两软件和RTL均采用20 bit `{dirty, tag}` SRAM及独立valid寄存器。测试探针将二者重组为21 bit `{dirty, valid, tag}` 逻辑观察视图，按有效行比较，不要求无效行的 SRAM 内容等于软件初始零值。

## ICache

`rv32_icache` 为 1 KiB 直接映射缓存，`REQUEST_DEPTH=4`。有序请求槽保存 PC、预测 PC、checkpoint 和结果；实际消费响应后释放，满时可同拍替换。

- 命中：组合查旧 tag，接受沿发 SRAM 读；下一拍可旁路到匹配队首，否则保存到原槽。禁用或写周期的 SRAM 输出无效。
- 缺失：每个已接受 miss 独立发一个行请求，同行请求不合并。行返回携带 `valid/address/data`，只接受匹配最老同行未就绪槽且无待完成 SRAM 读的返回，以 `memRspReadyOutput` 确认。
- 回填：写整行和 tag，完成一个旧 miss。同拍同行新请求可按 `PC[5:2]` 从回填总线取指；回填写优先，异行 hit 停收一拍。
- 准入：检查旧 IMEM 容量；同拍同行回填可旁路容量门控，一般返回消费不提供此旁路。
- 恢复：`flushInput` 清逻辑请求与读身份，保留 Cache；`memFlushOutput` 取消逻辑 IMEM 队列。总线适配器负责识别并丢弃已取消的物理返回。

core 的 `imemCacheRequestOutput` 接 CPU 请求，Cache ready 接 core 请求 ready；响应 valid/instruction 接 core 返回，`imemRspReadyOutput/imemFlushOutput` 分别接消费与恢复。

## DCache

`rv32_dcache` 默认 `SETS=128`、`WAYS=1`，写回、写分配；支持`WAYS=1/2/4`。
多路采用同步data/metadata SRAM和独立valid，最低编号invalid优先、否则tree-PLRU；
不是恢复历史寄存器D$/四路路径。命中与末拍回填更新PLRU，单路替换状态无作用。

- 准入：4项请求队列，拍初 `count<4` 时接收；满队列本拍完成也不补入。入队与查询分离，miss等待期间仍可排队。
- 命中：n拍接受，n+1最早查询旧队首 data/tag+dirty，并在查询沿采样对应 valid；n+2 Load直接使用旧 SRAM 输出和对齐的valid返回。Store实际字节写/置 dirty 才出队。下一队首不提前查询。
- 缺失：查询结束并行读到所有16个bank，保存完整victim及旧metadata；外存仍只读回一条512-bit整行。回填游标按0、2、…、14推进，每拍写两个相邻bank，共8拍；回复可在首拍直通、之后保持到末拍。脏行读写可并行发起，但回填必须等脏写实际完成。
- Load early restart：完整512bit回复到达且脏写回已实际完成时，首个合格回填拍（游标0）按原地址/宽度提取字节并响应一次，即使目标位于最后一对bank。`loadRespondedInner`防重复；提前响应只释放LSU运输owner，不释放Cache队首、不消费行回复。
- 响应data选择与使能解耦：按队首`needMemory`选择完整回复或命中SRAM字节，只有valid使用完整服务资格；有效hit/miss返回值与拍数不变。valid=0时readData无约定，不把高扇出fill使能用于数据源选择，不加响应寄存级。
- 回填提交：首拍实际覆写bank时清对应valid，前7拍不改tag/dirty、不释放队首、不消费DMEM回复；第8拍写最后一对bank、更新tag/dirty并置valid、消费回复/释放队首，Load不再次响应。Store miss的字节在对应bank拍到达时合并，不能推迟到末拍；Store不形成Load响应。
- SRAM端口：查询同时同步读全部16个bank和metadata；回填只启用当前bank对，命中Store只启用被写字节触及的一个或两个bank，并同步置dirty。写/禁用周期的旧输出不作为新查询结果。Load返回只保留实际宽度的原始字节，符号扩展由LSU的冻结身份完成。
- 空闲：`idleOutput` 表示复位已释放且请求队列、读结果与外存事务均空；不是 HALT 结束条件。
- 恢复：D$保持已接受请求顺序，包含被取消的读。LSU四项FIFO持有 slot/tag/size/unsigned/drop，负责逻辑取消和返回鉴权，D$只完成有序运输；已提交Store保留。提前响应前/同拍取消仍消费一次owner但不写LQ；响应后取消不能再生成响应。Cache满时即使owner已释放仍不得提前接收下一请求。

## `rv32_dmem_backend`：处理器接口和复位

内部实例化 DCache，接口类型与位宽相同：

| 接口 | 端口 |
|---|---|
| CPU 请求/响应 | `cpuRequestInput/cpuReqReadyOutput/cpuResponseOutput` |
| 行请求/响应 | `memRequestOutput/memResponseInput` |
| 行接受/写完成 | `memReadReadyInput/memWriteReadyInput/memWriteDoneInput` |
| 复位释放兼容观察（无扫描等待） | `initializedOutput = rstNInput` |

core 的 `haltedOutput` 只表示 HALT 已提交，不等待SQ空、Cache空或外存完成。backend不含排空FSM，不扫描dirty行。assessment顶层的旧 `drainDoneOutput` 仅兼容观察，直接等于 `haltedOutput`；它不再驱动写回。

计时：`total=core`、`drain=0`，保留HALT提交当拍的正常更新。HALT时实际外存可能尚未包含已退休Store；测试分别验证退休Store序列与实际外存/Cache/队列，不能用dirty行覆盖外存来冒充最终落地。

## 验证入口与范围

共同父目录下的验证入口：

- `python3 -B sync/run_sram_dcache.py`：两软件实际模块、RTL与独立周期/字节参考，逐拍比较回填游标/完成、metadata/有效行数据及实际DMEM；覆盖8拍回填和脏缺失。
- 上述入口加`--poison-sram`：仅在外部软件测试副本预置tag=0/dirty=1/data=0xA5，验证valid=0屏蔽未初始化SRAM，不要求初始SRAM零值。
- `python3 -B sync/run_capacity.py`：另含16-bank逐拍写使能/byte mask断言、末拍metadata/释放门控，以及跨bank Store miss/hit合并和dirty refetch；`tb_sram_early_restart`接实际LSU＋DCache验证一次早响应、满Cache与owner独立、取消/同tag复用、脏行及部分回填复位。
- `python3 -B sync/run_capacity.py`：现行容量/接口门禁；新增D$非零初始SRAM、128项valid复位、脏行SRAM保留、部分回填/待返回命中复位检查；驻留dirty不自动写回、HALT保留posted SQ。
- `python3 -B sync/run_sram_cpu.py`：实际三CPU的70项每拍观察指纹、逐条独立ISA退休与实际DMEM/有效Cache内容；`--trace` 另逐word比较pre/post轨迹。
- 有意变更时序使用`--allow-cycle-change`，只放开旧周期golden，仍要求结果/退休数及三端逐拍严格一致；验证后才刷新活动表。`run_early_restart_cpu.py --binaries ...`专门检查真实HALT中止回填、恢复及独立有效内存。
- 旧 `run_cached_rtl_chain.py`、`run_cpu_benchmarks.py` 和 §56/68 的2872word/最终全dirty内存合同是历史，不代表本次新的整核内部状态门禁或课程AXI已通过。
