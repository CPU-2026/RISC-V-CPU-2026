# 文档导航

当前用法、历史决策与详细分析分开维护；同一组数据只保留一个主要出处。

| 想了解什么 | 文档 |
|---|---|
| 当前架构、流水约定与编译参数 | [architecture.md](architecture.md) |
| 验证范围、测试入口、计时及综合方法 | [assessment.md](assessment.md) |
| 参数控制实验及敏感度 | [参数敏感度分析.md](参数敏感度分析.md) |
| 架构探索与取舍 | [架构探索总结.md](架构探索总结.md) |
| 400 MHz 时序瓶颈与历史路径分析 | [频率分析.md](频率分析.md) |
| 阶段、采用/否决及证据清理边界 | [history.md](history.md) |

以下保留原始文档，其中`axi4-lite.md`仅按授权调整3处导航链接，正文不改：

- [template.md](template.md)：课程使用、构建与提交。
- [sram.md](sram.md)：公共 SRAM 模型与时序。
- [axi4-lite.md](axi4-lite.md)：总线、外部从机与退出协议。

生产身份以[正式指针](../../sync/evidence/current-production.json)为准；指标集中在[频率分析](频率分析.md)，不在导航页重复维护。

同级`sync/`、软件模拟器和历史工件不保证随本仓库克隆提供。旧实验工作集已清理，路径仅作来源记录，不表示原始证据仍可重审。
