# AXI4-Lite 协议与内存约定

课程顶层：[`student_top.sv`](../verilog/rtl/student_top.sv)；外部从机：[`scripts/sim.cpp`](../scripts/sim.cpp)。退出冻结流程见 [course.md](course.md)，架构探索与关键测量见 [process.md](process.md)。

## 当前主机结构

| 模块 | 容量与完成规则 |
|---|---|
| AXIFetch | 4项独立行运输槽，每个64 B I$行拆16次32 bit读；占用计数及分配/issue/collect epoch游标推进。完整接收才向I$呈现，恢复取消逻辑请求并排空旧R，但保留已断言未握手的AR。数据侧和外部Slave容量不变。 |
| AXIData | 读写合计 8 条行信用，共享 8×32 B payload/描述符；每 D$ 行 8 次 32 bit 操作，MMIO 仅 1 次完整字写。epoch 游标推进 AR/R/AW/W/B，AW/W 独立；收齐全部 R/B 才向 D$ 呈现带地址/MSHR ID 的完成，并保持至实际消费再释放槽。 |
| AXIBus | 64 项 R 归属 FIFO，AR 成功握手才入队；两源竞争且成功接受才翻转轮询，AR 背压锁定选择。 |

AXIData 从旧空闲位图分配，同时一读一写不得别名；旧满不借用本拍释放，最后信用写优先。两个顺序环保留 16 行槽索引以适配 4 bit 序列索引，不表示 16 条信用。AR/AW 复用地址进度字段，MMIO 不改无效尾数据。

每槽提前比较完整行/MMIO完成位，读写队头用3位镜像寄存器缓存物理槽，切断顺序环→描述符的间接索引。空队列入队、最后一项出队同时入队时旁路新分配槽；最后一项仅出队时镜像下一旧环行，保持无效载荷语义。镜像须恒等于旧环队头，不增加完成流水级。

两适配器 payload 按32 bit字组织，不复位/分配清零，以完整接收资格屏蔽旧值；仍为寄存器。分阶段验证见 [course.md](course.md)，历史16信用测试不能当成当前容量配置。

## 顶层端口

32 bit、无 burst，AR/R/AW/W/B 五通道独立。方向相对 CPU：

| 通道 | CPU 输出 | CPU 输入 |
|---|---|---|
| AR：读地址 | `araddr[31:0]`、`arvalid` | `arready` |
| R：读数据 | `rready` | `rdata[31:0]`、`rresp[1:0]`、`rvalid` |
| AW：写地址 | `awaddr[31:0]`、`awvalid` | `awready` |
| W：写数据 | `wdata[31:0]`、`wstrb[3:0]`、`wvalid` | `wready` |
| B：写响应 | `bready` | `bresp[1:0]`、`bvalid` |

`clock/reset` 均为 CPU 输入；上升沿采样，reset 高有效、启动保持 5 拍，内部转换为低有效异步复位。课程未连接 `ARPROT/AWPROT`，可不声明或置零。

## 握手与事务

- 仅同一上升沿 `VALID && READY` 才传输。
- 发送方断言 VALID 后，握手前不得撤回，也不得改变地址、数据、WSTRB 等有效载荷；不能等 READY 才断言 VALID。接收方可以等待 VALID 再给 READY。
- 读事务先 AR 握手，再以 R 握手返回数据/状态。
- 写事务的 AW/W 可任意先后、同拍或隔拍握手，必须**分别记进度**；从机收齐二者后处理，以 B 握手完成。不能要求 AWVALID/WVALID 始终相同，也不能在仅一个通道接受后重发已接受部分。
- AR/AW 地址须 4 B 对齐；WSTRB 每位对应一个小端字节。

## 课程从机

| 项目 | 约定 |
|---|---|
| RAM | 小端 256 MiB，`0x00000000..0x0fffffff`；程序未覆盖区域初始为零。 |
| 通道队列 | AR/AW/W/R/B 各 16 项，非复位且接收 FIFO 未满时 ready=1。 |
| 服务 | 每拍最多启动一读、一写；接受请求的下一拍才可进入服务。 |
| 延迟 | 服务后 `due=cycle+latency` 返回，默认 10 拍；`--latency N` / `make run LATENCY=N` 可调。主机不能依赖固定值。 |
| 退出 | 向 `0x80000000` 全字写，`WSTRB=4'hf`；对应 B 握手捕获完整 32 bit 返回值并结束，与用例 expected 比较。 |

响应码：

| 值 | 含义 |
|---|---|
| `2'b00` OKAY | 正常响应。 |
| `2'b10` SLVERR | 地址非 4 B 对齐，或退出写的 WSTRB 非 `4'hf`。 |
| `2'b11` DECERR | 地址超出 RAM 且不是退出地址。 |
