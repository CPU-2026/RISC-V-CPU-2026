# 过程记录归档（整理前原文）

本页完整保留本次整理前的 `process.md`，仅供追溯；其中“当前”“执行中”等措辞均属于原记录时点。最新阅读入口见 [文档导航](README.md)，演进摘要见 [process.md](process.md)。原文中的相对链接保持原路径，证书及原始工件未改写。

---

## 当前状态索引（更新至2026-11-07，优先于历史阶段叙述）

当前生产已采用**跨16B四取指**，默认fetch/decode/rename/commit为 **4/4/4/4**；两软件同步及发布后复验完成，不是仍待采用的实验版。

| 当前认证指标 | 数值 | 相对上一双取指生产 |
|---|---:|---:|
| 面积 | 34947.061567 μm² | +0.713718% |
| Fmax估计 | 319.301528 MHz | +0.997817% |
| 原六项几何IPC | 1.137201912621 | +6.947322% |
| 评分 `IPC^4 / Area^2 × Fmax` | 4.372501753378e-7 | +30.260993% |

面积严格<36000、Fmax>300、几何IPC>1.0985三项目标均通过；面积余量约1052.938433 μm²。IPC×Fmax估算+8.014461%，**不是墙钟实测**；Fmax为同理想时钟／无寄生约束的整核STA估计，**不是后布局频率**。原六中qsort多614拍（IPC−0.414616%），其余五项改善，不称逐项无退化。

权威入口为[正式生产指针](../../sync/evidence/current-production.json)，本次发布后的指针SHA256为`0037724c518a01e3ea42c397587cda7a4231665eec448ea896a1971a089a2718`。完整过程见下文“11 月 7 日：跨16B四取指的三方案对照、PPA与生产采用”，以及[采用证书](../../sync/evidence/fetch4-cross16-production-adoption-20261107-r01/adoption.json)、[最终收口](../../sync/evidence/fetch4-cross16-production-adoption-20261107-r01/finalization.json)和[发布后复验](../../sync/evidence/fetch4-cross16-production-adoption-20261107-r01/post-completion-verification.json)。

本次仅整理本文件；不修改RTL、两软件、生产指针或历史证书，不重跑模型、仿真或综合。历史记录中的“当前生产”“未采用”“执行中”归属各自时点；发布时的文档哈希也保持原证书归属，不因后续文档更新回写。全部综合／ABC／STA继续暂停，未提交／推送，不自动继续实验、组合或清理。

## 2026-11-07：正式采用跨16B四取指（优先于以下历史）

用户“采纳生产”，在已审计`fetch4-cross16-ppa-20261107-r01`及两软件资格通过后正式发布。面积34947.061567 μm²（+0.713718%），Fmax估计319.301528 MHz（+0.997817%），六项几何IPC1.137201912621（+6.947322%），评分4.372501753378e-07（+30.260993%）。面积<36000、Fmax>300、IPC>1.0985三项均通过；IPC×Fmax估算+8.014461%，非墙钟实测，频率为同理想时钟／无寄生STA估计、非后布局结果。
默认fetch/decode/rename/commit为4/4/4/4，双ALU／三CDB保持。只替换pkg／frontend／ICache三RTL：任意字位置连续最多4条、允许跨16B但不跨64B行、最早CFI截断、cold单条、单预测及逐条PC／CID不变。两请求包槽／派生8条指令信用，FQ8／IQ8／ROB32／PRF64／checkpoint64／I$1KiB保持，四取指仍采用保守恢复冻结，不加入双取指专属恢复扩展；LSU已采用通知提前计算／SQ完成旁路／SQ4-owner0仲裁／Load预取／标准RAS、Cache／AXI／Slave及其他容量执行宽度保持。
两软件默认宽度头与取包几何共4项构建输入变化、122项保持。主树只读旧快照/Input逐字段写目标，模板Register单写／统一sync保持；所有状态writer／预测及训练不改，无模块next-state复制或生产观察探针。全新Release／断言四构建原六答案／退休／init+core+drain及两外部副本各374104条退休PC／周期匹配。周期7620/12379/3740/5477/148089/159739；qsort相对双取指多614拍，其他五项改善。限定原六资格，不是全状态／全输入形式等价。
44RTL／公共SRAM／converted与已审计候选精确同源，复用本次已认证全新整核综合／ABC／STA及native／converted筛选，不重新综合或冒称另建生产路径RTL模型。发布前备份三RTL／四软件／文档／旧指针，旧黄金／镜像／Slave／既有code及三树HEAD索引保持；历史证书不回写。采用证书`sync/evidence/fetch4-cross16-production-adoption-20261107-r01/adoption.json`，正式指针`sync/evidence/current-production.json`；软件说明`docs/hardware-baseline-fetch4-cross16.md`。
单候选授权完成，全部综合／ABC／STA继续暂停，未提交／推送；不自动继续实验、组合、综合或清理，无额外面积专项，不算完整新优化轮。

## 2026-11-06：正式采用LSU通知资格提前计算（优先于以下历史）

用户明确“采用”，在已审计整核PPA及本次两软件资格通过后发布`lsu-notify-precompute-ppa-20261106-r01`。面积34699.405687 μm²（+0.679820%），Fmax316.146959 MHz（+3.056499%），六项几何IPC1.063329023912（不变），评分3.356723806268e-07（+1.669462%）。面积增234.300600 μm²，面积<36000／Fmax>300通过，长期IPC>1.0985仍未达。IPC×Fmax估算+3.056499%，非墙钟实测；同理想时钟无寄生STA估计，不是后布局频率。
只替换`rtl/memory/rv32_lsu.sv`的返回通知优先级组合拓扑：旧LQ×SQ常数行先计算同START同WIDTH／年龄及年轻未知地址或同word屏障，晚到SV／返回身份仅选一位。notify函数／完整事件身份与flush、Load地址事件最终覆盖、全部SQ／LQ状态写入／完整转发／SQ完成旁路／owner取消／SQ4-owner0仲裁／Load预取／标准RAS及容量宽度和Slave保持。不组合ROB候选，不恢复已否决方案。
两软件126项构建输入全部保持，无需算法改写；主树旧快照/Input逐字段写目标、模板Register单写／统一sync纪律不变，不恢复生产观察探针。全新Release／断言四构建原六答案／退休／init+core+drain及两外部副本各374104条退休PC／周期匹配。周期7676/16908/3984/5509/147475/162806全部保持，独立软件raw审计通过；限定原六资格，不是全状态／全输入形式等价。
44RTL／公共SRAM／converted与已测候选精确同源，复用其已审计整核综合／ABC／STA及native／converted局部619252组任意旧态／真实LSU差分／六有效负向和原六完整日志，本次无新综合或生产路径RTL模型重建。发布前备份一RTL／文档／旧指针，旧黄金／镜像／Slave／既有code和三树HEAD索引保持，旧证书不回写。采用证书`sync/evidence/lsu-notify-precompute-production-adoption-20261106-r01/adoption.json`，正式指针`sync/evidence/current-production.json`；软件说明`docs/hardware-baseline-lsu-notify-precompute.md`。
单候选授权完成，全部综合／ABC／STA继续暂停，未提交／推送。不自动继续实验、组合、综合或清理，无额外面积专项，不算完整新优化轮。

## 2026-11-06：正式采用旧SQ完成事件旁路（优先于以下历史）

用户“采纳当前的SQ完成旁路”后明确“综合”，在本次新整核PPA独立审计、面积<36000／Fmax>300及两软件资格通过后采用`store-completion-events-ppa-20261106-r01`。面积34465.105087 μm²（-0.432579%），Fmax306.770521 MHz（-2.127022%），六项几何IPC1.063329023912（+0.366506%），评分3.301604769298e-07（+0.180573%）。IPC×Fmax估算-1.768312%，非墙钟实测；长期IPC>1.0985仍未达。
仅一LSU完成bitmap：旧有效未提交SQ完整身份的真实地址／数据／非P0匹配WB可通知ROB寄存ready，退休仍读旧ready。SQ／LQ全部状态写入、实际Store退休／访存接受、Store→Load转发、owner／取消、SQ4-owner0仲裁、Cache预取、标准RAS、容量宽度和Slave保持，不恢复已否决地址→Load数据通知，不含三取指。
两软件各SQ组合查询／头文件与CPU接线共6项构建输入同步、120项保持，主树旧快照/Input逐字段写目标，模板Register单写／统一sync保持。只在完成锥读取完整WB，旧SV／LQ转发锥仍只读early-ALU；旧SV owner保存软件数据依赖身份，对应RTL SQ dataTag，不创建模块next-state或生产观察探针。全新Release／断言四构建原六答案／退休／init+core+drain与两外部副本各374104条退休PC／周期匹配。周期7676/16908/3984/5509/147475/162806，相对标准RAS−345/−85/+31/+32/+1105/+953，median IPC+4.494528%，整体+0.366506%，四项回退已披露。限定原六资格，不是全状态／全输入形式等价。
44RTL／公共SRAM／converted与已审计r02精确同源，本次从elaborate全新六checkpoint／整核opt／ABC／STA及独立逐叶面积／248原宏／工具约束／raw退休评分审计，不拼接旧PPA。复用筛选完整双模型资格，不冒称另建生产路径RTL模型。软件r01只因验证入口未导出路径ImportError停止，未构建；r02仅修导入，六源保持，原失败保留。发布前备份一RTL／六软件／文档／旧指针；旧黄金／镜像／Slave／既有code及三树HEAD索引保持，旧证书不回写。采用证书`sync/evidence/store-completion-events-production-adoption-20261106-r02/adoption.json`，正式指针`sync/evidence/current-production.json`；软件说明`docs/hardware-baseline-store-completion.md`。
单候选授权完成，全部综合／ABC／STA恢复暂停，未提交／推送。不自动继续实验、组合、综合或清理，无额外面积专项，不算完整新优化轮。

## 2026-11-06：正式采用标准同link JALR只push修正（优先于以下历史）

用户“替换生产并综合”，在本次新整核PPA独立审计、面积<36000及Fmax>300和两软件资格通过后采用`ras-same-link-ppa-20261106-r01`。面积34614.841687 μm²（+0.313261%），Fmax313.437404 MHz（-0.306091%），六项几何IPC1.059446088949（+1.509617%），评分3.295653702718e-07（+5.191507%）。IPC×Fmax估算+1.198905%，非墙钟实测；长期IPC>1.0985仍未达。
仅四RTL frontend／core／rename-plan／RAS分类：JALR pop=rs1Link && rd!=rs1、push=rdLink，x1/x5同link只push，异link保留pop后push。同步投机／BTB类型／标量双宽四宽ROB／真实退休／原始指令恢复，RAS容量8、满空与恢复节奏不变；不组合总线2∶1，不改SQ4／owner0仲裁、Cache／Slave／容量／宽度。
两软件各CPU／StaticArbiter共4项构建输入同步、122项保持，decoded hint沿既有退休／恢复路径；主树旧快照/Input逐字段写目标、模板Register单写／统一sync保持。精确复用r04已审计全新Release／断言四构建原六答案／退休／init+core+drain及两外部副本各374104条退休PC／周期资格，不重复构建、不冒称另建生产路径RTL模型。周期8021/16993/3953/5477/146370/161853；towers少372拍、multiply少413拍，qsort多1拍。局部双模型24576组合、真实RAS／SRAM及七有效RTL负向通过；原三夹具失败证据保持，限定原六资格而非全状态／全输入形式等价。
44RTL／公共SRAM／converted精确同源，本次从elaborate全新六checkpoint／整核opt／ABC／STA，独立Liberty逐叶面积／248原宏形状／工具库约束／raw退休评分审计通过，不拼接旧PPA。发布前备份四RTL／四软件／文档／旧指针；旧黄金／镜像／Slave／已有code和三树HEAD索引保持，旧证书不回写。证书`sync/evidence/ras-same-link-production-adoption-20261106-r01/adoption.json`，正式指针`sync/evidence/current-production.json`；软件说明`docs/hardware-baseline-ras-same-link.md`。
单候选授权已完成，全部综合／ABC／STA恢复暂停，未提交／推送。不自动继续实验、组合、综合或清理，无额外面积专项，不算完整新优化轮。

## 2026-11-06：正式采用SQ≤4／owner=0安全Load让行仲裁（优先于以下历史）

用户“采用SQ <=4 且owner = 0的并进行综合”，在新整核PPA及两软件资格通过后采用`lsu-sq4-owner0-ppa-20261106-r02`。面积34506.745567 μm²（+0.259469%），Fmax314.399754 MHz（+2.364139%），六项几何IPC1.043690365779（+0.759869%），评分3.133003593523e-07（+4.965701%）。IPC×Fmax估算+3.141972%，不是墙钟实测。面积<36000及Fmax>300通过，长期IPC>1.0985未达；rsort+2262拍，其他五项改善。
仅LSU＋core两RTL：旧态全部已分配SQ≤4且LSU运输owner=0时，原最老合法Load可越过全部字节不重叠的已提交／同拍真实退休普通RAM Store一次，随后强制真实Store接受；债务跨flush保持、两处SQ只认真实Store grant，恢复冻结／冲刷／退出不新增让行。不改Cache／Slave／容量／执行宽度／原转发，保留既有Load下一行预取。
两软件9项构建输入同步、117项保持；运输owner计数包括取消后的真实返回，Cache新增纯功能终结事件查询而非改变Cache算法或生产观察探针。主树旧快照/Input逐字段写目标，模板Register单写／统一sync，raw proposal-valid与实际接受分离保持。r01新增顶层标量被原纪律检查拒绝，r02模板SQ计数混用epoch尾指针与物理头槽导致周期漂移，两次失败保留；r03用旧有效行计数，未放宽检查。全新Release／断言四构建原六答案／374104条退休／init+core+drain及两外部副本退休PC周期匹配RTL；周期8022/17406/3953/5849/146369/161862。限定原六资格，不是完整状态／全输入形式等价。
44项RTL／公共SRAM／converted与已审计sq4-owner0精确同源，本次从elaborate全新六checkpoint／整核opt／ABC／STA及独立Liberty逐叶面积／248原宏形状／工具库约束／raw退休评分审计完成，不拼接旧PPA；原r01在ABC因服务器重启中断，五个checkpoint与失败产物保留；r02从elaborate全新重测，无checkpoint继承。r02完成后首审因来源标签变量遮蔽失败，旧失败保留；r03依据原五checkpoint路径与哈希重绑定来源，完整重审同一PPA，不重跑综合／ABC／STA。采用阶段复用r02新PPA与r03审计和已通过的软件r03资格，不重复软件构建，也不冒称另建生产路径RTL模型。备份／旧黄金／镜像／Slave／既有code及三树HEAD索引保持，旧证书不回写。采用证书`sync/evidence/lsu-sq4-owner0-production-adoption-20261106-r03/adoption.json`；正式指针`sync/evidence/current-production.json`；软件说明`docs/hardware-baseline-lsu-sq4-owner0.md`。
单候选授权已完成，全部综合／ABC／STA恢复暂停，未提交／推送；不自动继续实验／组合／综合或清理，无额外面积专项，不算完整新优化轮。

## 2026-11-05：正式采用Load触发下一行预取（优先于以下历史）

用户明确“采纳”，采用已审计`load-prefetch-ppa-20261105-r01`。面积34417.443067 μm²（+0.523014%），Fmax307.138572 MHz（-1.979604%），六项几何IPC1.035819497011（+2.458373%），评分2.984787940536e-07（+6.899400%）。IPC×Fmax估算+0.430103%，不是墙钟实测。面积<36000及Fmax>300通过，长期IPC>1.0985未达；towers+10拍，其他五项改善。
仅DCache＋backend两项RTL采用r02同源候选：真实接受普通RAM Load触发下一条32字节行，4项最近源行／单pending目标，最多一个typed内部预取，共享8请求／4MSHR／2bit ID。需求优先、入槽占用≤6／MSHR≤2；未占MSHR冲突可丢弃，已占MSHR保留脏victim／写回／回填所有权。全部CPU返回排除预取类型，不占LSU身份；退出接受后停止新预取。不改容量／宽度／BPU或Slave，不带已否决方案。
两软件10项构建输入同步，116项保持：DCache预取和CPU／MemArbiter原始proposal-valid接线；实际接受事件仍单独门控。主树只读旧快照/Input逐字段写目标，模板Register单写／统一sync保持，无模块下一状态复制或生产观察探针。全新Release／断言四构建原六答案／退休／init+core+drain匹配，两外部副本各374104条退休PC／周期匹配RTL；周期8025/17410/3971/5874/153886/159600。r01两软件rsort均少5拍被门禁拦住；外部状态见证定位满Cache时raw-valid被旧接受门控隐藏，r02仅修软件映射，旧失败／诊断保留，RTL／PPA不变。限定原六资格，不是完整状态或全输入形式等价。
44项RTL／公共SRAM及converted精确同源认证，复用已审计整核综合／ABC／STA和native／converted筛选，本次不新综合，也不冒称另建生产路径RTL模型。旧黄金／镜像／Slave／既有code和三树HEAD索引保持，历史证书不回写。采用证书`sync/evidence/load-prefetch-production-adoption-20261105-r02/adoption.json`，正式指针`sync/evidence/current-production.json`；软件说明`docs/hardware-baseline-load-prefetch.md`。
全部综合继续暂停，未提交／推送；不自动继续实验／组合／综合或清理，无额外面积专项，不算完整新优化轮。

## 2026-11-05：Load预取整核PPA完成，面积／频率通过，尚未采用

`load-prefetch-ppa-20261105-r01`完成用户授权的唯一一次全新整核opt综合／ABC／STA，独立Liberty逐叶面积／248原SRAM宏形状数量／工具／库／约束／六checkpoint／raw退休和评分审核通过。面积34417.44306697736 μm²（相对生产+0.5230142443%），Fmax307.13857228554286 MHz（−1.9796040792%），六项几何IPC1.0358194970105774（+2.4583730405%），评分2.9847879405359694e-07（+6.8994001670%）。IPC×Fmax估算+0.4301029084%，非墙钟实测。面积<36000及Fmax>300通过，长期IPC>1.0985仍未达。原六周期8025/17410/3971/5874/153886/159600，towers+10拍，其余五项改善，不能称逐项无退化。

44项RTL／公共SRAM／converted和原六双模型完整日志精确复用已审计r02，不重复已完成仿真，从elaborate新测无checkpoint继承，不拼接旧PPA。原248宏形状不变。r26追加认证指标并继承全部历史否决，不伪称已删原始产物恢复。收口再次核原始PPA产物、认证输入、保护／生产指针和三树HEAD索引通过。证书`sync/evidence/load-prefetch-ppa-20261105-r01/finalization.json`与同目录`post-completion-verification.json`，报告`sync/LOAD-PREFETCH-PPA-RESULTS-20261105.md`，说明`sync/LOAD-PREFETCH-PPA-20261105.md`。

单候选授权结束，全部综合／ABC／STA恢复暂停。生产RTL、两软件126项、Slave／正式指针保持，未采用／提交／推送；不自动启动新实验／组合／综合、采用或清理。无额外面积专项，不算完整新优化轮。以下保留执行阶段归属。

## 2026-11-05：用户授权Load预取候选一次全新整核PPA（历史执行阶段）

用户“开始综合”仅授权已审计`load-prefetch-screen-20261105-r02`同源候选一次新整核opt综合／ABC／STA及独立审计，不授权采用或其他候选／组合／清理。入口`sync/run_load_prefetch_ppa_20261105.py`，审计`sync/audit_load_prefetch_ppa_20261105.py`；工作根`.cpu2026-synthesis/load-prefetch-ppa-20261105-r01/`，服务`cpu2026-load-prefetch-ppa-20261105-r01`，说明`sync/LOAD-PREFETCH-PPA-20261105.md`。

复用已审计44项RTL／SRAM／converted与原六双模型完整日志及IPC，不重复仿真资格，不改候选／生产／两软件／Slave。周期8025/17410/3971/5874/153886/159600，几何IPC1.0358194970105774（+2.458373040548%，towers+10拍）。从elaborate新测、六阶段checkpoint，无旧checkpoint继承；同AppImage三工具／五库／248原宏／2ns／INVx1／5fF与理想时钟无寄生口径。独立Liberty逐叶面积／宏形状／约束／工具／checkpoint／raw退休及评分审核，收口保护指针／输入／三树HEAD索引；cleanup-aware指标追加不访问已删历史原始产物，继承全部否决决定。当前无新面积／Fmax／评分结论，最终看`sync/evidence/load-prefetch-ppa-20261105-r01/finalization.json`。单项结束全部综合恢复暂停，不自动采用、追加实验／组合／综合或清理；未提交／推送，无额外面积专项，不算完整新优化轮。

## 2026-11-05：Load触发下一行预取筛选通过，几何IPC+2.458373%，未综合／采用

用户“尝试load-based预取”授权一个隔离正确性／IPC候选。只改DCache和backend，实际接受普通RAM Load触发下一条32字节行，4项源行去重／单pending目标，最多一个显式typed内部预取，共享原8请求／4MSHR／2bit ID，无LSU假请求或新数据buffer。入槽请求占用≤6／MSHR≤2，miss分配前≥3则放弃；需求Tag和待发送miss优先。未占MSHR预取遇同set Store或同行miss可丢弃；占用MSHR后保留真实victim／脏写回／set锁及回填所有权，所有CPU返回路径排除预取，退出接受后停止新预取。

r01整核预检通过，局部夹具将响应valid与ready写在同组合块而触发UNOPTFLAT，运行前停止。r02仅把ready等式拆成连续赋值，不关闭诊断，44项RTL逐字节同r01，旧失败／脚本／模型保留。r02局部真实Cache／SRAM／行控制器双模型字节／不可变owner oracle、整行及寄存早字两环境和三个有效RTL负向通过；全新整核native／converted原六答案／374104条退休／九字段架构退休匹配生产，完整日志逐字节一致。独立raw周期／退休／答案、源码／夹具／负向／真实预取读握手及保护／正式指针／三树HEAD索引核验通过。

周期8025/17410/3971/5874/153886/159600，相对生产−580/−140/−14/+10/−1833/−8901。逐项IPC+7.227414/+0.804136/+0.352556/−0.170242/+1.191141/+5.577068%；六项几何IPC1.0358194970105774（+2.458373040548%），最弱median改善，towers小幅退化，不能称逐项无退化，长期IPC>1.0985仍未达。实际预取行读102/37/41/3/298/748，总行读154/55/153/16/797/4958（相对原总读+2/+2/+1/+3/+134/+62），脏写0/0/0/0/268/3026。入槽可命中驻留行，预取读是总读子集；含投机，不推导精确命中率、固定节省拍数或未测污染因果。

