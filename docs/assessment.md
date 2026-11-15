# 验证与综合评估

本文集中维护验证范围、入口、计时和工具方法。当前配置见[架构说明](architecture.md)，生产采用见[历史记录](history.md)，完整PPA/路径数据见[频率分析](频率分析.md)。命令是用法说明，本次整理未执行测试或综合。

## 目标与比较口径

- 当前研究目标为400MHz/2.5ns、面积严格<36000μm²、原六几何IPC严格>1.1，并要求其他主要路径组不退化；覆盖或匿名FF对应不足标待审，不能用主组收益抵消。
- 早期300MHz、IPC>1.0985和`IPC⁴×Fmax/Area²`为历史阶段口径；后续记录`Fmax²×IPC/Area`。不同阶段评分不得混排，评分不能覆盖硬门槛。用户明确采用也不改写原技术拒绝。
- IPC为各程序退休数/课程周期，再取六项几何平均，非总指令/总周期或算术平均。`IPC×Fmax`只是吞吐估算，非墙钟实测。
- 比较绑定同源码、配置、转换、工具/库、驱动/负载及结束协议；不拼接不同快照的IPC与PPA。局部面积/延迟不能相加为整核结果。

## 验证范围与测试入口

当前反向信用版完成9437184全表示cut、真实queue+planner FW2/FW4独立列表与原gold全部公开输出含invalid差分、四变异六有效运行时反例；converted整核原六完整日志/374104条架构退休及周期保持。两软件126项构建输入不变，采用时新Release/断言四构建、两个外部副本各374104退休PC/周期对照通过。见[采用证书](../../sync/evidence/frequency400-queue-backward-production-adoption-20261112-r01/adoption.json)。采用复用精确同源RTL资格及PPA，不重复重建模型或综合。

| 程序 | median | multiply | vvadd | towers | qsort | rsort |
|---|---:|---:|---:|---:|---:|---:|
| 课程周期 | 8341 | 13119 | 3101 | 5531 | 162354 | 162410 |
| 架构退休数 | 6961 | 21722 | 4524 | 5278 | 139900 | 195719 |

后续动态策略仅converted，可保留严格native静态lint；11月7日参数实验的native/sv2v双模型资格仍按当时事实保留，不倒改为converted-only。有限原六通过不等于完整25课程、全部LINK/定向测试、异常支持、任意参数或全状态形式等价。

在硬件仓库根运行：

```bash
make test MAX_CYCLES=100000000
make perf MAX_CYCLES=100000000
python3 -B -m unittest discover -s scripts/tests -v
```

构建/提交见[template.md](template.md)。宽度专项为`scripts/check_{issue_width,decode_width,rename_width,dual_commit}.py`。软件对拍还需C++20及同级软件模拟器；旧`check_course_sync.py`/`check_axi_sync.py`须先核配置和接口，`check_dcache_sync.py`依赖已移除的DMEM接口，不能直接作为活动验收。

历史参数验证入口位于**工作区根**，不是硬件仓库根：

```bash
python3 -B sync/check_independent_parameters_20261107.py \
  --out .cpu2026-synthesis/independent-parameters-validation-new --phase all
```

