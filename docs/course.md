# 验证范围与入口

## 当前ROB16／PRF48生产资格

新默认4/4/4/4、ROB16／PRF48、checkpoint64／恢复4槽。硬件默认lint／常量检查及与显式配置的预处理token精确桥接通过；复用已认证原六native／sv2v答案、各374104条九字段退休及同配置周期。两软件全新Release／断言四构建与两外部退休副本资格通过（各374104条PC／周期）；仅两个容量头变化，用户PRF编译修复保留。周期8341／13119／3101／5531／162354／162410。

新配置未综合，无面积／Fmax／评分；不是全输入或全状态形式证明。证书：[采用](../../sync/evidence/rob16-prf48-production-adoption-20261107-r02/adoption.json)、[收口](../../sync/evidence/rob16-prf48-production-adoption-20261107-r02/finalization.json)。以下旧资格保持历史归属。

本页区分已认证结果与可运行入口；**本次文档整理未重跑测试**。构建／提交细节见 [template.md](template.md)，架构见 [architecture.md](architecture.md)。

## 前一ROB32／PRF64采用版本的历史资格

| 层次 | 已完成的资格 |
|---|---|
| 前端局部 | native／sv2v：真实frontend/FQ/IQ/decoder/checkpoint的768包oracle，真实ICache/SRAM的275项检查，6个有效RTL负向。 |
| 整核RTL | 原六perf答案、退休数、374104条九字段架构退休匹配基线；同候选native／converted完整日志一致。 |
| 两软件同步 | 全新Release／断言四构建，原六答案、退休及init+core+drain匹配；两个外部副本各374104条退休PC／周期匹配RTL。 |
| 发布收口 | 精确源码、PPA复用、备份、正式指针及发布后复验通过；不是另建生产路径RTL模型。 |

原六为median、multiply、vvadd、towers、qsort、rsort；周期对照统一见 [process.md](process.md#四取指边界对照)。来源：[筛选最终证书](../../sync/evidence/fetch4-cross16-screen-20261107-r01/finalization.json)、[采用最终收口](../../sync/evidence/fetch4-cross16-production-adoption-20261107-r01/finalization.json)、[发布后复验](../../sync/evidence/fetch4-cross16-production-adoption-20261107-r01/post-completion-verification.json)。

**不能外推**：原六通过不代表完整25课程／全部定向与LINK重验、任意输入形式等价、全部异常支持或所有参数组合通过。10月29日旧四宽结果仅为历史，不能作为后续源码的验收。

## 工作树参数化验证

独立ROB/PRF、I$组数／相联度及checkpoint扩展的配置、组合和入口集中在[参数化配置](parameterized-configuration.md#无综合验证)。本次整理不宣布其新增资格通过；以各输出根的`finalization.json`及独立raw审计为准，不继承旧PPA或两软件资格。

## 常用入口

以下在硬件仓库根目录运行；运行命令不等于已有通过记录。

```bash
make test MAX_CYCLES=100000000
make perf MAX_CYCLES=100000000
python3 -B -m unittest discover -s scripts/tests -v
```

宽度专项：`scripts/check_issue_width.py`、`check_decode_width.py`、`check_rename_width.py`、`check_dual_commit.py`。对拍另需C++20和同级软件模拟器；旧`check_course_sync.py`／`check_axi_sync.py`须先核对配置与接口，`check_dcache_sync.py`依赖已移除的软件DMEM接口，不能直接当作活动验收。

## 计时与事件边界

- 退出Store退休后冻结核心，已提交SQ/Cache/AXI继续排空，到**对应B握手**结束；不扫描所有dirty行。
- 课程sim包含复位释放后的独立boot一拍；旧软件活动total不包含，不能混比core周期、活动周期与课程退出周期。
- 逐拍事件不得平移凑周期；模块／整核、native／转换、ISA正确／逐拍一致分别记录。
- 同级`sync/`、证书及实验工件不随本仓库克隆提供；历史缺失工件不以摘要冒充原件。