证书`sync/evidence/load-prefetch-screen-20261105-r02/finalization.json`及同目录`post-completion-verification.json`，说明`sync/LOAD-PREFETCH-SCREEN-20261105.md`。无综合／ABC／STA、新面积／频率／评分，不拼接生产PPA，不算完整优化轮。授权已结束，不自动采用、追加候选／组合／综合／清理；生产44项RTL／SRAM、两软件126项、Slave和正式指针保持，综合继续暂停，未提交／推送。

## 2026-11-05：Load预取研究先查Slave容量，原六从机均未满（未实现／综合）

用户“研究基于load的预取”后追加先看从机容量／是否满，执行只读生产观察和固定流下一行时机分析，不实现预取。现存同源native／converted模型仅外部新链接驱动，原六所有答案／周期8605/17550/3985/5864/155719/168501及C/L/W/R/P完整日志逐字节保持，新增五队列step前后记录两模型相同。独立raw队列峰值／满周期／valid背压／服务守恒和跨拍连续性通过。

Slave的AR／AW／W／R／B各16项，原六五队列满周期全部0，所有通道valid&&!ready和R/B容量引起服务阻塞也全0。AR／AW／W峰值均1，R均11，B为1/1/1/1/8/11。全观测读服务占用率（含取指）16.271502/3.379110/33.007028/12.485076/3.637987/23.548961%，最长连续40/48/48/40/48/48拍。真实从机可每拍同时服务1读字＋1写字，不是共用单服务口；一条D$32字节行仍占8个读传输。4MSHR峰值2/2/2/1/2/4，仅rsort满48拍；8项D$请求槽满0/0/116/162/284/33292拍，满状态不直接等同被阻塞的新需求或省拍数。AXIData8描述符均未满。证书`sync/evidence/slave-capacity-profile-20261105-r01/finalization.json`。

复用固定C/L/W流的Load首次源行→下一行提示，在目标首次需求和取行之前的候选数100/37/112/0/289/510；vvadd的112个候选提前量32/69/111拍。独立直接raw首访／分类／提前量审计通过，证书`sync/evidence/load-nextline-opportunities-20261105-r01/finalization.json`。全程去重只是离线分析便利，没有有限预测器／额外流量／污染／排队反馈模型，不是预取IPC或命中率实测。当前从机没有容量背压瓶颈，支持研究限流预取，但不能保证加入后不抢带宽／信用。

仅形成Load触发下一行、最多1条预取在途、需求留信用等研究建议。现有MSHR依赖真实request owner及2bit ID，必须先设计预取类型／无架构返回／Store陈旧数据防护／Tag端口及普通RAM边界；按PC步长还需可靠PC通道。说明`sync/LOAD-PREFETCH-RESEARCH-20261105.md`。两软件Slave仅只读源码核对，没有新两软件观察模型，不冒称本次三端重新逐拍。无新RTL模型／候选实现／综合／ABC／STA或PPA；生产／两软件126项／Slave／指针和三树HEAD索引保持，综合继续暂停。研究结束不自动实现／实验／采用／综合或清理，未提交／推送，不算完整轮。

## 2026-11-05：用户明确否决仅Store数据RS4项，生产保持2项

用户获知仅SV4／SA2／消费2候选原六几何IPC−1.461943440%和vvadd−9.018264840%后明确“不采纳”。追加决定`sync/evidence/sv-capacity4-rejected-20261105-r01/decision.json`，否决`sv-capacity4-screen-20261105-r02`及r01同源尝试。原筛选／审计完成证书不回写，源码／模型／trace及r01失败证据保留，不自动恢复、采用或继续该方案，不启动其他实验／综合／清理。生产仍ROB载荷复位分离、SV容量2项；两软件／正式指针／三树HEAD索引保持，综合继续暂停，未提交／推送。以下“不替用户否决”保留决策前归属。

## 2026-11-05：仅Store数据RS容量4项筛选完成，几何IPC−1.461943%，未采用／综合

用户授权SV容量2→4、SA仍2、Store数据消费最多2条／拍的独立筛选。候选仅pkg／core分离STORE_VALUE_ISSUE_WIDTH=2，所有数据消费数组／循环／RS发射／LSU输入保持两条，容量及分配信用4；两ALU同拍旁路、三CDB普通唤醒、实际离站信用及其他42项RTL／SRAM保持，不带已否决前端或Load选择候选。

首轮`sv-capacity4-screen-20261105-r01`局部真实RS运行到末尾覆盖检查失败，未跑IPC；r02仅补双操作数同时由ALU0／1到达的定向激励，不删除检查，44项RTL逐字节保持，原失败快照／脚本／日志保留。r02局部列表oracle native／converted各4125拍、容量退回2／误扩消费4／共享CDB误开同拍三个有效RTL负向、真实RS→两通道LSU公开端口集成通过；新整核两模型原六答案／374104条退休／九字段架构退休匹配生产，完整日志一致，无环／锁存。独立raw周期／退休／答案、源码范围／夹具／负向／保护和三树HEAD索引审计通过。

周期8605/17550/4380/5832/155722/168384，相对生产0/0/+395/−32/+3/−117。vvadd IPC−9.018264840%，towers+0.548696845%，qsort−0.001926510%，rsort+0.069484036%，其余不变；六项几何IPC0.9961864233581463，−1.461943440020%。四项真实SV占用达到4，扩容实际生效但目标vvadd明显退化，不将旧SV背压直接当作加槽必有收益，不伪称已定位Cache／请求序等具体因果。建议不推进，不替用户明确否决。

最终证书`sync/evidence/sv-capacity4-screen-20261105-r02/finalization.json`，说明`sync/SV-CAPACITY4-20261105.md`。无综合／ABC／STA、新面积／Fmax／评分或吞吐估算，不算完整优化轮。筛选授权结束，不自动采用、继续候选／组合／综合／清理；生产44项RTL／SRAM、两软件126项输入、正式指针和三树HEAD索引保持，全部综合继续暂停，未提交／推送。

## 2026-11-05：用户明确否决最老可发出Load，其他候选仅建议

用户“不采纳，其他候选优化有什么”明确不采用`lsu-eligible-load-screen-20261105-r01`。追加决定`sync/evidence/lsu-eligible-load-rejected-20261105-r01/decision.json`，原筛选／审计完成证书不回写，候选源码／模型／trace／证据保留。不得自动恢复／采用或继续此方案；用户询问其他候选只授权分析建议，不授权实施、组合、综合或清理。生产仍ROB载荷复位分离、Load仍用原选择规则，两软件／正式指针／三树HEAD索引保持；综合继续暂停，未提交／推送。以下“不替用户否决”保留决策前归属。

## 2026-11-05：最老可发出Load隔离筛选完成，整体IPC微降，未采用／综合

用户授权“尝试一下，虽然这个可能会增加组合逻辑”，只筛选一个独立`lsu-eligible-load-screen-20261105-r01`。从当前ROB载荷复位分离生产复制44项RTL，只改`rv32_lsu.sv`：对每个旧Load先用旧SQ判断未知地址或字节重叠阻塞，再由原年龄树选择最老合格候选。保留旧Load匹配AGU当拍地址、最终原SQ准入门、Store优先级、SQ转发／通知、Load结果仲裁和全部状态写入，不猜测访存依赖，不新增容量／级数／端口，不带已否决前端部分接受。

局部native／converted独立公开端口数学字节区间／非环绕年龄oracle各9014次检查，覆盖149次跳过阻塞旧项、未知Store、匹配AGU／错误身份、字节／半字／字和跨word、背压／halt／flush／tag回绕／工作后reset。四个源码负向均实际构建成功并检出；原真实LSU owner／取消／同tag复用／退休／posted Store回归两模型通过。新整核无组合环／锁存，双模型原六答案／374104条退休／九字段架构退休匹配同源生产基线，两模型完整日志一致，独立raw／源码复现／保护和三树HEAD索引审计通过。

周期8605/17550/3985/5864/155708/168514，相对生产0/0/0/0/−11/+13。qsort IPC+0.007064505%、rsort−0.007714493%，其他不变；几何IPC1.0109650809515047，相对−0.000108422327%，基本持平但非正收益，未改善最弱median。不据微小周期变化伪称已证明Cache／BPU等因果。建议不推进，不替用户追加明确否决；未综合／ABC／STA，无新面积／频率／评分，组合逻辑实际代价未知。

证书`sync/evidence/lsu-eligible-load-screen-20261105-r01/finalization.json`，说明`sync/LSU-ELIGIBLE-LOAD-20261105.md`。筛选授权已完成，不自动采用、扩展实验／组合、综合或清理；生产44项RTL／公共SRAM、两软件126项、正式指针及三树HEAD／索引保持。综合继续暂停，未提交／推送，不算完整优化轮。

## 2026-11-05：前端两层部分接受筛选通过，原六IPC持平，用户不采用

用户要求尝试空IQ及空FQ新包直通的部分接受，隔离`partial-frontend-bypass-screen-20261105-r01`只改queue／rename-plan：上游整包单次握手、资源允许的连续前缀分配、剩余后缀压紧入IQ。没有软件、容量、宽度、BPU或访存协议变更。FW2／FW4实际队列＋planner独立oracle在两种来源分别覆盖真前缀，四个有效RTL负向、真实RAT／PRF状态及恢复／freeze／flush／容量native／converted通过；新整核两模型原六项答案／退休／九字段架构退休匹配已采用同源基线，两模型完整日志一致。独立源复现／raw退休与周期重数／保护／三树HEAD索引审计通过。

原六周期8605/17550/3985/5864/155719/168501全不变，几何IPC1.010966177065（+0%）。未综合／ABC／STA，无新面积／频率／评分，不拼接生产PPA。筛选证书`sync/evidence/partial-frontend-bypass-screen-20261105-r01/finalization.json`。已启动外部只读统计用于区分未触发与触发但无省拍，仅链接现成模型，不改RTL，不作PPA或采用授权。

用户获知结果后明确“那不应用了”：追加`sync/evidence/partial-frontend-bypass-rejected-20261105-r01/decision.json`，不采用、不自动继续此方案或其他实验／综合／清理。原筛选证书不回写，候选源码／模型／trace／证据保留。生产继续ROB载荷复位分离、前端两层仍整组接受；44项RTL／SRAM、两软件126项构建输入、正式指针及三树HEAD／索引保持。全部综合继续暂停，未提交／推送，不算完整优化轮。说明`sync/PARTIAL-FRONTEND-BYPASS-20261105.md`。

## 2026-11-04：正式采用ROB载荷复位分离（优先于以下历史）

用户要求“采纳ROB 复位分离”，仅采用已审计`rename-area-ppa-sequence-20261104-r01/rob-payload-reset`。面积34238.371507 μm²（-1.349543%），Fmax313.341493 MHz（+1.744186%），六项几何IPC1.010966177065（不变），评分2.792146575072e-07（+4.546957%）。IPC×Fmax估算+1.744186%，非墙钟实测。
仅替换`rv32_rob_lanes.sv`：载荷raw不复位，每行initialized复位并屏蔽未初始化读出；valid／ready／完整tag控制复位及写优先级保持。initialized不跟随valid清除，保留取消项replay和失效端口载荷。不带PRF或ROB SRAM候选，不改容量／宽度／BPU／访存协议。现有frontend格式及等宽截取修复原样保留并记录旧指针差异。
44项RTL／公共SRAM与已审计候选同源，复用该候选已完成整核综合／ABC／STA及native／converted局部与原六资格；本次不新综合、不声称另建生产路径RTL模型或全状态形式等价。两软件126项构建输入不变，无需改算法；全新Release／断言四构建原六答案／退休／init+core+drain及外部副本各374104条退休PC／周期匹配。周期8605/17550/3985/5864/155719/168501。旧黄金／镜像／Slave／既有code和三树HEAD／索引保持。
面积<36000及Fmax>300通过，长期IPC>1.0985未达。面积／频率合格候选中评分最优，不是无面积限制的最高IPC或最高评分者；历史排名／否决保持。采用证书`sync/evidence/rob-payload-reset-production-adoption-20261104-r01/adoption.json`；正式指针`sync/evidence/current-production.json`；软件说明`docs/hardware-baseline-rob-payload-reset.md`。
全部综合／ABC／STA继续暂停，未提交／推送；不自动继续新实验／组合／清理，不算完整新优化轮。

## 2026-11-04：用户明确不采用Victim4，追加否决决定

用户获知Victim4面积35615.175487 μm²、Fmax293.157744 MHz、几何IPC+0.133898%及评分−9.118523%后明确“不采用”。已追加`sync/evidence/dcache-victim4-rejected-20261104-r01/decision.json`，记录禁止自动采用该候选，不以排名改变用户决定；r20只追加否决与rejected_roots，r19历史指标／排名及原筛选／PPA证书不回写。

本次没有新综合、仿真、采用或删除；保留测量／审计／失败证据，生产仍原FQ＋SA组合8 KiB D$无VC／I$1 KiB，两软件／正式指针／三树HEAD索引保持。所有综合继续暂停，不继续此方案或自动启动其他实验／清理。说明`sync/DCACHE-VICTIM4-20261104.md`；以下“不建议／尚无否决”保留决策前归属。

## 2026-11-04：Victim4综合／ABC／STA及独立审计完成，频率失败未采用

唯一授权PPA `dcache-victim4-ppa-20261104-r03`已从elaborate全新完成整核综合、六阶段checkpoint、ABC与STA，独立Liberty逐叶面积／真实SRAM几何／约束／时序／评分审计和最终核验均通过。面积35615.175487 μm²（相对生产+2.617420%）、Fmax293.157744 MHz（−4.809619%）、六项几何IPC1.012319842491（+0.133898%）、评分2.427181157597e-7（−9.118523%）。IPC×Fmax吞吐估算−4.682161%，不是墙钟实测。

面积严格<36000通过、余量384.824513 μm²；Fmax>300失败、距300约6.842256 MHz，长期IPC>1.0985仍未达。当前实现IPC收益小而面积／频率及评分代价明显，建议不采用；此建议不等同用户已否决，不自动删候选或继续新实验。

主D$保持128组×2路×32字节，VC为4条寄存器全相联树PLRU，248个原SRAM宏和形状完全等于生产。精确复用44项RTL／公共SRAM／converted及原六native／converted完整日志资格，不重跑已完成筛选、不继承旧checkpoint或拼接PPA。两次观察器别名失败及证书保留，r01／r02未综合，r03一次新PPA。最终只读再次核验原始产物／认证输入／保护清单、正式指针和三树HEAD／索引保持。

证书`sync/evidence/dcache-victim4-ppa-20261104-r03/finalization.json`；报告`sync/DCACHE-VICTIM4-PPA-RESULTS-20261104.md`；说明`sync/DCACHE-VICTIM4-20261104.md`。cleanup-aware指标索引r19仅追加新认证指标，不访问或假称历史已删源码／模型／网表被恢复重审，排名不授权采用。生产仍D$8 KiB无VC／I$1 KiB，两软件／正式指针保持，未采用／提交／推送。

本次条件综合授权已结束，所有综合／ABC／STA恢复暂停，不自动启动其他候选、采用或清理。没有独立面积专项，不算完整新优化轮。以下为筛选及执行历史。

## 2026-11-04：Victim4双模型筛选及独立审计通过，正向IPC门禁后启动唯一PPA

r03筛选及独立审计已通过，证书`sync/evidence/dcache-victim4-screen-20261104-r03/finalization.json`。局部native／converted字节／PLRU oracle和四有效RTL负向、整核两构建及native原六按哈希复用，r03只补转换observer及原六项；native／converted答案／退休数／九字段架构退休匹配生产、完整日志及所有D/V计数相同，独立raw周期／退休／事件重数、源复现与复用链／保护输入核验通过。两次observer别名失败及旧门禁证书保留，不改候选RTL、不重复完成工作。

最终周期8605/17550/3985/5864/155646/167232，相对生产qsort−73、rsort−1269，其余四项不变，六项无退化；几何IPC1.012319842491（+0.133898%）。VC hit0/0/0/0/14/118；实际行读152/53/152/13/649/4780（生产末两项663/4896）、脏行写0/0/0/0/260/2928（生产末两项266/3037）。计数含投机与时序变化，不等同退休miss或固定节省拍数，长期几何IPC>1.0985仍未达到。

用户“有ipc加成，进行综合”条件已满足，`sync/evidence/dcache-victim4-conditional-ppa-20261104-r03/qualification-gate.json`passed=true；条件服务在单次pidfd观察审计完整退出后核验输入／指针，已启动本候选唯一一次新整核综合／ABC／STA，根`.cpu2026-synthesis/dcache-victim4-ppa-20261104-r03/`，job状态fresh-full-core-synthesis-ABC-STA，从elaborate新测。精确复制已验证44项RTL／公共SRAM／converted及原六日志资格；r01／r02均未综合，不继承历史checkpoint，不重复筛选构建。当前没有候选面积／Fmax／评分，不提前认定收益或面积达标。

生产8 KiB D$无VC／I$1 KiB、两软件／正式指针保持，未获采用授权；最终以`sync/evidence/dcache-victim4-ppa-20261104-r03/finalization.json`为准。仍只本单候选综合，结束后全部综合暂停，不启动其他候选／采用／清理，无独立面积专项，不算完整新优化轮。说明`sync/DCACHE-VICTIM4-20261104.md`。

## 2026-11-04：Victim4 native六项有小收益，第二个观察别名问题后r03仅补转换六项

r02完成native原六项答案／退休数／九字段匹配：周期8605/17550/3985/5864/155646/167232，qsort−73、rsort−1269，其余四项不变，native几何IPC1.012319842491（+0.133898%）。VC hit0/0/0/0/14/118，实际行读152/53/152/13/649/4780、脏行写0/0/0/0/260/2928，包含投机／时序影响，不将流量差等同VC hit或固定省拍数。converted整核构建也成功，但该模型优化消去了`vcReadMissInner`别名，外部观察器再次停止，converted六项未跑，尚不是双模型完整资格；r02失败／审计及门禁不通过收据保留，正确未启动PPA。

r03只修observer，用有符号allocateMiss>=0、实际vcAllocHit以及allocation&&!hit还原同一事件，预检同时通过两份实际头文件全部所需字段。原RTL／逻辑／bench不改，44项RTL及full-converted输入逐字节同源。按哈希复用r01局部两模型／四负向／native构建、r02 native六项完整日志和converted构建，不重复这些已完成工作；只链接converted新observer及补跑converted原六项，随后独立重新raw重数、比对两模型完整日志及复用证据链。

入口`sync/resume_dcache_victim4_experiment_r03.py`，根`.cpu2026-synthesis/dcache-victim4-screen-20261104-r03/`，审计`sync/audit_dcache_victim4_screen_r03.py`。条件`sync/qualify_and_measure_dcache_victim4_ppa_r03.py`单次pidfd等审计，门禁`sync/evidence/dcache-victim4-conditional-ppa-20261104-r03/`；同一条件授权通过后只测`dcache-victim4-ppa-20261104-r03`一次新PPA。r01／r02均未综合；不提前认定最终IPC资格。生产／两软件／指针保持，不自动采用。说明`sync/DCACHE-VICTIM4-20261104.md`。

## 2026-11-04：Victim4局部资格通过，观察器别名消除失败后r02原RTL接续

r01整核环／锁存、实际DCache＋SRAM＋行控制器局部native／converted字节及树PLRU端口oracle、四个实际源码负向全部通过，native整核模型成功构建；外部观察驱动生成因头文件不存在`vcAccessFireInner`停止。该wire是功能开启下`allocateMissInner>=0`的别名，Verilator已消去；不是已观测的DUT错误，但整核六项IPC尚未执行，不能标候选完整通过。r01失败／局部资格／模型及审计保留，条件门`qualification-gate.json`passed=false，正确未创建PPA根或启动综合。

r02只修外部observer，读取保留的32位allocateMissInner，以有符号>=0还原原分配事件；不改RTL或加观察端口，原candidate／logic／bench保持，44项RTL与r01逐字节相同。按哈希认证旧local／四负向证据和整个native模型，纳入新pins并原地只读复用，不重复局部测试或native构建；仅新链接observer、converted整核构建以及两模型原六项完整执行。旧证书／输入／失败不回写。

入口`sync/resume_dcache_victim4_experiment_r02.py`，工作根`.cpu2026-synthesis/dcache-victim4-screen-20261104-r02/`，独立审计`sync/audit_dcache_victim4_screen_r02.py`核验复用链、源复现、全部新raw退休／周期／计数及保护输入。条件`sync/qualify_and_measure_dcache_victim4_ppa_r02.py`单次pidfd等待r02审计完整退出，以同一“有IPC加成再综合”授权严格门禁，收据`sync/evidence/dcache-victim4-conditional-ppa-20261104-r02/`；通过后只测`dcache-victim4-ppa-20261104-r02`一次新PPA，r01没有综合。不提前认定IPC收益，生产／两软件／正式指针保持，未采用。说明`sync/DCACHE-VICTIM4-20261104.md`。

## 2026-11-04：8 KiB D$加4条寄存器全相联树PLRU victim cache筛选与条件综合启动

用户要求在8 KiB基础尝试4 cacheline全相联PLRU victim cache、寄存器实现，随后明确“如果有ipc加成，进行综合”。本次只授权单候选先正确性／IPC，独立审计通过且原六项逐项不退化、几何IPC严格提高后一次全新整核综合／ABC／STA；不授权采用、其他候选或新清理。保持主D$128组×2路×32字节、I$1 KiB、8信用／4 MSHR、早字与LSU/AXI/Slave合同；隔离快照只改DCache及backend两项，其余42项RTL／公共SRAM保持，不恢复已否决方案。

VC为4×32字节数据寄存器＋完整line tag／valid／dirty／3位树PLRU和交换身份簿记，不是精确LRU，128字节非全部面积成本。主miss实际分配时查VC；hit则预留VC行到内部整行fill、换进主D$并将旧主victim存该VC槽，dirty随行。miss则有效主victim插VC，最低无效优先／PLRU排除预留行，只有脏VC淘汰才以原MSHR写回真实line／payload；复用原四个MSHR victim payload，不额外复制四行data buffer。物理fill优先，内部fill绝不ack物理总线；运输owner仍按原完整fill生命周期释放，reset不假设flush脏数据。

