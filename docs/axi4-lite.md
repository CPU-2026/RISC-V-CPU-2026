# AXI4-Lite 协议与内存约定

课程顶层：[`student_top.sv`](../verilog/rtl/student_top.sv)；外部从机：[`scripts/sim.cpp`](../scripts/sim.cpp)。内部主机队列与退出控制见 [course.md](course.md)。

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
