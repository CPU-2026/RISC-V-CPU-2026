# 同步 SRAM：`sram_fakeram`

公共模型：[`scripts/ram/sram_fakeram.sv`](../scripts/ram/sram_fakeram.sv)，用于片上存储，独立于外部 AXI RAM。当前 Cache 阵列布局见 [cache.md](cache.md)，面积/时序口径见 [assessment.md](assessment.md)。

## 实例化

```systemverilog
sram_fakeram #(
    .DEPTH(1024), .WIDTH(32), .WRITE_GRANULARITY(8)
) data_ram (
    .clk(clock), .en(ram_en), .we(ram_we), .wmask(ram_wmask),
    .addr(ram_addr), .wdata(ram_wdata), .rdata(ram_rdata)
);
```

构建/综合脚本自动引入模型，**不要加入 filelist，也不要自行声明空桩**。`sram_fakeram`、`sram_fakeram_*`、`fakeram_asap7_*` 为框架保留名称。框架外仿真时直接将上述模型与设计一同编译，无需 Yosys/Liberty。

## 参数与端口

| 参数 | 默认值 | 约束 |
|---|---:|---|
| `DEPTH` | 256 | 1..1,048,576 字。 |
| `WIDTH` | 32 | 1..4,096 bit。 |
| `WRITE_GRANULARITY` | WIDTH | 1..WIDTH，且整除 WIDTH。 |

每实例 `DEPTH×WIDTH≤2²⁴ bit`（2 MiB）。

| 端口 | 方向 / 位宽 | 含义 |
|---|---|---|
| `clk` | 输入 / 1 | 上升沿。 |
| `en`、`we` | 输入 / 各 1 | en=1 时访问；we=0 读、we=1 写。 |
| `wmask` | 输入 / WIDTH÷WRITE_GRANULARITY | 高有效，低位对应低数据段。 |
| `addr` | 输入 / max(1, ceil(log₂DEPTH)) | **字索引**，非字节地址；使能时必须小于 DEPTH。 |
| `wdata` / `rdata` | 输入 / 输出，各 WIDTH | 写数据 / 同步读数据。 |

整字写默认一位 wmask；32 bit 字节写设粒度 8，四位 mask 分别控制 `[7:0]` 至 `[31:24]`。

## 时序

- 单端口 1RW，每拍只能读或写一次。
- 读沿采样 `en=1,we=0`，该沿后 rdata 有效并保持该周期；不是组合读。
- 写沿只更新 wmask 为 1 的段，其余保持；全零 mask 不修改内容。
- 写周期或 en=0 时 **rdata 未定义**，需要背压保持的回复必须另行锁存。
- 无复位端口、不保证初值为零。通过独立 valid 位屏蔽旧内容，或显式扫描初始化。
