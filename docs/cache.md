# RTL 缓存：公共容量 3A 与核外整行接口

当前SPEC §63/64：完整24镜像共同逻辑Memory下12667040拍三端全等，最终128KiB
独立byte核验。长回归直接观察真实Cache metadata/有效line存储，仅未变才复用
指纹，生产I$公共SRAM/D$寄存器及完成协议保持；课程AXI/STA另验，README §56。

当前SPEC §62：用户最终完成要求全部dirty写回，既有dmem_backend的WAIT_IDLE/
WRITEBACK/DONE与两软件生产协议同步。实际D$scan/wait流程、最后write ack、
128组/128KiB外存逐字节核验和DONE保持16拍通过；提前DONE或写接受当完成的
源码负向真实留下byte0x13/正确0x44。I$仍公共SRAM，D$仍寄存器；README §54。

当前SPEC §61：实际SRAM I$/IMEM及寄存器D$/DMEM与完整CPU恢复67程序9001/2872
严格三端一致，42次返回/新读同拍、迟到取消Load排空及已提交SQ保留通过。
没有因逻辑恢复绑定旧返回到新队首；物理AXI身份/最终drain计时另验，README §53。

当前SPEC §60：真实SRAM I$/IMEM驱动BTB竞争26程序6690/1848严格三端一致；
checkpoint必须覆盖ROB16/I$4/FQ4/IQ4预算28，联合64参数引脚测试通过。访存
4803/764及RTL16回归通过，第18全流水恢复继续，入口sync/README §52。

当前SPEC §59：真实CPU接公共SRAM I$/实际IMEM、BPU、执行/ROB/退休/恢复33程序
13041拍1848字段三端严格同值。用户双link pop-push与checkpoint一次取指一次CID
内容恢复通过，7实际功能负向有效；I$ data/寄存器tag保持，访存4803/764回归通过。
当前六IPC新691640、18 ISA保持11967396，README §51。

当前SPEC §58：I$ data使用用户指定`rtl/common/rv32_sram.sv::sram_fakeram`真实宏
接口，16×512bit/32bit写粒度；tag为16×22bit寄存器。软件形式I$/IMEM2324/160、
真实取指至decoded IQ前端2259/216四方严格全等，4＋3实际负向有效，标准RTL16项及
真实core/SRAM I$ Store/Load/branch/HALT通过。当前接口与命令见sync/README §50。

最新SPEC §56：实际D$接三端RS/AGU/LSQ/共享PRF/ROB至退休联合对拍，4803步28组
763语义字段一致，Cache/DRAM指纹和真实响应身份逐拍比较。并行脏冲突/重新读回、
47返回/下一读、恢复旧miss复用及四实际负向通过；正常末尾仅等已接受事务，额外
最终dirty flush仍另验。当前联合后端域已闭合，入口sync/README §48。

最新SPEC §55：用户确定D$寄存器实现，READY/WAIT直接映射软件，6378步14字段真实
三端DCache/DMEM与独立参考全等。命中接受+1响应、连续每拍接受；缺失并行读/脏写回，
等待写完成再回填。LSU旧响应/新读可同拍重填。默认展开核验65536时钟数据位、无SRAM；
全规模通用综合超时不作为通过证据。core真Cache4、标准RTL14及LSU/四路/生命周期通过。
下方§54及更早SRAM D$记录仅为历史，当前合同和命令见sync/README §47。

最新SPEC §54：LSU未知支配规则对齐软件，22个后端suite严格全等。允许完整SQ来源
支配更老未知写只影响转发；Cache准入仍保守阻塞未知地址或任何未提交重叠。真Cache
4组与drain/token实际负向保持正确，mixed287/partial195/恢复234/full370拍；DCache
FSM未改、完整三端Cache周期仍另验。入口sync/README §46。

最新SPEC §53：LSU已采用(A)单源完整覆盖，部分覆盖不再合并Cache返回，等待相关
Store接受后再读取。真Cache四组功能/全行/最终内存与drain/token负向通过；mixed
280→287拍、partial175→195拍、恢复234/full370保持。DCache自身命中/缺失FSM未改，
不能把单源化写成对原拼接RTL全场景性能提高。完整三端Cache周期仍待验，README §45。

2026-10-09（SPEC §50）：真实core→LSU→DCache同步SRAM→64B行内存四组整链
已验收。新增rv32_dmem_backend管理末尾事务与脏行drain，LSU读解释token冻结。
部分字节转发合并、脏逐出/回取、真实恢复迟到/槽复用、满SQ及HALT后最终内存
通过；现有Cache命中/缺失FSM周期未因本轮改变，不宣称已三端逐周期等价。

2026-10-05：容量以共同父目录 `CPU-SYNC-SPEC.md` 为准。核外主存延迟不在 RTL 内固定为
20 拍；请求 ready/响应 valid 由环境提供。`rv32_core` 的32位处理器端口与 Cache 512位
行端口分开；课程 `student_top` 尚未封装，原 cpu_top/cpu_cached_top 已删除。

```text
frontend → I$：16组 × 1路 × 64 B = 1 KiB → 512-bit 整行读
LSU      → D$：128组 × 1路 × 64 B = 8 KiB → 512-bit 整行读/写
```

## 公共几何与 SRAM

