# 工程使用与 RTL 验证

课程环境、`config.mk`、Make 命令、评分和 OJ 提交统一见 [template.md](template.md)；本文只记录本工程补充与验证证据。
活动顶层为 [`student_top.sv`](../verilog/rtl/student_top.sv)，源码清单为 [`filelist.f`](../verilog/filelist.f)。文档整理未重跑仿真或综合。

## 本工程使用补充

- 当前 RTL 综合需要可用的 `sv2v`；Docker 基础镜像未提供，需另行安装/指定。软件对拍驱动需要 C++20 及同级 `RV32IM_Simulator/`，普通课程构建无需该目录。
- `make` / `make code` 总是编译 RTL 并生成 `./code`；`SIM=/path/to/sim` 仅供本地 run/test/perf 跳过编译。
- `make clean` 会删除 `BUILD`、`SYNTH_OUT`、`code` 及其中历史报告，重要工件须先备份。
- 综合范围、模式及产物见 [assessment.md](assessment.md)；工具包重建见 [packaging/appimage](../packaging/appimage/README.md)。

## 活动路径与退出

```text
core（寄存器 BTB、两路 CDB） → I$ → AXIFetch ─┐
                           → D$ → AXIData  ──┴→ AXIBus → AXI4-Lite
```

容量见 [package.md](package.md)，预测见 [frontend.md](frontend.md)，四拍恢复见 [backend.md](backend.md)，Cache/行接口见 [cache.md](cache.md)，总线主机和从机见 [axi4-lite.md](axi4-lite.md)。当前仍为单宽取指/发射/提交，未实现多发射。

- 默认 `0ff00513` 为普通 ADDI；旧镜像须显式设置 core/frontend/decoder 的 `LEGACY_HALT=1`。
- 向 `0x80000000` 的 SW 按序退休时冻结核心 IPC，退休数包含该 Store。核心/FQ/IQ/BPU/FU/LQ 使用同步状态使能冻结，不产生门控时钟。
- 已提交 SQ、D$、AXI 继续推进。MMIO 最老请求等待 AXIData 读写均空，旁路 Cache，执行完整 32 bit 写；对应 `BVALID && BREADY` 握手才输出结果并结束。不扫描全部 dirty 行，不以退休或 AW/W 握手冒充结束。
- 复位清队列/身份，SRAM 内容由独立 valid 屏蔽；释放后独立 boot 1 拍。课程 sim 的 cycles 含 boot，软件活动表 total 不含；对拍先执行 boot 再计数，不平移流水事件凑周期。

## 验证入口

```bash
python3 -B scripts/build.py --verilator /usr/bin/verilator --out /tmp/opencode/course-rtl --jobs 2
python3 -B scripts/testcase.py --kind correctness --build /tmp/opencode/course-rtl --max-cycles 100000000
python3 -B scripts/testcase.py --kind perf --build /tmp/opencode/course-rtl --max-cycles 100000000
python3 -B scripts/check_course_sync.py --out /tmp/opencode/course-sync-register
python3 -B scripts/check_axi_sync.py
python3 -B scripts/check_course_smoke.py --build /tmp/opencode/course-sync-register
python3 -B -m unittest discover -s scripts/tests -v
```

`check_course_sync.py` 以真实软件 CPU/Slave 驱动课程 DUT，比较有效 AXI 载荷、取指/预测/发射/恢复、ROB、GHR/checkpoint、写回、D$ 事件、退休及退出结果；独立 RV32IM 解释器核验退休 PC、寄存器和 Store。只在外部软件副本增加测试 friend，不在生产恢复 Probe/Tester。`--skip-build` 核对源码摘要并拒绝陈旧二进制，验证前后源码摘要须一致。

`check_axi_sync.py` 对真实软件三模块与 RTL 逐拍施加独立 AR/AW/W 背压、延后 R/B、回复保持、满信用及未握手 AR 恢复，并检查 VALID/载荷稳定。上述检查不是全部内部数组逐 bit 等价、任意异常域证明或门级等价。

## 当前验证记录

下表按快照分开记录，不将旧验收自动扩展到后续 RTL。

| 快照 | 已有证据与边界 |
|---|---|
| 10-16 寄存器 BTB 课程基线 | 默认 Verilator lint、sv2v 全顶层转换及 Yosys 层级检查通过；18/18 单元/转换回归。课程 `-Wall` 仍有空输出口/未用信号诊断，不称全零警告。 |
| 同基线 AXI 对拍 | 20,000 拍；11,426 次读接受/返回、3,802 拍 AW/W 独立背压、7,795 拍 AR 保持、300 次恢复、17,343 拍共享 16 行满信用、1 次完整 MMIO。16 行是当时配置，当前容量见总线文档。 |
| 同基线 CPU/ISA | 8/8 定向：普通 addi255、32 bit 退出、课程栈、RAM 末行、字节扩展、8 个冷 Load、同组脏逐出、错路退出取消；BTB hit 强制为 0 的负向在 cycle 287 检出，陈旧二进制负向被拒绝。 |
| 同基线课程 25 镜像 | 逐拍＋独立 ISA 25/25：total 14,827,154、core 14,826,804、退休 7,303,489；真实课程 Slave 输出 25/25，含 boot 总周期 14,827,179。软件/RTL 源码摘要前后保持。 |
| 10-16 两路 CDB | 25/25 完整逐拍事件/退休核验，周期保持；报告在父工作区 `build/cdb2-20261016/`。 |
| 10-17 四拍恢复及后续软件同步 | 四构建 25/25、各自对 RTL 的逐拍/ISA 通过；不含 boot 15,541,955 拍、退休 7,303,489。定向覆盖 20 组模块用例及恢复期间 Load 返回，详见[实验记录](experiments.md#recovery4)。 |
| 10-17 D$ 局部地址 | 25/25 输出及逐例周期保持；8,106 拍/828 请求旧 RTL 对照、60,000 拍字节 oracle 通过。 |
| 10-18 面积收敛 | 最新 LSU 轮 24/24 单元回归、0 skip（189.7 s）；`byte_overlap` 6,192 例穷举＋1,000,000 例随机无差异。不将此前完整课程逐拍证据视为本轮重跑。 |

10-16 基线当时未完成技术映射/STA，额外 `check -assert` 曾因 3 GiB 地址空间上限 `std::bad_alloc` 退出；这不是后续综合仍未完成的结论。已完成的分阶段综合统一见 [assessment-results.md](assessment-results.md)。

10-16 小报告在 `build/course-sync-register-20261016/`，后续工件见对应实验/PPA 节。`build/` 未纳入 Git，`/tmp/opencode/` 工件重启可能丢失；摘要不能替代可执行工件。