局部真实DCache＋公共SRAM＋行控制器native／converted端口字节oracle，独立两路主cache＋4条树PLRU模型检查读写流量、dirty swap／淘汰、完整地址、数据mask／高tag、reset，另8槽／4MSHR饱和、独立背压／900随机及早字owner／后到同字Load测试。禁hit、丢dirty、坏payload、错PLRU四个有效源码负向；原安全／组合环／锁存检查不关。之后全新原六项native／converted答案／退休数／九字段退休匹配当前生产、同容量完整日志一致。外部D/V事件观察及独立raw计数不等同退休miss率或固定节省拍数。

筛选`sync/run_dcache_victim4_experiment.py`，根`.cpu2026-synthesis/dcache-victim4-screen-20261104-r01/`，审计`sync/audit_dcache_victim4_screen.py`单次pidfd事件接续。条件服务`sync/qualify_and_measure_dcache_victim4_ppa.py`单次pidfd等审计完整退出，核验原六项、正向几何IPC、认证输入和指针才启PPA；失败／无收益只写门禁未通过、不创建PPA根。条件收据`sync/evidence/dcache-victim4-conditional-ppa-20261104-r01/`。通过后新测量`dcache-victim4-ppa-20261104-r01`精确复制同源44项RTL／SRAM／converted及日志资格，从elaborate新跑，同五库／248原SRAM／2ns／INVx1与5fF，独立逐叶面积、约束／六checkpoint／STA／评分和cleanup-aware指标归档。单候选结束全部综合恢复暂停。

生产／两软件／正式指针／镜像／Slave／旧黄金／既有code和三树HEAD／索引保持，不自动采用。当前执行中，不提前认定资格或收益，不拼接旧PPA，不算含独立面积专项的完整优化轮。说明`sync/DCACHE-VICTIM4-20261104.md`。

## 2026-11-04：减面积模块离线排查完成，未实现／未综合

按用户“查找可以减少面积的模块”只读分析当前生产及16 KiB候选现存认证网表／Liberty／源码。驱动`sync/analyze_area_opportunities_20261104.py`、结果`.cpu2026-synthesis/area-opportunities-20261104-r01/analysis.json`、说明`sync/AREA-OPPORTUNITIES-20261104.md`。两份design／report／converted哈希对原审计，宏几何由认证report核对，逐单元Liberty面积合计容差匹配；无新Yosys／ABC／STA或RTL模型构建。

16 KiB面积增长3405.887962 μm²，其中D$ SRAM增2956.124122（86.794520%），非SRAM增449.763840（组合305.713440／时序144.050400）；其他SRAM几何不变。要保16 KiB并过严格<36000须压缩超过2112.641969，约逻辑面积6.675921%。仅消除扩容控制增量不够。展平ABC门无source属性，不能得到当前精确完整模块组合面积；只报告可归属时序和实际SRAM，854.562960时序留作未唯一归属，不强行摊分。

建议优先ROB载荷／写入与存储结构、RS载荷／宽mux、PRF多路读与上一拍写转发，次选FQ/IQ payload banking及D$请求／MSHR／victim。ROB1401.837840、RS763.467120、PRF278.857080、FQ/IQ575.268480和D$1044.219600均仅是成功归属的时序面积，不是模块总面积或节省估计。全部17458带reset/set FF若不现实地全部一换一普通FF，单元差也仅1527.225840；实际控制／预测计数器不能这么改，此数不是完整优化收益上限（不含组合门变化）。

必须保持原容量／执行宽度／信用与WB旁路、完整tag安全、freeze/flush及多读写周期；SRAM化不能忽略同步读／最近写转发成本，载荷去复位需审查失效端口可观察合同。已实现的ROB分组写、PRF全局仲裁和FIFO/D$载荷去复位不重复算新方案，已否决方案不恢复；不改BPU算法／表。所有方向尚无实现、资格或PPA收益，不承诺可省2113。生产D$8 KiB／I$1 KiB、两软件／指针及HEAD／索引保持，全部综合继续暂停，不自动实现／组合／采用。

## 2026-11-04：16 KiB D$综合／ABC／STA及独立审计完成，面积超限未采用

唯一授权任务`dcache16-ppa-20261104-r01`已完整完成全新elaborate、六阶段checkpoint、ABC映射和STA，独立Liberty逐叶面积、约束／时序／评分及真实SRAM几何审计通过。面积38112.641969 μm²，相对生产+9.813329%；Fmax314.399754 MHz（+2.087811%），六项几何IPC1.067120429364（+5.554513%），评分2.806711828927e-7（+5.092327%）。IPC×Fmax吞吐估算+7.758292%，不是墙钟实测。**面积<36000失败，超出2112.641969 μm²**；Fmax>300通过，长期IPC>1.0985仍未达。评分改善不能覆盖面积硬约束，不自动采用。

精确复用已审计16 KiB候选44项RTL／公共SRAM／converted和原六项资格，不重新构建已完成模型，不继承历史checkpoint或拼接生产PPA。实际D$256组×2路×32字节、数据64个256×8／tag2个256×20宏及其他SRAM形状保持独立检查通过；原六周期8605/17550/3985/5864/153691/123434，同源native／converted答案／退休／完整日志资格保持。没有新面积专项，不算完整新优化轮。

最终证书`sync/evidence/dcache16-ppa-20261104-r01/finalization.json`；结果报告`sync/DCACHE16-PPA-RESULTS-20261104.md`，说明`sync/DCACHE16-PPA-20261104.md`。最终收口只读再次核验新PPA原始产物及认证输入／保护清单、正式生产指针和三树HEAD／索引保持。cleanup-aware指标索引r18追加新认证指标，旧已清理源码／模型／网表不重新认证，不冒称可恢复重审。生产D$8 KiB／I$1 KiB、两软件／正式指针均未改，未采用／提交／推送。

当前单候选综合授权已结束，所有综合／ABC／STA恢复暂停，不启动32 KiB或新候选／面积专项／采用／清理。此前两次定界清理均已完成，当前／生产原始PPA及必要资格模型保留；旧已删产物不可伪称仍可执行或重新审计。以下为各阶段历史。

## 2026-11-04：旧仿真编译缓存清理完成，释放约24.09 GiB

后台清理正常完成：删除18066个生成编译文件、25846338431逻辑字节／25871749120分配字节（约24.09 GiB）；完成时F盘可用43241811968字节（约40.27 GiB），同期当前综合可能继续写入，不把可用空间变化全归因清理。`du -x -sh`复测实验目录约20 GiB，仍保留日志／trace、源码／输入／记录、当前和生产综合及受保护模型。

收据`.cpu2026-synthesis/simulation-cache-clear-20261104-r01/completion.json`；全量意图／执行journal配对和18066路径全部不存在、符合此次范围的残余重扫、当前PPA／资格／软件认证输入、生产原始PPA与三树HEAD／索引检查通过。收口再次认证两journal SHA256、正式生产指针和protected清单完整。当前16 KiB综合未停止／重启／修改，当前及正式生产资格模型、必要8 KiB基线和最新生产软件构建保持。

RTL／转换Verilog／夹具源码、trace／日志、指标／审计／manifest、镜像／Slave／工具链／Git及既有code未纳入删除。旧生成模型已删后须重新编译才能执行，不回写历史证书或宣称旧模型仍直接可用。本次清理结束，不继续删除剩余trace／日志或保护模型，不扩展综合／采用授权。说明`sync/SIMULATION-CACHE-CLEAR-20261104.md`。

## 2026-11-04：按用户追加要求清理旧仿真编译缓存（已完成，以下保留执行阶段）

用户查看目录空间后要求“帮我把旧仿真编译缓存删除”。新增授权仅清F盘`.cpu2026-synthesis/`内旧Verilator生成C++／头／对象／库／预编译头／ELF模型、旧sim／probe-*和旧CMake软件模拟器对象缓存，覆盖此前旧仿真模型保留要求；RTL／转换Verilog／夹具源码、trace／日志、指标／审计／manifest、镜像／Slave／工具链／Git及实际生产源码不删，既有code可执行文件保持。

保留当前16 KiB综合、16 KiB已验证模型及8 KiB基线、当前正式生产FQ＋SA综合及资格模型和最新软件采用构建；当前PPA及资格全部认证输入逐路径保护，其他活动实验根动态排除。不停止／重启／修改本次综合，也不启动新综合或采用。独立清理mutex与retention共享锁在定界排除后并行运行。

入口`sync/clear_old_simulation_cache_20261104.py`，收据`.cpu2026-synthesis/simulation-cache-clear-20261104-r01/`。逐批路径／SHA256／字节数意图先fsync持久化，再核验文件身份并unlink；全量意图／执行配对、所有删除路径不存在、残余缓存重扫及当前认证输入／生产原始PPA／三树HEAD索引复验。只读预检目录扫描超过120秒返回超时，没有执行删除；正式清理后台服务不带该前台超时，执行中不提前认定完成。最终以completion.json为准。

历史原manifest和认证结论保持，不将删除后的旧生成模型描述为仍可运行；后续若需重执行须重新编译。说明`sync/SIMULATION-CACHE-CLEAR-20261104.md`。

## 2026-11-04：旧综合产物与编译缓存清理完成，当前16 KiB及生产PPA保留

用户追加授权的定界清理已完成：删除50文件、2369238271逻辑字节（约2.21 GiB），完成时F盘可用16857563136字节。实际有残余待删大产物的两树为`rob-load-identity-ppa-20261103-r01/synthesis`（中断记录2文件）和`rob-load-identity-ppa-20261104-r01/synthesis`（48文件）；其他旧synthesis此前已清至指标／约束capsule，两个早于本次的ABC临时目录无残余文件，未伪报额外缓存删除量。

收据`.cpu2026-synthesis/synthesis-products-clear-20261104-r01/completion.json`，独立核验`verification.json`。逐文件SHA256意图先持久化再unlink，全量意图／执行配对及50路径全部不存在通过；复扫84个符合范围的旧synthesis／ABC树，无非capsule产物残余。当前`dcache16-ppa-20261104-r01`认证输入和保护清单、现正式生产`fq-sa-combined-ppa-20261104-r01`原始PPA哈希、三树HEAD／索引完整。当前综合未停止／重启／修改，生产／两软件／I$保持。

RTL／软件源码、仿真模型／退休trace、镜像／Slave／工具链／Git、指标摘要和审计证书未纳入删除；原manifest不回写，旧根追加清理标志，不声称旧已删网表仍可重新审计。该次清理结束，不自动继续清理。16 KiB综合仍执行中，无提前PPA结论；最终看`sync/evidence/dcache16-ppa-20261104-r01/finalization.json`。说明`sync/DCACHE16-PPA-20261104.md`。

## 2026-11-04：16 KiB D$单候选综合及旧综合工作集／编译缓存清理启动

用户要求“尝试16kib的综合”，仅对已审计16 KiB候选一次全新整核综合／ABC／STA及独立审计，不授权32 KiB或生产采用。入口`sync/measure_dcache16_ppa.py`，根`.cpu2026-synthesis/dcache16-ppa-20261104-r01/`，精确复制`dcache-capacity-screen-20261104-r02/dcache-16k`44项RTL／公共SRAM／已验证converted与原六项日志资格；不重跑筛选、不热改原快照。几何IPC1.067120429364（+5.554513%），课程周期8605/17550/3985/5864/153691/123434。新测量从elaborate开始，同五库／248宏／2ns／INVx1及5fF，没有checkpoint继承；独立Liberty逐叶面积、实际D$256组数据／tag宏几何及其他SRAM形状、STA／约束／六阶段checkpoint和评分审计。指标只追加认证记录，不访问已清理历史原始网表／源码。

用户同时要求“清除除了当前综合和应用到生产的综合以外的所有综合产物”“与综合编译缓存”。本次覆盖旧保留最近三次规则，仅清F盘实验根旧synthesis工作集网表／checkpoint／生成包装和综合编译文件、早于当前启动且无主的ABC临时缓存；保留指标／约束摘要capsule和审计证书，不回写旧manifest，不删RTL／软件源码、仿真模型／trace、镜像／Slave／工具链／Git。保护当前16 KiB综合和当前正式生产`fq-sa-combined-ppa-20261104-r01`及二者资格与认证输入，动态排除活动路径和当前新临时目录。

清理入口`sync/clear_old_synthesis_products_20261104.py`、收据`.cpu2026-synthesis/synthesis-products-clear-20261104-r01/`；独立mutex＋retention共享锁，在严格排除当前与生产树后同时清旧树，不停／重启／修改本次综合，常规独占清理延后。逐文件路径／字节数／SHA256意图先持久化再unlink，全量意图／执行配对及不存在检查，并重核当前PPA认证输入／生产原始PPA。删除后仅保留历史认证指标，不宣称旧网表仍可重审。

两任务执行中，不提前认定完成；PPA最终看`sync/evidence/dcache16-ppa-20261104-r01/finalization.json`。生产D$8 KiB／I$1 KiB、两软件及正式指针保持。没有额外面积专项，不算完整优化轮；此次单候选结束后所有综合恢复暂停。说明`sync/DCACHE16-PPA-20261104.md`。

## 2026-11-04：D$容量筛选及最终独立审计完成，生产保持8 KiB

最终r02独立审计已完成通过，证书`sync/evidence/dcache-capacity-screen-20261104-r02/finalization.json`，三项correct均为true。独立raw退休／周期／实际D$端口计数重数、源参数复现、同容量native／converted完整日志和有效负向资格、保护输入及三树HEAD／索引核验通过。收口只读再次核验三项audit哈希、认证输入／保护输入及当前生产指针SHA256 `cae9211354a5724188eb0e4a74ae9872eb89751517a963248d5893c69698fc66`保持，未重跑已完成的构建或实验。

16 KiB几何IPC1.067120429364（+5.554513%），32 KiB1.072228789166（+6.059808%），均相对8 KiB生产六项不退化；32 KiB相对16 KiB的rsort少3489拍而qsort多3拍。扩容在本批IPC有收益，但没有候选面积／Fmax／评分，不能认定哪个容量满足PPA门槛或更划算，长期几何IPC目标仍未达。原失败及r01审计不回写；r02仅提高工具循环展开预算，两扩容候选44项RTL与r01逐字节一致，8 KiB原资格按哈希复用并重核。

生产仍D$8 KiB／I$1 KiB，两软件／正式指针保持。没有综合／ABC／STA或采用，不拼接旧PPA，不算完整优化轮。此有限序列完成，不自动继续容量／组合／其他实验，不恢复综合；所有综合仍暂停。说明`sync/DCACHE-CAPACITY-SCREEN-20261104.md`；以下接续中记录保留阶段归属。

## 2026-11-04：D$容量筛选完成，最终独立审计接续中

r02的16／32 KiB两候选局部native／converted实际模块字节oracle、两个有效RTL负向、原六项全新native／converted答案／退休数／九字段架构退休匹配均通过，同容量完整日志和计数一致。44项RTL逐字节等于各自r01，只提高工具展开预算。8 KiB复用r01已审计基线。

16 KiB周期8605/17550/3985/5864/153691/123434，几何IPC1.067120429364（相对生产+5.554513%）；32 KiB周期8605/17550/3985/5864/153694/119945，几何IPC1.072228789166（+6.059808%）。两者相对生产六项均不退化：qsort分别−2028／−2025拍，rsort分别−45067／−48556拍，其他四项不变。32 KiB相比16 KiB的rsort再少3489拍、qsort多3拍，不宣称更大容量逐项都更好。长期几何IPC>1.0985两者仍未达。

实际行读8 KiB152/53/152/13/663/4896，16 KiB152/53/152/13/519/1152，32 KiB152/53/152/13/516/803；实际脏行写分别0/0/0/0/266/3037、0/0/0/0/6/505、全零。零脏行写仅是课程内观察，Store请求数保持，结束未人为flush，不能当作所有脏数据已持久化；Load含投机，不当作退休miss率或固定节省拍数。

有限筛选已结束，最终独立审计接续中，不提前标其完成。无综合／ABC／STA、无新面积／Fmax／评分，不能判断容量是否满足PPA门槛或更值得。生产D$8 KiB／I$1 KiB、两软件及正式指针保持，全部综合暂停，不自动采用或扩展实验。最终以`sync/evidence/dcache-capacity-screen-20261104-r02/finalization.json`为准，说明`sync/DCACHE-CAPACITY-SCREEN-20261104.md`。

## 2026-11-04：D$首轮基线通过，16／32 KiB工具循环展开限制后r02接续

r01有限序列已完成并独立审计；8 KiB新观察基线局部native／converted、两个有效负向及原六项全新模型／退休／计数通过，周期8605/17550/3985/5864/155719/168501严格匹配生产。实际行读152/53/152/13/663/4896，脏行写0/0/0/0/266/3037（课程结束未人为flush）。16／32 KiB在首个native-lint因原逐组valid／PLRU非阻塞赋值循环触发五条BLKLOOPINIT；无UNOPTFLAT／LATCH，没有扩容IPC资格，不把工具限制称为功能失败或无收益结论。r01证书`sync/evidence/dcache-capacity-screen-20261104-r01/finalization.json`明确all_attempts_correct=false，原日志／输入不回写。

r02只提高Verilator unroll-stmts 100000→1000000，保留unroll-count1024及全部检查，不改RTL／非阻塞赋值／生产builder。新构建包装`sync/build_dcache_capacity_verilate.py`仅对本实验生效。入口`sync/resume_dcache_capacity_sequence_r02.py`在新根`.cpu2026-synthesis/dcache-capacity-screen-20261104-r02/`复用已审计8 KiB资格、只重试16／32 KiB；两候选44项RTL必须逐字节等于r01。审计`sync/audit_dcache_capacity_sequence_r02.py`单次pidfd退出接续，重核raw计数、源同一性和保护输入，最终以r02 finalization.json为准。

生产／两软件／正式指针、I$1 KiB和Git HEAD／索引保持，所有综合继续暂停；尚不提前认定扩容正确或有收益，无新面积／频率／评分，不自动采用或扩展其他实验。

## 2026-11-04：按用户要求开始D$容量8／16／32 KiB隔离筛选

用户“尝试扩容D$”。当前FQ＋SA生产D$为128组×2路×32字节＝8 KiB，本次顺序新测8 KiB计数基线、独立16 KiB（256组）、独立32 KiB（512组）。每项从同一生产复制44项RTL，扩容只改dmem_backend实际cache实例SETS参数，其他43项RTL和公共SRAM实现保持。两路相联、32字节行、PLRU、8总请求信用、4 MSHR、Store位置4项、合并、写回／早字返回、LSU及AXI／Slave和访存延迟保持；I$按用户决定仍为1 KiB。不扩其他队列或执行宽度、不混入已否决旁路。

先整核环／锁存检查，再实际DCache＋SRAM＋行控制器native／converted端口字节oracle，覆盖全部组两路、高index／tag边界、暖一拍命中、跨word mask、全部驻留行脏淘汰实际地址／整行payload、旧脏数据读回、随机并发和reset语义，两个有效RTL负向分别丢高set位及脏victim高index位。通过后各容量全新native／converted原六项答案／退休数／九字段架构退休匹配生产，同容量完整日志和计数一致；8 KiB基线严格匹配生产周期。外部驱动只读CPU及行接口握手，独立raw周期／退休／请求计数审计，不将含投机／合并的行请求率说成精确miss率、不以请求数代替节省拍数。

入口`sync/run_dcache_capacity_sequence.py`；根`.cpu2026-synthesis/dcache-capacity-screen-20261104-r01/`；审计`sync/audit_dcache_capacity_sequence.py`单次pidfd事件接续，不轮询。F盘输出／临时文件及清理共享锁保持；说明`sync/DCACHE-CAPACITY-SCREEN-20261104.md`。最终看根及`sync/evidence/dcache-capacity-screen-20261104-r01/finalization.json`，执行中不提前认定正确或收益。

生产／两软件／正式指针／镜像／Slave／旧黄金／既有code和三树HEAD／索引保持，所有综合／ABC／STA仍暂停，不自动采用。不测PPA、无新面积／Fmax／评分，不拼接生产PPA、不算完整优化轮；此有限筛选不授权其他实验。

## 2026-11-04：I$最终审计通过，用户决定不扩容

1／2／4 KiB有限筛选及最终独立审计已完成通过，证书`sync/evidence/icache-capacity-screen-20261104-r01/finalization.json`。收口只读核验三项audit哈希、认证输入、保护输入、正式生产指针和三树HEAD／索引保持，未重复构建或实验。2／4 KiB均仅towers少46拍，几何IPC+0.131343%，4 KiB无额外收益；没有综合／ABC／STA或新面积／Fmax／评分。

用户最终明确“那I$不扩容”。生产保留1 KiB（16行×64字节），不采用本批2／4 KiB候选，不启动扩容综合或后续容量实验。两软件及正式指针保持，筛选结果与审计证据保留，所有综合继续暂停。说明`sync/ICACHE-CAPACITY-SCREEN-20261104.md`；以下接续中记录保留阶段历史归属。

## 2026-11-04：I$扩容筛选结束：2／4 KiB同收益，独立审计接续中

1／2／4 KiB三项局部native／converted实际ICache＋公共SRAM端口oracle、两个有效源码负向及原六项全新native／converted答案、退休数、九字段架构退休匹配均通过，同容量完整日志及计数相同；1 KiB计数基线周期严格等于当前生产。最终独立raw重数、源参数／保护／HEAD索引审计接续中，不提前认定其完成。

2 KiB与4 KiB周期完全相同8605/17550/3985/5818/155719/168501，仅towers比生产5864少46拍，其余五项不变，无单项退化；几何IPC1.012294009574，相对生产+0.131343%。实际取指行请求由13/19/8/54/29/48变为13/19/8/51/29/48，总计171→168，仅towers少3次。towers接受包tag命中率98.627002%→98.702620%，投机接受包3933→3931；其余五项接受包tag命中率原为99.6749%～99.9784%。计数包含投机，不当退休miss率或每次固定节省拍数。

