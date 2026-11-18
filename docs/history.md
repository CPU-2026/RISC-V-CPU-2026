# 项目历史

## 版本沿革

| 日期 | 主要变化 |
|---|---|
| 2026-11-07 | 放开 16 B 边界的四指令取指；完成 14 组有限配置的[参数实验](参数敏感度分析.md)。 |
| 2026-11-12 | ROB16、PRF48、8 KiB D$ 基线保留完整写回包，加入双队列反向信用。 |
| 2026-11-16～17 | Load/StoreAddr 采用选择性晚唤醒，Branch 禁用 Load 同拍旁路；Load 改为独占一路 CDB。 |
| 2026-11-18 | LSU 调度摘要 H 替换版本 B，不保留 B 的 D$ 树形选路；S 在 H 上前移 SQ 扫描，400 MHz 下无 setup 违例。 |
| 2026-11-18 | W8 把每拍恢复槽数由 4 增至 8，原六周期下降，但未通过 400 MHz。 |
| 2026-11-18 | 采用 W8 上的八路 RAS 组合重放；原六周期不变，估计 Fmax 超过 400 MHz。 |

A2、R6 各自从 W8 测量，均降频；未采用，也未叠加。独立 postmap、LSU 返回寄存边界、D$ tag 快照和 PRF 并行排名仍未采用。

## 发布记录

- 硬件 [`0c9ba970ac4e`](https://github.com/CPU-2026/RISC-V-CPU-2026/commit/0c9ba970ac4ed233e52c1bbe2e06c29f0ffb8c24) 相对 W8 只换入实测的 [`rv32_bpu_ras.sv`](../verilog/rtl/predictor/rv32_bpu_ras.sv)，未合入远端分叉的两个提交。
- 软件主树 `403071cd0868`、模板 `a9b409ff6406` 已与该版本同步。见[原六验证](assessment.md#验证范围与测试入口)与[整核时序](频率分析.md)。
- 工作区证据：`sync/evidence/current-production.json`；`.cpu2026-synthesis/w8-ras-depth-rails-production-adoption-20261118-r01/adoption.json`。

## 清理与证据边界

逐项实验、采用与否决依据保存在[原提交的历史记录](https://github.com/CPU-2026/RISC-V-CPU-2026/blob/0c9ba970ac4ed233e52c1bbe2e06c29f0ffb8c24/docs/history.md)。工作区的 `sync/` 和实验产物不随硬件仓库克隆提供；已清理的日志、网表和检查点不能凭历史摘要重审或接续。
