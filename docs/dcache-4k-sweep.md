# 4 KiB DCache几何扫描

目标：固定**数据容量4096 B**，最大化`Fmax × 六个IPC用例的几何IPC / 整核含Cache面积`。
扫描32/64/128 B行与1/2/4路；多路统一采用tree-PLRU，不采用LRU或随机替换。
默认生产几何暂保留8 KiB/64 B/1路，扫描在独立副本中进行；活动golden不跟着候选切换。

## 网格及物理结构

| 行长 | 1路组数 | 2路组数 | 4路组数 | word bank/路 | 回填拍数 |
|---|---:|---:|---:|---:|---:|
| 32 B | 128 | 64 | 32 | 8 | 4 |
| 64 B | 64 | 32 | 16 | 16 | 8 |
| 128 B | 32 | 16 | 8 | 32 | 16 |

`SETS × WAYS × LINE_BYTES = 4096`；metadata的tag宽度由组数和offset派生。
每路独立SRAM data/tag+dirty与valid；查询同步读所有路和word bank，命中选择对应路，
Store命中当拍使用组合命中路而不是尚未写入的表项way。miss在查询结果拍冻结victim的
way/tag/dirty/完整数据，直到末拍才能释放Cache队首。

PLRU规则三端相同：先选编号最低的无效路；全有效时走树中的非MRU分支。
2路用1 bit MRU；4路用3 bit，bit2为根、bit1为左节点、bit0为右节点，1表示右子树MRU。
每次命中和完成整行回填时更新该组PLRU，early Load响应本身不更新、不释放队首。
单路没有有效的替换状态。valid只在复位清除、首个实际覆盖拍清除、末拍安装时置位。

I$保持1 KiB/64 B行；D$使用独立的`DCACHE_LINE_BYTES/BITS`与
`dcache_line_response_input_t`，不改变I$、BPU、ROB或ALU依赖派发寄存边界。
保持4项请求队列、写回/写分配、有序运输owner和持久取消、立即HALT不排空。

## 度量口径与限制

- 每个配置都运行实际SRAM DCache/DMEM的两软件、RTL和独立周期参考；20项观察包括
  元数据/有效行数据、PLRU哈希、回填游标、一次早响应与队首释放。
- 两软件完整18 ISA＋6 IPC校验结果、退休数、周期和保留统计，允许与8 KiB周期不同。
- 排名IPC由**未舍入的`retired / ipc_cycles`**取六例几何平均，不使用日志中六位小数IPC。
- 全部9个配置都综合**core＋I$/D$**，外存为接口，不用独立DCache面积/频率代替整核。
- ASAP7 RVT TT、相同Yosys/ABC/OpenSTA、FakeRAM模型和2.0 ns目标；理想时钟、无互连
  寄生。该Fmax为综合级估计，不是布局布线/芯片实测；不能声称满足2 ns。
- 外存模型维持独立20周期整行读写。载荷随行长变为256/512/1024 bit，**没有增加总线
  串行传输成本**。因此排名仅适用于本模型；固定带宽AXI/真实SRAM宏需要另测。

## 工件与复现

路径相对`RISC-V-CPU-2026/`：`build/dcache-sweep-20261015/`。
每个`行长-组数-路数/`保存完整PASS日志、sv2v源快照、转换输入、网表、STA及综合JSON。
`audited-ranking.json/csv`核对几何、源码、转换摘要、工具/库/模型和固定回填拍数。
早期`/tmp`统计JSON随重启丢失时，审计器明确标注从持久PASS日志恢复的周期和当时校验
过的golden退休数，不冒称原始统计JSON；不重跑已完成测量。

在共同父目录执行：

```bash
python3 -B sync/dcache_sweep.py --reuse --synth-jobs 3
python3 -B sync/report_dcache_sweep.py RISC-V-CPU-2026/build/dcache-sweep-20261015
python3 -B sync/run_sram_cpu.py --geometry 32 128 1 --allow-cycle-change --trace \
  --out RISC-V-CPU-2026/build/dcache-sweep-20261015/verification-32B-1way
```

`--geometry`仅改私有观察副本，生产Probe/Tester不恢复。整核验证比较每拍pre/post的70项
可观察合同、独立ISA退休流、实际DMEM与valid Cache字节，不扩大为完整内部状态形式证明。
32 B行的4拍回填可能早于依赖分支/HALT提交结束；专项如实记录该边界，不为凑“中途
HALT”而人为延长回填。Store-HALT仍验证已接受Cache事务可留在途。

## 结果状态

综合和完整整核验证正在收口；最终9配置排名以完成后的审计表为准，不由局部IPC或
暂时领先推断未完成配置的结果。

已经完成且不需因重启重跑的验证：

- 所有9个配置的普通SRAM四方比较、两软件18 ISA＋6 IPC通过，PASS日志位于各配置目录。
- `verification-rtl-default/report.json`：20/20 RTL测试（固定8 KiB默认几何）；恢复时保留
  已通过用例，仅补后两个SRAM测试。
- `verification-rtl-negatives/report.json`：9/9故障注入均由运行期检查检出，不以编译失败
  当作有效负向。
- `verification-32B-1way-poison/report.json`：13,596拍/20项比较，471次4拍回填、290次
  不释放队首的早响应、125次并行dirty缺失，两软件/RTL与独立参考一致。
- `verification-32B-1way-early/report.json`：7个实际三CPU程序共480拍，独立退休/有效内存
  检查通过；4拍填完后才提交的Load-HALT/依赖分支边界如实记录，Store-HALT保留在途请求。

`verification-32B-1way-full/report.json`已经完整通过24/24：ISA总13,354,791、IPC总932,876，
共14,287,667周期、28,575,334个exact 70项pre/post观察点；独立退休流、实际DMEM/有效Cache
全等。六例未舍入几何IPC为0.5072817116894153，结果和退休数不变。

相对此前8 KiB合并版，32 B单路候选的面积−8.5153%、Fmax＋18.0748%、几何IPC−7.3753%，
密度评分＋19.5461%；它并非IPC最优，不能隐去rsort/vvadd等个例的周期退步。
这仍是候选对照，是否为9配置最高分须等完整综合表。

仍在运行：`verification-8K-default-full/`（24例默认strict周期及每拍指纹）与剩余综合。
未完成报告不能算通过。