`rv32_pkg` 定义 CACHE_LINE_BYTES=64、CACHE_LINE_BITS=512、ICACHE_SETS=16、
DCACHE_SETS=128、DCACHE_WAYS=1。地址 offset=6 bit，I$/D$ index=4/7 bit、tag=22/19 bit。
CPU 数据仍为32位，store strobe 为4位；整行请求/响应携带512位数据并64 B对齐。

I$数据阵列实例化公共sram_fakeram，DEPTH=16、WIDTH=512、WRITE_GRANULARITY=32，
整行回填写掩码全1，1RW同步读写；tag/valid在寄存器阵列。D$为
128×512bit寄存器bank，组合读取、时钟沿写入，共享字节使能译码，复位清元数据而
不清数据。两种存储结构当前已由用户分别确定，各自按软件服务边界实现。

## ICache

`rv32_icache`为1 KiB直接映射，REQUEST_DEPTH=4。四个有序请求槽保存PC、预测PC、
checkpoint、单指令结果及ready；真实返回消费释放槽，满时消费/分配可同拍替换。

- CPU请求`valid/address/predictedProgramCounter/predictorCheckpointId`，按ready
  接受；响应保留同一上下文，`cpuRspReadyInput`为真正消费资格。
- 旧tag组合hit，接受沿发SRAM同步读，下一拍旧队首身份匹配时旁路；受阻或年轻读
  结果拍末保存到原请求槽。禁用/写周期rdata无效，保存后的单指令用于保持返回。
- 每个旧态cold miss发一个64B行请求；相同行多个已接受miss分别占软件IMEM事务，
  不能通过串行化把四次miss改成一次。
- 返回`icache_line_response_input_t`包含valid/address/512bit data；仅匹配最老
  同行未ready槽且非待完成SRAM读时接受，并反馈`memRspReadyOutput`。
- 接受回填沿写整行/寄存器tag并完成一个旧miss；同拍新请求同行可按自己的
  `PC[5:2]`直接取fill bus，不另读SRAM/不发IMEM。回填写优先，异行hit停收一拍。
- 软件请求准入同时检查旧IMEM容量；同行已接受回填供数可旁路此门，不给一般
  IMEM满时返回消费添加准入旁路。
- `flushInput`清逻辑请求/read身份并保留Cache，通过`memFlushOutput`取消配套逻辑
  IMEM队列。物理总线适配器维护已接受运输身份并丢弃取消返回，之后再提供活返回。
- core的`imemCacheRequestOutput`可直接接CPU请求；Cache ready接core请求ready，
  Cache响应valid/instruction接core返回，core的rspReady/flush分别接消费与恢复。

## DCache

`rv32_dcache` 默认 SETS=128、WAYS=1，写回+写分配。way运输位宽至少1位，避免零宽
端口；直接映射固定way0，无需依靠PLRU选择。保留可选WAYS=4实现。

正常CPU请求在READY接受，组合探测旧寄存器；Load命中拍末寄存、下一拍响应，
Store命中拍末按字节更新并置dirty，状态保持READY，允许连续请求。
缺失保存完整请求/victim，WAIT_FILL中独立读写通道同时登记，按各自ready接受。
读先返回可暂存，等待写完成后回填，按原Store掩码合并或返回Load。外存延迟由环境提供。

Store不产生读响应，CPU仅在READY且未flush时可接收；当前正常Cache/DMEM模块域
已和两软件逐拍验收，额外外部背压及最终flush为RTL独立功能域。

flushInput阻止新请求，FLUSH_SCAN读旧寄存器并登记写回，FLUSH_WAIT等待写完成再
清dirty/推进，全部完成后flushDoneOutput=1。idleOutput表示READY且无待发/在途行命令。

## `rv32_dmem_backend`：处理器接口和最终排空

模块接口为clk/rstN、cpuRequestInput/cpuReqReadyOutput/cpuResponseOutput、
memRequestOutput、memReadReadyInput/memWriteReadyInput/memWriteDoneInput、memResponseInput
及drainInput/drainDoneOutput。
CPU/line类型和数据宽度与rv32_dcache一致，内部实际实例化DCache，不是另一个缓存模型。
core.haltedOutput表示HALT和SQ接受排空，接backend.drainInput；系统最终停止应看
drainDoneOutput。RUN收到drain停止新CPU接受，WAIT_IDLE等已接受Cache事务完成及
读响应交付，WRITEBACK持续flush，全部脏行写完成后DONE保持直到复位。课程总线
适配器应分别提供接受与写完成事件，不能在尚未完成时以接受冒充完成。

## 已验证

公共 `python3 sync/run_capacity.py` 包含：I$四项总预算、顺序响应、1 KiB冲突回填；
D$8 KiB冲突逐出、512位高lane、行尾子字掩码、脏写回/重新读取及flush。
容量测试不比较核外Memory实现，也不宣称整核软硬件逐拍等价。

`python3 -B sync/run_cached_rtl_chain.py`独立比较退休/CPU写接受、每个64字节
写回及最终64KiB内存，检查命中接受+1和缺失按独立读返回/写完成算出的最早fill拍，
并验证两个通道独立背压保持。四正常整链与三个实际负向通过，不含I$/AXI课程封装；见README §47。