可分`lint|cache|local|full`；原入口使用当时双模型策略及旧默认，不能不经审阅直接当当前验收器。原有限8配置96次加六配置72次的完整结果、局部边界与桥接说明集中在[参数分析](参数敏感度分析.md#parameter-validation)。旧工件已缺失，需要重建的阶段不能伪称可直接复用；不覆盖旧输出目录。

## 计时与事件边界

- 退出Store退休后冻结核心，已提交SQ/Cache/AXI继续排空，到**对应B握手**结束；不扫描全部dirty行。
- 课程周期包含初始化、核心执行、退出排空；sim还包含复位释放后的独立boot一拍。旧软件活动total不包含该拍，不能与core或课程周期混比。
- 事件按真实valid/ready/grant核对，不把proposal、队列满或投机计数当实际接受/退休，也不平移逐拍事件凑周期。
- 局部oracle、整核原六、软件同步、native/converted及形式证明分别记范围，互不替代。

## 综合入口与约束

在硬件仓库根运行，需要课程工具包和sv2v；可用`SV2V`显式指定前端：

```bash
make synth MODE=opt CLOCK_PERIOD_NS=2.5 SYNTH_OUT="../.cpu2026-synthesis/<新任务>/synthesis"
make synth MODE=diagnose SYNTH_OUT="../.cpu2026-synthesis/<新诊断任务>/synthesis"
```

- 默认时钟仍2.0ns，400MHz目标须显式传2.5ns；目标周期不代表已经达标。
- 评估`verilog/filelist.f`完整`student_top`，含core/Cache/AXI/MMIO主机，**不含外部Slave**。`opt`展平用于整核PPA；`diagnose`保层次定位，父子inclusive面积不能相加或按比例套到opt。
- `scripts/assess.py --scope core/cached/dcache`仅为诊断：core适配器显式单取指且未完整观察四lane退休，cached使用旧HALT且不排空，不能替代课程整核。
- 采用ASAP7 RVT TT＋FakeRAM，理想时钟、无互连寄生；生产ABC驱动INVx1/负载5fF，STA输出5fF，I/O预算各0.2ns，不确定度及transition各0.05ns。历史BUFx2/1fF流程须另标，不能作纯RTL收益比较。
- 实际`-noautowire`及优化前`check -assert`和完整日志门禁通过后才继续；generic过门禁才ABC，mapped过门禁才STA。不关闭UNOPTFLAT/LATCH/未知warning，也不用无协议依据的false path/multicycle掩盖违例。

### SRAM先读与-defer

`scripts/synth.py`先读空SRAM接口再读CPU输入，两者加`-defer`，推迟到`hierarchy -top student_top`按实际参数生成RTLIL；RAM仍用`-noblackbox -D SYNTHESIS`。native Yosys和sv2v输入路径均采用该顺序，后续`proc`、`memory_collect`、`synth -noabc`、DFF映射、ABC/STA及宏成本模型不因本方法改变。

11月10日用户采用的是**前端读取方法**。隔离展开1493.324032→933.802430秒，56模块按显式对象/位映射逐边核验；完整新make共2280.181435秒，其中展开917.959082秒（−38.529143%），综合+ABC1258.465386秒（+6.199744%），STA80.938200秒（+24.794114%）。同源面积32233.321739→32154.137759μm²，Fmax323.922499→316.110361MHz，2.5ns slack退76.352ps。

因此前端更快不等于整轮同比例更快，更不等于RTL提频或PPA不变。旧整轮中断接续，没有严格可比的连续总墙钟；单样本不能给稳定统计加速比，嵌套profile计时也不能直接相加。历史来源为工作区`.cpu2026-synthesis/production-deferred-opt-20261110-r02/`及`frontend-mapping-review-20261110-r04/`，旧工件已不可直接重审。

### 统计JSON与时间戳

Yosys `-t`会使`tee ... stat -json`带日志时间戳，但`write_json`网表不受影响，不应对两者套相同清理规则：

```text
[01679.974975] {
[01679.975244]    "creator": "Yosys ...",
```

- `stat.raw.json`保留原始带时间戳文本；`stat.json`为严格解析后的纯JSON，供面积汇总。
- 普通JSON直接解析；带时间戳格式仅移除每个非空行开头完整`[数字.数字] `前缀，不改字符串内部内容。混合前缀、warning、截断、额外文本和损坏JSON仍拒绝，原始统计不回写。
- `profile.json/txt`分别记录统计读取/清理和写出墙钟；保留原始/纯净统计与完整工具日志。
- 历史`sync/resume_synth_json_timestamp_20261110.py`曾在冻结SHA和日志认证后，只复用同次mapped/design/RAM补统计与未完成STA，不重跑展开/ABC。这是一次限定接续，不是当前仍可用的检查点，也不重新认证功能/IPC。

## 产物与只读诊断

产物位于`SYNTH_OUT/MODE/`：`report.json/txt`、`area.json`、`timing.json/rpt`、`constraints.sdc`、`abc.constr`、`ram/manifest.json`及阶段profile。未指定时默认`build/synth/`；新实验统一放F盘`.cpu2026-synthesis/`，进程临时目录由工作区`sync/experiment_storage.py`配置。`make clean`会删除构建、配置的综合输出及`code`，不要用于清理需保留证据。

以下需替换为**实际仍存在**的同次工件；只读分析不启动新综合：

```bash
python3 scripts/assessment_paths.py <已有任务>/synthesis/opt --all-paths
python3 scripts/module_area.py <已有任务>/synthesis/diagnose/report.json --flat-report <已有任务>/synthesis/opt/report.json
```

关键路径须由同次mapped逐pin认证，generic仅辅助结构定位，不能当逐门STA或可敏化证明。`--reuse-elaboration`/`--reuse-pre-abc`及`--elaborated-json`/`--pre-abc-json`仅在来源、源码/转换、工具/库与约束认证且任务授权允许时使用，不混用快照。旧工作集已清理，不能凭历史路径宣称可接续；详见[证据边界](history.md#清理与证据边界)。