对本批六项，2 KiB已取得4 KiB的全部容量收益，4 KiB无额外实测收益；不证明所有程序更大I$都无用。没有综合／ABC／STA或面积／频率／评分，不能判断PPA值得，不自动采用或扩大容量实验。生产I$仍1 KiB，生产／两软件／正式指针及镜像／Slave／旧黄金／既有code和三树HEAD／索引保持。最终看`.cpu2026-synthesis/icache-capacity-screen-20261104-r01/finalization.json`；说明`sync/ICACHE-CAPACITY-SCREEN-20261104.md`。

## 2026-11-04：I$扩容1／2／4 KiB隔离正确性与IPC筛选启动

用户要求“帮我尝试扩容I$，看看有没有用”。当前FQ＋SA组合正式生产I$为1 KiB＝16行×64字节直接映射；本次顺序新测1 KiB真实计数基线、独立2 KiB（32行）和独立4 KiB（64行）。每个候选从当前生产复制44项RTL，只在student_top的实际u_icache实例增加SETS参数，其他43项保持；同步单1RW公共SRAM实现、64字节行、相联度、请求深度、包几何、BPU、AXI／Slave和服务延迟不变。无预取、关联度／缓存协议／执行宽度扩展，不混入其他候选。

先整核native组合环／锁存检查，再实际ICache＋公共SRAM native／converted全部行、高index位及tag边界、双词及行末、预译码控制、backpressure、flush／freeze／reset端口oracle与两个实际源码负向，通过后分别全新native／converted原六项答案、退休数和九字段架构退休匹配生产，同容量完整日志逐字节一致。1 KiB计数基线需保持当前生产周期8605/17550/3985/5864/155719/168501。外部驱动增加逐拍I$实际握手计数，不修改RTL、sim.cpp、生产探针或Slave；独立重数周期和行请求／fill等，投机取指包含在内，不把重复miss都说成容量冲突、也不以事件数代替整核节省。

入口`sync/run_icache_capacity_sequence.py`；根`.cpu2026-synthesis/icache-capacity-screen-20261104-r01/`，三个独立子目录`baseline-1k`／`icache-2k`／`icache-4k`；审计`sync/audit_icache_capacity_sequence.py`单次pidfd退出事件接续，不轮询。F盘输出／临时文件，持清理共享锁。最终看工作根`completion.json`／`finalization.json`和`sync/evidence/icache-capacity-screen-20261104-r01/`；说明`sync/ICACHE-CAPACITY-SCREEN-20261104.md`。

当前生产／两软件／正式指针／镜像／Slave／旧黄金／既有code和三树HEAD／索引保持；全部综合／ABC／STA仍暂停，不自动采用。没有候选面积／Fmax／评分，不将数据位数增长冒称整核面积实测，不拼接生产PPA，不算完整优化轮，执行中不提前认定扩容有效。

## 2026-11-04：FQ＋SA组合重启后归档修复、正式替换与发布后复验完成

正式采用与发布后收口均完成，生产指针已切换为`fq-sa-combined-ppa-20261104-r01`，SHA256 `cae9211354a5724188eb0e4a74ae9872eb89751517a963248d5893c69698fc66`。已备份并替换三项RTL、两软件13项源码，其余41项RTL及113项软件构建输入保持；发布后Release／断言六项双树复验匹配8605/17550/3985/5864/155719/168501。44项RTL、126项软件与同源资格、PPA原始产物及备份／三树HEAD／索引核验通过。镜像／Slave／旧黄金／既有code保持，未提交／推送。

本次全新综合／ABC／STA在重启前已完成；首份PPA审计之后，旧最优保留入口访问用户此前清理的历史RTL，`retention.log`报`invalid RTL entry`，采用门禁正确停止。重启后核验确认新输入、六阶段checkpoint、网表、STA及软件资格完整，仅旧job记录了真实归档失败状态；保留原失败与r01审计，不重跑已完成综合／ABC／STA／软件四构建。`audit_fq_sa_combined_ppa_r02.py`只读重新审计同一次测量、写新r02证书，并用cleanup-aware helper只追加历史认证指标，不假称旧源码／模型恢复；新PPA最终证书通过后才备份、复制、原子发布及复验。修复归属`sync/evidence/fq-sa-combined-ppa-20261104-r01/archival-recovery-provenance.json`。

最终面积34706.754007 μm²、Fmax307.969925 MHz、几何IPC1.010966177065、评分2.670710512892e-7；相对旧生产面积+0.223820%、Fmax−3.248120%、IPC+2.780824%、评分+7.489459%。IPC×Fmax估算−0.557621%，不是墙钟实测。面积<36000与Fmax>300通过，长期几何IPC>1.0985仍未达。r16追加指标、r17生产重绑定，本组合为已审计最高IPC／最高评分者；排名不自动授权后续采用。r17通用helper历史“评分退化”标志与本次正向评分变化不符，另以`production-decision-clarification.json`追加实际正向变化及本次用户授权归属，原证书不回写。

采用最终证书`sync/evidence/fq-sa-combined-production-adoption-20261104-r02/finalization.json`及`post-publication-verification.json`；说明`sync/FQ-SA-COMBINED-PPA-ADOPTION-20261104.md`。模型资格精确复用已审计组合native／converted，不声称另重建生产路径RTL模型或完整状态／全输入形式等价。全部综合／ABC／STA已恢复暂停，本次单候选采用结束，不启动其他候选／组合／清理；没有额外面积专项，不算完整优化轮。

## 2026-11-04：正式采用空FQ＋Store地址RS WB组合（优先于以下历史）

用户要求“采纳，并开始综合”，已在全新PPA及两软件资格通过后采用`fq-sa-combined-ppa-20261104-r01`。面积34706.754007 μm²、Fmax307.969925 MHz、原六项几何IPC1.010966177065、评分2.670710512892e-07。相对上一生产IPC+2.780824%、面积+0.223820%、Fmax-3.248120%、评分+7.489459%。IPC×Fmax估算-0.557621%（非墙钟实测）。排名不自动授权其他候选。
仅旧FQ／IQ均空时返回包直通译码，整组分配或整组进入IQ；宽前端proposal独立ready，真实上下文按实际接受出队，旧路径保持。旧Store地址RS使用已授权CDB值派发，真正获共享AGU接受才返还信用，新分配不得同拍派发。三项RTL变化，不加其他释放信用、已否决PRF排名／Store地址通知／回填字捕获／miss接续，不改BPU算法／表、容量、执行宽度、访存协议或Slave。
44项RTL及公共SRAM与已审计组合精确同源；本次同源全新整核综合／ABC／STA已完成并独立Liberty逐叶面积、约束、六阶段checkpoint及评分审计，不拼接旧PPA。资格来自`fq-sa-combined-screen-20261104-r01`局部native／converted两组oracle、四源码负向和原六项完整日志；不声称完整状态／全输入形式等价或另建生产路径RTL模型。
两软件同步空FQ单次消费与SA旁路，共13项构建输入变化、113项保持；主树只读旧快照/Input逐字段写目标，模板Register单写／统一sync保持。全新Release／断言四构建原六项答案／退休数／init+core+drain及外部副本退休PC／周期匹配。课程周期8605/17550/3985/5864/155719/168501。旧黄金、镜像、Slave、既有code及三树HEAD／索引保持。
面积<36000及Fmax>300通过，长期几何IPC>1.0985仍未达。此次为已筛选组合的PPA及采用，没有额外面积专项，不算完整新优化轮。单候选综合授权已结束，全部综合／ABC／STA恢复暂停，不自动启动其他实验。
正式指针`sync/evidence/current-production.json`；证书`sync/evidence/fq-sa-combined-production-adoption-20261104-r02/adoption.json`；软件说明`docs/hardware-baseline-fq-sa-combined.md`。以下记录保留历史归属。

## 2026-11-04：空FQ＋SA组合两软件四构建及退休资格完成，新PPA仍执行

r02隔离软件资格已完成，收口核验输入／二进制／报告哈希通过。主树及模板全新Release／断言四构建原六项答案、退休数、init+core+drain均等同组合RTL课程周期8605/17550/3985/5864/155719/168501；两个外部观察副本各374104条退休PC／周期逐条匹配。主树旧快照/Input写纪律及模板Register单写／统一sync保持，无生产观察探针。13项构建输入变化、113项保持，原r01缺ICache include构建失败保留，不重标通过。

资格证书`.cpu2026-synthesis/fq-sa-combined-production-adoption-20261104-r02/validation-complete.json`、`software/validation-r01/summary.json`、`software/retirement-r01/summary.json`。当前生产RTL／两软件／正式指针及三树HEAD／索引核验保持，新整核综合／ABC／STA仍为`fq-sa-combined-ppa-20261104-r01`同一授权任务。采用服务已通过单次pidfd事件等待PPA完整退出并成功审计，之后核验新面积<36000及Fmax>300才发布；软件通过不等于PPA或采用完成，不热改／重启综合，不扩大其他候选。

## 2026-11-04：用户授权采用空FQ＋SA组合并开始全新综合，尚未正式发布

用户最新要求“采纳，并开始综合”。只对已审计单组合`fq-sa-combined-screen-20261104-r01/candidate`启动一次全新整核综合／ABC／STA及独立审计；精确复制44项RTL、公共SRAM、converted输入和原六项日志，无旧checkpoint继承，不热改运行中快照。同五ASAP7库、248 SRAM宏、2ns目标及INVx1／5fF约束。入口`sync/measure_fq_sa_combined_ppa.py`；根`.cpu2026-synthesis/fq-sa-combined-ppa-20261104-r01/`；独立审计`sync/audit_fq_sa_combined_ppa.py`，最终看对应证据根`finalization.json`。没有扩大其他候选／组合或恢复第28轮，也无额外面积专项，不算完整优化轮。

采用已获用户授权，但正式发布仍须新面积<36000、Fmax>300和软件资格通过，任何失败停止发布，不把用户授权或综合启动当采用完成。独立暂存两软件只同步空FQ原始返回上下文／单次消费和Store地址RS授权WB，主树只读comb旧快照／Input逐字段写目标，模板Register单写／统一sync保持；共13项构建输入变化、113项保持，不复制模块next-state，不恢复观察探针。将跑全新Release／断言四构建原六项答案／退休数／init+core+drain和外部副本退休PC／周期匹配RTL组合。

首轮软件暂存r01首次主树构建缺ICache完整类型include而失败，未标通过，原日志保留；r02仅补include，新根`.cpu2026-synthesis/fq-sa-combined-production-adoption-20261104-r02/`重跑四构建，入口`sync/validate_fq_sa_combined_software_r02.py`。综合RTL和既有资格保持。采用入口`sync/adopt_fq_sa_combined_after_qualification.py`用单次pidfd事件等两个服务退出，通过新PPA及软件证书／门槛后才备份、复制三项RTL／13项软件、原子发布正式指针并做发布后回归。

当前生产及两软件、正式指针尚为ROB Load身份版，镜像／Slave／旧黄金／既有code和三树HEAD／索引保持，未提交／推送。没有提前面积／Fmax／评分或采用成功结论，不拼接旧PPA。最终采用看`sync/evidence/fq-sa-combined-production-adoption-20261104-r02/finalization.json`；说明`sync/FQ-SA-COMBINED-PPA-ADOPTION-20261104.md`。本次单候选工作结束后综合恢复暂停。

## 2026-11-04：空FQ＋SA WB单组合筛选及独立审计完成，未综合／未采用

`fq-sa-combined-screen-20261104-r01`最终独立审计及收口核验通过。组合整核native环／锁存检查、组合快照上重跑实际FQ＋planner与Store RS两组native／converted独立oracle及四个有效源码负向、全新原六项native／converted答案／退休数／九字段架构退休匹配生产，两模型完整日志逐字节一致；独立raw退休／周期重数、源三文件精确并集、三组对比、保护输入与三树HEAD／索引保持核验通过。

最终组合周期8605/17550/3985/5864/155719/168501，几何IPC1.010966177065（相对生产+2.780824%），六项全部改善。对空FQ单独周期−1/−1/0/−47/−1/−31，IPC+0.139207%；对SA单独周期−484/−678/−9/−46/−8257/−27，IPC+2.608839%；三个基准逐项无退化，非叠加独立收益。长期IPC>1.0985仍未达。

精确复用已审计FQ的queue／frontend两项及SA的core一项，其余41项RTL与公共SRAM保持，不带入其他释放信用或已否决方案。最终证据`sync/evidence/fq-sa-combined-screen-20261104-r01/finalization.json`；完整证书／每候选审计与模型日志在`.cpu2026-synthesis/fq-sa-combined-screen-20261104-r01/`；说明`sync/FQ-SA-COMBINED-SCREEN-20261104.md`。

生产／两软件／正式指针／镜像／Slave／旧黄金／既有code及三树HEAD／Git索引保持，未综合／ABC／STA／采用，无新面积／Fmax／评分或IPC×Fmax结论，不拼接生产PPA，不算完整优化轮。单组合授权完成，不自动采用、恢复综合或扩大其他实验。以下阶段记录保留历史归属。

## 2026-11-04：空FQ＋SA WB组合IPC筛选通过，独立审计接续中（已完成，见上）

单组合`fq-sa-combined-screen-20261104-r01`执行通过：组合整核环／锁存检查、组合快照上重跑实际FQ＋planner与Store RS两组native／converted独立oracle及四个有效源码负向、全新原六项native／converted答案／退休数／九字段架构退休匹配生产，两模型完整日志逐字节一致。

组合周期8605/17550/3985/5864/155719/168501，相对生产−485/−678/−9/−104/−8258/−55，六项全改善。几何IPC1.010966177065，相对生产+2.780824%；相对空FQ单独−1/−1/0/−47/−1/−31，几何IPC+0.139207%，逐项无退化；相对SA单独−484/−678/−9/−46/−8257/−27，几何IPC+2.608839%，逐项无退化。三组对比均为原六项实测，非叠加独立收益。长期IPC>1.0985仍未达。

最终独立raw重数、源三文件精确并集、四负向、组件对比和保护核验仍在pidfd事件后接续，不提前声称审计完成。生产／两软件／正式指针保持，未综合／ABC／STA／采用，无新面积／Fmax／评分及IPC×Fmax结论，不算完整优化轮。完整数据见`sync/FQ-SA-COMBINED-SCREEN-20261104.md`；最终以`.cpu2026-synthesis/fq-sa-combined-screen-20261104-r01/finalization.json`为准。

## 2026-11-04：空FQ直通＋Store地址RS WB组合筛选启动，未综合／采用

用户在六项独立结果确认后要求“尝试二者组合”。只授权空FQ直通与Store地址RS WB数据旁路的单个组合正确性／IPC筛选，不授权综合或采用。已核验两个组件独立证书、输入哈希和逐项无退化资格，从当前ROB Load身份生产复制44项RTL；组合queue／frontend与已审计FQ逐字节一致，core与已审计SA逐字节一致，其余41项及公共SRAM保持，预检精确三文件并集通过。不带入LQ／SQ／ROB／owner／PRF信用或已否决方案，不改BPU算法／表、存储协议、容量或执行／写回／退休宽度。

组合不是独立正确性的自动继承：先整核native环／锁存检查，再在组合快照上重跑实际FQ＋rename planner及Store RS两组native／converted独立oracle与四个有效源码负向；通过后全新原六项native／converted答案、退休数、九字段架构退休匹配生产，组合两模型完整日志逐字节一致。逐项对比生产周期9090/18228/3994/5968/163977/168556、FQ单独8606/17551/3985/5911/155720/168532及SA单独9089/18228/3994/5910/163976/168528，不能把独立收益相加当作实测。

入口`sync/run_fq_sa_combined_experiment.py`；工作根`.cpu2026-synthesis/fq-sa-combined-screen-20261104-r01/`，候选在`candidate/`；独立审计`sync/audit_fq_sa_combined_screen.py`单次pidfd退出事件后接续，不轮询，核验raw日志重数、源复现／组件精确并集、四负向和三组对比。F盘独立服务和实际临时文件，持清理共享锁。最终以工作根`completion.json`／`finalization.json`及`sync/evidence/fq-sa-combined-screen-20261104-r01/`为准，执行中不提前认定通过或有收益。

生产／两软件／正式指针／镜像／Slave／旧黄金／既有code和三树HEAD／索引保持。没有综合／ABC／STA、面积／Fmax／评分或IPC×Fmax结论，不自动采用、不算完整优化轮，不扩大其他组合。说明`sync/FQ-SA-COMBINED-SCREEN-20261104.md`。下面独立六项的“不自动组合”仍归属其结束阶段；本组合由此次明确新请求授权。

## 2026-11-04：六旁路筛选及最终独立审计完成，未综合／未采用

`additional-bypass-sequence-20261104-r04`最终独立审计已完成。五个可测候选的实际模块native／converted独立oracle／两个有效源码负向及原六项全新native／converted答案、指令数、九字段架构退休匹配生产，两模型完整日志逐字节一致；独立raw退休／周期重数、源改写复现、保护输入和三树HEAD／Git索引核验通过。按哈希复用r01已审计Store地址RS成功及Store数据全CDB扩源阻塞，r01／r02／r03失败与生成C++保留，旧证书不回写。

最终结果：空FQ直通周期8606/17551/3985/5911/155720/168532，六项全改善，几何IPC1.009560796304（+2.637944%），本批最高无退化IPC；Store地址RS WB旁路周期9089/18228/3994/5910/163976/168528，几何IPC0.985262268387（+0.167612%），各项无退化。DCache请求槽信用周期9090/18228/3994/5969/163977/168551，几何IPC0.983591014278（−0.002298%），towers多1拍不推进；LSU owner、PRF退休回收均生产周期及IPC完全持平0.983613617806。Store数据全CDB扩源仍为工具依赖环阻塞，未测IPC，不计功能正确；不冒称所有扩源设计均不可能。

空FQ仅旧FQ／旧IQ均空时新包直通，整组分配或整组IQ回退，宽接口proposal与ready分离，真实上下文按实际接受出队，旧接口保持。DCache／owner／PRF功能RTL与首轮逐字节相同，修正的是夹具／负向入口，容量／协议断言一直开启。未组合SA＋FQ，不相加独立收益；长期IPC>1.0985仍未达，面积／频率未测，不能把IPC收益当作Fmax或评分收益。

最终证据`sync/evidence/additional-bypass-sequence-20261104-r04/finalization.json`；完整证书／原始日志与每候选审计在`.cpu2026-synthesis/additional-bypass-sequence-20261104-r04/`及引用r01根；说明`sync/ADDITIONAL-BYPASS-SCREENING-20261104.md`。发布后收口核验确认生产／两软件／正式指针／镜像／Slave／旧黄金／既有code及三树HEAD／索引保持，无组合／综合／ABC／STA／采用，无新PPA，不算完整优化轮。本次有限序列完成，不自动启动其他候选或恢复综合。以下阶段文字保留历史归属。

## 2026-11-04：六旁路原六项筛选结束，最终独立审计接续中（已完成，见上）

`additional-bypass-sequence-20261104-r04`原六项筛选执行结束，按哈希复用r01已审计Store地址RS成功及Store数据扩源阻塞，重新完成FQ／DCache／owner／PRF局部native／converted实际模块独立oracle、两个有效源码负向及原六项全新native／converted答案／退休数／九字段退休匹配生产，两模型完整日志逐字节一致。最终独立raw重数、源复现和保护审计正在pidfd事件后接续，不提前声称r04最终审计通过。

| 独立候选 | 六项周期变化（median／multiply／vvadd／towers／qsort／rsort） | 几何IPC | 相对生产 | 逐项不退化 |
|---|---|---:|---:|---|
| Store地址RS WB | −1／0／0／−58／−1／−28 | 0.985262268387 | +0.167612% | 是 |
| 空FQ直通 | −484／−677／−9／−57／−8257／−24 | 1.009560796304 | +2.637944% | 是 |
| DCache请求槽信用 | 0／0／0／+1／0／−5 | 0.983591014278 | −0.002298% | 否 |
| LSU运输owner信用 | 0／0／0／0／0／0 | 0.983613617806 | 0 | 是 |
| PRF退休回收信用 | 0／0／0／0／0／0 | 0.983613617806 | 0 | 是 |
| Store数据全CDB扩源 | 未跑：chooseResponseResultInner工具依赖环阻塞 | — | — | — |

空FQ周期8606/17551/3985/5911/155720/168532，六项全部改善，为本批最高无退化IPC者，仍未达长期几何IPC>1.0985目标。DCache虽正确但towers多1拍，故不推进。owner／PRF持平，不将局部满资源替换数当作整核节省拍数，亦不证明所有工作负载无收益。各项独立，未测试SA＋FQ组合，不能把两者收益直接相加。

生产／两软件／正式指针／镜像／Slave／旧黄金／既有code和三树HEAD／索引保持；未综合／ABC／STA、未组合、未采用，无新面积／Fmax／评分及IPC×Fmax结论，不算完整优化轮。最终看`.cpu2026-synthesis/additional-bypass-sequence-20261104-r04/finalization.json`，说明`sync/ADDITIONAL-BYPASS-SCREENING-20261104.md`。以下接续过程保留历史归属。

## 2026-11-04：六旁路首轮已审计，夹具／FQ接口修正后新根接续

首轮`additional-bypass-sequence-20261104-r01`六项均已实际尝试并独立审计。Store地址RS WB数据旁路通过实际RS native／converted独立队列oracle及两个有效源码负向；全新原六项native／converted答案、退休数和九字段架构退休序列匹配生产，两模型完整日志逐字节相同，独立raw退休／周期重数、源改写复现、保护及HEAD／索引核验通过。周期9089/18228/3994/5910/163976/168528，相对生产−1/0/0/−58/−1/−28；几何IPC0.985262268387（+0.167612%），各项不退化。没有综合，不能据此推断频率或评分。

其余首次尝试如实保留失败／阻塞：空FQ接ready门控的返回valid，形成ready→responseAccept→decodeCount→ready工具依赖环；Store数据RS全CDB扩源出现`chooseResponseResultInner`反馈，停止全开实现、不跑IPC、不屏蔽告警，也不证明所有安全扩源方法均不可能。DCache局部夹具过早假设backing返回时刻；owner正向多发已释放ID响应违反已有接口断言；PRF局部读地址任务数组接线未实际送入DUT，r02诊断显示外部地址32而读ready仍取P0。以上原始日志／模型／生成C++和r01证书保留。

