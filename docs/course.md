# 课程说明与当前 RTL 验证

当前实现基准：2026-10-16。课程顶层为 [`student_top.sv`](../verilog/rtl/student_top.sv)，
源码清单为 [`filelist.f`](../verilog/filelist.f)。以下为已有验证记录，本文整理未重跑测试。

## 环境与常用命令

宿主需要 Python 3.10+、GNU Make、G++（C++17）与 binutils；软件对拍驱动需要 C++20。
Linux x86-64 / WSL2 默认使用根目录课程 AppImage，另需可用的 `sv2v` 处理本工程 SystemVerilog。

```bash
git submodule update --init --recursive
chmod +x cpu2026-tools-x86_64.AppImage
make help
make build JOBS=4
make test MAX_CYCLES=100000000
make perf MAX_CYCLES=100000000
make test Case=correctness_add_to_100
make run PROGRAM=testcases/correctness_add_to_100/program.data EXPECTED=5050 WAVE=trace.vcd LOG=run.log
make synth MODE=opt CLOCK_PERIOD_NS=2.0
```

`make` / `make code` 总是编译 RTL 并生成 OJ 入口 `./code`；`SIM=/path/to/sim` 仅供本地 run/test/perf 跳过编译。
`make clean` 删除 `BUILD`、`SYNTH_OUT` 和 `code`，包括这些目录内保存的历史报告。

配置写入根目录 [`config.mk`](../config.mk)，命令行覆盖优先：

| 配置组 | 变量与默认值 |
|---|---|
| 工具包 | `APPIMAGE=cpu2026-tools-x86_64.AppImage`；设空禁用 |
| 原生工具覆盖 | `VERILATOR`、`YOSYS`、`SV2V`、`ABC`、`STA`、`ASAP7_LIB` |
| 宿主工具 | `PYTHON=python3`、`CXX=g++`、`AR=ar`、`BUILD_MAKE=make` |
| 输入/输出 | `FILELIST=verilog/filelist.f`、`TESTCASES=testcases`、`BUILD=build`、`SYNTH_OUT=$(BUILD)/synth` |
| 运行 | `JOBS=4`、`MAX_CYCLES=1000000`、`LATENCY=10`；可选 `Case`、`SIM`、`WAVE`、`LOG` |
| 综合 | `MODE=opt`、`CLOCK_PERIOD_NS=2.0`、`ABC_DRIVING_CELL=INVx1_ASAP7_75t_R`、`ABC_LOAD_FF=5.0` |

综合范围、模式差异、产物和恢复方法统一见 [assessment.md](assessment.md)。
也可使用根目录 Dockerfile：`docker build -t cpu2026 .`，然后
`docker run --rm -it -v "$PWD":/work cpu2026 bash`；该基础镜像未提供 `sv2v`，使用当前 RTL 综合前需另行安装/指定。
`packaging/appimage/` 仅用于重建工具包，见其 [说明](../packaging/appimage/README.md)。

## 活动路径

```text
core（寄存器BTB） → I$ → AXIFetch ─┐
                → D$ → AXIData  ──┴→ AXIBus → student_top AXI4-Lite
```

容量统一见 [package.md](package.md)，预测路径见 [frontend.md](frontend.md)，请求/MSHR 与 SRAM 仲裁见 [cache.md](cache.md)。

## AXI主机

- AXIFetch/AXIData/AXIBus逐项对应软件`src/AXI/AXI.cpp`。
- AXIFetch独立16项行运输队列，每个I$行拆16次32bit读。
- AXIBus使用64项R归属FIFO；AR成功握手才入队，轮询仅在两源竞争且成功握手时翻转。
  AR背压锁定选择；恢复保留已断言的AR并排掉旧响应，不撤回VALID或改地址。
- AXIData读/写合计16条整行信用，不是各16。旧满不复用本拍释放，最后信用写优先。
  D$每行拆8次32bit操作，AW/W有独立进度；整行收齐R/B才向D$呈现带地址/MSHR身份的完成，
  并保持到Cache实际消费。不把首个B当成整行写完成。
- 外部Slave不综合进CPU；端口、背压规则、RAM与延迟见 [axi4-lite.md](axi4-lite.md)。

## 退出与复位

- 默认`0ff00513`为普通ADDI；旧镜像显式设置core/frontend/decoder的`LEGACY_HALT=1`。
- 向`0x80000000`的SW按序退休时冻结核心IPC，退休数包含该Store。
  核心/FQ/IQ/BPU/FU/LQ使用同步状态使能冻结，不产生门控时钟。
- 已提交SQ、D$、AXI继续推进。MMIO最老请求等待AXIData读写均空才进入独立完整32bit写，
  不查询/分配Cache行；外部Slave在对应`BVALID && BREADY`握手输出完整结果并结束。
  不全dirty写回，不以Store退休或AW/W握手冒充仿真结束。
- 复位清空内部队列/身份，Cache SRAM不清零、valid独立复位。
  释放后独立boot1拍。课程sim的cycles包含boot，而软件活动表total不含boot；
  对拍实际执行boot后再计数，不通过平移流水事件掩盖周期差。

## 验证入口

