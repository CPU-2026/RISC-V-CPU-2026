# 实现计划

正确性与可综合性是每个里程碑的硬性门槛。

1. 公共类型、RV32IM 解码、执行单元
2. PRF/空闲位图、RAT（`arch` 基线 + ROB 窗口重放）、ROB、有界保留站
3. 加载/存储队列（字节精确转发）、ready/valid 存储器接口
4. 前端队列与 Tournament + BTB/RAS/SARAS 预测器
5. 单宽度重命名、多 FU 发射、四条完成通道、顺序提交、分支恢复
6. ISA 边界与资源压力定向汇编测试
7. 提交跟踪差分测试（ISA 参考与所附 C++ 模拟器）
8. 缓存集成、预测器保真度、Yosys 综合、时序/面积优化

## 当前状态

- 里程碑 1-6 已完成，并有全核正确性与 IPC 回归覆盖
- 缓存已集成，含脏行写回与 HALT 排空
- 数据通路使用手写 CLA 加法器系列；预测器为 Tournament
  （localPHT/globalPHT/selector 各 256x2b + 推测 GHR8、BTB64、RAS8、
  SARAS16、condSeen512），具备 32 项 fetch checkpoint、16 项 RAS journal、
  三源 BTB 仲裁（line 与 target 两组）与 squash 恢复
- BTB 已落到 **56 bit 物理条目**（`{tag[23:0], target[29:0], state[1:0]}`，
  索引 `PC[7:2]`），具备三源写口仲裁
- `make area`、`make area-modules` 与 `make area-bpu` 提供标准单元面积报告
- 三层回归已建立：`make basic`、`make advanced`（18/18）和 `make ipc`；所有
  x10 比较均为完整 32 bit
- IPC testbench 已提供动态 mix、互斥 no-issue 分类、DIV/load-store 事件和
  `+CF_TRACE=1` 的 fetch/execute/commit 控制流 trace
- memory-RS 拆分经 profile 否决：共享 RS/LQ 分别为 0 个 no-issue cycle，SQ 为
  74，而 frontend 为 421398；保留现有结构
- 待办：提交跟踪差分自动化、时序/面积优化

## 已知限制

- ASAP7 flow 目前只能给出标准单元面积。NLDM timing tables 与可信 SDC/OpenSTA
  约束尚未接入，因此不报告频率或 `IPC x frequency`。
- I$ 仍是单 outstanding 的串行 miss 路径；本轮没有改动 I$ 或前端 RTL。
