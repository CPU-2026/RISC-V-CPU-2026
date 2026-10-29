# 课程框架、使用与评分

本页保留课程要求及工程操作入口，不描述当前微架构。当前配置见 [architecture.md](architecture.md)，本工程验证边界见 [course.md](course.md)。

## 环境

宿主需要Python 3.10+、GNU Make、支持C++17的G++、binutils。初始化`testcases/`子模块：

```bash
git submodule update --init --recursive
chmod +x cpu2026-tools-x86_64.AppImage
```

Linux x86-64/WSL2默认使用根目录AppImage，含Verilator/Yosys/ABC/OpenSTA/ASAP7；Make不自动下载/重建工具包。当前SystemVerilog综合还需要另装`sv2v`。

可选Docker：`docker build -t cpu2026 .`，再`docker run --rm -it -v "$PWD":/work cpu2026 bash`；基础镜像不含sv2v。原生工具覆盖在根目录 [`config.mk`](../config.mk)，命令行优先。

| 配置组 | 变量与默认值 |
|---|---|
| 工具包 | `APPIMAGE=$(FRAMEWORK_DIR)/cpu2026-tools-x86_64.AppImage`，设空禁用。 |
| 宿主工具 | `PYTHON=python3`、`CXX=g++`、`AR=ar`、`BUILD_MAKE=make`。 |
| 原生工具覆盖 | `VERILATOR`、`YOSYS`、`ABC`、`STA`、`SV2V`、`ASAP7_LIB`；库目录须含五份ASAP7 lib。 |
| 输入/输出 | `FILELIST=verilog/filelist.f`、`BUILD=build`、`SYNTH_OUT=$(BUILD)/synth`。 |
| 运行 | `JOBS=4`、`MAX_CYCLES=1000000`、`LATENCY=10`；可选`Case`、`SIM`、`WAVE`、`LOG`。 |
| 综合 | `MODE=opt`、`CLOCK_PERIOD_NS=2.0`、`ABC_DRIVING_CELL=INVx1_ASAP7_75t_R`、`ABC_LOAD_FF=5.0`。 |

## 构建与运行

```bash
make help
make build JOBS=4
make test MAX_CYCLES=100000000
make test Case=correctness_add_to_100
make perf MAX_CYCLES=100000000
make perf Case=perf_median
make run PROGRAM=testcases/correctness_add_to_100/program.data EXPECTED=5050 WAVE=trace.vcd LOG=run.log
```

默认模拟器为`build/sim`；`SIM=/path/to/sim`只在本地run/test/perf跳过编译。波形可用Surfer/GTKWave查看。`make`/`make code`编译RTL并生成OJ入口`./code`。

```bash
make synth MODE=opt CLOCK_PERIOD_NS=2.0
make synth MODE=diagnose
```

综合范围、sv2v转换、检查点、opt/diagnose区别和输出文件统一见 [assessment.md](assessment.md)。`make clean`删除BUILD/SYNTH_OUT/code，先备份其中历史报告。

## 架构与交付要求

- RV32I整数及完整M扩展：MUL/MULH/MULHSU/MULHU、DIV/DIVU/REM/REMU；LB/LBU/LH/LHU/LW、SB/SH/SW。课程只要求自然对齐数据访存，不要求CSR、FENCE/FENCE.I、ECALL/EBREAK。
- 就绪指令可乱序执行、按程序顺序退休；发射宽度、ROB、PRF、RS和Cache容量/相联度应支持参数探索。
- 顶层名`student_top`、源码以相对`verilog/`路径列入`verilog/filelist.f`。端口、5拍高有效reset、外部RAM、退出写及B握手规则见 [axi4-lite.md](axi4-lite.md)。
- 片上RAM使用公共`sram_fakeram`，面积计入总面积，参数/时序见 [sram.md](sram.md)。课程Slave不综合入CPU，不修改评测条件来使设计通过。
- 两人一组，报告包含参数敏感度、架构探索和权衡；中期第7周，最终第14周周六23:59。允许AI辅助，Code Review检查设计理解与LLM交互记录。

## 课程评分

正确性：向量乘法、向量加法、0到100累加累计75分，其余正确性程序累计85分；未过前阶段不能获得后一阶段分数，退出值须匹配标准答案。

性能面积为标准单元＋全部FakeRAM；IPC为官方六个`perf_*`动态指令数/课程运行周期的几何平均。

| 阶段 | 最大面积μm² | 最低几何IPC | 最低频率MHz | 累计分数 |
|---|---:|---:|---:|---:|
| 1 | 9,000 | 0.6000 | 300 | 90 |
| 2 | 18,000 | 0.8450 | 300 | 95 |
| 3 | 36,000 | 1.0985 | 300 | 100 |

满足同档全部条件后，400MHz加2分、500MHz加4分。本工程历史搜索评分函数与上述课程分数不同，不能用raw score替代门槛通过。