FQ接续改宽接口proposal独立于ready，真实上下文仍按responseAccept出队，旧标量路径保持；r03整核lint无环，随后oracle条件函数非纯分支求值触发，r04将reference改纯函数并独立校验选中上下文。DCache改夹具为等待真实响应，r03实际native／converted满槽替换及630请求回归通过，第二负向被启用的RTL容量断言检出但入口期待旧文字，故仍停下、不标完整通过；r04接受真实断言诊断。owner移除正向非法重复响应但保持协议安全断言，r03实际native／converted满owner及原owner回归通过，后停在负向anchor不唯一，r04精确限定Load容量语句。PRF固定地址改genvar连续驱动，不改读路径，r03实际native／converted全部值／ready及两个负向通过；这些局部诊断没有原六项性能资格，不冒称整项完成。

经逐字节预检，DCache／owner／PRF功能RTL始终与r01一致，修的只是夹具／负向入口；FQ只增加其必要proposal／握手接线分离，不带入其他候选。r04新根`.cpu2026-synthesis/additional-bypass-sequence-20261104-r04/`只重做FQ、DCache、owner、PRF四项完整局部＋原六项native／converted筛选，按哈希复用已审计SA成功及SV阻塞，不回写旧证书。入口`sync/resume_additional_bypass_sequence_r04.py`；独立审计`sync/audit_additional_bypass_sequence_r04.py`单次pidfd退出事件接续，不轮询。

生产／两软件／正式指针／镜像／Slave／旧黄金／既有code和三树HEAD／索引保持；无新综合／ABC／STA、面积／Fmax／评分或采用许可，不将IPC变化当频率收益、不算完整优化轮。最终以r04 `finalization.json`为准，执行中不提前认定四项通过。首轮证据`sync/evidence/additional-bypass-sequence-20261104-r01/finalization.json`；说明`sync/ADDITIONAL-BYPASS-SCREENING-20261104.md`。

## 2026-11-04：其他六种旁路逐项筛选启动，生产／综合保持

用户在询问其他旁路机会后要求“都尝试一下，逐项尝试”。本次有限顺序为Store地址RS WB数据旁路、空FQ直通、DCache请求槽释放、LSU运输owner释放、PRF退休回收、Store数据RS扩大WB来源，每项独立从当前ROB Load身份生产复制44项RTL，不先混合改动。入口`sync/run_additional_bypass_sequence.py`；工作根`.cpu2026-synthesis/additional-bypass-sequence-20261104-r01/`；独立审计`sync/audit_additional_bypass_sequence.py`单次pidfd退出事件接续，不轮询。F盘独立服务和实际临时文件，持清理共享锁。

先整核native lint检查组合环／锁存，再局部真实模块native／converted独立oracle和有效源码负向，通过后才新建原六项native／converted模型，答案／退休数及九字段架构退休序列匹配生产，两模型完整日志逐字节一致。每项披露周期／IPC，单项退化不推进；有反馈环或其他失败则保留原始诊断，继续后续独立候选，不屏蔽告警。工具报告依赖环不是完整逻辑可敏化证明，也不是所有安全实现均不可能的结论。

空FQ直通限制在旧FQ和IQ都空，ready在此模式独立于valid／后端ready，新包整组分配或整组存IQ，不重复入FQ。DCache请求槽按真实旧释放且保持新分配写优先，不恢复已否决miss接续或字捕获。owner信用只来自真实live旧owner返回，取消不回收，满owner／同tag复用／旧取消响应和背压专项验证。PRF先旧free FIFO再普通退休批次，不复用恢复回收信用，不改已有值／ready及WB写优先级、不恢复被否决并行排名。Store地址／数据RS全CDB来源可能因共享Load反馈形成组合环，本轮会实际检查，不先假定可用。

生产／两软件／正式指针／镜像／Slave／旧黄金／既有code及三树HEAD／索引保持。不综合／ABC／STA，无候选面积／Fmax／评分，不把IPC变化当作频率收益、不拼接生产PPA、不自动采用、不算完整优化轮。说明`sync/ADDITIONAL-BYPASS-SCREENING-20261104.md`；最终看新工作根`completion.json`／`finalization.json`，执行中不提前认定通过。

## 2026-11-04：夜间释放／退休信用筛选与独立审计完成，未综合／未采用

指定有限序列已完成并独立审计。所有实际启动候选均局部native／converted真实模块队列oracle、有效源码负向及原六项全新native／converted答案、指令数和九字段架构退休序列等同生产，两模型完整日志逐字节一致。独立raw退休／周期重数、源改写复现、保护输入与三树HEAD／索引保持核验通过。

| 候选 | 六项周期变化（median／multiply／vvadd／towers／qsort／rsort） | 几何IPC | 相对生产 | 逐项不退化 |
|---|---|---:|---:|---|
| LQ释放 | 0／−1／−1／0／−1／−1 | 0.983665635992 | +0.005288% | 是 |
| SQ释放 | 0／0／0／+1／0／−5 | 0.983591014278 | −0.002298% | 否 |
| LQ＋SQ | 0／−1／−1／+1／−1／−6 | 0.983643031298 | +0.002990% | 否 |
| ROB退休 | 0／0／0／0／0／0 | 0.983613617806 | 0 | 是 |

SQ及LSQ组合均有towers多1拍，不满足此次逐项IPC不下降要求，故LSQ＋ROB组合未启动。最高无退化候选为LQ，但仅四项各少1拍，不能将局部信用／等待事件数当作整核节省。上述几何IPC变化与单项变化分别披露，不把LSQ几何提升说成六项都无退化。

首轮SQ／LSQ失败为局部真实模块仍启用旧容量断言、未扣同拍实际出队；r02仅修容量断言为减去真实旧Store下游接受，继续保留溢出门禁，SYNTHESIS内功能RTL逐字节相同，失败及原证书不回写。r01 LQ／ROB已审计资格在r02按哈希认证复用，新SQ／LSQ重新完整验证和审计。

最终证据`sync/evidence/release-credit-night-20261104-r02/finalization.json`；完整证书和逐候选记录在`.cpu2026-synthesis/release-credit-night-20261104-r02/`及r01原根，说明`sync/RELEASE-CREDIT-NIGHT-20261104.md`。生产／两软件／正式指针／镜像／Slave／旧黄金／既有code和三树HEAD／Git索引保持。未综合／ABC／STA，无候选面积／频率／评分或IPC×Fmax，不拼接生产PPA、不自动采用，不算完整优化轮。本次有限序列结束，不自动扩大其他实验或恢复综合。以下执行阶段记录保留历史归属。

## 2026-11-04：夜间信用筛选首批结果与SQ容量断言接续（已完成，见上）

第一批`release-credit-night-20261104-r01`已完成，独立审计通过并如实保留两项局部失败。LQ释放信用原六项周期9090/18227/3993/5968/163976/168555，相对生产0/−1/−1/0/−1/−1，几何IPC0.983665635992（+0.005288%），逐项不退化。ROB退休信用原六项完全持平9090/18228/3994/5968/163977/168556，几何IPC0.983613617806。局部native／converted实际模块队列oracle、有效源码负向、原六项答案／退休数／九字段退休及两前端完整日志一致通过；独立raw重数、源码复现、保护输入和HEAD／索引核验通过。证据`sync/evidence/release-credit-night-20261104-r01/finalization.json`，仅证明筛选，不是PPA。

SQ和LSQ组合首轮停在局部真实模块的原“Store allocation exceeds old SQ capacity”断言：它仍要求旧使用量＋新分配≤容量，未扣同拍真实出队。失败和原始候选完整保留，不标正确或形成组合。r02将断言改为旧使用量＋新分配−实际旧队首Store下游接受≤容量，保留断言并限制四宽／SQ复用开关，不能把ready或仅退休当作释放；经预检，`SYNTHESIS`范围内功能RTL与失败候选逐字节相同，未通过改变功能掩盖失败。

接续只重做SQ独立、LSQ组合，资格均满足后测试LSQ＋ROB组合；已审计LQ与ROB独立资格按哈希复用。入口`sync/resume_release_credit_night_r02.py`，工作根`.cpu2026-synthesis/release-credit-night-20261104-r02/`；独立审计`sync/audit_release_credit_night_r02.py`单次pidfd退出事件接续，不轮询。最终看r02 `completion.json`／`finalization.json`。生产／两软件／正式指针保持，无新综合／ABC／STA、面积／Fmax／评分或采用结论。

## 2026-11-04：夜间LQ／SQ释放及ROB退休信用旁路筛选（首批完成，接续见上）

用户要求先尝试LQ／SQ释放信用旁路，再尝试ROB退休信用旁路，今晚进一步优化。已建立有限顺序：LQ独立、SQ独立、LSQ组合，随后ROB独立；只有LSQ组合及ROB独立均正确且原六项逐项IPC不下降才测试最终组合。所有候选独立从当前已采用ROB Load身份行并行校验版复制44项RTL，生产和两软件先保持。工作根`.cpu2026-synthesis/release-credit-night-20261104-r01/`；入口`sync/run_release_credit_night.py`；独立审计`sync/audit_release_credit_night.py`。审计服务通过单次pidfd退出事件接续，不轮询，工作与临时文件都在F盘，持清理共享锁保护。

LSQ只改默认四宽：LQ实际ROB退休完整tag匹配返还旧槽，重复tag不重复计数、旧epoch不匹配；SQ只按旧队首Store实际下游接受返还一份信用，ready或仅退休不算释放。旧Store请求／转发及Load owner仍读旧态，新分配控制最终写入覆盖旧退休／响应／转发，保留真实新分配＋匹配地址事件，旧地址不能污染新槽；新项不许同拍发访存。ROB只用实际连续退休握手，沿用新分配高于旧完成／退休的写优先级，不改PRF回收或提交顺序。冻结／flush不授权分配，无新级／容量／执行宽度／BPU／访存协议变更。

计划先局部native／converted实际LSU／ROB队列oracle及源码负向，再原六项全新native／converted答案、退休数和九字段架构退休序列等同生产，候选两模型完整日志一致。逐项记录周期／IPC，退化项不推进，不将所有等待事件加总为节省拍数。失败完整保留，独立后续候选可继续，但失败项不进入组合。

此阶段只做正确性／IPC筛选，不启动综合／ABC／STA、不自动采用、不拼接旧PPA，无候选面积／Fmax／评分，不标完整优化轮。说明`sync/RELEASE-CREDIT-NIGHT-20261104.md`；最终以工作根`completion.json`、`finalization.json`及`sync/evidence/release-credit-night-20261104-r01/`为准，执行中不提前认定通过。

## 2026-11-04：正式采用ROB Load身份行并行校验版（优先于以下历史）

用户明确要求“可以，采用”，已采用`rob-load-identity-ppa-20261104-r01`。面积34629.246727 μm²、Fmax318.308984 MHz、六项几何IPC0.983613617806、评分2.484625496498e-07；相对上一生产IPC+0.000000%、面积-0.273049%、Fmax+5.377681%、评分+5.955512%。IPC×Fmax估算+5.377681%（不是墙钟实测）。本版为已审计评分最优、最高IPC并列中评分优胜者；排名不自动授权后续采用。
仅`rv32_rob_lanes.sv`独立Load lookup valid改为各行并行完整身份检查后归约；仍检查stored tag低位与常数row、query slot及高位epoch，非split输出全零。ROB全部状态写入和其他输出保持，无新流水级／接口／容量／执行宽度变化，不带入已否决PRF排名方案，不改PRF、RS信用、写回旁路、BPU、访存协议或Slave。整组IQ旁路、非MUL／DIV真实离站信用、前端恢复安全鉴权和后端冻结均保持。
44项RTL与公共SRAM同已审计候选逐字节认证；复用已有整核综合／ABC／STA，本次采用不重跑PPA。模型资格来自`rob-load-identity-screen-20261103-r02`的native／converted组合切片、实际ROB队列oracle、三个源码负向及原六项完整日志，测量根单独归属20261104；不声称另建生产路径RTL资格模型或完整状态／全输入形式等价。旧20261103中断展开记录保留，不冒称已完成或checkpoint续算。
此为RTL组合拓扑等价改写，两软件全部126项构建输入保持，无需改算法。两软件全新Release／断言四构建原六项答案／退休数／init+core+drain及外部观察副本退休PC／周期匹配；课程周期9090/18228/3994/5968/163977/168556。主树旧快照/Input纪律与模板Register单写／统一sync保持，不恢复生产观察探针。旧黄金、镜像、Slave、既有code及三树HEAD／Git索引保持。
面积<36000与Fmax>300通过，长期几何IPC>1.0985仍未达到。本次是既有已测候选采用，不算新优化轮；全部综合／ABC／STA继续暂停，不自动继续新候选。历史指标与否决记录保留，不伪称已清理历史源码／模型重新可用。
正式指针`sync/evidence/current-production.json`；证书`sync/evidence/rob-load-identity-production-adoption-20261104-r01/adoption.json`；软件说明`docs/hardware-baseline-rob-load-identity.md`。以下记录保留各自历史归属。

## 2026-11-04：ROB Load身份校验整核PPA与独立审计完成，未采用

同一候选`rob-load-identity-ppa-20261104-r01`已完成全新elaborate、六阶段checkpoint、整核综合／ABC／STA及独立Liberty逐叶面积、约束、时序和评分审计，无历史checkpoint继承。使用同五份ASAP7库、248项SRAM、2ns目标、INVx1／5fF约束；理想时钟、无寄生估计。精确复用`rob-load-identity-screen-20261103-r02`的44项RTL、公共SRAM、已验证converted输入和原六项资格，不声称新建RTL资格模型。

| 指标 | 当前生产 | ROB Load身份候选 | 变化 |
|---|---:|---:|---:|
| 面积 μm² | 34724.060467 | 34629.246727 | −0.273049% |
| Fmax MHz | 302.064897 | 318.308984 | +5.377681% |
| 六项几何IPC | 0.983613617806 | 0.983613617806 | 0 |
| 评分 | 2.344970490776e-07 | 2.484625496498e-07 | +5.955512% |

原六项答案、退休、native／converted完整日志均等同生产，周期9090/18228/3994/5968/163977/168556。面积<36000与Fmax>300通过，长期几何IPC>1.0985仍未达。按各自Fmax的IPC×Fmax估算+5.377681%，不是墙钟实测；只确认整核测量改善，不扩张为未经逐门认证的具体STA归因。

只改ROB独立Load身份valid归约，全部状态写入和其他输出源码保持，无新流水级；已否决PRF排名不带入，PRF、RS信用及其他模块保持生产。服务器重启前旧20261103测量仅部分elaborate，原样保留不标完成；本次在独立新根从头测量，中断归属见`interruption-provenance.json`。

生产RTL、两软件、正式指针、镜像／Slave／旧黄金／既有code及三树HEAD／Git索引均保持，未采用、不提交／推送。无额外面积专项，不算完整新优化轮。r14指标索引中本候选为已审计评分最优、最高IPC并列中评分优胜者，长期全部门槛无达标者；历史指标按旧认证保留，不声称恢复或重新认证已清理历史源码／模型，排名不构成采用许可。

本次授权完成，所有综合继续暂停，不自动继续新候选或采用。证书`sync/evidence/rob-load-identity-ppa-20261104-r01/finalization.json`；说明`sync/ROB-LOAD-IDENTITY-PPA-20261104.md`；指标`sync/evidence/best-results-retained-20261103-r14/retention.json`。以下阶段记录保留历史归属。

## 2026-11-04：重启后继续同一ROB Load身份候选综合（已完成，见上）

用户要求“继续综合”。已核验原六项native／converted完整日志及逐项周期／IPC完全等同生产，独立筛选审计通过，条件资格门收据已生成。服务器重启后旧条件服务inactive、MainPID0且没有运行中的综合进程；旧测量`.cpu2026-synthesis/rob-load-identity-ppa-20261103-r01/`只到RTL展开，`synthesis/opt/`仅有elaborate.log和elaborate.ys，尚无已提交阶段checkpoint，未完成PPA。

原尝试及其输入／日志全部保留不覆盖；重新认证旧输入和筛选证书后，在新根`.cpu2026-synthesis/rob-load-identity-ppa-20261104-r01/`从elaborate重新开始同一候选的整核综合／ABC／STA与独立审计。不是checkpoint恢复，不改变或重新筛选候选RTL；44项源码、公共SRAM及converted输入精确复用已通过的r02资格。入口`sync/continue_rob_load_identity_ppa_20261104.py`；同五份ASAP7库、248 SRAM、2ns、INVx1／5fF约束，F盘独立unrestricted服务，全程持清理共享锁。

中断归属单独记录于新根`interruption-provenance.json`；完成证据`sync/evidence/rob-load-identity-ppa-20261104-r01/`。原条件收据保留历史归属，不伪称旧测量已完成。生产／两软件／正式指针／镜像／Slave／旧黄金／既有code及三树HEAD／索引保持，不恢复已否决PRF排名、不启动其他候选、不授权采用、不标完整优化轮；本次完成后综合继续暂停。结果未出，不宣称面积／频率收益。

## 2026-11-03：用户条件授权ROB Load身份候选在IPC不变后综合（执行中）

用户明确要求“确认ipc不变后综合”。已建立仅针对此ROB候选的条件接续任务：单次pidfd进程退出事件等待`rob-load-identity-screen-20261103-r02`完成，不轮询、不停止／重启筛选；先通过`sync/audit_rob_load_identity_screen.py`独立审计，再逐项认证原六项native／converted完整日志、答案、九字段退休、周期及IPC严格等同生产，条件满足后才创建测量根并执行一次全新整核综合／ABC／STA。失败即止，不以几何IPC相等代替逐项无回退，不提前认定当前筛选通过。

入口`sync/qualify_and_measure_rob_load_identity_ppa.py`；条件授权及资格门收据`sync/evidence/rob-load-identity-conditional-ppa-20261103-r01/`；实际测量输出`.cpu2026-synthesis/rob-load-identity-ppa-20261103-r01/`，证据`sync/evidence/rob-load-identity-ppa-20261103-r01/`。使用相同五份ASAP7库、248项SRAM、2ns目标、INVx1／5fF约束，全新elaborate／六阶段checkpoint；不继承历史checkpoint，不声称重跑已复用的RTL资格模型。整段任务持清理共享锁，工作和实际临时文件均在F盘。

此授权不含生产采用、恢复已否决PRF并行排名或其他候选；生产／两软件／镜像／Slave／旧黄金／既有code／正式指针及三树HEAD／索引保持。无额外面积专项，不标完整优化轮；授权完成后所有综合恢复暂停。尚无候选面积／频率结论，下方筛选阶段“未综合”不回写。

## 2026-11-03：继续研究其他频率路径，ROB Load身份校验隔离筛选（执行中）

用户要求“继续探究其他优化关键路径频率的方法”。此新请求授权其他路径的分析与隔离筛选，不撤销PRF并行排名的明确否决，不授权新综合或采用。生产仍为RS信用旁路版；既有原六项IPC不得下降，面积<36000及Fmax>300仍记录为后续PPA门槛。

本次比较ROB晚到Load存活查询、DCache回填鉴权与LSU返回转发优先级三处源码组合依赖；后两者只做分析，未实现／测试，不将generic依赖描述为STA中间门逐门定位。说明`sync/FREQUENCY-ALTERNATIVES-20261103.md`。先选择最小ROB方向：独立Load查询由“选出stored tag后比较”改为各行并行valid／完整身份校验后归约，不新增级或接口，不依赖stored tag低位天然等于row；所有ROB状态写入和其他输出源码保持，不改PRF、RS信用或其他模块。

隔离输出`.cpu2026-synthesis/rob-load-identity-screen-20261103-r02/`；入口`sync/run_rob_load_identity_screen_r02.py`；审计入口`sync/audit_rob_load_identity_screen.py`。计划局部native／converted单行状态／query穷举、多行随机、实际ROB队列oracle及三个源码负向，再验证原六项全新native／converted完整日志、答案、九字段退休、周期严格等同生产。r01因候选局部变量matches为SV保留字而解析失败，失败保留；r02仅改名rowMatch，不改逻辑。结果未出不提前声称通过，未综合／ABC／STA，无候选面积／频率，不自动继续其他候选或采用。

## 2026-11-03：用户明确否决PRF并行分配排名候选，不采用

用户在获知Fmax280.317547 MHz（−7.199562%）、面积34697.714407 μm²（−0.075873%）、IPC持平和评分−7.058581%后明确要求“不采用”。拒绝`prf-parallel-rank-ppa-20261103-r01`及对应`prf-parallel-rank-screen-20261103-r03`，不将本候选替换生产，不自动继续该方案、其他优化或综合。当前RS信用旁路生产、两软件及正式指针保持，生产输入／软件桥接与三树HEAD／Git索引核验不变；测量和审计证据保留。

否决记录`sync/evidence/prf-parallel-rank-rejected-20261103-r01/decision.json`。最优指标索引r13仅追加否决决定，测量行与champions逐项沿用r12；PPA和筛选两根均加入`rejected_roots`，排名不是采用许可。此前PPA完成证书、报告、指标和哈希均不回写。未新测量／新建模型／启动综合，全部综合继续暂停。以下“建议不采用”保留测量完成时的历史归属，此节用户明确决定优先。

## 2026-11-03：PRF并行分配排名PPA与独立审计完成，频率退化／未采用

用户在得知原六项native／converted完整日志、周期与IPC持平后要求“开始综合”，本次仅授权`prf-parallel-rank-ppa-20261103-r01`一次全新整核综合／ABC／STA及独立Liberty逐叶面积、约束、时序和评分审计。入口`sync/measure_and_finalize_prf_parallel_rank_ppa.py`；精确复用`prf-parallel-rank-screen-20261103-r03`的44项RTL、公共SRAM与已验证converted输入，不热修改候选，不重复声称新建资格模型；全新elaborate和六阶段checkpoint，不继承历史checkpoint。同五份ASAP7库、248项SRAM实例、2ns目标及INVx1／5fF约束，进程工作与临时文件均在F盘，独立unrestricted用户服务运行。

已完成全新整核综合／ABC／STA、六阶段checkpoint与独立Liberty逐叶面积、约束、时序和评分审计。结果如下：

| 指标 | 当前生产 | 并行排名候选 | 变化 |
|---|---:|---:|---:|
| 面积 μm² | 34724.060467 | 34697.714407 | −0.075873% |
| Fmax MHz | 302.064897 | 280.317547 | −7.199562% |
| 六项几何IPC | 0.983613617806 | 0.983613617806 | 0 |
| 评分 | 2.344970490776e-07 | 2.179448842261e-07 | −7.058581% |

