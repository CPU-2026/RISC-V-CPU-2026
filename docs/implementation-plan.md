# 实现记录与当前边界

本文件记录保留的 RV32IM 乱序核设计。其所有源码已整理到 `verilog/rtl/`，并由
`verilog/filelist.f` 统一列出。旧的回归脚本、旧测试镜像和旧 testbench 已移除；
课程框架提供的 `testcases/` 子模块是当前唯一保留的测试输入。

## 已实现的微架构

1. 公共类型、RV32IM 解码和整数执行单元
2. PRF 空闲位图、RAT（`arch` 基线加 ROB 窗口重放）、ROB 和有界保留站
3. 加载/存储队列、字节精确转发和 ready/valid 存储器接口
4. 前端队列及 Tournament、BTB、RAS、SARAS 预测器
5. 单宽度重命名、多功能单元发射、四条完成通道、顺序提交和分支恢复
6. I$/D$，包括脏行写回和 HALT 排空

数据通路使用手写 CLA 加法器。预测器包含 localPHT、globalPHT、selector（各
256x2 bit）、推测 GHR8、BTB64、RAS8、SARAS16、condSeen512、32 项 fetch
checkpoint、16 项 RAS journal 和三源 BTB 仲裁。BTB 的物理条目为 56 bit：
`{tag[23:0], target[29:0], state[1:0]}`，索引为 `PC[7:2]`。

## 当前接口状态

现有顶层是 `cpu_top`（无缓存的指令/数据 ready-valid 接口）和
`cpu_cached_top`（128-bit 缓存行接口）。它们使用低有效复位和带外 HALT 指令，
尚未提供课程框架要求的 `student_top`、AXI4-Lite、MMIO 退出存储或
`sram_fakeram` 实例。因此，在完成适配前，官方的 `make build`、`make test`、
`make perf` 和 `make synth` 不能用于本实现。

## 后续工作

1. 添加 AXI4-Lite `student_top` 适配层并转换复位与退出协议。
2. 将片上缓存存储替换为框架支持的 `sram_fakeram` 接口。
3. 在官方框架下恢复正确性、IPC、面积和时序验证。
