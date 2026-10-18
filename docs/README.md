# 文档索引

按主题只维护一份完整说明；历史实验不代表当前 RTL，数值须匹配源码摘要及评估边界。

| 主题 | 文档 | 内容边界 |
|---|---|---|
| 课程原始规范 | [template.md](template.md) | 环境、配置、命令、评分与提交；保留原文 |
| 实现计划 | [plan.md](plan.md) | 原始目标与周计划；保留原文，其中“现状”是计划制定时的快照 |
| 工程使用与验证 | [course.md](course.md) | 本工程补充、退出控制、验证入口及分阶段证据 |
| 参数与公共类型 | [package.md](package.md) | 当前容量、身份宽度、跨模块载荷 |
| 前端与预测 | [frontend.md](frontend.md) | 取指、译码、BTB、方向预测、RAS |
| 后端与执行 | [backend.md](backend.md) | 重命名、两路 CDB、执行、四拍恢复 |
| 访存队列 | [memory.md](memory.md) | AGU、LSU、转发、消歧、迟到返回 |
| 缓存 | [cache.md](cache.md) | SRAM 布局、请求信用、MSHR、回填与行接口 |
| 外部总线 | [axi4-lite.md](axi4-lite.md) | AXI 主机结构、端口、握手与课程从机 |
| SRAM 模型 | [sram.md](sram.md) | `sram_fakeram` 参数、端口与同步时序 |
| 评估方法 | [assessment.md](assessment.md) | 综合范围、运行、产物、诊断及 STA 口径 |
| 测量结果 | [assessment-results.md](assessment-results.md) | 分快照 PPA、路径、报告位置 |
| 实验对照 | [experiments.md](experiments.md) | 容量、Cache、SRAM BTB、四拍恢复的功能与 IPC |
| 决策脉络 | [process.md](process.md) | 演进时间线与取舍，不重复完整数表 |

`_archive/` 仅保存补充历史明细，不作为当前配置或验收结论。