原六项周期9090/18228/3994/5968/163977/168556及完整日志均保持。面积<36000通过，但Fmax>300不通过，长期IPC>1.0985仍未达；本次未实现频率优化，建议不采用。按各自Fmax估算IPC×Fmax下降7.199562%，不是墙钟实测。源码中的并行排名不保证映射后的整核关键路径更短，不将此次回退归因于未经认证的具体中间门。

任务输出`.cpu2026-synthesis/prf-parallel-rank-ppa-20261103-r01/`；最终证书`sync/evidence/prf-parallel-rank-ppa-20261103-r01/finalization.json`；说明`sync/PRF-PARALLEL-RANK-PPA-20261103.md`。生产／两软件／镜像／Slave／旧黄金／既有code／正式指针与三树HEAD／索引保持，未采用；无额外面积专项，不标完整优化轮。测量和最终审计全程持清理共享锁。最优指标索引r12只追加本次认证指标，不读取或伪称恢复已清理历史源码／模型；各最优指标归属未变。单候选授权已完成，全部综合继续暂停，不恢复第28轮或自动继续其他候选。筛选阶段记录中的“未综合”保留其当时归属。

## 2026-11-03：频率关键路径诊断与PRF并行分配排名筛选通过，未综合／未采用

用户要求“开始优化频率的关键路径，不要降低ipc”。从当前RS信用旁路生产建立独立候选，不恢复已清理历史源码，不改生产或两软件。当前整核综合／ABC／STA继续暂停；本次先做诊断与正确性／IPC筛选，不宣称新面积或频率，也不自动采用。

现存PPA的`design.json`、`mapped.v`、`generic.json`、`critical_paths.json`已对已完成独立审计中的哈希认证。以匿名cell全数排序及类型逐项匹配，确认STA起点`_635495_/QN`是`u_axi_data.writeHeadOwnerInner[0]`（别名`writeHeadSlotInner[0]`）；最差五条均终止于PRF第26行SRAM的写数据位10～14，首条到达3.210 ns，当前生产Fmax302.064897 MHz。原始generic网表存在AXI写响应→DCache填充资格→Load返回／ROB鉴权→共享CDB→整数RS的既有写回旁路／实际离站信用→整组重命名接受→PRF串行分配排名及写优先级的组合依赖。**generic最长门数依赖路径不是STA中间门的逐门归因，也未证明整条可敏化，不能把其门数当作时序实测。**诊断入口`sync/record_current_frequency_path.py`；证据`.cpu2026-synthesis/current-frequency-path-20261103-r01/diagnosis.json`。

首个最小候选只改隔离副本的`rv32_prf_lanes.sv`：每lane以原始valid前缀人口计数直接取得目的寄存器rank，独立比较旧free credit，不再等待较老lane的接受计数；free-head按独立常数步数候选选择，保留非二次幂回绕函数。保持所有接口、容量、流水级、写优先级、未ready载荷、上一沿写旁路以及RS信用／WB旁路语义，不取消同拍复用。局部native／converted完整PRF公共端口、1／2／4宽全部稀疏mask×低信用96项独立oracle通过，另检查全部64个PRF值（含未ready）、reset／freeze／recovery／tag复用／WB冲突优先级；包含自身的错误rank、忽略free credit、丢失free-head推进三个实际源码负向均检出。

`prf-parallel-rank-screen-20261103-r01`因常数head候选数组跨元素连续赋值触发Verilator `UNOPTFLAT`门禁而停止；失败、原始候选和日志保留，没有压制告警。r02将每个常数步数候选独立从旧free-head计算，候选已改；r02接续脚本因Python `log`变量遮蔽，在首次测试前停止，其预备源码和记录保留。r03只修启动入口，44项候选RTL与r02逐字节相同，重新完整验证。

原六项全新native／converted答案、退休数、九字段退休和完整日志均与当前生产逐字节相同，周期**9090/18228/3994/5968/163977/168556**，几何IPC **0.983613617806（完全持平）**。独立重数审计、源改写复现、44项源码及保护输入完整性、三树HEAD／Git索引保持核验通过。当前生产、两软件、镜像／Slave／旧黄金／既有code及正式指针均未改变。

未启动综合／ABC／STA，无候选面积、Fmax、评分或IPC×Fmax结论，不拼接旧PPA，不算完整优化轮，不自动采用。继续保持综合暂停，待用户重新授权该候选测量。入口`sync/run_prf_parallel_rank_screen_r03.py`；审计`sync/audit_prf_parallel_rank_screen.py`；说明`sync/PRF-PARALLEL-RANK-SCREEN-20261103.md`；源码、模型、原始trace、失败和审计证据位于`.cpu2026-synthesis/prf-parallel-rank-screen-20261103-r03/`，最终状态为其中`finalization.json`。

## 2026-11-03：正式采用非MUL／DIV全RS信用旁路版（优先于以下历史）

用户在知悉频率／评分代价后要求“采纳到生产”，已采用`rs-credit-reuse-ppa-20261103-r01`。面积34724.060467 μm²、Fmax302.064897 MHz、六项几何IPC0.983613617806、评分2.344970490776e-07；相对上一生产IPC+0.169731%、面积-0.275521%、Fmax-2.654867%、评分-1.449979%。IPC×Fmax估算-2.489642%（不是墙钟实测）。本版是已审计最高IPC候选，不是评分最优版；旧评分最优指标与审计记录保留，历史源码／仿真模型／网表缓存按用户清理授权处理，不承诺仍完整存在。
仅Store地址RS补开实际离站信用同拍复用；整数／Branch／Load／Store数据RS原已开启并保持，MUL／DIV仍不复用。共享AGU必须实际选中并接受旧Store地址指令才能返还SA信用，不能把Load获胜或仅有ready候选算作SA离站。新分配写入优先于旧释放，不允许新项同拍派发；不增加写回当拍数据旁路，Store地址RS仍只看旧就绪。
两软件默认四宽同步同一实际AGU离站信用；仅主树StaticArbiter与模板CPU功能接线变化，两个RS文件只更新注释。主树只读拍初快照/Input逐字段写目标，模板Register单写／统一sync保持；无模块下一状态复制。不改容量、执行／写回／退休宽度、BPU算法／表、存储协议或Slave，不恢复已否决Store地址通知Load数据、回填字捕获、DCache miss接续或第28轮方案。原整组IQ旁路、前端恢复安全鉴权与后端冻结保持。
44项RTL及公共SRAM与已审计候选逐字节认证，复用已完成的整核综合／ABC／STA，本次不重跑综合，也不声称另建生产路径RTL模型。模型资格来自`rs-credit-reuse-screen-20261103-r02`的native／converted、七池列表oracle、共享AGU及三个有效负向；PPA归属独立测量目录，不冒称完整状态／全输入等价。
两软件全新Release／断言四构建原六项答案／退休数／init+core+drain和外部观察副本退休PC／周期匹配；课程周期9090/18228/3994/5968/163977/168556。采用阶段与缓存清理互斥；旧黄金、镜像、Slave、既有code和三树HEAD／Git索引保持；当前验收使用专用生产检查器，不套历史黄金周期。
面积<36000和Fmax>300通过，长期几何IPC>1.0985未达。此次是已测候选采用，不算新优化轮次。所有综合／ABC／STA继续暂停，不恢复第28轮或自动继续优化；历史指标索引只重绑定新生产，不伪称已删历史源码／模型仍可复核。
正式指针`sync/evidence/current-production.json`；证书`sync/evidence/rs-credit-reuse-production-adoption-20261103-r01/adoption.json`；软件说明`docs/hardware-baseline-rs-credit-reuse.md`。以下数字保留各自历史归属。

## 2026-11-03：历史实验缓存、源码副本与仿真模型清理完成

用户先要求删除综合产物缓存，随后明确范围为“除了本次综合任务以外的，然后不保留源码和仿真模型，但是做process.md的记录”。本次一次性清理覆盖工作区`.cpu2026-synthesis/`内的旧实验，不沿用“保留最近三个”的数量豁免；删除旧综合网表／checkpoint／工具中间产物、实验源码副本、仿真模型及构建缓存。实际生产RTL、两软件工作树、课程镜像、Slave、旧黄金、既有code及Git数据库／索引不在删除范围；历史指标摘要、审计证书与退休trace保留。
本次`rs-credit-reuse-ppa-20261103-r01`及对应筛选资格`rs-credit-reuse-screen-20261103-r02`保留，其综合、ABC、STA与独立审计现已正常完成，未被清理中断或重启。原先审计仍需读取的历史候选依赖先延后，清理程序在收到当前服务完整退出事件后接续处理，不轮询、不停止当前任务；工具链和本次新建临时文件不删。清理严格限定F盘实验根，逐文件写入路径／大小／SHA256删除清单后才unlink；不批量修改旧manifest或伪装成原始数据仍在。
清理后，下面历史“源码／模型／网表继续保留”的文字只代表原实验完成时的状态，不再表示现在可用；旧测量与当时的审计结论保留，但已删文件不能重新逐字节验证，也不自动恢复。若以后继续优化，须从实际生产代码及当时仍可用的资产建立新的可复核输入，不能把历史指标或哈希当成原始数据仍存在。
执行入口`sync/clear_experiment_cache.py`；本次已正常完成。共删除**91,163个文件、41,319,993,256字节（文件逻辑大小，约41.32 GB）**；完成时F盘可用47,417,081,856字节，前后可用空间增量不能全部归因于清理，期间本次综合仍产生新文件。两阶段SHA256 intent／deleted清单逐项配对重数通过，62个删除路径抽样均不存在；当前PPA和筛选资格各44项RTL仍在。此复核不是对所有残余文件的穷举扫描。
授权、逐文件SHA256清单、分阶段统计及完成收据：`.cpu2026-synthesis/historical-cache-clear-20261103-r01/`中的`authorization.json`、`immediate-completion.json`、`after-current-task-completion.json`、`completion.json`与`verification.json`。生产、指标摘要、审计证书与退休trace未纳入删除。当前资格／PPA目录、实际工具链和本次新建临时文件作为明确例外保留；源文件已清掉的历史索引只保留当时认证的指标，不再冒称其源码／模型仍可逐字节复核。

## 2026-11-03：RS信用旁路补齐PPA与独立审计完成，未采用

用户“开始综合”所授权的单候选`rs-credit-reuse-ppa-20261103-r01`已完成全新整核综合／ABC／STA、六阶段checkpoint及独立Liberty逐叶面积、约束、时序和评分核验。精确复用`rs-credit-reuse-screen-20261103-r02`的44项RTL、公共SRAM及原六项native／converted资格，不继承旧checkpoint，不声称重跑模型。仅补开Store地址RS实际离站信用复用，其余非MUL／DIV池保持已开，MUL／DIV及所有写回数据旁路开关不变。

| 指标 | 本候选 | 相对当前生产 |
|---|---:|---:|
| 面积 | 34724.060467 μm² | −0.275521% |
| Fmax | 302.064897 MHz | −2.654867% |
| 六项几何IPC | 0.983613617806 | +0.169731% |
| 评分 | 2.344970490776e-07 | −1.449979% |

原六项周期9090/18228/3994/5968/163977/168556，towers少61拍、rsort少1拍，其余不变。按各自Fmax估算IPC×Fmax为−2.489642%，不是墙钟实测。面积<36000、Fmax>300通过，长期几何IPC>1.0985仍未达；候选是已审计最高IPC，当前整组IQ旁路生产仍为评分最高，不自动采用。
生产RTL、两软件、镜像／Slave／旧黄金／既有code和三树HEAD／索引保持。本次仅既有候选PPA补测，没有新增面积专项，不标完整新优化轮次。单候选综合授权已完成，所有综合恢复暂停，不恢复第28轮或继续其他候选；缓存清理另按上节明确授权执行，本候选及资格目录保留。
说明`../../sync/RS-CREDIT-REUSE-PPA-20261103.md`；正式完成证书`../../sync/evidence/rs-credit-reuse-ppa-20261103-r01/finalization.json`；最优指标索引`../../sync/evidence/best-results-retained-20261103-r10/retention.json`。最优索引不构成生产采用许可，历史源码可用性受上节清理授权约束。

## 2026-11-03：正式采用空IQ整组旁路版（优先于以下历史）

用户在知悉面积／频率代价后要求“采用生产”，已采用`iq-whole-group-ppa-20261103-r01`。面积34819.996867 μm²、Fmax310.303030 MHz、六项几何IPC0.981946949077、评分2.379472345843e-07；相对上一生产IPC+2.807266%、面积+0.387729%、Fmax-1.151515%、评分+9.573112%。IPC×Fmax估算+1.623425%（不是墙钟实测）。本版为已审计评分及IPC最高候选，旧生产和旧评分最优版继续保留。
旧IQ为空时展示旧FQ译码整组，候选展示不依赖后端ready；仅全部有效lane都能分配时授权全部RAT／PRF／ROB／RS／LSQ目标并跳过IQ写入，否则分配数零、整组入IQ。IQ非空保持原连续前缀；按实际有效条数，不要求凑满四条。两软件同步同一门控与单次消费语义，主树只读旧快照/Input逐字段写目标，模板Register单写／统一sync保持；无模块下一状态复制。
保留前端恢复冻结解耦、安全响应鉴权及后端恢复冻结；不改BPU算法／表、访存、容量、执行／写回／退休宽度。不是部分整组旁路，不带入已否决DCache miss接续、接受沿回填字捕获、Store地址通知或第28轮候选。
44项RTL及公共SRAM与已审计候选逐字节认证，复用已完成整核综合／ABC／STA，不重跑综合，也未另建生产路径RTL模型。模型资格来自`iq-whole-group-screen-20261103-r01`的native／converted、局部合同及三个负向控制；PPA归属独立测量目录，不冒称完整状态等价。
两软件全新Release／断言四构建原六项答案／退休数／init+core+drain及外部观察副本退休PC／周期匹配；课程周期9090/18228/3994/6029/163977/168557。旧黄金、镜像、Slave、既有code及三树HEAD／Git索引保持；使用当前生产专用检查器，不套历史黄金周期。
面积<36000与Fmax>300通过，长期几何IPC>1.0985仍未达到。此次为已测候选采用，不是新优化轮次。单候选PPA授权已完成，综合／ABC／STA继续暂停，不恢复第28轮、不自动继续优化。
正式指针`sync/evidence/current-production.json`；证书`sync/evidence/iq-whole-group-production-adoption-20261103-r01/adoption.json`；软件说明`docs/hardware-baseline-iq-whole-group.md`。以下数字均保留各自历史归属。

## 2026-11-03：正式采用前端恢复冻结解耦版（优先于以下历史）

用户在知悉评分和频率代价后要求“应用到生产”，采用`frontend-recovery-decouple-ppa-20261103-r01`。面积34685.510947 μm²、Fmax313.917842 MHz、六项几何IPC0.955133800420、评分2.171584154117e-07；相对上一生产IPC+0.185873%、面积+0.125295%、Fmax-0.735745%、评分-0.245794%。IPC×Fmax估算-0.551240%（非墙钟实测）。本版是已审计IPC最高版，不是评分最优版；评分最优旧生产仍完整保留。
恢复期间继续禁止未知／控制包的新预测请求，按实际返回指令鉴权安全非控制响应，并允许安全FQ→IQ推进；后端分配／派发／写回／退休仍冻结。两软件同步同一门控语义，保留旧快照/Input逐字段写目标和模板Register单写／统一sync纪律。不改BPU预测／训练算法或表、队列容量、存储协议、Slave；不恢复已否决回填字捕获或Store地址通知，不带入第28轮候选。
44项RTL及公共SRAM与已审计候选精确同源，复用其整核综合／ABC／STA，本次采用不重跑综合，也未另建生产路径RTL模型。模型资格来自`frontend-recovery-decouple-screen-20261103-r01`的native／converted及局部定向／负向验证；测量归属独立PPA目录，不冒称新生产路径重建或完整状态等价。
两软件全新Release／断言四构建原六项答案／退休数／init+core+drain及外部观察副本退休PC／周期匹配；课程周期9570/18946/3995/6126/174053/168587。旧黄金、镜像、Slave、既有code、三树HEAD／Git索引保持，专用当前生产检查器验收，不套旧黄金周期。
面积<36000和Fmax>300通过，长期几何IPC>1.0985仍未达到。本次是已测候选的采用，不是新优化轮次。综合／ABC／STA保持暂停；此前单候选综合授权已完成，不恢复第28轮或自动继续优化。
正式指针`sync/evidence/current-production.json`；采用证书`sync/evidence/frontend-decouple-production-adoption-20261103-r01/adoption.json`；软件说明`docs/hardware-baseline-frontend-decouple.md`。以下数字均保留各自历史归属。

## 2026-11-03：采用评分最优生产版；全部综合暂停（优先于以下历史）

用户要求“暂停所有综合任务，将评分最优应用于生产即可”，已采用`round27-lq-address-area-20261103-r01`。面积34642.106287 μm²、Fmax316.244595 MHz、六项几何IPC0.953361761030、评分2.176934924387e-07；相对上一生产IPC+1.415615%、面积-0.104184%、Fmax-0.154416%、评分+5.840915%。IPC×Fmax估算+1.259013%（非墙钟实测）。
采用奇字位置双取指（跨8字节对齐对、不跨I$行、最早控制指令截断）及LQ结果/地址载荷去复位；valid/就绪/身份控制仍复位。不是三Load仲裁组合版，不含第28轮年龄门禁或SQ地址候选；Store位置表仍4项、Store地址/数据RS仍2项、Branch RS仍4项。不改预测/训练算法或表，不恢复被否决字捕获或Store地址通知。
44项RTL及公共SRAM与已审计候选逐字节认证，复用该版本已审计PPA，本次不启动任何综合/ABC/STA。两软件只同步fetch2包几何与恢复时控制截断（模板适配位于BPU.cpp的fetchGroup，不改predict/训练）；保留无效载荷初始化的表示差异，不声称完整状态等价。
两软件全新Release/断言四构建原六项答案/退休数/init+core+drain及外部副本退休PC/周期匹配；课程周期9607/18947/3995/6126/175315/168588。未另做生产路径RTL模型重建；采用资格来自精确同源候选native/converted完整日志和局部契约。
所有综合已暂停；未经用户重新授权，不恢复第28轮或启动新优化综合。第28轮面积任务在dff-map中止，checkpoint/失败与既有产物保留，整轮不标完成。面积/频率门槛通过，长期IPC>1.0985仍未达到；旧黄金/镜像/Slave/既有code、三树HEAD及Git索引保持。
正式指针`sync/evidence/current-production.json`；证书`sync/evidence/score-best-production-adoption-20261103-r01/adoption.json`；软件说明`docs/hardware-baseline-score-best.md`。以下历史数字保留原归属。

# 架构探索过程（2026 年八月底至 11 月 7 日）

主线：**软件原型 → 周期合同 → SRAM/面积收敛 → 单宽调度与关键路径 → 双宽 → 四宽双 ALU → 同源PPA与生产采用 → 逐拍瓶颈优化**。本文统一保留关键实验结论与取舍；[architecture.md](architecture.md)、[assessment.md](assessment.md)、[course.md](course.md)保留各自标注日期的架构、方法及验收范围，最新生产与候选状态见本文后续章节及正式生产指针。

## 记录来源

- 8～9 月：同级 `RV32IM_Simulator/` 的 Git 历史，不是本硬件仓库的提交历史。
- 9 月 23 日起：本仓库提交及阶段文档；迁移后 commit 时间集中在 10 月 14 日，按 author date 和阶段记录排序。
- 10～11 月细分实验：本目录及同级 `sync/README.md`、`CPU-SYNC-SPEC.md`、版本化采用/审计证书。后续工作含未提交改动，不虚构提交号；同级目录与实验工件不随克隆提供。

## 8～9 月：建立硬件式周期模型

| 阶段 | 决策与依据 |
|---|---|
| 8-26 | TAGE、取指预译码训练 RAS（`a2c61f3`）；已有 I$、LQ/SQ、RAT/PRF/ROB 及恢复。 |
| 8-30～31 | 迁移 `Register/Wire/work()/sync()`（`03828f0`），读拍初、写拍末；统一 epoch＋slot 完整 ROB tag（`3f17f30`）。周期漂移按实际错误修复，不接受隐含软件执行顺序旁路。 |
| 9-01～03 | 引入 64 KiB/4 路/16 B 行写回 D$（`8b20648`）、改 PLRU（`76da3c4`）；I$ 冷缺失为主，未升级两路。 |
| 9-05～13 | ALU/Load 独立双 CDB（`cbc6a0e`）、Booth/CSA 流水乘法（`a11c47f`）、SRT radix-4 除法及第四 CDB（`b2cb0d8`）。并行执行/写回不等于多发射。 |
| 9-18～23 | 收紧循环和身份宽度，支持非二次幂编码；PRF 收至 48、checkpoint 收至 32（`3ef79f9`）。 |
| 9-20～23 | TAGE→Tournament（`3e13e55`），删除当时语料无收益的间接 Target Cache（`8db1ed7`），GHR16→8、压缩 BTB 对齐位（`3ef56bf`、`e310f2f`）；不推广为任意负载均无收益。 |
| 同期 | 退役 MDP Load 违例恢复：未知更老 Store 阻塞准入；伪 SARAS 改为提交/投机 RAS，后续恢复重放完整栈。建立 RTL 计划（`feb764a`、`59243da`），先单发射正确性、再多宽扩展。 |

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

10-16 课程接入提交为 `71c7421`，10-18 面积收敛提交为 `61ba5e6`。下面阶段主要来自工作区快照与外部实验记录，不把它们伪装成已提交里程碑。

## 10 月 20 日：双提交、窄控制与缩容边界

先扩宽退休：ROB连续旧ready前缀，RAT/PRF/LSU/RAS共同消费退休lane；本拍写回不旁路退休，退出Store截断年轻lane。双提交不等于双重命名或双整数执行。

同容量实现优化逐步从宽索引/串行选择转向局部控制：Load请求与结果的平衡年龄选择、RAT SRAM局部写使能、转发覆盖检查窄化、SQ本字/邻字预计算、D$返回ID早选、I$使能表达式重构。局部RTL变“短”不保证整核Fmax提高：Q2空槽预选仅改善约1 ps却增面积，放弃；Store选源树、进位摘要、邻居前缀和SQ8→4也因整核回退撤回。部分被撤回实验仅完成18或21个课程程序，不记作25例全通过。

