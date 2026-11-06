# 编译配置：宽度、容量与 I$ 相联度

本页集中维护配置规则。独立ROB/PRF、I$相联度及checkpoint扩展属于生产采用后的工作树修改：只做有限仿真验证，不进行综合／ABC／STA，不修改正式指针或两软件，旧PPA不自动覆盖。默认架构见 [architecture.md](architecture.md)，已认证范围见 [course.md](course.md)。

## 宽度与队列

| 编译宏 | 默认值／约束 |
|---|---|
| `CPU_FETCH_WIDTH`／`CPU_DECODE_WIDTH`／`CPU_ISSUE_WIDTH`／`CPU_COMMIT_WIDTH` | 默认均4，支持1/2/4；四取指要求四译码／分配 |
| `CPU_RENAME_WIDTH` | `CPU_ISSUE_WIDTH`的旧兼容别名；同时定义须相等 |
| `CPU_ALU_UNITS`／`CPU_ALU_CDB_PORTS` | 默认均2，支持1/2；独立双ALU CDB要求issue4 |
| `CPU_FQ_ENTRIES`／`CPU_IQ_ENTRIES` | 默认各为译码宽度的两倍，默认四宽各8项 |

`CPU_ISSUE_WIDTH`表示顺序重命名／分配，不是所有执行单元的派发口数。切换窄配置须同步选择匹配的取指／译码／分配／提交及ALU/CDB宏。

## 编译入口

ROB/PRF参与`rv32_pkg`公共tag、数组及恢复类型定义，**同次编译的全部RTL必须统一传递宏**，不能只覆盖某个实例。完整ROB tag为`clog2(ROB_ENTRIES)+1` bit。

| 宏 | 未指定时 | 有效配置约束 |
|---|---|---|
| `CPU_ROB_ENTRIES` | issue4 为32，issue1/2 为16 | 2的幂，至少16项，覆盖分配及提交宽度 |
| `CPU_PRF_ENTRIES` | issue4 为64，issue1/2 为48 | 至少 `32 + ROB_ENTRIES`；允许48、80、96等非2幂大小 |
| `CPU_BPU_CKPT_ENTRIES` | 根据 ROB、取指信用、FQ/IQ 向上取2的幂 | 至少覆盖上述总活跃预算，且为2的幂 |
| `CPU_ICACHE_SETS` | 16 | 至少2且为2的幂，表示**每路组数** |
| `CPU_ICACHE_WAYS` | 1 | 1、2、4 |

扩ROB时应显式选择足够大的PRF，二者不会互相强制改变。checkpoint预算为`ROB + 取指字信用 + FQ + IQ`，默认`32+8+8+8=56≤64`；自动扩大不改变预测或训练算法。标准窄配置默认ROB16/PRF48/checkpoint32，默认四宽仍32/64/64。

例如四宽、ROB64、PRF96、1 KiB 四路 I$：

```text
-DCPU_FETCH_WIDTH=4 -DCPU_DECODE_WIDTH=4
-DCPU_ISSUE_WIDTH=4 -DCPU_COMMIT_WIDTH=4
-DCPU_ALU_UNITS=2 -DCPU_ALU_CDB_PORTS=2
-DCPU_ROB_ENTRIES=64 -DCPU_PRF_ENTRIES=96
-DCPU_ICACHE_SETS=4 -DCPU_ICACHE_WAYS=4
```

相应checkpoint自动为128项。

I$ 的 `SETS`/`WAYS` 还通过 `student_top.ICACHE_SETS`/`ICACHE_WAYS` 向下传递，允许工具支持时用顶层参数覆盖。ROB/PRF 则使用编译宏而非顶层 `-G` 参数，以保证公共类型一致。

## I$ 行为

- 容量 = `SETS × WAYS × 64 B`。16组1路、8组2路、4组4路均为1 KiB；只增加路数而不减少组数也会增加容量。
- 每路真实同步单端口 SRAM；命中读取时保存对应 way。没有用寄存器数据副本替代 SRAM。
- 最低编号无效路优先；满组后2路使用 MRU 反向替换，4路使用3位树 PLRU（不是精确 LRU）。
- tag、valid、CFI 预译码 mask 按路保存；fill 发布同一路元数据。保持最早 CFI 截断、冷 miss 单取、跨16B但不跨64B行、单预测、逐条 PC/CID 语义。
- 保留请求顺序、背压、冻结、flush、取消后迟到响应拒绝及同线实际接受回填旁路。逻辑 flush 不清缓存，reset 清 valid。
- 公共 SRAM 在禁用沿不保证保留 `rdata`。冻结期间若有尚未捕获的同步命中读，继续刷新该请求的原组地址及原 way；不因新 PC 或冻结而丢数据，不新增数据副本，也不授权新请求或回填。

## 无综合验证

主入口为工作区`sync/check_independent_parameters_20261107.py`；已有中断／修复接续使用`sync/resume_independent_parameters_20261107.py`，独立raw审计使用`sync/audit_independent_parameters_20261107.py`。这些路径及下列命令均相对**CPU-2026工作区根**，不是硬件仓库根；所有生成源码、转换、模型和日志写入F盘`.cpu2026-synthesis/`。

```bash
python3 -B sync/check_independent_parameters_20261107.py \
  --out .cpu2026-synthesis/independent-parameters-validation-new --phase all
```

也可用 `--phase lint|cache|local|full` 分阶段。每个输出目录不可覆盖，失败日志保留。

- 8项整核组合：默认；四宽 ROB16/PRF48、ROB32/PRF96、ROB64/PRF96；同容量2/4路 I$；一宽 ROB32/PRF80/2路 I$；二宽 ROB64/PRF96/4路 I$。
- I$ 18项局部组合：取指1/2/4 × 相联度1/2/4 × 组数4/16；公开端口独立数据、CFI、命中及替换 oracle，包含同步读跨路连续请求、实际回填同线旁路、边界、背压、冻结、flush和reset。
- ROB列表／旧信用／完整身份及恢复窗口oracle；PRF全寄存器值／ready及抽象free FIFO oracle；checkpoint64/128的全部行上下文、GHR、冻结、squash及CID回绕。夹具位于`scripts/tests/parameterized_{icache,prf,checkpoint}_tb.sv`。
- 无效参数拒绝与有效 RTL 变异负向测试；native 和 sv2v 模型交叉检查；整核原六答案及九字段架构退休日志对照当前基线。非默认配置允许周期改变，默认配置要求原六周期保持。

以上为验证范围说明，**不是全部通过声明**，也不是任意参数全覆盖、形式等价或两软件同步资格。实际结果以各输出根的报告／`finalization.json`及独立raw审计为准；旧失败与证书保留，本次整理不重跑验证。
