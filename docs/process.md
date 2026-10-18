# 架构探索过程（2026 年八月底至 10 月 18 日）

主线：先在周期级 C++ 模拟器探索，再迁移到 SystemVerilog，接入课程 AXI，并按物理成本收敛。本文只保留决策；参数/IPC 数表见 [experiments.md](experiments.md)，PPA 见 [assessment-results.md](assessment-results.md)，验收见 [course.md](course.md)。

## 记录来源

- 8～9 月：同级 `RV32IM_Simulator/` 的 Git 历史，不是本硬件仓库的提交历史。
- 9 月 23 日起：本仓库提交及阶段文档；迁移后 commit 时间集中在 10 月 14 日，按 author date 和阶段记录排序。
- 10 月细分实验：本目录及同级 `sync/README.md`、`CPU-SYNC-SPEC.md`。后续工作含未提交改动，不虚构提交号；同级目录与 `build/` 工件不随克隆提供。

## 8～9 月：建立硬件式周期模型

| 阶段 | 决策与依据 |
|---|---|
| 8-26 | TAGE、取指预译码训练 RAS（`a2c61f3`）；已有 I$、LQ/SQ、RAT/PRF/ROB 及恢复。 |
| 8-30～31 | 迁移 `Register/Wire/work()/sync()`（`03828f0`），读拍初、写拍末；统一 epoch＋slot 完整 ROB tag（`3f17f30`）。周期漂移按实际错误修复，不接受隐含软件执行顺序旁路。 |
| 9-01～03 | 引入 64 KiB/4 路/16 B 行写回 D$（`8b20648`）、改 PLRU（`76da3c4`）；I$ 冷缺失为主，未升级两路。 |
| 9-05～13 | ALU/Load 独立双 CDB（`cbc6a0e`）、Booth/CSA 流水乘法（`a11c47f`）、SRT radix-4 除法及第四 CDB（`b2cb0d8`）。并行执行/写回不等于多发射。 |
| 9-18～23 | 收紧循环和身份宽度，支持非二次幂编码；PRF 收至 48、checkpoint 收至 32（`3ef79f9`）。 |
| 9-20～23 | TAGE→Tournament（`3e13e55`），删除当时语料无收益的间接 Target Cache（`8db1ed7`），GHR16→8、压缩 BTB 对齐位（`3ef56bf`、`e310f2f`）；不推广为任意负载均无收益。 |
| 同期 | 退役 MDP Load 违例恢复：未知更老 Store 阻塞准入；伪 SARAS 改为提交/投机 RAS，后续恢复重放完整栈。建立 RTL 计划（`feb764a`、`59243da`）；多发射至今仍是目标。 |

## 10 月上旬：落实三端逐拍合同

软件主树、模板树与 RTL 比较握手、身份、写回和退休，而非只比最终结果：

- epoch 队列可用满，FQ/IQ 与返回允许消费同拍补入；PRF FIFO 分配/回收，旧结果须完整 tag 认证。
- ALU 单槽消费同拍重填、AGU 登记地址/身份、MUL 三级弹性、DIV 取消与准入统一；坚持写回拍捕获、下拍依赖派发。
- LQ 退休才释放，SQ 已提交项内存接受才释放；转发统一为单源完整覆盖，不拼多源字节。
- 训练运输真实 taken，RAS 双 link 先 pop 后 push；BTB 分槽仲裁、Flush Arbiter 选择最老恢复。

10-10～11 旧 18 ISA＋6 IPC 完成三端逐拍与最终内存核验（`fdaddea`），但不含课程 AXI。当时 D$ 为贴合软件时序使用寄存器，HALT 后扫描 dirty 排空；该边界不能与后续 MMIO 周期拼接。

## 10 月中旬：从容量代理转向物理测量

| 阶段 | 取舍 |
|---|---|
| 10-11～12 | RS 共 23→12 槽、FQ/IQ 4→2、RAS32→16；软件容量代理下降，但综合暴露寄存器 D$ 占面积约 64% 及全局 flush 高扇出。转向 SRAM 和恢复/选择网络优化。 |
| 10-13～14 | SRAM D$（`d7c98ef`）；valid 独立复位，删除初始化扫描及释放网络；RAS 深度收紧，early restart 提高 IPC，但合并物理吞吐仍不胜仅 RAS 版。建立互斥模块面积归属。 |
| 10-14 | ABC 驱动/负载、buffering/cell sizing（`302f0cf`）属于流程改进，不能将跨流程频率差归因于微架构。 |
| 10-14～15 | 固定 4 KiB 扫描九种行长/相联度；32 B 单路候选改善密度，不是已证明全局最优。固定整行延迟模型未体现课程 AXI 串行带宽成本。 |
| 10-16 BTB | 单 SRAM→4-bank tag/target 分离，需新增预测汇合、训练 FIFO/credit、取消逻辑；面积收益抵不过旧负载 IPC 损失，课程路径恢复寄存器 BTB，保留两模块独立实验。 |
| 10-16 数据侧 | D$ 改 4 MSHR/两路，支持合并、hit-under-miss、乱序返回；LSU 用独立 owner/持久 drop，不用有序 FIFO 猜归属。中间 4 请求/owner 后扩为 8。 |
| 10-16 课程集成 | 接 AXIFetch/AXIData/AXIBus；退出 Store 退休冻结核心，对应 B 握手结束，不再全 dirty 排空。后续 ALU 独占 CDB0、MUL/DIV/LQ 共用 CDB1。 |
| 10-17 | AXIData 共享 payload/游标及三模块收敛减少面积；提交 RAT/RAS 改 SRAM＋四拍恢复，以 IPC 损失换面积。D$ 局部 SRAM 地址消除原地址广播瓶颈。 |
| 10-18 | 收敛 D$ 提取/ROB 重放窗口、AXI 容量和 LSU 扩展/重叠逻辑；PPA 与测试只对各自快照有效，最新结果不等于已达到课程 IPC 或 2 ns 目标。 |

**保留的原则**：输出正确不等于周期正确；软件对象大小不等于 ASIC 面积；IPC、频率和面积须在同边界实测，不能相加独立收益或用旧快照替代当前验收。