合法RV32IM/对齐控制转移成为明确输入边界，删除RTL异常检测、传播与trap状态；该变更功能域收窄，但映射面积略增、频率下降，不能称天然PPA优化。

容量最终先选BTB64→32、取指/AXIFetch信用8→4，保持完整PC tag和运输身份；面积降至约24,164 μm²，六perf IPC约0.553333。原两软件/golden不改，对拍使用对应容量的私有副本。

来源：[双提交](../../sync/DUAL-COMMIT-20261020.md)、[SQ4否决](../../sync/LSU-DEPTH4-20261020.md)、[无异常域](../../sync/RTL-NO-EXCEPTIONS-20261020.md)、[BTB/取指容量](../../sync/FETCH4-AREA-20261020.md)。

## 10 月 21 日：调度、Load ABC 与双取指

1. **调度先行**：Branch RS2→4，Integer/Branch旧项支持授权WB当拍派发、实际离站同拍复用；恢复仍遍历完整原ROB窗口，但处理完可提前结束。IPC提高，Fmax下降，采用是明确的IPC/结构权衡，不称吞吐全面改善。
2. **Load ABC**：D$旧hit消费与下一lookup重叠、AGU交付地址当拍发Load、合法Cache返回当拍参加CDB。IPC升至约0.639255，但初版出现SQ→I$片选跨模块长链，频率仅约232.52 MHz。
3. **切断晚控制链**：I$物理读使能提前，不让后端ready控制片选；缓冲Load结果先选最老，再与迟到返回只比一次年龄，转发资格提前共享。无新流水级，整核约322.93 MHz；额外闲置读的功耗没有测量。
4. **双取指packet_first**：I$行内预译码，在8 B包内最早控制流截断，用一个BPU查询；FQ拆包、每条CID，译码/重命名当时仍单宽。IPC约0.648484，频率下降使估算吞吐比父版低约0.59%；接受该回退是为建立宽前端能力。

取指/提交随后改为独立静态宽度参数，不用运行时开关。来源：[RS](../../sync/RS-PRESSURE-IPC-20261021.md)、[Load ABC](../../sync/LOAD-ABC-20261021.md)、[时序收口](../../sync/FREQUENCY-TARGET-20261021.md)、[双取指](../../sync/DUAL-FETCH-FIRST-CFI-20261021.md)。

## 10 月 22～24 日：固定容量的物理实现优化

以当时双取指、单译码/分配、双提交配置为基线，先比较RS/RAS容量，再转向固定容量逻辑。Integer最终取4、Branch保留4、RAS16→8；Branch3虽有合格数据，未因缩容评分更高就覆盖固定容量路线。

- AXI按槽提前比较完成位、缓存队头物理槽，避免顺序环→描述符间接索引。
- Integer/Branch用并行年龄关系、一热选源和WB mask因式分解，ALU加减共享网络。
- D$在同步读沿保存offset/size、响应一热选择、将迟到hit从宽仲裁中提出。
- BRU仅保留实际使用的六种条件分支通路，PC+4用窄增量；BTB分字段写、flush有序队头直读、双字包地址利用对齐不变量。

测试要求周期/profile与父版相同，再比较完整顶层PPA；不从单模块门数或综合网名直接推断整核瓶颈。评分从早期IPC²×Fmax转为IPC⁶×Fmax/Area³，决定只对当时目标有效。单译码冻结组合达到约24,262 μm²、352.62 MHz，不能套给后来的双/四宽。

来源：[逻辑优化](../../sync/IPC2-FMAX-OPT-20261022.md)、[BRU专用化](../../sync/BRU-CONDITIONAL-ONLY-20261024.md)、[冻结组合PPA](../../sync/LOGIC-PPA-20261024.md)。

## 10 月 25～26 日：双译码、双分配与木桶优化

双译码先建立逐指令FQ、已译码prefix IQ和连续消费信用；奇偶分银行写、信用分类、D$字节终点快照、AXIFetch计数mux降低控制开销。随后打通双路RAT/PRF/ROB/七池RS/LSQ共同分配，支持组内RAW/WAW、LINK即就绪及双Load/双Store入队，**不增加ALU/AGU/数据请求口**。

同配置双分配令六perf IPC约0.660200→0.735362，首次PPA面积约26,172 μm²，超过当时25,000上限；后来面积门槛改为27,000后再继续路径优化，不能回写旧报告为“当时已达标”。PRF写mask、CDB晚到比较bit选择与D$响应身份组合进一步改善物理评分。

以六perf最弱项为目标逐轮优化：Load RS授权WB派发/复用、chooser按PC索引、纯局部预测、一位局部历史、三位饱和计数器、PC/历史拼接、空队列Load接受沿同步读。纯局部版虽有IPC回退但当时面积评分更优；两位历史未胜一位方案，不采纳。第七轮双宽IPC约0.758905，median仍最弱，改预测和读时序比盲目加容量更有效。

双AGU独立实验确实交付了第二地址，但median周期不变、六项几何IPC略降，**拒绝该同池批量双地址方案**，没有继续为它跑完整PPA；不推广为所有双AGU都无收益。

来源：[双分配](../../sync/RTL-DUAL-RENAME-20261025.md)、[木桶路线](../../sync/PERF-BOTTLENECK-LOOP-20261026.md)、[双AGU](../../sync/DUAL-AGU-20261026.md)、[接受沿读](../../sync/MEDIAN-DCACHE-ACCEPT-20261026.md)。

## 10 月 26～27 日：四路分配与预测/数据侧重新同步

四译码/四分配采用数组RAT/PRF/ROB和统一前缀规划器，ROB32/PRF64/CKPT64、FQ8/IQ8；RS/LSQ稀疏请求按本池排名认证，真实消费者共用fire。先以fetch2/commit2验收，实际decode4/issue4和ROB占用>16均出现；六perf IPC约0.798448，相对双宽提高5.21%，**包含容量扩容，不是纯宽度收益**。直接扩容的双宽PPA候选超当时面积上限且降分，未采用；四分配功能启用不等于已完成四取指/四提交。

预测侧重新采用真实Tournament：LHT256×1、local256×3、global/chooser各256×2，并将预测时局部历史和两分量预测加入checkpoint；训练不能用解析时上下文代替。D$64→128组成为8 KiB，完整容量/脏写回oracle与生产复验通过。旧软件主树保留，模板建立独立实测表，不能再默认两树周期相同。

双向同步把RTL已有的接受沿同步读、Load RS真实WB旁路/复用移回模板。critical-word部分行早返回则只在隔离候选验证；紧凑版虽功能通过，但频率/IPC未过新门槛，未带入生产。当前仅保留**完整行到达后的**early restart。

来源：[四分配贯通](../../sync/FOUR-LANE-INTEGRATION.md)、[BPU/D$采用](../../sync/ADOPT-BPU-DCACHE-20261027.md)、[双向同步与早返回否决](../../sync/MUTUAL-OPT-SYNC-20261027.md)。

## 10 月 28～29 日：完整四宽、双 ALU 与默认切换

先在隔离快照打通4/4/4/4：16 B包边界和首控制流截断、最多128 bit取指、按实际1～4条分配CID，四退休贯通RAT/PRF/LSU/RAS；保留单AGU、Load/Store RS各2。恢复每拍槽数随ROB容量派生，ROB32为8槽，最多四拍；四取指恢复期间保守停取。

三种四宽对照均只跑六个原始perf与独立退休ISA，不扩大成全量资格：

| 执行/写回方案 | 六perf core周期几何IPC | 结论 |
|---|---:|---|
| 单ALU、两CDB | 0.829014 | 四宽真实握手已贯通，执行仍单整数口。 |
| 双ALU、共享整数CDB | 0.829644 | 旧结果竞争严重，仅小幅收益，并有单例回退。 |
| 双ALU、各自CDB，第三路共享Load/MUL/DIV | 0.859878 | 比共享整数CDB提高约3.64%，真实双算术/三路同拍写回均出现。 |

10月29日明确选择最高已验证IPC候选作为生产默认，采用4/4/4/4、双ALU三写回、8 KiB D$；不是自动通过PPA筛选。默认课程入口重新lint/构建后六perf通过，课程退出计时IPC为0.858428，和上表core周期边界不同。

完整顶层综合在展开/TECHMAP遇到工具兼容与资源问题，多轮中断曾误归于“重启”，后以内核日志确认OOM。随后隔离资源、分阶段/分批断点、原生文件系统及低内存续接；静态化pool路由只做独立局部实验，未混入采用源码。**截至10月29日，正式PPA暂停，没有有效最终面积/Fmax**，不能拿旧2442或2222结果为新4444背书。后续补测见下文，不回写这一历史阶段为当时已经通过。

当时性能政策改为：Area<30,000 μm²、Fmax>300 MHz、六perf IPC>0.865，评分IPC⁴×Fmax/Area²；均须同配置实测且严格满足。当时IPC仍低于门槛，已采用不等于已达标。

来源：[四宽接入/资源诊断](../../sync/SUPERSCALAR4-BRINGUP-20261028.md)、[默认采用凭据](../../sync/evidence/superscalar4-production-adoption-20261029-r01/adoption.json)、[性能政策](../../sync/PERFORMANCE-POLICY.md)。

## 10 月 30～31 日：新测量epoch与完整整核PPA

用户决定不恢复缺失的Linux旧实验数据，以当前生产源码建立F盘独立测量epoch。新的源码副本、构建、模型、trace、网表、checkpoint和工具临时目录统一进入 `.cpu2026-synthesis/`；旧结果只保留历史归属，不冒称已恢复。后续已审计基线采用 **fetch2/decode4/allocation4/commit4、双ALU/三写回、单AGU、ROB32/PRF64/CKPT64、FQ8/IQ8、8 KiB D$**，不能与10月29日四取指结果混用。

`production-baseline-20261031-r01`完成原六项native/converted及全新整核综合/ABC/OpenSTA，独立审计面积 **35603.510308 μm²**、Fmax **324.153213 MHz**、几何IPC **0.863669235770**。这是新epoch实测，不是为早期四取指快照补写PPA；按其当时Area<30000策略仍未达标。

后续每轮要求面积专项与IPC候选先独立实现、验证和整核PPA，不能因IPC持平或下降跳过面积专项。最新推进条件为面积严格 **<36000 μm²**、六项几何IPC提高，继续记录 **Fmax>300 MHz**、长期几何IPC **>1.0985**和 `IPC⁴×Fmax/Area²`。综合大产物只保留最近3次，活动及待首次审计任务延后清理；源码、模型、trace、指标和审计出处继续保留。

来源：[存储与新epoch边界](../../sync/EXPERIMENT-STORAGE.md)、[新基线独立审计](../../sync/evidence/production-baseline-20261031-r01/completed-audit-r01/completion-audit.json)、[迭代合同](../../sync/ITERATIVE-OPTIMIZATION.md)。

## 11 月 1～2 日：PRF、Store位置复用与正式生产收敛

下面均为各自当时明确采用的历史版本，不把它们的IPC与其他版本PPA拼接：

| 阶段 | 采用内容与取舍 | 面积 μm² | Fmax MHz | 六项几何IPC |
|---|---|---:|---:|---:|
| 第17轮 | PRF值载荷使用63个1×32 SRAM，保留P0、写优先级及旁路合同 | 34584.063307 | 315.270936 | 0.903890966873 |
| 第18轮 | 局部预测计数器等价翻转实现；IPC持平，采用较小的物理评分收益 | 34617.305707 | 317.815022 | 0.903890966873 |
| 第19轮 | 两项Store命中位置元数据，复用此前确认的Cache命中way，省掉重复标签查询 | 34734.558067 | 307.599880 | 0.923231817701 |
| 第20轮 | PRF共享写优先级仲裁；用户拒绝更大面积的重定时版 | 34590.361867 | 316.440049 | 0.923231817701 |
| 第21轮 | 新接受Load可越过不同行的排队Store提前查询，旧查询/写入优先级不变；median回退已披露 | 34587.314647 | 308.805790 | 0.930507527921 |
| 第22轮 | 按用户要求删除Store地址就绪通知旁路，保留Load地址查询SQ及Store数据通知 | 34433.947627 | 326.843281 | 0.930507527921 |
| Store位置表4项 | 仅位置元数据2→4，Store地址/数据RS仍2项、Branch RS仍4项 | 34678.235527 | 316.733684 | 0.940054209024 |

Store位置表4项是最低无效项优先、已有同行原位训练、victim取训练项后一项，**不是精确四项LRU**。相对第22轮，IPC +1.025965%，但Fmax −3.093102%、评分 −0.471751%，按各自Fmax估算IPC×Fmax −2.098872%（不是墙钟实测）；披露代价后按授权采用。44项RTL及公共SRAM同源认证、原六项native/converted完整日志、两软件Release/断言四构建与外部退休PC/周期对照均通过；不扩大为任意输入完整状态等价。

两个未采用方向保留：第23轮当前/前一拍回填字复用被用户明确否决，不以收益更小的当前字版替代；Store地址/数据RS 2→4和Branch RS 4→8仅完成局部及六项native筛选，未做整核PPA，也未带入生产。后者说明有容量压力不等于扩容一定提高整核IPC。

**截至11月3日正式生产仍为Store位置表4项版**，六项课程周期为 `9338/19591/4278/6127/177204/168587`（median/multiply/vvadd/towers/qsort/rsort）；面积、频率通过，长期IPC目标未达。正式身份以 [`current-production.json`](../../sync/evidence/current-production.json) 为准。

来源：[第19轮采用](../../sync/STORE-LOCATION-PRODUCTION-20261101.md)、[PRF共享写采用](../../sync/PRF-GLOBAL-WRITE-PRODUCTION-20261101.md)、[Load提前查询采用](../../sync/DISJOINT-LOAD-PRODUCTION-20261102.md)、[第23轮否决](../../sync/ROUND23-MEMORY-20261102.md)、[参数筛选](../../sync/PARAMETER-SCREENING-20261102.md)、[4项位置表正式采用](../../sync/STORE-LOCATION4-PRODUCTION-20261102.md)。

## 11 月 2～3 日：逐拍瓶颈诊断与第25轮奇字双取指

诊断不只按指令比例猜瓶颈：median的退休Load返回→CDB均无额外拍，关键比较分支就绪后很快派发；towers的1074拍顺序资格等待中，SRAM始终在做其他访问，不是1074个闲置读机会。后者在保留其他资格时严格仅Store写口拒绝为0、仅回填写口拒绝为1拍，不能据此宣称物理端口不构成约束或删除门禁必然提速。

multiply实际执行的是移位/条件加法循环，没有MUL指令。`0x120`的3200次BEQ均在其ANDI生产者派发后一拍派发，就绪后额外等待为0；条件加法484次也均入站后一拍派发。633次退休条件分支误预测中，位测试分支贡献524次、循环分支102次。观察支持先改善供给/控制开销，而不是扩大乘法器或RS。

第25轮在当前生产上独立测量两项候选：

1. **奇字位置双取指**：允许两条连续指令跨8字节对齐对，但不跨I$行尾，仍截止最早控制流指令；不改BPU。例如从`0x124`起的add/srai/slli/bne可由三次请求变两次，不代表整核必然节省一拍。
2. **BRU载荷面积专项**：保留valid复位，受valid保护的载荷仅在接受时覆盖；无效载荷不要求为零。有效输出契约、复位/冻结/冲刷/tag回绕及负向控制独立验证。

两项均完成原六项native/converted、答案/退休数/九字段退休序列核对、整核PPA与独立Liberty叶实例面积重算。服务器重启后，取指候选从**本轮同一测量**已认证DFF checkpoint接续ABC/STA，不冒称再次从RTL重跑，也不复用其他历史候选PPA；面积候选复用既有正确性资格，首次执行独立整核综合。测试台随机选择、转换typed-port和接续参数问题的失败记录均保留，未据此修改候选RTL。

| 版本 | 面积 μm² | Fmax MHz | 六项几何IPC | 评分 |
|---|---:|---:|---:|---:|
| 正式生产 | 34678.235527 | 316.733684 | 0.940054209024 | 2.056799041947e-7 |
| 奇字双取指候选 | 34742.970727 | 312.480928 | 0.953361761030 | 2.138555515103e-7 |
| BRU载荷面积候选 | 34471.738987 | 309.739867 | 0.940054209024 | 2.035552533509e-7 |

奇字双取指相对生产：面积 +0.186674%、Fmax −1.342691%、几何IPC +1.415615%、评分 +3.974937%；IPC×Fmax仅估算提高 **0.053917%**，不是墙钟实测。面积专项实际省206.496540 μm²，但Fmax −2.208106%、评分 −1.032989%，IPC持平。两项**未组合、未替换正式生产或同步两软件**；两者均未达到长期IPC目标。

| 原六项 | 生产周期 | 奇字双取指周期 | IPC变化 |
|---|---:|---:|---:|
| median | 9338 | 9607 | −2.800042% |
| multiply | 19591 | 18947 | +3.398955% |
| vvadd | 4278 | 3995 | +7.083855% |
| towers | 6127 | 6126 | +0.016324% |
| qsort | 177204 | 175315 | +1.077489% |
| rsort | 168587 | 168588 | −0.000593% |

multiply的633次退休误预测及736/866拍flush/恢复均未减少；有退休的周期由14139降至13510，同样21722条指令退休更集中，不能把收益描述成预测改善或IQ空拍减少。该候选成为后续实验基线不等于生产采用许可。按用户最新方向，后续优先分析IPC最高的rsort，而非自动套用此前最弱项策略。

来源：[median诊断](../../sync/MEDIAN-LOAD-BRANCH-20261102.md)、[towers顺序等待复核](../../sync/TOWERS-REQUEST-ORDER-20261102.md)、[multiply瓶颈](../../sync/MULTIPLY-BOTTLENECK-20261102.md)、[第25轮对比](../../sync/ROUND25-MULTIPLY-20261102.md)、[双取指审计](../../sync/evidence/round25-multiply-odd-fetch-20261102-r01/completed-audit-r01/completion-audit.json)、[面积专项审计](../../sync/evidence/round25-bru-payload-area-20261102-r02/completed-audit-r01/completion-audit.json)。

## 11 月 3 日：第26轮rsort仲裁与LQ结果载荷专项

按用户方向选择IPC最高的rsort，在第25轮奇字双取指实验基线上定位散布循环入口`0x1f0`：2048条退休Load累计占据38502个队首等待周期，其中22831拍尚未被Cache接受。观察器完整日志与已审计模型逐字节一致，退休源生产者、物理端口与请求资格均复核。分析器漏认的既有pending-load字捕获路径另补地址/MSHR/前拍返回证明，不是恢复被否决的当前/前拍接受请求捕获优化。

本轮两个独立候选均完成原六项native/converted、局部端口契约及负向控制、全新整核综合/ABC/STA与独立Liberty叶实例面积复算：

| 版本 | 面积 μm² | Fmax MHz | 六项几何IPC | 评分 |
|---|---:|---:|---:|---:|
| 第25轮实验基线 | 34742.970727 | 312.480928 | 0.953361761030 | 2.138555515103e-7 |
| 单Load有界仲裁 | 34765.642627 | 309.739867 | 0.950332085529 | 2.090249622906e-7 |
| LQ结果载荷去复位 | 34753.395427 | 315.757015 | 0.953361761030 | 2.159680159578e-7 |

仲裁在一次Store接受后允许一个普通Load提前入Cache，要求SQ有效行地址全部已知/对齐/不同行/非MMIO，并保留原消歧和Store发送顺序。六项周期为`9607/18945/3994/6244/174672/169272`：qsort改善，但rsort增加684拍、towers增加118拍；几何IPC−0.317789%、评分−2.258809%，不推进。

独立逐拍对照证明提前入Cache确实发生5573次；`0x1f0`队首等待减少27269拍，但后续`0x1f4/0x1f8`分别增加14609/10120拍，全体队首Load等待只少28拍，有退休的周期增加775拍。不能把一个PC的等待减少当作整核周期收益，亦不能把Store优先等待改成Cache背压当作问题消失。

面积专项只取消LQ 8×32位结果数据的复位，控制复位与原响应/SQ转发覆盖优先级保留。**实测未省面积**（+10.424700 μm²、+0.030005%），但六项完整日志持平、Fmax+1.048412%、评分+0.987800%，保存为评分最优实验版；最高IPC与第25轮并列。相对正式生产，几何IPC+1.415615%、评分+5.002001%，仍未达到长期IPC门槛。

局部测试台关键字、sv2v端口打平及黄金struct层次访问失败均保留，仅修正测试台桥接。两候选未组合、未替换生产、未同步软件。后续实验可从评分最优版验证连续Load分组供给，但新的未测假设不计入本轮收益。

来源：[rsort瓶颈](../../sync/BEST-RSORT-BOTTLENECK-20261103.md)、[第26轮测量](../../sync/ROUND26-RSORT-20261103.md)、[仲裁退化复核](../../sync/ROUND26-SHARE-REGRESSION-20261103.md)、[完成证书](../../sync/evidence/round26-completion-20261103-r01/completion.json)。

## 11 月 3 日：第27轮三Load分组供给与地址载荷专项

本轮从第26轮LQ结果载荷实验版独立派生：仲裁信用扩大为一次Store接受后最多三个普通Load，零信用仍Store优先；面积候选只取消LQ 8×32位地址数据的复位，原分配/地址身份与恢复边界不变。两者均完成局部native/converted及负向控制、原六项完整日志/九字段退休序列、全新整核综合/ABC/STA及独立叶实例面积复算。

| 版本 | 面积 μm² | Fmax MHz | 六项几何IPC | 评分 |
|---|---:|---:|---:|---:|
| 三Load有界突发 | 34655.607367 | 304.761905 | 0.953794290234 | 2.100063965662e-7 |
| LQ地址载荷去复位 | 34642.106287 | 316.244595 | 0.953361761030 | 2.176934924387e-7 |

三Load版相对本轮实验父版本：面积−0.281377%、Fmax−3.482143%、几何IPC+0.045369%、评分−2.760418%，按各自Fmax估算IPC×Fmax−3.438354%（非墙钟实测）。六项周期`9594/18909/3990/6185/174049/168513`；rsort少75拍、qsort少1266拍，但towers多59拍（IPC−0.953921%）。满足推进的IPC/面积/频率条件，保留为IPC最高实验版，不隐去频率及评分代价。