```bash
python3 -B scripts/build.py --verilator /usr/bin/verilator --out /tmp/opencode/course-rtl --jobs 2
python3 -B scripts/testcase.py --kind correctness --build /tmp/opencode/course-rtl --max-cycles 100000000
python3 -B scripts/testcase.py --kind perf --build /tmp/opencode/course-rtl --max-cycles 100000000
python3 -B scripts/check_course_sync.py --out /tmp/opencode/course-sync-register
python3 -B scripts/check_axi_sync.py
python3 -B scripts/check_course_smoke.py --build /tmp/opencode/course-sync-register
python3 -B -m unittest discover -s scripts/tests -p test_predictor_register.py -v
```

`check_course_sync.py`仅在外部副本的CPU头增加测试friend，不在生产恢复Probe/Tester。
同一实际软件CPU/Slave驱动实际课程DUT，比较有效AXI载荷、取指/预测/发射/恢复、ROB头尾、
GHR/checkpoint、四路写回、D$计划事件、退休结果与课程独立动态指令数；另以独立RV32IM解释器
逐条核验退休PC、寄存器值和Store载荷，最后比较完整退出结果。
这不是全部内部数组逐bit等价、任意异常域证明或门级等价。
`--skip-build`核对源码摘要，拒绝陈旧二进制；验证前后软件/RTL源码摘要必须一致。

`check_axi_sync.py`用实际软件三模块与RTL逐拍对拍，独立背压AR/AW/W、延后R/B、
保持行回复、满16条信用和恢复遇到未握手AR；额外检查VALID/载荷背压稳定。

## 当前验证记录

| 门禁 | 结果 |
|---|---|
| 原生Verilator默认lint（无warning抑制） | 通过；课程`-Wall`构建仍报告空输出口/未用信号等诊断，不称全`-Wall`零警告 |
| sv2v完整课程顶层转换＋Yosys层级检查 | 通过；活动层级无SRAM BTB，不是技术映射/STA或门级等价 |
| 单元/转换回归 | 18/18通过，包含两种保留SRAM BTB的独立参考及转换测试 |
| 寄存器预测器专项 | 组合查询、直接训练、接受才更新GHR/checkpoint、冻结/恢复通过 |
| AXI真实软件模块逐拍 | 20,000拍通过；11,426次读接受/返回、3,802拍AW/W独立背压、7,795拍AR保持、300次恢复、17,343拍共享16行满信用、1次完整MMIO |
| 真实CPU定向例＋独立ISA | 8/8逐拍通过：普通addi255、完整32bit退出、课程栈、RAM末行、字节符号扩展、8个冷Load、同组脏逐出、错路退出取消 |
| 实际源码负向 | 仅外部副本将寄存器BTB hit强制为0，cycle287检出预测PC错值（RTL96/软件80）；生产摘要保持。陈旧二进制摘要负向也被拒绝 |
| 课程25镜像逐拍＋独立ISA | 25/25通过；total14,827,154拍、core14,826,804拍、退休7,303,489条，逐项与软件一致；软件/RTL源码摘要前后保持 |
| 课程`sim.cpp`真实外部Slave | 25/25完整32bit结果通过；含boot总周期14,827,179，每例恰为软件total＋实际boot1拍；当前源码与逐拍报告摘要一致 |

本版本未完成技术综合/STA；旧数据侧/BTB面积和频率不能套用。额外Yosys进程降级已执行，
但随后`check -assert`在3 GiB地址空间硬上限下以`std::bad_alloc`退出，不能记为通过；
这不替代已通过的sv2v转换/层级检查，也不是已完成映射或时序签核。

已完成的小报告归档于`build/course-sync-register-20261016/`；大型构建在`/tmp/opencode/`，
重启后临时构建可能丢失，不能将摘要当成原始可执行工件。

## 课程要求与评分

- 支持 RV32I 整数与 M 扩展，包括全部整数 Load/Store；访存自然对齐。不要求 CSR、FENCE/FENCE.I、ECALL/EBREAK。
- 乱序执行、按序提交；微架构应支持参数化探索。当前实现是单宽取指/发射/提交，并非已完成多发射。
- 两人一组提交报告，包含参数敏感度分析、架构探索及权衡；中期第 7 周，最终第 14 周周六 23:59。
- 允许 AI 辅助，Code Review 会检查设计理解、权衡与 LLM 交互记录。

正确性基础程序（向量乘法、向量加法、0 到 100 累加）累计 75 分，其余正确性程序累计 85 分；未通过前一阶段不能获得后一阶段分数。
性能 IPC 为官方 `testcases/perf_*` 动态指令数/运行周期的几何平均，不能替换成历史 HALT 镜像 IPC。

| 性能阶段 | 最大总面积 μm² | 最低几何 IPC | 最低频率 MHz | 累计分数 |
|---|---:|---:|---:|---:|
| 1 | 9,000 | 0.6000 | 300 | 90 |
| 2 | 18,000 | 0.8450 | 300 | 95 |
| 3 | 36,000 | 1.0985 | 300 | 100 |

满足某档全部门槛后，400 MHz 加 2 分、500 MHz 加 4 分。面积包含标准单元与全部 FakeRAM。
OJ 提交前确认所有 RTL 都以相对路径列入 filelist，顶层端口符合课程要求。

架构演进及未完成路线见 [process.md](process.md)。
