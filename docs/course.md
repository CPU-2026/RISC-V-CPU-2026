# 验证范围

构建/运行/提交见 [template.md](template.md)，当前硬件见 [architecture.md](architecture.md)。本页记录已有结果，文档整理未重跑硬件测试。

## 当前状态（2026-10-29）

- 默认4/4/4/4、双ALU三CDB、单AGU、8 KiB D$，native lint无LATCH/UNOPTFLAT。
- 默认课程入口六perf原答案通过，按外部退出完成周期计的几何IPC为 **0.858427672694**。
- 原隔离候选六perf通过独立退休ISA、退出值及退休数检查，core周期IPC为0.859877973781；与课程计时边界不同，不能直接比较退化/收益。原报告/二进制已不可用，不能把摘要当原件。
- 当前默认未完成完整25课程/定向/LINK、sv2v整核全量重验；旧配置验收不能继承，既有恢复专项失败/夹具限制未因六perf通过消除。
- 最终面积/Fmax缺失，正式PPA暂停，不能宣称性能资格通过。

来源：[采用凭据](../../sync/evidence/superscalar4-production-adoption-20261029-r01/adoption.json)，新验证报告SHA-256为`6d01c60c1b0696bf600a7ab1a42e0b15a7672aa9021ad29eb03e9da45d63772e`。同级`sync/`及未跟踪工件不随克隆提供，历史里程碑见 [process.md](process.md)。

## 验证入口与计时

```bash
make test MAX_CYCLES=100000000
make perf MAX_CYCLES=100000000
python3 -B -m unittest discover -s scripts/tests -v
```

宽度专项：`scripts/check_issue_width.py`、`check_decode_width.py`、`check_rename_width.py`、`check_dual_commit.py`。软件对拍另需C++20和同级模拟器；旧`check_course_sync.py/check_axi_sync.py`须先核对配置/接口，`check_dcache_sync.py`仍依赖已移除的软件DMEM接口，不能作为活动通过记录。

退出Store退休冻结核心、已提交SQ/Cache/AXI继续至对应B握手，不扫描dirty；复位释放后有独立boot一拍，课程sim计入、旧软件活动total不计入。逐拍比较不得平移事件凑周期。模块/整核、原生/转换、ISA正确/逐拍等价必须分开记录。