地址专项六项完整日志与父版本持平，实测省111.289140 μm²（−0.320225%）、Fmax+0.154416%、评分+0.798950%，成为评分最高实验版。两个冠军分开保留，均未达到长期IPC目标，也均未采用生产或同步软件。不能把一个的IPC与另一个的PPA拼成“组合结果”。

收口首次误指向旧第26轮报告，保护断言在覆盖前阻止写入；接续只修正新报告路径，并认证复用已经发布的精确最优索引，不重跑仿真或综合、不改旧报告及已审计输入。后续若组合两项，须另建源码、独立验证并实测整核PPA；仍不自动替换生产。

来源：[第27轮测量](../../sync/ROUND27-RSORT-20261103.md)、[完成证书](../../sync/evidence/round27-completion-20261103-r01/completion.json)。

### 第27轮组合补验：相同IPC下改善物理代价

两项独立审计完成后，另建组合源码进行原六项native/converted、局部三Load契约与负向控制、全新整核综合/ABC/STA及独立叶实例面积复算。组合面积 **34519.663447 μm²**、Fmax **306.311696 MHz**、几何IPC **0.953794290234**、评分 **2.127400942691e-7**；六项完整日志与三Load父版本逐字节一致。相对三Load父版本面积−0.392271%、Fmax+0.508525%、评分+1.301721%，IPC持平；相对地址专项评分最优版仍下降2.275400%，没有宣称两个方向同时最优。

初始保留器在IPC并列时按枚举顺序留下三Load父版本。随后另建保留器，只在实测IPC完全相等时优先较高实测评分，因此最新最高IPC代表为物理代价更好的组合版，评分冠军仍为地址专项。旧索引、旧保留器及全部测量不改，不改变门槛或采用许可。该补验不是新完整优化轮次，正式生产和两软件仍不变。

来源：[组合补验](../../sync/ROUND27-COMBINATION-20261103.md)、[并列选择凭据](../../sync/evidence/best-results-retained-20261103-r04/tie-resolution.json)。

## 11 月 4 日：PRF／ROB面积结构四项隔离筛选（执行中）

用户根据当前diagnose层次报告要求按顺序开始实验：PRF上一拍转发优先级共享、PRF读译码重组、ROB载荷复位分离、ROB单行SRAM载荷＋4组共享最近写记录。四项各自从当前生产工作树快照出发，不组合，不改变容量、宽度、访存或BPU，不恢复已否决PRF排名。

旧实验工作根已清空，不能复用旧模型；此次新建native／converted基线及原六项九字段退休日志，随后每项做环／锁存检查、局部双模型公开端口差分与独立数据／队列oracle、两个有效源码负向，再新建原六项双模型并重数raw日志。当前frontend用户格式与等宽截取修复独立记差异，不回写工作树。生产／两软件／正式指针和三树HEAD／索引保持。

四项局部源码／夹具lint预检通过，不当作运行时正确性或IPC资格。服务启动首次因本机不支持MemoryOOMGroup属性被拒，尚未启动实验；移除该属性，使用已有OOMPolicy=kill及资源检查器接续，失败单独保留。新工作根`.cpu2026-synthesis/rename-area-sequence-20261104-r01/`，说明`sync/RENAME-AREA-SCREENING-20261104.md`；最终看`sync/evidence/rename-area-sequence-20261104-r01/finalization.json`。

本次只筛选，综合／ABC／STA继续暂停，无新面积／Fmax／评分，不自动采用，也不计作完整优化轮。执行中不提前宣称通过或面积收益。

### PRF／ROB四项筛选最终收口

四项全部局部native／converted公开端口差分＋独立oracle、各两个有效RTL负向和原六项全新双模型完成。四项周期均`8605/17550/3985/5864/155719/168501`，几何IPC均 **1.010966177065**，逐项与本次新基线持平；答案／退休数／九字段架构退休匹配，native／converted完整日志一致。PRF各局部模型12843次检查，ROB各局部模型2136拍含取消项历史replay和工作后reset。

原r01服务在全测量结束后的审计前缀比较中失败：read-decode新增两行解释注释未排除。原失败脚本、inputs和job保持，新增r02只读审计仅修源码边界，另核全部步骤日志哈希、负向原因与答案；未改RTL／模型／测量，未重跑构建、仿真或综合。最终证书`sync/evidence/rename-area-sequence-20261104-r02/finalization.json`通过，工作根保留r01归属。保护输入／正式指针及三树HEAD／Git索引核验通过。

这是面积结构的正确性／IPC筛选，不是面积实测：无新面积／频率／评分，不能据此认定省面积或排名。生产和两软件不改，全部综合／ABC／STA继续暂停；本有限序列结束，不自动组合／采用／继续其他实验。

### PRF／ROB四项逐项整核PPA获授权（执行中）

用户进一步要求“开始逐项综合”，仅授权上述四项按原序各一次新整核opt综合／ABC／STA，不授权组合或采用。新根`.cpu2026-synthesis/rename-area-ppa-sequence-20261104-r01/`精确复制r02筛选已认证44项RTL、converted和IPC资格；不重跑仿真，各自从elaborate开始、六checkpoint、无历史checkpoint继承。同AppImage／五库／2ns／INVx1与5fF、原理想时钟无寄生口径；前三项248原宏，ROB SRAM项另外32个1×129宏亦全额计价。

逐项独立Liberty逐叶面积／宏形状／约束／阶段／STA／原六raw退休与评分审计，通过后追加cleanup-aware指标，历史否决和指标不回写；生产对比仅据保留认证记录，不恢复已删原始网表。四项结束全部综合恢复暂停，生产和两软件不改，不自动组合／采用／清理。入口和说明见`sync/RENAME-AREA-PPA-20261104.md`；最终以同名证据根finalization.json为准，执行中不提前认定面积收益。

### PRF／ROB四项独立PPA完成，未采用

四项各自全新elaborate、六阶段checkpoint、整核opt展平、ABC和STA及独立逐叶Liberty面积／实际宏／约束／raw退休／评分审计全部通过。同源复用此前已认证native／converted资格，IPC均1.010966177065、六周期均`8605/17550/3985/5864/155719/168501`；本次未重复仿真，无旧checkpoint或旧PPA拼接。

| 独立候选 | 面积 μm² | Fmax MHz | 评分 | 相对生产面积 | 频率 | 评分 |
|---|---:|---:|---:|---:|---:|---:|
| PRF上一拍转发共享 | 34683.207307 | 307.322929 | 2.668719718965e-7 | −0.067845% | −0.210084% | −0.074542% |
| PRF读译码 | 34754.824267 | 308.526665 | 2.668142463234e-7 | +0.138504% | +0.180777% | −0.096156% |
| ROB载荷复位分离 | 34238.371507 | 313.341493 | 2.792146575072e-7 | −1.349543% | +1.744186% | +4.546957% |
| ROB单行SRAM载荷 | 33700.451751 | 268.414155 | 2.468769102511e-7 | −2.899442% | −12.844037% | −7.561337% |

第三项同时省468.382500 μm²并提频，面积／频率通过，是本次推荐者；第四项更省面积但频率失败，不建议采用。原248宏及新增32个1×129宏（第四项280例）均全额计价，转发／initialized和控制开销已包含。r21–r24追加已审计指标并保留历史否决，r24面积／频率合格评分冠军为第三项；长期IPC目标仍未达。历史生产比较依据既有认证记录，不声称已删原始网表恢复。

最终证书`sync/evidence/rename-area-ppa-sequence-20261104-r01/finalization.json`，报告`sync/RENAME-AREA-PPA-RESULTS-20261104.md`。生产／两软件／正式指针与三树HEAD／Git索引保持，未采用、组合或提交推送。该有限授权结束，全部综合／ABC／STA恢复暂停，不自动继续候选、采用或清理，不计作完整新优化轮。

## 11 月 5～6 日：从ROB复位分离到LSU通知提前计算

11月4日面积结构筛选后，用户明确采用ROB载荷复位分离，生产随后沿Load下一行预取、安全Load让行、标准RAS分类、SQ完成事件旁路及LSU通知资格提前计算逐项演进。下表各行为**分别已认证并获采用的版本**，不是把独立候选收益相加，也不是为旧筛选补写PPA。

| 采用版本 | 面积 μm² | Fmax估计 MHz | 原六项几何IPC | 评分 |
|---|---:|---:|---:|---:|
| ROB载荷复位分离 | 34238.371507 | 313.341493 | 1.010966177065 | 2.792146575072e-7 |
| Load触发下一行预取 | 34417.443067 | 307.138572 | 1.035819497011 | 2.984787940536e-7 |
| SQ≤4／owner=0安全Load让行 | 34506.745567 | 314.399754 | 1.043690365779 | 3.133003593523e-7 |
| 标准同link JALR只push | 34614.841687 | 313.437404 | 1.059446088949 | 3.295653702718e-7 |
| 旧SQ完成事件旁路 | 34465.105087 | 306.770521 | 1.063329023912 | 3.301604769298e-7 |
| LSU通知资格提前计算 | 34699.405687 | 316.146959 | 1.063329023912 | 3.356723806268e-7 |

### 先观察再改动：RAS分类与median的Store完成链

- **towers RAS观察**：在SQ4／owner0生产5849拍／5278条退休的同源双模型上，仅外部观察得真实函数返回68次，其中34次实际使用RAS且34次全对；投机／架构峰值深度均1，容量为8。该结果不支持先扩RAS。随后修正标准RISC-V同link规则：`pop = rs1Link && rd != rs1`、`push = rdLink`，同link仅push，异link才pop后push；不改变RAS容量或恢复节奏。新原六`8021/16993/3953/5477/146370/161853`，towers少372拍，multiply少413拍，qsort多1拍；几何IPC+1.509617%，但Fmax−0.306091%，采用时披露了频率代价。
- **median完成链观察**：标准RAS生产median为8021拍／6961条退休，互斥无退休分类中队首Store未ready共816拍；其中320拍旧SQ地址／数据已齐但ROB仍未ready，另248拍数据已齐而地址在当沿真实到达。这些是旧执行流的观察拍数，不能直接相加当作可省周期。候选只把旧有效未提交SQ的完整身份真实事件纳入完成bitmap，仍由ROB寄存ready、下一拍读旧ready退休，不提前实际Store接受，不恢复已否决的Store地址→Load数据通知。
- **SQ事件旁路实测**：原六变为`7676/16908/3984/5509/147475/162806`，median少345拍（IPC+4.494528%），整体几何IPC+0.366506%；vvadd／towers／qsort／rsort分别多31／32／1105／953拍。PPA面积−0.432579%、Fmax−2.127022%、评分+0.180573%；IPC×Fmax估算−1.768312%，没有把局部省拍包装成整体吞吐必增。

来源：[towers RAS画像](../../sync/TOWERS-RAS-PROFILE-20261106.md)、[median机会与完成链](../../sync/MEDIAN-OPPORTUNITIES-20261106.md)、[SQ完成事件筛选](../../sync/STORE-COMPLETION-EVENTS-RESULTS-20261106.md)。各版本的正式采用记录见本文件前部，不将旧观察数当成当前四取指的重新画像。

### 未进入生产的独立候选：全核仲裁与ROB普通查询

全核仲裁有限九项均从当时SQ4／owner0生产独立筛选：AGU Load／Store年龄窗4偏向、共享CDB两种偏向、AXI AR I∶D／D∶I各2∶1、Cache查询Load让行一次、需求miss发送Load／Store优先一次。两模型局部消费者oracle、18个有效RTL负向与每候选原六374104条九字段退休审计通过，但收益不支持任意叠加：

| 独立策略 | 相对当时基线几何IPC | 截至本次更新的结论 |
|---|---:|---|
| AGU Load年龄窗4偏向 | −0.657787% | 未采用／未综合 |
| AGU Store年龄窗4偏向 | −0.796057% | 未采用／未综合 |
| 共享CDB两偏向、需求miss发送两偏向 | 均持平 | 原六实际争用有限，不等于全输入无收益证明 |
| AXI AR I∶D=2∶1 | +0.142158% | 有限集合中最高；未采用／未综合，rsort仍多1拍 |
| AXI AR D∶I=2∶1 | −0.000633% | 未采用／未综合 |
| Cache合法查询Load让行一次 | +0.053741% | 未采用／未综合，含单项退化 |

SQ完成旁路采用后，又尝试ROB**普通**查询逐行并行身份校验；它不同于此前已采用的独立Load lookup身份校验。原六周期／完整双模型日志持平，但新整核PPA为面积34454.520007 μm²、Fmax303.587311 MHz、评分3.269353492373e-7：面积仅−0.030712%，Fmax−1.037652%、评分−0.976836%。因此没有采用；用户未明确否决，不能把“建议不采用”改记成用户拒绝，更不能由源码并行性宣称提频成功。

来源：[全核仲裁九项汇总](../../sync/CORE-ARBITRATION-RESULTS-20261106-r02.md)、[ROB普通查询PPA](../../sync/ROB-REGISTERED-IDENTITY-PPA-RESULTS-20261106.md)。这些版本没有与后续RAS、LSU通知或跨16B四取指组合。

### LSU通知资格提前计算：同周期下改善频率

最终选择LSU返回通知优先级组合拓扑：旧LQ×SQ常数行先算同START同WIDTH／ROB年龄及年轻未知地址或同word屏障，晚到SV／返回身份仅选择一个资格位。保留原notify函数、全部SQ／LQ状态写入、完整转发载荷、SQ完成旁路和owner取消；不改变事件语义、流水级或软件算法。

每模型619252组任意旧态检查、真实LSU差分与六个有效RTL负向，以及新原六双模型完整日志／九字段退休通过。原六周期完全保持`7676/16908/3984/5509/147475/162806`，几何IPC仍为1.063329023912。一次新整核PPA实测面积+0.679820%、Fmax+3.056499%、评分+1.669462%；两软件126项构建输入无需改变，仍做全新Release／断言四构建及外部退休PC／周期资格后采用。这成为11月7日四取指实验的**精确当前生产双取指基线**，不是更早四取指的历史配置。

来源：[LSU通知筛选](../../sync/LSU-NOTIFY-PRECOMPUTE-RESULTS-20261106.md)、[新PPA](../../sync/LSU-NOTIFY-PRECOMPUTE-PPA-RESULTS-20261106.md)、[采用证书](../../sync/evidence/lsu-notify-precompute-production-adoption-20261106-r01/adoption.json)。历史PPA报告的“未采用”归属测量阶段，随后明确授权的采用以证书为准。

## 11 月 7 日：跨16B四取指的三方案对照、PPA与生产采用

### 1. 先隔离边界收益，不混用旧四取指数据

用户要求“能否和当前的双取指一样尝试可以跨16字节对齐边界”。以刚采用的LSU通知提前计算双取指为基线，新建同源16B受限四取指`aligned4`控制及跨16B候选`cross16`，不恢复或套用10月29日的旧四取指PPA。

两种四取指均只先将pkg默认FETCH2→4，沿既有128位数据路径、两请求包槽和派生8条在途指令信用；decode／rename／commit仍4，双ALU／三CDB、FQ8／IQ8／ROB32／PRF64／checkpoint64、I$1KiB／64B行、单真实SRAM端口和全部LSU／AXI／Slave合同保持。因此双取指→四取指比较包含宽度及原派生行为，而两种四取指之间才隔离了**16B包边界**的影响。

`cross16`额外只改frontend包上限、ICache相对lane控制hint和严格边界断言：最多4条且不跨64B行，最早branch／JAL／JALR即截断，不论预测是否taken；cold miss单条、单预测口、逐条PC／CID保持。I$原已有任意word起点的128位滑动数据选择，不新增端口／buffer／流水级。四取指保留原保守恢复冻结，不额外合入双取指专属安全恢复运输。

### 2. 双模型原六对照：主要改善multiply，仍披露qsort回退

下表均为相同课程计时口径，周期越少越好；逐项IPC变化按同一退休数计算。

| 原六测试 | 双取指基线周期 | 16B受限四取指 | 跨16B四取指 | 相对双取指拍差 | 相对双取指IPC |
|---|---:|---:|---:|---:|---:|
| median | 7676 | 7471 | 7620 | −56 | +0.734908% |
| multiply | 16908 | 17415 | 12379 | −4529 | +36.586154% |
| vvadd | 3984 | 3982 | 3740 | −244 | +6.524064% |
| towers | 5509 | 5507 | 5477 | −32 | +0.584261% |
| qsort | 147475 | 149619 | 148089 | +614 | −0.414616% |
| rsort | 162806 | 159792 | 159739 | −3067 | +1.920007% |
| **六项几何IPC** | **1.063329023912** | **1.063797503283** | **1.137201912621** | — | **+6.947322%** |

仅改成受限四取指的整体收益为+0.044058%；解除16B限制后，相对受限控制提高6.900224%。但median相对受限四取指多149拍，qsort相对双取指仍多614拍。包变宽本身不保证每例更快，不把投机取指包数或事件差当作固定节省拍数，也不据此推断具体退化因果。当前原六最低IPC为median约0.913517，其次qsort约0.944702；整体达标不等于每个测试IPC都超过1.0985。

正式资格包含：真实frontend／FQ／IQ／decoder／checkpoint对16起始字×16控制掩码×taken／not-taken／cold的768包oracle，真实ICache／公共SRAM的275项完整128位数据／hint／回填旁路／身份／背压冻结／flush／reset检查，以及六个有效RTL负向。两种四取指各自新建native／converted整核模型，原六答案和374104条九字段架构退休匹配生产，同变体两模型完整日志逐字节一致；独立源码逆变换、接受包宽／跨16B且不跨64B、raw重数及保护审计通过。正式筛选约13分18.707秒完成。

来源：[三方案筛选报告](../../sync/FETCH4-CROSS16-RESULTS-20261107.md)、[筛选设计](../../sync/FETCH4-CROSS16-SCREEN-20261107.md)、[筛选最终证书](../../sync/evidence/fetch4-cross16-screen-20261107-r01/finalization.json)。

### 3. 用户另行授权一次新整核PPA，三项目标通过

用户“进行综合”后，仅对`cross16`做一次全新整核opt综合／ABC／STA，不综合`aligned4`控制。精确复用筛选44RTL／公共SRAM／converted与原六完整双模型资格，从elaborate全新六checkpoint，无旧checkpoint继承或PPA拼接，也未重复仿真。

| 版本 | 面积 μm² | Fmax估计 MHz | 原六项几何IPC | 评分 |
|---|---:|---:|---:|---:|
| 上一双取指生产 | 34699.405687 | 316.146959 | 1.063329023912 | 3.356723806268e-7 |
| 跨16B四取指 | 34947.061567 | 319.301528 | 1.137201912621 | 4.372501753378e-7 |
| **相对变化** | **+0.713718%** | **+0.997817%** | **+6.947322%** | **+30.260993%** |

面积增加247.655880 μm²，但仍满足严格<36000；Fmax>300、几何IPC>1.0985也通过。IPC×Fmax估算+8.014461%，不当墙钟实测。采用同AppImage／五库／248原SRAM宏、2ns目标、INVx1／5fF及理想时钟无寄生口径，独立Liberty逐叶面积／宏形状／工具库约束／六checkpoint／raw退休评分审计通过；约49分37.676秒完成。先以r37追加认证指标，未据排名自动采用。

来源：[PPA结果](../../sync/FETCH4-CROSS16-PPA-RESULTS-20261107.md)、[PPA最终证书](../../sync/evidence/fetch4-cross16-ppa-20261107-r01/finalization.json)、[PPA收口复验](../../sync/evidence/fetch4-cross16-ppa-20261107-r01/post-completion-verification.json)。

### 4. “采纳生产”：两软件资格后再原子发布

用户另行明确“采纳生产”，才启动生产替换和两软件同步。RTL仅复制已测pkg／frontend／ICache三文件；两软件仅修改两个默认宽度头及主树CPU／模板`BPU::fetchGroup`中的取包上限，共4项构建输入变化、122项保持。模板BPU改的是包几何，不是预测或训练算法；主树clock后缀和模板全部状态writer保持，旧快照/Input逐字段写目标、Register单写及统一sync纪律不变，不恢复生产观察探针。

新建Release／断言四构建，原六答案、退休数与`init+core+drain`逐项匹配RTL；再仅在两个外部软件副本记录各374104条退休PC／周期，与RTL逐条匹配。独立raw／源码范围审计通过后，先备份三RTL／四软件／文档／旧指针，再复制精确源码、原子发布正式指针，随后两模式原六及44RTL／公共SRAM／126软件／备份保护／三树HEAD索引复验通过；约6分30.996秒完成。采用复用已认证PPA及RTL资格，没有重新综合，也不声称另建生产路径RTL模型或任意输入完整状态等价。

最终[生产指针](../../sync/evidence/current-production.json)为`current-production-adopted-fetch4-cross16`，r38只重绑定新生产并保留历史否决。目前该版本是r38认证集合中的全门槛评分最优、已审计评分最高及几何IPC最高者，不是对所有架构或参数的全局最优证明。旧黄金／镜像／Slave／既有code保持，未提交／推送，全部综合恢复暂停；此次有限筛选／PPA／采用不算附带独立面积专项的完整新优化轮，不自动扩搜、组合或清理。

来源：[采用过程](../../sync/FETCH4-CROSS16-ADOPTION-20261107.md)、[采用证书](../../sync/evidence/fetch4-cross16-production-adoption-20261107-r01/adoption.json)、[采用最终收口](../../sync/evidence/fetch4-cross16-production-adoption-20261107-r01/finalization.json)、[采用后复验](../../sync/evidence/fetch4-cross16-production-adoption-20261107-r01/post-completion-verification.json)、[当前认证指标索引r38](../../sync/evidence/best-results-retained-20261103-r38/retention.json)。

## 后续边界与经验

- 早期“PPA暂停/待补”按各节日期保留；当前生产已有上述同源整核PPA及原六项/两软件验证，但六perf成功仍不覆盖任意输入完整状态等价、全部课程/恢复专项或所有异常域。
- 输出正确不等于周期正确；软件对象大小不等于ASIC面积，代码“平衡化”不等于整核提频。
- 拓宽取指、分配、执行、写回、提交是不同步骤，前端变宽不代表四个ALU或四个访存口。
- IPC、频率、面积必须来自同源码/配置/工具/结束协议；单项收益不可相加，历史快照不得替代当前验收。
