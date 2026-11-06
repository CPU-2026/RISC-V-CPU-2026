# 文档导航

按问题查阅，避免在多份文档中重复维护状态。

| 想了解什么 | 文档 |
|---|---|
| 默认架构、流水与模块约定 | [architecture.md](architecture.md) |
| 宽度、ROB/PRF 容量、I$ 相联度 | [parameterized-configuration.md](parameterized-configuration.md) |
| 已验证范围、测试入口与周期边界 | [course.md](course.md) |
| PPA 指标、综合方法与比较口径 | [assessment.md](assessment.md) |
| 演进主线、采用与未采用结论 | [process.md](process.md) |
| 完整历史记录（按需追溯） | [process-history.md](process-history.md) |
| 原始阶段计划（历史） | [plan.md](plan.md) |

以下四份文档保持原样：

- [template.md](template.md)：课程使用、构建与提交。
- [sram.md](sram.md)：公共 SRAM 模型与时序。
- [axi4-lite.md](axi4-lite.md)：总线、外部从机与退出协议。
- [架构探索总结.md](架构探索总结.md)：按架构问题归纳的探索总结。

**状态边界（2026-11-07）**：正式采用版本为跨16B四取指；工作树另有独立容量及 I$ 相联度修改。生产身份以[正式指针](../../sync/evidence/current-production.json)为准，旧 PPA 不自动覆盖后续源码。`sync/`、两份软件模拟器及实验工件位于同级工作区，不随本硬件仓库克隆提供。本次仅整理文档，未运行硬件测试或综合。
