# 项目历史与决策记录

本页只记录阶段、重要采用/否决及资产边界。技术原理与实验对照分别见[架构探索总结](架构探索总结.md)、[参数敏感度分析](参数敏感度分析.md)、[频率分析](频率分析.md)。增减幅只相对各次实验基线，不可相加。

## 三仓库提交归档（2026-11-15）

按用户授权分别提交硬件、模板及主模拟器现有改动，沿用`update: 英文摘要`格式；模板提交`124c42f`，主模拟器提交`5a4d18b`并记录该模板子模块指针，硬件随本条归档。仅做Git差异/空白检查，不重新构建、仿真或综合，不新增采用、不改生产指针、不推送；README仅纳入已有改动，未额外编辑。

## 实验目录删除前交接（2026-11-15）

用户准备自行删除 `/mnt/f/计算机体系结构/CPU-2026/.cpu2026-synthesis/`，要求先记录历史。**本次仅更新现有文档，未执行删除、迁移、采用、提交或推送，暂停新实验与后续审查。** 本轮full/PPA两服务均已正常退出（MainPID0、inactive/dead），检查时未发现仍引用该工作目录的工作进程。

正式生产仍为下节 **385.143394MHz / 32506.259339μm² / IPC1.109725209820**，保已采用ALU与AGU16/16组合carry-select，未采用任何后续候选。生产源码、两软件及 `sync/evidence/current-production.json` 在待删目录外，本次未动；指针SHA256为 `af4c93facee68651e1f0935d6d2b56435628a6c260b5c36e7802f6e9e588970a`。生产原六周期8241/13428/3112/5732/163214/164296，完整退休记录374104条。

**后续复查：工作目录仅余 `tmp/`，原选择性旁路源码/验证收据和生产PPA原始资产已缺失，工作区未找到该候选备份。** `sync/evidence` 虽在目录外，正式采用证书引用的目录内证据与备份也已不可用，不能宣称证据链仍可复核；文档指标仅保留历史事实，不替代原始资产。最新前端恢复重叠版不采用；其同次FF身份、最终具名路径闭合及自身>500MHz清单此前未执行，仍不记作完成。缺失旧资产如实标缺失，不自动恢复或伪造旧证书，不叠加未采用候选；另授权后可从现存生产建立新基线，不能把新产物冒充旧成功阶段。

用户要求诊断综合IPC1.057142选择性旁路版，并在原资产缺失后明确选择“按记录重建新修订”。新根`.cpu2026-synthesis/rs-selective-wakeup-rebuild-20261115-r01/`从现存生产独立重建BRU/Load/StoreAddr三池OLD-ready Q旁路、late-WB选择寄存，声明7位状态，原行writer/容量/信用保持，不叠加前端版。262144组oracle/精确逆变换、真实三池各16392周期、三有效valid1反例及独立审计通过；新生产与候选converted原六374104条完整九架构字段一致，候选周期8398/14668/3267/5865/178512/168106，**新实测IPC1.057141841639**。普通IPC门禁仍false，仅此次用户诊断授权允许PPA，不冒充旧SHA/资格，不自动采用。

新测量根`.cpu2026-synthesis/rs-selective-wakeup-rebuild-ppa-20261115-r01/`串行基线/候选各一次同生产opt/2.5ns/INVx1/5fF/sv2v综合及完整端点、232宏、独立叶面积、全组审查完成。新基线精确复现385.143394MHz/32506.259339μm²；候选**384.240150MHz/32561.648759μm²/IPC1.057141841639**，频率−0.234522%、面积+0.170396%、频率×IPC粗估−4.961822%，没有提频收益，**不采用**。400MHz违例29→440（FF21→2、DCache地址0→400/控制0→38、其他SRAM控制8→0），TNS−0.978709→−20.539098ns、3937稳定端点退化、missing0；完整对照见`candidate/all-group-review.json`。同次FF身份及最终独立复核通过，实际FF22323→22330、选择状态7位确认，身份歧义保留全部别名、不作跨版匿名FF等价或功能敏化证明；证据`FF-comparison.json`、`independent-final-verification.json`及`post-verifier-exit.json`。旧工具清单缺失不回填，本次二进制清单/精确十条Liberty输出起点时序警告另存。生产指针及两软件不改，无重跑综合、采用或清理；本次诊断闭合。

用户随后要求分析真实路径；新分析根`.cpu2026-synthesis/rs-selective-wakeup-real-path-analysis-20261115-r01/`复用已闭合候选STA，并仅补一次基线定点只读STA，独立pin/net/六位时序算术复核通过。相同逻辑起点LSU`lqTagInner[4][2]`至相同DCache bank5地址bit3，slack+20.887→−102.527ps（退123.414ps），55→57门、buffer5→11；该长链原已存在，不只是旧BRU瓶颈移除后暴露。新增7个选择FF不在此组合锥内；同起点`readWayMaskInner[1]`亦退10.405ps，FF组总体改善不代表这族改善。末级20fF/4个SRAM lane负载，末门延迟120.986→176.386ps；中间RTL别名被purge，不伪造逐门函数归因或功能敏化证明。证据`analysis.json`及`independent-verification.json`；下一步仅建议研究LSU晚资格/Store让行与DCache地址选择的串行耦合，不据此自动改HDL或恢复否决方案。

另外发现目录外`RISC-V-CPU-2026/synth/production-evidence/frequency400-lq-address-insertion-screen-20261112-r02/`仍存旧黄金完整raw，已按原审计和归档manifest SHA核验，当前原六输入相同；仅作为架构字段参考只读复用，不恢复到旧路径、不把2026-11-12周期/身份冒充385MHz或本重建候选。旧385MHz基线PPA缺失事实不变，本次已独立新测；原选择性旁路及旧385MHz证据不回填。

## 当前生产：AGU原结果寄存前16/16纯组合进位选择（2026-11-15）

用户获知385MHz版违例22→29及局部退化后明确“采用”，仅发布精确实测`verilog/rtl/execute/rv32_agu_unit.sv`：**385.143394MHz / 32506.259339μm² / IPC1.109725209820**。相对381.289272MHz前生产频率+1.010813%、面积+0.477395%、IPC不变；完整always_ff/writer、freeze/flush和可见周期不变，声明状态增0、实际FF仍22323，保既有已采用ALU，不叠加其他未采用AGU/BRU/LSU/DCache。

400MHz统一约束下WNS−122.076→−95.931ps、TNS−1.708720→−0.978709ns；违例22→29（AGU地址12、BRU误预测1/nextPC6、DCache way-mask2、RAS控制8），DC地址/控制及PRF仍0违例。**3251稳定端点退化、missing0、原全组拒绝及未400MHz事实保留**，本次明确采用不放宽后续门禁。真实AGU196613周期/三有效反例、原六374104条完整raw同周期、唯一PPA/232宏/后测/同次身份及独立审计精确复用，无新模型或综合。两软件126输入/旧同步证书目标保持，旧软件周期资格仅经完整相同HDL raw复用，不声称新软件运行或全状态证明。

旧AGU/正式指针/两文档精确备份及发布审计根`.cpu2026-synthesis/frequency400-agu-carry-select-comb-production-adoption-20261115-r01/`；正式证书`sync/evidence/frequency400-agu-carry-select-comb-production-adoption-20261115-r01/adoption.json`。旧证书/原始拒绝/模型/日志不改写，README、停止通知归约/request-age状态及软件保持，无提交、推送或清理。下一步以本385MHz身份研究剩余瓶颈；旧381MHz独立LSU实验保留但不自动叠加。

## 385MHz共享前40级优化接续（2026-11-15）

用户指定研究DCache readIndex[1]起的AGU/BRU共享40级（门延迟和1455.46ps）。已按385MHz正式指针和采用备份映射复核原共享弧/独立审计，不重跑只读分析；第21级侧输入含FIFO→LQ索引，支持晚owner选择后仍串资格查询的研究方向，不作逐门RTL归属或功能敏化证明。

新独立LSU候选仅把identity/forward/winner资格按旧transport owner提前形成，晚owner选择1-bit结果；完整CDB packet、通知匹配、实际grant/信用、writer/容量/协议/周期不变，不带旧381MHz未合格packet候选。524288组oracle、98304组完整包cut/三反例、真实LSU双模式各3840包＋96等龄行例/205068次完整公开输出对照/三gold valid1反例及独立审计通过；原六374104条完整raw同周期/独立审计通过，IPC **1.109725209820**不变。根`.cpu2026-synthesis/frequency400-owner-qualification-before-route-{cut,actual,full}-20261115-r01/`。

唯一实际PPA r02/232宏/全组/post/handoff及同次身份/路径审计已闭合：**383.880037MHz（−0.328022%）/32337.554159μm²（−0.518993%）/IPC不变，不采用**。违例29→30（FF21→20、DCache控制0→10、RAS控制8→0），WNS−95.931→−104.949ps、TNS−0.978709→−1.132397ns；1812稳定端点退化、missing0、原全组拒绝保留。实际FF22323不变；新三类代表路径共享33级/1303.01ps，起点已转ALU0 tag[1]，最差BRU误预测65级；不同起点/代表位，不作原40级直接消除152ps或功能敏化证明。证据同前缀`{ppa,register-identity,post}-20261115-r02/`，无重复综合。首次r01为make入口缺解释器头失败（EDA0），原失败及串行接续失败保持；r02仅修入口，成功模型/转换/raw零重跑。生产385MHz/软件/正式指针保持，无采用、提交、推送或清理；采用版文档快照见cut根`documentation-backup-mapping.json`。

仅提前身份与buffer年龄、保原三路通知的独立`owner-identity-age-before-route`已全闭合：524288组oracle、98304组cut/三反例、真实LSU双模式各3840包＋96等龄行例/完整公开输出及实际grant信用回归/三gold valid1反例、原六374104完整raw同周期/独立审计通过。唯一PPA/232宏/全组/post/同次身份为 **381.200558MHz（−1.023732%）/32317.827419μm²（−0.579679%）/IPC1.109725209820不变，不采用**；实际FF22323不变。违例29→105（FF21→17、DC地址0→80、RAS控制仍8），WNS−95.931→−122.786ps、TNS−0.978709→−2.853907ns；1895稳定端点退化、missing0、原全组拒绝保持。最差68级/8 buffer起AXI writeHeadOwner[1]→BRU误预测，DC地址60级/9 buffer起LQ tag[5][3]，不作功能敏化或原锥消除证明。实际make2022.250s（33分42秒），较上版2004.442s仅增17.808s；展开944.032s、综合998.070s、STA61.531s。证据`.cpu2026-synthesis/frequency400-owner-identity-age-before-route-{cut,actual,full,ppa,register-identity}-20261115-r01/`，成功模型/转换/综合零重跑，生产/软件保持。

独立`lq-row-forward-flags`已全闭合：oracle/cut/真实LSU双模式3840包＋96等龄行＋1152专项接口例/三有效反例、原六374104完整raw同周期/独立审计及唯一PPA/232宏/全组/post/同次身份通过，**378.383372MHz（−1.755196%）/32364.425099μm²/IPC1.109725209820不变，不采用**。违例29→305（FF117、DC地址188、RAS控制0），WNS−142.309ps、TNS−5.863051ns；2941稳定端点退化、missing0、实际FF仍22323，原全组拒绝保留。证据`.cpu2026-synthesis/frequency400-lq-row-forward-flags-{cut,actual,full,ppa,register-identity}-20261115-r01/`，成功模型及PPA不重跑；该失败触发下述用户流水线授权。

用户新增条件授权：**若本次合格整核PPA仍未提高频率，可改做流水线切分，最终原六几何IPC严格>1.06**。允许为此增加寄存器/周期，不再要求新旧完整raw同周期，但完整架构字段、身份/flush/实际grant/信用、原六答案与独立审计仍须重新合格，面积严格<36000μm²。当前组合候选先完成；切分版仍从385MHz生产独立生成、不叠加未采用版，不自动恢复此前明确否决的具体方案，不自动采用或同步软件。

用户要求本次综合结束后列举所有“>500MHz路径”，已明确选择**等效频率严格>500MHz（所需周期严格<2ns）**，不是500MHz超时路径。须按同一STA约束口径计算，检查路径覆盖/截断，完整清单保存实验产物；每端点最差路径不得冒称所有路径，未约束/覆盖不足如实标明。

用户追问生产版：复用385MHz生产完整STA，核22323 FF＋232宏时钟全部直连同一理想上升沿、IO预算/uncertainty固定，方可按保存精度用`Treq=2.5−slack`筛选；28365个已计时端点中**19213条端点最差路径等效>500MHz**，完整TSV及独立阈值/分组审计根`.cpu2026-synthesis/frequency500-current-production-paths-20261115-r01/`。FF15319、DC控制66/数据554、其他SRAM地址64/控制158/数据2948、输出104；DC地址及PRF端点最差路径均0。仅端点最差路径完整清单，非全部备选逻辑路线；27693个无max-path候选端点不算已覆盖。无新STA/综合，非整核500MHz或后布局结论。

三池`rs-resident-select-pipeline`已完成原六答案/374104条完整九架构字段及独立审计，**几何IPC1.016527480785，低于严格>1.06门槛，不综合、不采用**；六周期8948/14784/3439/6185/188121/169267。262144组oracle/严格lint、真实三池各16391周期独立接口/信用/flush/freeze/重填oracle、三gold valid1反例与局部独立审计通过，原RS行writer/容量不变，新增7位选择状态。根`.cpu2026-synthesis/frequency400-rs-resident-select-pipeline-screen-20261115-r01/`；原警告审查、重启partial构建及旧桥接锚点失败保持，窄修后全部成功模型/转换不重跑；PPA接续正确被IPC门禁拦截，综合0。

BRU单池选择版已完成唯一PPA/232宏/完整全组/post/同次身份及独立审计：**381.822419MHz（−0.862270%）/32398.571459μm²/IPC1.073288762881，不采用**。原六374104完整架构字段通过，FF22323→22326；违例29→75（FF19、DC地址56、RAS0），WNS−118.505ps、TNS−1.459782ns，3215稳定端点退化、missing0，原全组拒绝保持。最差DCache readIndex[0]→AGU地址[31]67级/7 buffer，非功能敏化证明。4条INT信用mask层级/越界警告经精确静态死消费证明闭合（REUSE=0/CREDIT_FIT=0/ISSUE_WIDTH2，两隐式位无cell/输出消费），原失败保留，唯一make/模型零重跑。证据`.cpu2026-synthesis/frequency400-branch-resident-select-pipeline-{screen,ppa,register-identity}-20261115-r01/`及`post-20261115-r02/`。本候选>500MHz端点最差路径18588/28368条，完整TSV/独立审计`.cpu2026-synthesis/frequency500-branch-resident-paths-20261115-r01/`；非所有备选路线。生产385MHz/软件保持。

用户询问尝试利用>500MHz快路径余量换IPC：允许研究局部时序余量→减少执行等待/跨级，不把降低某条快路径频率直接等同IPC收益。先完成现有BRU PPA、不打断或重跑；后续优先独立研究BRU旧行已就绪操作数当拍旁路、当拍CDB唤醒仍经寄存切点，实测IPC/整核频率/全组验证，避免重接晚WB长链。>500MHz清单的SRAM数据多为写端路径，不据此宣称Load返回可少一拍；不扩展到容量/BPU/协议/软件变更，不自动采用或叠加未采用候选。

`rs-selective-wakeup-pipeline`三池OLD-ready旁路/late-WB寄存版已完成原六及独立审计：374104条完整九架构字段相等，**IPC1.057141841639≤1.06，不综合、不采用**；六周期8398/14668/3267/5865/178512/168106。262144组oracle、严格静态lint、真实三池各16397周期及三个gold valid1反例通过；声明增7位选择、原行容量/writer/grant信用保持，直接385MHz生产生成。根`.cpu2026-synthesis/frequency400-rs-selective-wakeup-pipeline-screen-20261115-r01/`，证据`functional-completion.json`、`independent-verification.json`、`verifier-exit.json`；r03只修日志解析，成功模型/转换零重跑，原失败保留。服务退出0仅表示测量/审计完成，IPC资格明确失败；生产/软件不变。下一步研究更窄切分配置，未启动新PPA。

前端恢复重叠r07实测：**383.880037MHz（−0.328022%）/32543.817419μm²（+0.115541%）/IPC1.111319022767（+0.143622%），不采用**；频率×IPC粗估−0.184871%，未400MHz。原六周期8239/13424/3111/5710/162589/164285，完整374104条九架构字段及独立审计通过。唯一make2135.703s，232宏不变，完整分组/post/handoff通过测量审计但保留非退化拒绝：违例29→175（FF21→27、DCache地址0→140、RAS控制仍8），WNS−95.931→−104.478ps、TNS−0.978709→−7.381051ns，1804稳定端点退化、missing0。声明无新状态，但同次FF身份/最终具名路径及本候选>500MHz清单未执行，因用户准备清空工作集暂停，不声称全闭合。

该版仅改core/frontend：四取指在恢复期间允许已知命中且四提示均非控制的包提前进入既有前端队列，返回当前包按实际字数逐字鉴权；后端仍冻结、恢复拍数/BPU/容量/宽度/协议/软件不变，安全断言随条件扩展而未关闭。绑定的是原生产>500MHz清单994条路径（原Treq最差1.961068ns），不代表新链仍>500MHz；perf排除乘除法。1792组oracle、真实frontend2/4各8223/8232周期/三有效反例及独立审计通过，旧夹具槽数/双取指专属断言等失败未回写。证据根`.cpu2026-synthesis/frequency500-frontend-recovery-overlap-{screen-20261115-r01,full-20261115-r07,ppa-20261115-r07}/`；PPA completion SHA256 `1a5df81d5970d76bd14c00952b8032374aa8720059357b3c24eb8fe1928eaeab`。目录删除后这些路径仅作历史定位，不再视为可复用资产。

## 前生产：ALU既有槽操作数寄存边界前移（2026-11-14）

用户在获知提频、违例减少及新增8个RAS控制违例后明确“采纳”，发布精确实测`verilog/rtl/execute/rv32_alu_unit.sv`：**381.289272MHz / 32351.813399μm² / IPC1.109725209820**。相对前生产频率+1.559227%、面积+0.467401%、IPC不变；总违例329→22（AGU地址10、BRU2、DCache way-mask2、RAS控制8），DC地址280→0，TNS−14.678912→−1.708720ns。单槽容量、接口、可见周期及同拍drain/refill保持；声明状态增206位、同次mapped FF22118→22323（净增205），不称零新状态。

原六374104条完整raw同周期、真实ALU/oracle/三有效结果反例、唯一PPA/232宏/全组/post/同次身份及独立审计精确复用，不重跑。**2936稳定端点退化、missing0、原全组拒绝、新增RAS违例及未400MHz事实保留**，本次明确采用不放宽后续门禁。两软件126项输入和旧同步证书目标未改，仅通过相同HDL raw复用既有周期资格，不声称新软件运行或全状态证明。旧ALU/真实指针/两文档精确备份及采用证据根`.cpu2026-synthesis/frequency400-alu-operand-retime-production-adoption-20261114-r01/`；正式证书`sync/evidence/frequency400-alu-operand-retime-production-adoption-20261114-r01/adoption.json`。不带INT issue切点、shared-valid cofactor或16KiB版；旧通知归约/request-age停止状态保持，未提交、推送或清理。

## AGU/BRU保留清理（2026-11-14）

用户确认仅清理工作区`.cpu2026-synthesis/`，随后明确“保留本次agu/bru改进的”。**已完成**：按清单删除344处资产，可用空间增加**54.38GiB**，F盘剩余约**59.73GiB（使用率20%）**；实验目录保留约3.3GiB，含本次AGU/BRU完整工作集、共用脚本、当前381.289272MHz生产的screen/PPA/身份/采用备份及精确SHA依赖。1869个保留文件、AGU与生产证据依赖SHA、生产HDL/指针/两软件126输入和全部`sync/evidence`证书均复核不变；README及`RISC-V-CPU-2026/{build/synth,synth}/`未动。收据见AGU根`authorized-cleanup-completion.json`。本次无模型/转换/EDA、提交/推送或全局配置变更；授权不扩展为持续清理。未保留历史实验原产物已删除，不可再凭旧证书声称原始资产齐全。

接续状态：AGU边界迁移真实模块正向65540周期通过（31113次payload捕获、15766次进位），live-input/wrong-operand两个反例在valid1检出；freeze-writer反例只在valid0检出，门禁拦截，**尚无完整局部资格、原六/IPC或PPA结果，不采用**。BRU已准备独立候选/夹具，含保护invalid复位载荷的初始化位，**尚未运行**；两者均从已采用ALU版独立生成、未合并。保留根`.cpu2026-synthesis/frequency400-{agu-operand-retime-screen,bru-operand-retime-screen,agu-bru-retime-support}-20261114-r01/`；清理计划及精确保留SHA见AGU根`authorized-cleanup-plan.json`。后续先补AGU有效freeze反例及独立审计，再接原六；BRU独立验证，成功阶段不重跑。

## 前生产：AGU-tag＋DCache地址组合（375.435380MHz）

用户明确“那就采用这个版本，停止正在进行的验证”，发布精确LSU AGU-tag提前查询＋DCache Fill/Store地址并行组合：**375.435380MHz / 32201.304059μm² / IPC1.109725209820**。相对377.511521MHz前生产频率−0.549954%、面积−1.084110%、IPC不变；总违例494→329（FF49、DC地址280，其余0）。仅发布实测`rv32_lsu.sv`、`rv32_dcache.sv`，不含lookup直接选择或未合格通知归约；原六374104条raw同周期、唯一PPA/232宏/全组/post/22118 FF身份资格精确复用，不重跑。**4628稳定端点退化、missing0、原全组拒绝及未400MHz保留**，本次明确采用不放宽后续门禁。

通知归约真实LSU验证已按用户要求停止，SIGTERM不算完成或合格，不恢复、不再启动后续验证/综合；旧request-age保持停止。两软件126项输入和旧同步证书目标不改，仅复用既有PC/周期资格，不声称新软件运行或全状态证明。旧377MHz两HDL/真实指针/文档精确备份；正式证书`sync/evidence/frequency400-agu-tag-dcache-address-combination-production-adoption-20261114-r01/adoption.json`，备份、停止收据和发布审计根`.cpu2026-synthesis/frequency400-agu-tag-dcache-address-combination-production-adoption-20261114-r01/`。未提交、推送或清理。

375MHz当前生产违例路径只读复核：329个端点最差路径仅从AXI读owner位（47）或LQ tag位（282）发出；前者以ALU/AGU结果为主，后者含280 SRAM地址及2个way-mask FF。完整具名归类`.cpu2026-synthesis/frequency400-current-production-violating-path-review-20261114-r01/violating-endpoints.json`，无新验证/综合，停止状态不改。

375MHz最差FF完整门级路径及侧锥只读复核闭合：AXI读owner[1]→ALU1结果[27]，72组合单元/9 buffer、176侧输入/27597节点，无截断；末20级约639ps、总到达约2.605ns。逐门清单与独立审计根`.cpu2026-synthesis/frequency400-agu-tag-dcache-address-combination-ff-bottleneck-20261114-r01/`；中段无公开RTL别名，模块解释仅结构支持，不作功能敏化或全RTL映射证明。未启动模型/转换/EDA或恢复已停验证。

上游DCache Fill readiness分解已闭合：唯一有效PPA r02/232宏/完整全组/post/handoff及22118 FF同次身份审计通过，**341.689260MHz（−8.988530%）/32485.482839μm²（+0.882507%）/IPC不变**，不采用。FF/DC地址改善53.294/71.480ps，但I$ `headInner[0]`→数据SRAM地址[2]成最差−426.156ps（29单元含20 buffer、16违例）；其他SRAM控制新增8违例，总329→229不抵消降频。2275稳定端点退化、missing0、原全组拒绝保持。根`.cpu2026-synthesis/frequency400-dcache-fill-readiness-split-{ppa,register-identity}-20261114-r02/`，旧r01 exec前失败/EDA0及原资产保持。

完整Fill逐行cofactor唯一PPA/232宏/完整全组/post/handoff及22118 FF同次身份审计闭合：**356.561480MHz（−5.027203%）/32378.451059μm²（+0.550124%）/IPC不变**，不采用。FF/DC地址WNS退141.211/21.642ps，违例329→615（FF161/DC地址454）；3881稳定端点退化、missing0。FF74门起于AXI读owner[0]→ALU1结果[31]，DC69门起于AGU辅助索引[2]；I$无新增违例。证据`.cpu2026-synthesis/frequency400-dcache-fill-row-cofactor-{ppa,register-identity}-20261114-r01/`，成功功能与唯一PPA不重跑，原准备/诊断失败保持。

Fill owner请求提前查询的局部/真实DCache双模式/三有效CPU数据反例、新源原六374104条raw同周期和独立审计已闭合，IPC1.109725209820不变。原shell退出通知缺失后只读核真实进程/产物：准备日志显示预检完成、无残留EDA进程，尚未启动PPA，不把通知错误算综合失败；接续转用户16KiB IPC请求，不自动启动该候选综合。资格根`.cpu2026-synthesis/frequency400-dcache-fill-owner-query-{research,cut,full}-20261114-r01/`及`actual-20261114-r02/`，原失败保持。

用户授权16KiB D$ IPC测试已闭合：仅组数128→256（2路/32B不变），converted保断言原六答案及374104条九架构字段逐条相等、独立审计通过。几何IPC **1.109725209820→1.163892071852（+4.881106%）**；前四周期不变，qsort163214→159318（IPC+2.445424%）、rsort164296→126455（IPC+29.924479%）。原诊断/导入失败保持，成功lint/转换零重跑。证据`.cpu2026-synthesis/dcache16k-ipc-20261114-r01/{functional-completion,independent-verification}.json`；未综合、不声称16KiB面积/频率或采用，生产/软件不改。

**用户明确“先保存作为历史记录，不应用到生产”：16KiB仅归档，不采用、不据此启动后续实验。** 唯一同生产流程PPA/232宏/独立叶面积/完整全组/post/handoff闭合：**35554.806081μm²（+10.414181%，余445.193919）/372.787258MHz（−0.705347%）/IPC1.163892071852**。逻辑29109.363660、SRAM6445.442421μm²；64数据宏和2metadata扩容，其余166宏不变。全局违例329→298但2247稳定端点退化、missing2，原全组拒绝/对应不足和预检失败均保持。源码/模型/raw/网表/日志/耗时证据完整保留；归档决定及SHA见`.cpu2026-synthesis/dcache16k-ppa-20261114-r01/historical-record.json`。生产仍8KiB/375.435380MHz/32201.304059μm²/IPC1.109725209820，真实指针SHA未改；未提交、推送或清理。

同口径耗时：8KiB→16KiB整次make35分16.130秒→66分15.166秒，**增加30分59.036秒（+87.850725%）**；综合/映射17分7.836秒→18分2.617秒（+5.329806%），主要增量在elaborate16分43.249秒→46分40.999秒（+179.192688%）。单次历史基线非同时控负载因果实验，准备失败/嵌套计时不计入、不重跑基线；比较证书`.cpu2026-synthesis/dcache16k-ipc-20261114-r01/synthesis-time-comparison.json`。生产375.435380MHz/32201.304059μm²及两软件未改。

展开变慢只读定位：Yosys hierarchy726.441→1924.212s（约占新增时间67%），proc_mux132.043→397.335s、proc_dff80.909→318.265s；CPU总时间990.79→2791.37s接近各自wall，非主要I/O等待。按SET逐组valid/PLRU复位/更新展开后DCache临时cell112184→155832、mux41954→59362，大过程处理成本超线性；不是把数据SRAM展开为FF。原脚本/HDL相同，仅授权参数不同；证据IPC根`elaboration-slowdown-analysis.json`，无新EDA，未作Yosys内部算法复杂度或精确因果证明。

上一ready/wait版I$同端点只读对照/独立审计完成：两版均`headInner[0]`→way0/lane0地址[2]，裕量+986.962→−426.156ps；静态最大buffer路由的起始链10→19级，末级HB→NOR2。失败版保存STA的末级NOR2约976ps/80fF；基线无该端点完整STA，不能分摊精确增量或宣称映射根因已证。证据`.cpu2026-synthesis/frequency400-icache-same-endpoint-topology-20261114-r01/`；无新STA/模型/综合、mapped只读。

## 前生产：SV两槽选择器（377.511521MHz）

用户在知悉整体提频及局部退化后明确“采纳”，发布精确SV两槽选择器版：**377.511521MHz / 32554.227539μm² / IPC1.109725209820**，相对前生产频率+0.760369%、面积+1.004800%、IPC不变。仅`verilog/rtl/backend/rv32_rs.sv`组合分支，保完整排序包/invalid载荷/端口/全部writer/实际grant与旧行信用，无新状态或周期；LQ叶对比较及其他配置保持，不带失败ALU或通知旁带。原六374104条完整raw同周期、真实RS/反例/独立审计及唯一PPA/232宏/全组/post/身份复核精确复用，不重跑成功阶段。两软件126项输入不改，既有PC/周期资格经HDL完整raw相等复用，不声称新软件同步或全状态证明。旧RS/真实指针/文档精确备份；证书`sync/evidence/frequency400-sv-two-slot-select-production-adoption-20261113-r01/adoption.json`。2528稳定端点退化、missing0、原全组拒绝及未400MHz保留，本次采用不放宽后续门禁，旧request-age进程保持冻结，未提交、推送或清理。

## 前生产：LQ叶对并行比较（374.662703MHz）

按用户“改善即可，那就采用”发布精确LQ叶对并行比较版：**374.662703MHz / 32230.376579μm² / IPC1.109725209820**，对前生产频率+3.681683%、面积−0.142925%、IPC不变。仅LSU组合改写，28对年龄比较共享，各层保原树/invalid载荷/全部writer/实际grant，无新状态或周期；不含未合格request-age候选。原六374104条完整raw同周期、独立审计及唯一PPA/232宏/全组/post/身份复核精确复用，无新模型/转换/EDA。两软件126项输入不改，既有同步PC/周期资格经HDL完整raw相等复用，无新软件构建运行。旧LSU/真实指针/文档精确备份，正式证书`sync/evidence/frequency400-lq-pair-prefix-production-adoption-20261113-r01/adoption.json`；原全组拒绝、2613稳定端点退化、missing0及未400MHz保留，本次明确采用不放宽后续门禁，未提交、推送或清理。

## 前生产及软件同步（361.358624MHz）

按用户“那么就采用这个到生产中”采用精确old-row credit版：**361.358624MHz / 32276.507699μm² / IPC1.109725209820**。仅发布core五个REUSE参数，原issue旁路/selector/全部writer不变；全局违例10775→531。相对前生产频率−0.970446%、面积+0.414950%、IPC−1.115147%，2210稳定端点退化及原全组拒绝保持，未达400MHz；本次明确采用不放宽后续门禁。原六周期`8241/13428/3112/5732/163214/164296`，374104退休/独立审计及唯一PPA精确复用，不重跑模型/转换/EDA。旧core/真实指针/文档已备份；正式证书`sync/evidence/frequency400-old-row-credit-production-adoption-20261113-r01/adoption.json`。HDL采用时两软件126项输入不变、尚未同步，该历史证书保持原样。

用户随后要求“同步软件”，双树现已关闭离站信用及槽回退复用，保WB唤醒/实际grant/全部RS writer。126项输入中4项更新、122项保持；Release/保断言四构建原六答案、退休数及`init+core+drain`全匹配，双树各374104条退休PC/周期匹配现存converted raw。双树各458752组分配oracle及五池旧源码有效反例、每拍RS占用/flush/freeze检查和独立raw审计通过；仅默认四宽原六资格，非软件九字段退休载荷或全状态证明。新证据`sync/evidence/software-old-row-credit-sync-20261113-r01/synchronization.json`，产物`.cpu2026-synthesis/software-old-row-credit-sync-20261113-r01/`；旧软件/指针/文档精确备份，原失败保留，无新HDL运行/转换/EDA，旧黄金/镜像/Slave/既有code/README不变，未提交、推送或清理。下一步仍以本生产研究DCache残链。

## 最新研究（2026-11-14～15）

用户新授权“今晚继续持续优化，争取到达400mhz，先进行agu/bru的寄存边界迁移”。以已采用381.289272MHz版为唯一生产基线，IPC门槛严格>1.06、面积严格<36000μm²，同时比较频率/违例端点/TNS/完整分组；AGU与BRU独立候选，不叠加未采用版、不自动采用或继续清理。清理后保留工作集、126软件及当前生产SHA已核验，基线PPA273项引用均可认证。

AGU整段操作数寄存迁移已闭合：真实模块65540周期、三个有效结果反例、有效OLD/NEW年龄重放、原六374104条完整raw同周期及独立审计通过，IPC不变；唯一PPA/232宏/后测/handoff/同次身份均认证。**370.594888MHz（−2.804795%）/32434.394519μm²（+0.255260%），不采用**。违例22→610、TNS−1.708720→−71.268894ns，FF22323→22355；3134稳定端点退化、missing0，原全组拒绝保持。新最差offset寄存bit1→DCache地址（68组合单元），FF最差同起→way-mask（73单元）；下游加法尾链抵消上游切断。根`.cpu2026-synthesis/frequency400-agu-operand-retime-{screen,ppa,register-identity}-20261114-r01/`，完整闭合见screen根`final-cut-review.json`；旧失败及成功资产保持、不重跑。

BRU唯一PPA/232宏/后测/handoff/同次身份已闭合：**382.714319MHz（+0.373744%）/32487.757319μm²（+0.420205%）/IPC不变**。FF违例14→10、RAS控制8→0，但DC地址0→172，总违例22→182、TNS−1.708720→−4.387792ns；4815稳定端点退化、missing0，原全组拒绝保持，不自动采用。实际FF22323→22425（+102），BRU直接公开状态别名71→173，声明+69不是优化后FF数。当前最差AXI word-response[33]/wordMiss[1]→AGU地址[31]，68组合单元；DC起于LQ tag[4][2]。根`.cpu2026-synthesis/frequency400-bru-operand-retime-{screen-20261114-r02,ppa-20261114-r01,register-identity-20261114-r01}/`，完整对照见screen根`final-cut-review.json`。真实两模式/三有效反例/原六374104条完整raw同周期及独立审计精确复用，旧准备/诊断失败保持。

AGU16/16 carry-select寄存切点已闭合：独立oracle、真实模块196613周期/162186次捕获/81302次进位、三有效结果反例、原六374104条完整raw同周期及唯一PPA/232宏/后测/同次身份均通过资格审计。**379.259259MHz（−0.532407%）/32336.344019μm²（−0.047816%）/IPC不变，不采用**。违例22→300（FF52/DC地址240/RAS控制8）、TNS−1.708720→−9.437554ns；实际FF22323→22340（+17），2967稳定端点退化、missing0，原全组拒绝保持。新最差ROB head[1]→RAS控制，carry寄存位经高半选择→DCache地址成62单元尾链。根`.cpu2026-synthesis/frequency400-agu-carry-select-retime-{screen,ppa,register-identity}-20261115-r01/`，闭合见screen根`final-cut-review.json`；成功阶段不重跑，生产381MHz及软件不改。

AGU16/16纯组合carry-select已闭合：**385.143394MHz（+1.010813%）/32506.259339μm²（+0.477395%）/IPC1.109725209820不变**。选择器在原结果寄存前，完整always_ff/writer不变、实际FF22323→22323；真实196613周期/三有效反例/原六374104条完整raw同周期、唯一PPA/232宏/后测/handoff/身份及独立审计均通过。TNS−1.708720→−0.978709ns、DC地址仍0违例且WNS改善19.567ps，但总违例22→29、3251稳定端点退化、missing0，原全组拒绝及未400MHz事实保持，不自动采用。最差DCache readIndex[1]→BRU mispredict，71单元/13buffer；根`.cpu2026-synthesis/frequency400-agu-carry-select-comb-{screen,ppa,register-identity}-20261115-r01/`，完整对照screen根`final-cut-review.json`。生产仍381MHz，不叠加未采用BRU。

BRU四字节比较切点已完整闭合：**378.558226MHz（−0.716266%）/32174.637239μm²（−0.547654%）/IPC不变，不采用**。原六完整raw同周期、真实两模式各65605周期/三有效反例及唯一PPA/232宏/后测/同次身份全部认证；实际FF22323→22326（+3）。总违例22→359（FF23/DC地址328/RAS控制8）、TNS−1.708720→−15.263170ns，3427稳定端点退化、missing0，原全组拒绝保持。新最差ROB head[1]→RAS控制；FF最差AXI read-owner[1]→比较chunk[3]，70单元。根`.cpu2026-synthesis/frequency400-bru-compare-chunks-{screen,ppa,register-identity}-20261115-r01/`，闭合见screen根`final-cut-review.json`；成功阶段不重跑。

BRU误预测并行cofactor已闭合：**382.357060MHz（+0.280047%）/32402.303939μm²（+0.156067%）/IPC不变，FF22323→22323**。真实两模式各65605周期/三有效反例/原六完整raw同周期及唯一PPA/232宏/后测/同次身份均认证。RAS控制8→0，但DC地址0→40、FF14→18，总22→58、TNS−1.708720→−2.301820ns；3842稳定端点退化、missing0，原全组拒绝保持、不自动采用，不及385MHz候选。最差AXI read-owner[0]→AGU地址[31]，65单元；根`.cpu2026-synthesis/frequency400-bru-mispredict-cofactor-{screen,ppa,register-identity}-20261115-r01/`，完整闭合见screen根`final-cut-review.json`。生产及软件保持。

AGU四字节前缀版已完整闭合：**380.315692MHz（−0.255339%）/32511.318599μm²（+0.493033%）/IPC不变，不采用**。真实196613周期/三有效反例/原六完整raw同周期及唯一PPA/232宏/后测/同次身份均认证，FF仍22323。RAS控制8→0，但DC地址0→432、FF14→22，总22→454、TNS−1.708720→−18.929380ns；3688稳定端点退化、missing0，原全组拒绝保持。最差AXI read-owner[1]→AGU地址[31]，69单元；DC起于AGU auxiliary[0]。根`.cpu2026-synthesis/frequency400-agu-byte-prefix-comb-{screen,ppa,register-identity}-20261115-r01/`，screen根`final-cut-review.json`保完整证据；生产及软件保持。

AGU OR-propagate r02已完整闭合：**381.911422MHz（+0.163170%）/32253.908699μm²（−0.302625%）/IPC不变，FF仍22323**。真实196613周期/三有效反例/原六完整raw同周期及唯一PPA/232宏/后测/身份审计均认证，r01静态lint失败及窄修记录保持。FF14→13、TNS−1.708720→−1.652005ns，但DC地址新增8违例、RAS控制仍8且成最差，总22→29；3762稳定端点退化、missing0、原全组拒绝保持，不自动采用、不及385MHz候选。最差ROB head[2]→RAS控制52单元；FF最差AXI read-owner[0]→BRU mispredict71单元。screen根`.cpu2026-synthesis/frequency400-agu-or-propagate-comb-screen-20261115-r02/`，PPA/身份根同前缀`{ppa,register-identity}-20261115-r01/`，闭合见screen根`final-cut-review.json`。

381MHz生产及385MHz候选共8条保存路径的逐pin/类型/连接/完整公开别名及延迟窗口已通过独立审计。8条路径内部公开网别名均为0，不能可靠划分共享返回/唤醒段与执行尾段；生产AGU末16门约506ps、385版约541ps仅为门延迟和，不等于可删加法延迟。证据`.cpu2026-synthesis/frequency400-execute-tail-frontier-study-20261115-r01/`；无新模型/转换/EDA、候选叠加或采用。

同版真实共享弧及9个不截断侧输入锥已通过独立审计：生产AGU/BRU误预测/nextPC共享前35门、门延迟和约1294.94ps，385MHz候选共享40门/1455.46ps。共享节点侧锥包含DCache request/MSHR、AXI条目/word-response及40个宏输出边界，只作结构支持，不认定RTL边界或功能敏化；每锥一个未区分主输入/无驱动根保持未知。证据`.cpu2026-synthesis/frequency400-execute-shared-cone-study-20261115-r01/`，无新模型/EDA或候选叠加。

DCache响应出口packet onehot组合候选保持early>word>normal、无响应raw0及reset低时载荷，responseInner/正常winner、全部时序writer、容量/协议/周期不变。独立整数oracle及converted源码cut各524288组、三有效载荷反例通过；原独立审计因`run`同名导入失败保持，r02精确路径导入后仅补审计，成功转换/构建/模型重跑0。闭合入口cut根`cut-audit-handoff-r02.json`及`independent-verification-r02.json`；根`.cpu2026-synthesis/frequency400-dcache-response-packet-cut-20261115-r01/`，原pending/失败证据不回写。

真实DCache/背靠存储器4配置及独立审计已闭合：生产LOAD_PREFETCH0两返回模式各630接受/334响应，hit262/265、buffer9/6、注册word43；原预取回归各742/398保持。全部公开输出/invalid载荷、byte/owner/延迟/Store/背压对照通过。原drop-buffered故障先触发内部实际grant断言，外层预期短语门禁失败保留；r02认证其受valid bit35保护的运行时身份反例，只补未完成word反例/审计，旧成功模型不重跑。两有效数据＋一实际grant身份反例完成，不冒称三个外层数据反例。入口actual根`{completion,independent-verification}-r02.json`；根`.cpu2026-synthesis/frequency400-dcache-response-packet-actual-20261115-r01/`。

DCache packet版整核原六/完整raw同周期及唯一PPA/232宏/后测/handoff/身份审计已全部闭合：**383.072247MHz（+0.467617%）/32358.534779μm²（+0.020776%）/IPC不变，FF仍22323**。FF仍14违例，DC地址新增144，总22→166、TNS−1.708720→−5.314925ns；2710稳定端点退化、missing0，原全组拒绝保持、不自动采用，不及385MHz候选。最差AXI read-owner[1]→AGU地址[31]，76单元/12buffer。full根`.cpu2026-synthesis/frequency400-dcache-response-packet-full-20261115-r01/`，PPA/身份同前缀`{ppa,register-identity}-20261115-r01/`；完整闭合见full根`final-cut-review.json`，旧失败/成功资产保持。

LSU响应CDB分支cofactor的独立整数oracle1048576组、converted源码cut98304组及三有效包反例/独立审计已闭合，收据/输入/转换SHA复核通过，成功阶段不重跑；r01准备锚点失败保持。仅改既有packet组合块，通知匹配、writer、实际grant/信用/寄存边界不变，不叠加383/385MHz版。cut根`.cpu2026-synthesis/frequency400-lsu-cdb-branch-cofactor-cut-20261115-r02/`。

旧381MHz独立LSU r02正向双模式通过：各3840组packet、200074次22公开输出对照及owner/通知/信用回归。r03签扩展/目的寄存器两反例已有valid1见证，但反转选择在时间0得到original.valid0、gate.valid1，按门禁拒绝、不计有效反例；原失败/模型/日志保持。r04仅备“有效响应误选缓冲”新故障及独立审计脚本，尚未启动、未完成真实模块全资格或整核/PPA；所有unit已退出。actual根`.cpu2026-synthesis/frequency400-lsu-cdb-branch-cofactor-actual-20261115-r0{1,2}/`，不因本次385MHz采用改写旧成功或失败，也不自动叠加到新生产。

本轮用户授权运算单元上游切点研究，并将IPC门槛改为**严格>1.06**；面积仍严格<36000μm²、目标400MHz，同时比较违例端点/TNS/完整分组。INT-only共享CDB先捕获后发射通过真实RS两形态/三有效反例、原六374104条九架构字段及独立审计，周期`8241/13570/3464/5777/163405/166712`；原导入失败保留、成功阶段零重跑。生产8KiB/375.435380MHz、两软件和旧停止任务不改，不自动采用。

INT-only切点唯一PPA/232宏/全组/post/handoff/22118 FF同次身份及独立审计已闭合：**370.176231MHz（−1.400813%）/32338.020719μm²/IPC1.083902751388，不采用**。ALU结果负端点29→0，但总违例329→411（FF49→51、DC地址280→352、其他SRAM控制0→8），新最差ROB head[1]→RAS arch SRAM ce、−201.060ps；TNS−14.678912→−9.476633ns不能抵消降频/条数增加。2360稳定端点退化、missing0，原全组拒绝保持；闭合证据screen根`final-cut-review.json`及同前缀`register-identity-20261114-r01/`。局部切断有效不等于整核改善，后续从生产独立选点、不叠加本候选，生产/软件不改。

INT shared-valid完整排名cofactor（无新状态/周期）代数、真实RS两形态/三有效反例、原六374104条完整raw同周期及独立审计通过；唯一PPA/232宏/全组/post/handoff/22118 FF身份闭合：**381.111886MHz（+1.511980%）/32339.172539μm²/IPC1.109725209820不变**。但总违例329→503（FF49→127、DC地址280→376）、TNS−14.678912→−20.855719ns，2685稳定端点退化/missing0，原全组拒绝保持，**暂不采用、不称最优**。原stdout分类失败保持、成功阶段零重跑；根`.cpu2026-synthesis/frequency400-int-shared-valid-cofactor-{screen,ppa,register-identity}-20261114-r01/`；两切点统一对照`frequency400-execution-upstream-cut-baseline-20261114-r01/cut-comparison.json`。

ALU既有槽寄存边界前移全部闭合，随后用户明确采用，见当前生产。三深度真实ALU独立oracle各32772周期/全64操作、三个valid1结果反例、原六374104条完整raw同周期及独立审计通过；原invalid0反例、诊断/审计失败保持，正向及既有有效阶段零重跑。screen/PPA/同次22323 FF身份及全部22端点见`.cpu2026-synthesis/frequency400-alu-operand-retime-{screen,ppa,register-identity}-20261114-r01/`，screen根`final-cut-review.json`。采用不改写原全组拒绝、旧日志或两软件，不恢复其他候选。

单LSU的AGU完整tag提前查询已闭合：数学/converted613635组查询、真实LSU双响应各32768新增例/557056检查及完整旧回归/三有效实际反例、原六374104条完整raw同周期及独立审计通过。唯一PPA/232宏/完整全组/后测/handoff及同次22118 FF身份复核完成：**378.383372MHz（+0.230947%）/32333.734199μm²（−0.677311%）/IPC1.109725209820不变**，未400MHz；2671稳定端点退化、missing0，原全组拒绝保留，未采用。根`.cpu2026-synthesis/frequency400-agu-forward-tag-{research,cut,actual,full,ppa,register-identity}-20261114-r01/`。仅改资格查询tag，所有消费仍由事件鉴权，数据查询/size/全部writer/grant保持；无效raw查询允许不同而必须屏蔽。原诊断失败/重启中断日志保持，r03只补未完成末段make，成功阶段零重跑。生产仍377.511521MHz、软件不改，旧request-age已停止且不恢复。

单AGU 4位双进位/块前缀候选全部闭合：数学/converted组合AGU528384组双oracle/三反例，寄存单元1638403周期/3276806完整快照/五实际反例，原六374104条raw同周期及独立审计通过。唯一PPA/232宏/完整全组/后测/handoff及同次22118 FF身份复核完成：**368.179775MHz（−2.471910%）/32425.675679μm²（−0.394885%）/IPC不变**；3999稳定端点退化、missing0，降频/原全组拒绝，不采用。总违例494→396不抵消其他SRAM控制WNS退123.476ps，未400MHz。根`.cpu2026-synthesis/frequency400-agu-nibble-carry-select-{research,full,ppa,register-identity}-20261114-r01/`及同前缀`{cut,unit}-20261114-r0{1,2}/`；原数组/参考名失败保留，成功阶段不重跑。

标量RS早期flush候选已闭合：数学/converted控制393216组、真实RS两生产形态11141120周期/22282240完整快照/六有效反例，原六374104条raw同周期及独立审计通过。唯一PPA/232宏/完整全组/后测/handoff及同次22118 FF身份复核完成：**371.687840MHz（−1.542650%）/32485.482839μm²（−0.211170%）/IPC不变**，4019稳定端点退化、missing0；FF WNS退49.569ps、DC地址退12.435ps，总违例494→420不能抵消降频，原全组拒绝，不采用。根`.cpu2026-synthesis/frequency400-scalar-rs-early-flush-{research,cut,actual,full,ppa,register-identity}-20261114-r01/`；生产/软件不改，不叠加失败候选。

DCache r04地址掩码候选已闭合：307200组×16bank cut/三反例、真实DCache双响应各742接受/398响应及全部bank raw端口/metadata/三live反例、原六374104条完整raw同周期及独立审计通过。唯一PPA/232宏/完整全组/后测/handoff及同次22118 FF身份审计完成：**376.211251MHz（−0.344432%）/32383.685279μm²（−0.523871%）/IPC不变**；4775稳定端点退化、missing0，总违例494→506，降频/原全组拒绝，不采用。根`.cpu2026-synthesis/frequency400-dcache-bank-mask-{research,actual,full,ppa,register-identity}-20261114-r01/`及`cut-20261114-r04/`。全部旧失败/跨行case1940保持，成功模型/转换/EDA不重跑；live行内、跨行仅cut、非全状态/跨后端证明。

DCache Fill/Store地址互斥项并行合并全部闭合：数学、307200组×16bank cut/三反例、真实双响应完整字节/owner/bank端口/metadata/三live反例、原六374104条raw同周期及独立审计通过。唯一PPA/232宏/完整全组/后测/handoff及同次22118 FF身份审计完成：**380.846118MHz（+0.883310%）/32266.549559μm²（−0.883689%）/IPC1.109725209820不变**。3387稳定端点退化、missing0；DC地址WNS改善119.863ps，但DC控制退29.657ps且新增10违例，原全组拒绝及未400MHz保持，未自动采用。根`.cpu2026-synthesis/frequency400-dcache-parallel-address-{research,cut,actual,full,ppa,register-identity}-20261114-r01/`。跨行/禁用地址和原失败记录保持，成功阶段不重跑。

INT_RS完整包直接选择已闭合：数学/converted262144组完整包/三反例，真实RS19005440周期/38010880完整快照/三实际反例、原六374104条raw同周期及独立审计通过。唯一PPA/232宏/完整全组/后测/handoff及同次22118 FF身份审计完成：**369.425028MHz（−2.142052%）/32293.216379μm²（−0.801773%）/IPC不变**；4776稳定端点退化、missing0，总违例494→513，DC地址WNS退58.171ps，降频/原全组拒绝，不采用。根`.cpu2026-synthesis/frequency400-int-rs-decoded-payload-{research,cut,actual,full,ppa,register-identity}-20261114-r01/`。成功阶段不重跑，原诊断失败保持；live窗口/任意mask cut范围不扩称全状态证明。

DCache数据bank enable分解已闭合：数学/380928组×16bank cut/三反例、真实双响应完整字节/owner/bank端口/metadata/三live反例、原六374104条raw同周期及审计通过。唯一PPA/232宏/完整全组/后测/handoff及同次22118 FF身份审计完成：**328.270888MHz（−13.043478%）/32520.635219μm²（−0.103189%）/IPC不变**；5352稳定端点退化、missing0，总违例494→3246，DC控制WNS退532.389ps，明显降频/原全组拒绝，不采用。根`.cpu2026-synthesis/frequency400-dcache-data-enable-factor-{research,actual,full,ppa,register-identity}-20261114-r01/`及同前缀`cut-20261114-r0{1,2}/`；原漏变异夹具失败保持，正向成功阶段不重跑。

377生产/380未采用地址版/328使能版的只读拓扑与独立审计通过：13条保存负路径、5个稳定SRAM端点、922项stage负载。所选路径最大sink-pin数均10，同一地址端点生产65门/11buffer→328版80门/14buffer，证据不支持仅以最大扇出解释退化。根`.cpu2026-synthesis/frequency400-dcache-enable-topology-review-20261114-r01/`；无新EDA/模型，不跨版匹配匿名FF、未补非负端点缺失路径，非功能敏化或可达Fmax证明。

lookup地址直接选择已闭合：数学/1048576组cut/三反例、真实DCache双响应/三实际反例、原六374104条raw同周期及独立审计通过。唯一PPA/232宏/完整全组/后测/handoff及同次22118 FF身份审计完成：**366.942889MHz（−2.799552%）/32348.168399μm²（−0.632972%）/IPC不变**；3182稳定端点退化、missing0，总违例494→565，降频/原全组拒绝，不采用。根`.cpu2026-synthesis/frequency400-dcache-lookup-direct-{research,cut,full,ppa,register-identity}-20261114-r01/`及同前缀`actual-20261114-r0{1,2,3}/`，成功阶段不重跑，全部原失败保持。

用户指定AGU-tag＋DCache地址组合已闭合：新原六374104条raw同周期/独立审计、唯一PPA/232宏/完整全组/后测/handoff及同次22118 FF身份审计完成。**375.435380MHz（−0.549954%）/32201.304059μm²（−1.084110%）/IPC不变**；4628稳定端点退化、missing0，总违例494→329但FF WNS退22.656ps。最初因降频/全组退化不采用，随后用户明确采用此组合，原技术拒绝不改写。单项提频未相加，原失败/成功资产保持。根`.cpu2026-synthesis/frequency400-agu-tag-dcache-address-combination-{research,full,ppa,register-identity}-20261114-r01/`。

LSU旧行通知归约仅完成数学审计及converted262144组×lane1/2/4共786432项检查、三有效反例和独立审计；真实LSU双响应服务随后被用户明确停止，无实际模块完成/原六/PPA资格，不含于新生产、不恢复。根`.cpu2026-synthesis/frequency400-lsu-notify-row-reduce-{research,cut,actual}-20261114-r01/`，原日志和成功资产保留；停止收据见本次采用根`stop-verification.json`。

## 最新实验（2026-11-13）

单ALU并行ADD/SUB完整功能、原六374104条raw/同周期及独立审计通过，IPC1.109725209820不变；唯一PPA/232宏/完整全组/后测/handoff及同次身份复核完成：**371.350861MHz（−0.883953%）/32472.798239μm²（+0.752153%）**，3093稳定端点退化、missing0，拒绝、不采用。FF WNS改善47.596ps，但DC地址退80.031ps成为最差，不能以违例517→489抵消降频；根`.cpu2026-synthesis/frequency400-alu-parallel-add-sub-{cut,unit,full,ppa,register-identity}-20261113-r01/`。生产/软件不改，旧request-age保持暂停；下一步从374.662703MHz生产独立研究SV两槽选择提前计算，不叠加失败ALU候选。原SV通知集合1048576项数学审计见`frequency400-first-ff-combinational-research-20261113-r01/`，不等于真实模块或提频资格。

SV两槽选择器实验及用户随后“采纳”见当前生产；原审计导入失败、原全组拒绝及所有成功资产保持。根`.cpu2026-synthesis/frequency400-sv-two-slot-select-{research,cut,actual,full,ppa,register-identity}-20261113-r01/`。旧374MHz生产AGU→DC地址64门只读133侧输入/17445节点及独立DFS已完成（`frequency400-lq-pair-prefix-dc-bottleneck-20261113-r01/`）；仅旧版身份，不直接套到新生产63门，下一步从377.511521MHz基线继续组合优化，旧暂停进程不恢复。

当前72门FF第一瓶颈的完整171侧输入/28257节点只读拆解及独立DFS复核通过；主要关注StoreValue通知→Load响应资格→共享CDB→INT_RS选择及晚ALU操作控制串联，非单纯加法器问题，分段不等于逐位RTL或功能敏化证明。根`.cpu2026-synthesis/frequency400-lq-pair-prefix-ff-bottleneck-20261113-r01/`；生产不改、暂停实验未恢复，无新模型或EDA，下一步仅据已认证结构研究组合提前计算。

叶对版实验/采用结论见上；测量根`.cpu2026-synthesis/frequency400-lq-pair-prefix-ppa-20261113-r01/`，同次身份根`frequency400-lq-pair-prefix-register-identity-20261113-r01/`，原始拒绝及失败记录均保留。旧361MHz基线独立request-age比较方向1024对oracle/converted完整descriptor524288组/两有效反例及r02独立审计通过，真实LSU/原六screen未闭合、无PPA；根`frequency400-lq-request-age-prefix-cut-20261113-r01/`及同前缀`screen`。此次采用换代后旧生产pin不再适用，不据其启动或局部资格放行，也不自动叠加到374.662703MHz生产；后续先核退出收据及旧字节映射，成功阶段不重跑。

此前用户恢复持续优化授权，以当时364.899777MHz为基线推进。该版75门路径原103个截断侧锥已补齐并独立复核：21620节点，原52个完整侧锥复用，155个侧输入已计全；仅支持/重汇合关系，不冒称字段或敏化路径。证据：`.cpu2026-synthesis/frequency400-production-side-frontier-20261113-r01/independent-verification.json`。

LSU组合posted屏障功能/原六/独立审计、唯一PPA/232宏/完整后测及保存路径独立复核全部完成：358.826106MHz（−1.664477%）、33243.774059μm²（+3.424197%）、IPC1.122239838632不变；3264稳定端点退化，全组拒绝、不采用。证据：`.cpu2026-synthesis/frequency400-posted-hazard-ppa-20261113-r01/measurement-handoff.json`及`frequency400-posted-hazard-path-study-20261113-r01/independent-verification.json`（同一实验父目录）。

独立LQ存活资格功能/374104退休/完整raw周期及独立审计通过，IPC1.122239838632不变；唯一PPA及232宏/全组后测、handoff已闭合：361.119683MHz（−1.035927%）/32062.575359μm²，2374稳定端点退化，全组拒绝、不采用。原driver误检检查点绝对路径的失败保留，r02仅补收尾，综合/ABC/STA零重跑。证据根：`.cpu2026-synthesis/frequency400-lq-live-ppa-20261113-r01/`、`frequency400-lq-live-closure-20261113-r02/`。同次具名FF归因/独立检查完成：22118个FF全覆盖；FF/PRF起于ALU0 tag[0][0]，DC地址/控制起于LQ tag[3][1]；仅此版本身份，证据`frequency400-lq-live-register-identity-20261113-r01/`。

从364.899777MHz生产新建独立ROB身份bitmap，仅ROB一文件、旧完整tag资格组合表供ALU1/5及split Load查询，无新增状态/级，原writer与invalid元数据保持，不带LQ live候选。57344项代数、strict静态lint、converted六配置212992项/三有效反例、独立audit及cut告警复核通过；真实ROB六配置r02及独立审计通过：分配1/2/4×split0/1，退休2、DEPTH16，13项公开输出与每周期32身份查询均检查，epoch/valid两变异在真实模块检出。真实模型告警逐项复核未完成，整核原六及PPA未运行，不采用。r01反例提取漏声明与真实夹具SIDEEFFECT失败均保留；证据`.cpu2026-synthesis/frequency400-rob-identity-bitmap-cut-20261113-r02/`及`frequency400-rob-identity-bitmap-actual-20261113-r02/`。

用户要求暂停综合并计划删除实验目录：只读盘点2026-11-13 `.cpu2026-synthesis/`约62GiB、166个顶层目录；含原始模型、完整退休日志、mapped网表、全端点/STA、checkpoint及失败和审计证据。按用户要求已复制生产采用证书直接引用的471个文件及正式指针/证书共473文件、1351372130字节至`RISC-V-CPU-2026/synth/production-evidence/`，逐文件源/目标SHA核验；468个直接文件另有证书摘要绑定。清单`RISC-V-CPU-2026/synth/production-evidence-manifest.json` SHA256 `2942cbf1cd35ea390e1df7401d53d25457cdf64abe02ecbf1cd044da82395ce8`。只覆盖直接引用而非历史传递闭包；旧实验及未引用资产未备份，符号链接按内容复制。原证书与正式指针仍使用旧绝对路径，删除旧目录会使原有路径复核失效；未删除原件、未修改生产指针。

用户删除实验目录后继续优化：新独立ROB bitmap局部/真实ROB及有效变异、整核原六374104退休/完整raw周期、独立审计及告警复核通过，IPC1.122239838632不变；归档生产基线按SHA适配。唯一PPA、232宏及完整全组/后测/handoff已闭合：361.040106MHz（−1.057735%）/31981.233539μm²（−0.503673%），2805稳定端点退化、missing0，全组拒绝、不采用；DC地址WNS改善26.646ps不抵消DC控制/PRF数据退化138.135/82.217ps。根`.cpu2026-synthesis/frequency400-rob-bitmap-ppa-fresh-20261113-r03/`，生产364.899777MHz保持。

ROB bitmap保存路径/独立复核完成，FF/PRF代表源为同一AXI writer、共享63弧，DC地址/控制另由LSU writer发起，仅过程和代表路径归属。生产归档网表最差FF launch→全端点组合支持分析/独立DFS完成：该单一DCache writer发射点保守支持14759端点（FF12060、PRF数据1504/控制47、DC地址462/控制132/数据554）；非时序弧/功能敏化证明。r01离线脚本缺导入失败保留，r02未运行EDA；根`.cpu2026-synthesis/frequency400-production-launch-fanout-fresh-20261113-r02/`。

独立DCache响应存在性仅改一处guard，原winner/数据/grant/writer及级数保持；局部1048576项、真实DCache/有效变异、整核374104退休/完整raw周期及独立审计、告警复核通过，IPC1.122239838632不变。唯一PPA、232宏及全组/post/handoff闭合：348.225292MHz（−4.569607%）/32370.344579μm²（+0.706884%），3803稳定端点退化、missing0，全组拒绝、不采用；原生产保持。同次generic具名归因及独立检查完成：FF/PRF代表起于AXI `writeHeadOwnerInner[0]`，FF终点LSU `sqAddressInner[2][10]`。根`.cpu2026-synthesis/frequency400-dcache-response-presence-ppa-20261113-r01/`及`frequency400-response-presence-register-identity-20261113-r01/`。

独立DCache写ACK资格前移各MSHR，保完整victim/status、同周期ACK→fill/writer/级数；低域与4bit高域补测、真实DCache/有效反例、整核374104退休/raw周期及独立审计、告警复核通过，IPC1.122239838632不变。唯一PPA/232宏/全组/post/handoff闭合：353.255714MHz（−3.191031%）/32345.223239μm²（+0.628730%），3763稳定端点退化、missing0，全组拒绝、不采用。DC地址改善3.229ps不能抵消FF/PRF数据退90.521/94.292ps，生产保持364.899777MHz。同次具名归因/独立检查完成：FF74门/PRF72及71门起于AXI `readHeadOwnerInner[2]`，FF终点StoreValue RS `src1ValueInner[0][2]`；DC68/63门起于`lqTagInner[4][0]`。根`.cpu2026-synthesis/frequency400-dcache-write-ack-ppa-20261113-r01/`及`frequency400-write-ack-register-identity-20261113-r01/`。

独立读head 3→8bit singleton（+5bit、无新级）完整功能/374104退休/raw周期、独立审计及告警复核通过，IPC1.122239838632不变。唯一PPA/232宏/全组/post/handoff及同次具名复核已闭合：358.120219MHz（−1.857923%）/32250.424079μm²（+0.333801%），2657稳定端点退化、missing0，全组拒绝、不采用。新最差LQ tag[1][1]→DC地址66门，FF75/PRF67及65门起于ALU1 tag[0][3]，仅本次身份；前端独立逆变换证实RHS/writer原样、工具/脚本/综合序列保持，不重跑EDA。根`.cpu2026-synthesis/frequency400-axi-read-head-mask-ppa-20261113-r01/`及`frequency400-read-head-mask-register-identity-20261113-r01/`、`frequency400-read-head-mask-frontend-review-20261113-r01/`。

用户要求从组合重排转向多条关键路径上游共享切点；LQ叶对位候选已完成strict静态lint/converted524288项/两有效反例及独立审计，现暂停，不推进真实LSU/原六/PPA，不删除资产。根`.cpu2026-synthesis/frequency400-lq-tree-pair-flags-cut-20261113-r02/`。

生产10775条完整保存违例最差路径及独立重数完成：FF/PRF代表共享52弧，约1.297ns处覆盖10111违例端点；DC地址/控制代表共享44弧，约1.232ns处覆盖648端点。两束代表无共同弧，中段无具名RTL别名，不直接照匿名门加FF。源码边界研究也已完成，436419图节点正反计数一致：全部RS信用虚拟切后仍留普通WB→PRF及DCache响应→下一lookup，rename仅fire/完整分配包均非完整断集。证据`.cpu2026-synthesis/frequency400-production-shared-cut-frontiers-20261113-r01/`与`frequency400-shared-register-contracts-20261113-r01/`；下一步从生产隔离检查四池ALU-only即时issue/全CDB寄存捕获，须实测额外Load-use周期及IPC，不复跑旧Branch-only候选。无新PPA或提频结论，生产364.899777MHz保持。

四池共享issue切点已闭合：真实RS八配置/强化stress/三有效反例、原六374104退休九架构字段及独立审计通过；几何IPC **1.077279690032（−4.006287%）**，低于1.1，不综合、不采用。原六周期`8435/13220/3475/5618/174050/166923`，vvadd/qsort周期增加12.060626%/7.204011%。原审计拒绝的新linear selector两处零初始化诊断在full-audit-resume r02窄复核，旧失败/日志保持、模型/转换零重跑。证据`.cpu2026-synthesis/frequency400-shared-issue-edge-full-audit-resume-20261113-r02/independent-audit.json`；生产364.899777MHz保持。下一步区分唤醒延迟与信用反馈，检查保原同拍issue、仅用寄存占用隔离分配信用的独立合同，不叠加本候选。

独立old-row credit切点已闭合：仅core五个REUSE参数，原issue/selector/全部writer保持；真实RS十配置/反例/原六374104退休九架构字段/独立审计通过，IPC **1.109725209820（−1.115147%）**，周期`8241/13428/3112/5732/163214/164296`。唯一PPA/232宏/全组/post/handoff完成：**361.358624MHz（−0.970446%）/32276.507699μm²（+0.414950%）**，2210稳定端点退化、missing0；原技术拒绝保留，用户随后明确采用为生产。FF违例8689→41、PRF数据1504/控制47→0，信用反馈束有真实组级改善；全局10775→531违例，但DC地址WNS退40.963ps成为最差。证据`.cpu2026-synthesis/frequency400-old-row-credit-edge-ppa-20261113-r01/measurement-handoff.json`。

同次generic具名及独立复核完成，22118 FF全覆盖：DC地址67门/控制61门均起于`lqTagInner[1][1]`，代表共享42弧；剩余FF69门起于DCache `requestInner[0][50]`，终点别名含ALU1 value[0][29]，不能跨版套用身份。精确launch残支研究也已完成，127336图节点正反支持一致；Load winner metadata虚拟切边只截断该LQ源→DC，DCache源→DC/ALU仍在，不等于实际新D/使能时序。证据`frequency400-old-row-credit-register-identity-20261113-r01/`与`frequency400-old-row-credit-residual-boundaries-20261113-r01/`。后续从用户新采用的361.358624MHz生产继续，不重跑成功EDA或叠加其他未采用候选。

AXI收集资格预计算完成：361.757562MHz（−0.861117%）、32097.100799μm²、IPC不变；1855稳定端点退化，全组拒绝、不采用。功能/232宏/完整后测及保存路径独立复核齐全，不重复工具，继续独立优化。证据：`.cpu2026-synthesis/frequency400-axi-collect-cofactor-ppa-20261113-r01/measurement-handoff.json`。

AXI共享信用比较完成：361.837456MHz（−0.839223%）、32253.937859μm²、IPC不变；3623稳定端点退化，全组拒绝、不采用。功能/232宏/完整后测及保存路径复核齐全，继续独立优化、不重复EDA。证据：`.cpu2026-synthesis/frequency400-axi-credit-compare-ppa-20261113-r01/measurement-handoff.json`。

Load CDB年龄旁带完成：356.794425MHz（−2.221254%）、32268.284579μm²、IPC不变；3527稳定端点退化，全组拒绝、不采用。功能/232宏/完整后测及保存路径复核齐全，继续从生产独立检查AXI信用资格组合逻辑，不重复工具。证据：`.cpu2026-synthesis/frequency400-load-cdb-age-ppa-20261113-r01/measurement-handoff.json`。

字节重叠偏移布尔化完成：355.632733MHz（−2.539614%）、32155.027139μm²、IPC不变；2970稳定端点退化，全组拒绝、不采用。功能/232宏/完整后测及保存路径复核齐全，成功工具不重复。证据：`.cpu2026-synthesis/frequency400-byte-overlap-offsets-ppa-20261113-r01/measurement-handoff.json`。

LSU RAM/跨行资格窄化完成：350.609887MHz（−3.916114%）、32008.396079μm²、IPC不变；2950稳定端点退化，全组拒绝、不采用。r02复用完成转换补中断阶段，232宏/完整post/handoff齐全；继续只读路径复核和独立优化。证据：`.cpu2026-synthesis/frequency400-yield-line-guard-ppa-resume-20261113-r02/measurement-handoff.json`。

整数双发信用fit完成：356.949891MHz（−2.178649%）、32180.673359μm²、IPC不变；4085稳定端点退化，全组拒绝、不采用。功能/232宏/完整后测齐全，生产364.899777MHz保持。证据：`.cpu2026-synthesis/frequency400-integer-credit-fit-ppa-20261112-r01/measurement-handoff.json`；接续只读保存路径复核，不重跑已完成工具。

SA信用fit完成：355.324225MHz（−2.624160%）、32287.763459μm²、IPC不变，3750稳定端点退化，不采用；功能/232宏/完整全组及后测齐全。证据：`.cpu2026-synthesis/frequency400-sa-credit-fit-ppa-20261112-r01/measurement-handoff.json`。

分配元数据旁带完成：354.172071MHz（对生产−2.939905%）、32092.464359μm²、IPC1.122239838632不变，全组退化，不采用。r02只复用重启前prepared.json补未完成综合，232宏及完整后测通过；生产364.899777MHz保持。证据：`.cpu2026-synthesis/frequency400-allocation-meta-ppa-resume-20261112-r02/measurement-handoff.json`。

## 主要阶段

| 时间 | 演进与决策 |
|---|---|
| 2026年8—9月 | 从软件原型建立拍初读取/拍末写入、完整epoch+slot身份、乱序执行与顺序退休；预测器由TAGE收敛为Tournament。 |
| 10月上中旬 | 对齐两软件与RTL周期合同；DCache SRAM化、4 MSHR、owner及同行合并，接入AXI/MMIO；退出改为等待对应B握手，不扫描全部dirty行。 |
| 10月下旬 | 逐步扩宽译码、分配、退休和执行，形成双ALU/三CDB；10月29日四宽仅有功能/六perf结果，当时没有有效最终PPA。旧数据不恢复，随后从同源快照建立新测量epoch。 |
| 11月1—4日 | 采用PRF SRAM/共享写仲裁、Store位置表4项、空IQ/FQ整组旁路、RS真实离站信用、ROB Load完整身份校验及载荷复位分离；按要求删除Store地址→Load数据通知。 |
| 11月5—6日 | 采用Load下一行预取、SQ≤4/owner=0安全Load让行、同link JALR只push、SQ完成事件及LSU通知资格提前计算。 |
| 11月7日 | 采用跨16B四取指；完成14配置168次原六双模型参数验证，随后采用ROB16/PRF48；采用DCache读地址及整数双发RS直接行选择，完成严格warning清理。 |
| 11月8日 | 新16 KiB DCache完成PPA、两软件资格并正式采用；后续生产回到8 KiB，指标不得交叉套用。 |
| 11月9—10日 | 用户只认可HDL源码提频，否决独立postmap路线；采用SRAM先读＋`-defer`综合前端方法，但不把工具提速算成RTL提频。动态验证后续改为仅converted，native仅保留静态lint。 |
| 11月10—12日 | 新8 KiB基线316.110361MHz；先后采用三项组合333.346897、完整CDB包346.311562、双队列反向信用357.339149MHz，三次原全组非退化拒绝均保持。 |

### 11月12日晚：AGU→DCache地址预选择（已完成，不采用）

仅隔离改DCache需求/预取查询地址预选择，保原取消、grant、任意年龄无winner回退及全部writer/级数。converted局部262144项、真实Cache/SRAM两环境、两个有效反例及参考/候选原六374104退休、全部完整raw/周期同生产，独立审计通过；IPC1.122239838632不变。cut结构嵌套和采用证书字段来源两次流程失败已保留，仅接续未完阶段，成功局部与参考模型未重跑。

旧357MHz网表/端点已清理，本次**一次新同源参考＋一次候选串行PPA**均已完成，2.5ns、INVx1/5fF、SRAM先读＋`-defer`，独立逐叶232宏、完整全端点/路径组及后测通过。新参考重现357.339149MHz/32256.416459μm²；候选347.265791MHz（−2.818991%）/32234.473559μm²（−0.068026%），IPC不变。DCache地址/控制WNS退80.969/34.024ps，FF/PRF及其他组也退化，4036稳定端点退化、missing0，**全组拒绝、不采用**。参考是当前生产重建，不冒充旧工件复用；PPA准备的symlink路径错误在EDA前保留并窄修。生产/两软件未改；随后仅复用实际网表/完整STA研究瓶颈，不重复工具。工作根：`.cpu2026-synthesis/frequency400-dcache-lookup-preselect-pair-20261112-r02/`（工作区路径）。

随后转上游**旧LQ地址行插入预选择**：完整年龄树对各物理行提前计算，晚AGU事件/index/forward仅选结果，保任意非传递年龄/失效载荷和全部writer。源绑定419904组代数及保守假想图研究后，converted筛选r02的524288项cut、真实LSU两配置、四有效反例边界及原六374104退休/全部完整raw/周期、独立审计均通过，IPC不变；夹具重复端口导致的r01转换失败保留，仅修两冗余binding并复用成功lint/cut转换。唯一候选PPA及完整后测完成：**364.899777MHz（+2.115813%）/32143.129859μm²（−0.351206%）**，DC地址/控制WNS改善72.453/159.988ps；但I$地址新增16违例及其他组退化，3222稳定端点退化/missing0，**全组拒绝、未采用**。根`frequency400-lq-address-insertion-ppa-20261112-r01`，复用357MHz参考模型/PPA/全部端点，参考0重跑；随后只读研究新瓶颈，生产不变。

保存路径只读研究已完成：新全局最差为DCache writer→LSU writer，DC地址/控制组代表起点转LSU writer，I$新增违例为独立21门路径；具体字段bit未识别，不当全图/敏化证明。接续只读逐sink/Liberty负载核对，尚未新增RTL或EDA，也未叠加旧I$候选。开放workflow仅精确追加两条成功行的SHA修正独立记录，原证书/失败不回写，无工具重跑。

负载核对首版因标准库fF/SRAM库pF与bus引脚表示不同被解析门禁拦下，原失败保留。仅修单位归一化和总线范围解析、通过正反向小测试后r02只读研究完成：两版I$每个地址bit均16×5fF=80fF，候选未增加地址负载；新慢链上游还直接驱动16个SRAM写使能＋9个组合pin，rise总83.986095fF，再进入80fF地址门。参考WE实际20sink/81.875377fF且不直接接末地址门，候选25sink/约84fF且接末门A1；I$源码未改，这是全核映射共享/驱动形状线索，不相减推Fmax。随后研究新75门全局共享路径的有界侧输入来源，无模型/综合/STA重跑或自动叠加。

新75门主链155个侧输入有界回溯完成，103个截断；第68级XNOR侧支到AGU writer，62/63级侧支含FIFO/RS等但截断，不能凭此识别tagbit或敏化。候选展开中DCache writer1444具名Q位→LSU具名D位查询完成，所达图无环，地址ready保守见证经CDB→SA真实离站信用→rename→稀疏分配rank→兼容地址匹配；仍非映射路径逐门归因。转研究预览槽地址相等位先算、rank后选的等价边界，不改分配/信用、不删除同拍兼容，未启动新RTL/EDA或叠加未采用候选。

随后地址rank匹配131072控制类别/32768任意预览槽地址代数同值、三种错误见证通过；从正式357MHz版**独立**准备单LSU匹配位重组，分配器/fire/index/信用/全部writer保持，不带LQ插入或I$候选。严格静态lint、converted局部524290/两反例、真实LSU两配置/两活动反例及原六374104/全部raw周期、独立审计均过，IPC不变；首cut保留字失败只改夹具名接续且复用lint。唯一PPA/完整后测完成：**330.722648MHz（−7.448526%）/32050.196939μm²（−0.639313%）**，DC地址/控制及FF/PRF均退化，5315稳定退化/missing0，**全组拒绝、不采用**。根`frequency400-address-rank-match-ppa-20261112-r01`，参考0重跑；继续只读核新路径，不机械追加同类rank/mux综合，生产不变。

该负结果保存路径已核：AXI owner→prefix FIFO的75门FF最差与PRF代表共享58弧，DC代表仍AGU起点且共享49弧；只限代表/过程归属，不是全图或精确字段敏化。转共享CDB唤醒源绑定研究，要求Load实际LQ index/响应route也纳入、保持真实grant及ALU优先级；仅研究，不叠加或延迟CDB，无下一RTL/EDA。

Load-index唤醒源绑定代数已完成：131072个6bit源tag/LQ匹配类别、196608个允许preview组合、64个仲裁类别、32768个完整payload优先级样本同值；错误index/未grant/ALU优先级各有见证。非法preview11另有反例（两destination OR不等于OR后index查表），不冒称任意控制等价、不放宽原onehot0断言。下一先验证未改真实LSU的destination/index契约，之后才决定RS候选接口；无新PPA或生产变更。

新真实LSU生产者合同测试只用新公开刺激检查含invalid的destination/index、全64个destination、允许preview route及缓冲竞争，不重跑旧成功回归/参考整核。首版跨层结构观察未被sv2v展平而在构建失败，原失败保留；仅换同一packed位观察，r02又因driver路径变量被同名目录遮蔽在工具前停止。r03仅修路径变量接续，LSU/刺激/断言保持。另已准备默认关闭RS匹配接口helper及六配置真实arbiter/RS差分夹具，未运行消费者；须生产者新合同过后才执行，无生产接线/整核/PPA。

生产者合同r03已完成768新例、23040次检查（含13824次invalid），两配置全部64destination及缓冲/响应竞争通过；错index和原非法route拒绝均有效，原工具不重跑。随后才启动六配置真实arbiter＋RS消费者测试及两变异；三文件接线方案只做源码逆变换/全部writer/原arbiter与payload静态核对，尚未运行整核或综合，生产不变。

RS消费者r02已过六配置3072组/177664次全公开含invalid差分及两有效变异；首版单ALU夹具固定索引告警保留，只修索引不豁免。独立LSU/core/RS三文件候选开启四个当拍issue消费者的Load-index匹配，原writer/完整CDB包/仲裁和SV前缀保持；严格整核lint通过。组合夹具两个观察符号分别被SV保留字/工具公共符号检查拦下，原失败保留，只改名并复用成功lint；r03转换/环锁存静态检查过后已启动真实子系统→候选原六/独立审计完整筛选，参考0重跑。尚无新IPC/PPA结论或生产变更。

完整screen r03及独立audit已通过：真实LSU-CDB-RS两配置各12287次子系统检查及错别名反例、新候选原六374104退休/全部完整raw周期保持，IPC1.122239838632（0%），先前模块/357MHz参考0重跑。已启动唯一候选PPA，根`frequency400-load-index-wakeup-ppa-20261112-r01`，只读复用357MHz参考PPA/全部端点；保持原工具/五库/2.5ns/INVx1-5fF，不叠加旧候选，不自动采用。当前尚无新面积/Fmax/全组结论，生产不变。

该Load-index唤醒候选唯一PPA/完整后测已完成：**353.103448MHz（−1.185345%）/32632.405499μm²（+1.165626%）/IPC不变**。FF WNS改善83.216ps、PRF数据/控制39.583/70.096ps、DC控制78.686ps，违例11624→9402/TNS改善740.103927ns；但DC地址WNS退33.094ps、其他正slack组及真实输入FF退化，2186稳定退化/missing0，**全组拒绝、不采用**。参考0重跑、308927叶/232宏/所有SHA保持；继续只读核保存路径，不直接合并旧候选或追加综合，生产357MHz不变。

该保存路径研究已passed/通知结束：DC地址/控制为AGU writer起点70/69门、共享49弧，FF为AXI owner→RS writer68门，PRF数据/控制64/63门；具体字段bit未知，仅代表共享非全图/敏化证明。最差100ps内84端点全是DC地址，200ps内DC418/FF1584/PRF数据115/DC控制4。转回独立AGU→LSU准入→DCache地址研究，不叠加未采用Load-index/LQ/I$；没有下一RTL或EDA，参考资产不重跑。

当前357MHz保存展开的新准入边界研究完成：只虚拟切Cache阻塞，AGU→DC地址仍112逻辑目标可达、最长支持216→175算子；9个RAM/跨行返回位全切仍216，所以不将已过代数的小跨行化简直接排综合。均为保守支持非STA/敏化/收益。转**独立单LSU旧年龄位预比较**，保原8路字节overlap，不复制旧逐LQ全地址admission的64路重叠锥；32768 tag/control和65536任意原树年龄代数过，锚点空白失败保留。新converted切片163840项/三个有效变异已过。

该候选完整screen r01被严格lint发现真正的generate作用域错误（年龄块误在原CDB输出分支，preview下不可见），未跑实际LSU/整核，原失败保留。r02仅将相同块移到模块级，精确逆回/切片字节与全部writer保持；成功切片不重跑，新严格整核lint和两实际配置converted静态前端过后，已启动真实LSU→候选原六/独立audit完整筛选，根`frequency400-cache-block-age-full-screen-20261112-r02`。尚无新IPC/PPA结论，生产357MHz/两软件/指针不变，参考0重跑。

r02在新committed排除用例失败：实际converted证实夹具把两路12位完整身份的commit向量赋`2'b01`且ROB退休无效，根本未触发真实Store退休；原/新差分未报错不等于完整资格。原失败/模型/所有SHA保留。r03仅补完整同tag commit＋ROB-retire激励及实际ready/fire断言，原其他刺激/断言和候选RTL不变，成功严格lint/切片精确复用；新实际转换/静态lint过后已接续完整筛选。参考/整核/PPA未重跑，无新IPC或采用结论；PPA脚本只做静态准备，尚未启动。

该r03真实LSU/三实际控制反例及候选原六374104退休/全部完整raw周期已通过，IPC1.122239838632（0%）。原服务随后因旧切片delta仍记旧作用域位置被独立审计拒绝，exit1/failure保持；实际测试源精确为模块级同块移位结果。r04只追加严格作用域元数据更正/三错误更正拒绝，再只读完整审计passed，不改原清单/失败或重跑工具。之后才启动唯一候选PPA `frequency400-cache-block-age-ppa-20261112-r01`，原工具/五库/2.5ns/INVx1-5fF/全组/232宏/通用后测保持，357MHz参考0重跑；当前尚无新面积/Fmax，生产不变。

Cache阻塞年龄预比较唯一PPA及全组/后测完成：**344.563617MHz（−3.575184%）/32248.791119μm²（−0.023640%）/IPC不变**。DC地址WNS退103.284ps，FF退101.731ps、PRF数据/控制退106.438/109.832ps；DC控制改善48.512ps不能抵消。全局12342违例/TNS−2733.753824ns，4813稳定端点退化/missing0，**全组拒绝、不采用**；304913叶/232宏与全部SHA保持，参考0重跑。虚拟图216→175不等于实际RTL收益；继续只读核本轮保存路径，不机械扩大比较器或合并旧候选，生产357MHz不变。

该保存路径研究已passed/通知结束：DC地址/控制AGU writer起点69/64门，FF/PRF为AXI owner起点73/69/68门；100ps内DC272/FF2093/PRF控制5。AGU具体launch身份研究亦结束，两版42个同writer FF、无具名Q别名或具名pre-ABC，具体字段bit仍未知，不按编号猜测或重建参考证据。

转独立条件化新地址Load请求资格：旧SQ存在已知地址/数据的潜在转发源时，让未address-ready、未broadcast的旧LQ等待地址捕获，旧ready行/forward/返回/CDB及writer保持。65536 tag/control＋6561 cover/order＋384谓词源绑定代数过；已有改变同拍选择的明确见证，**非逐拍等价，需新测IPC**。首次空白锚点拒绝在工具前保留，窄修后源码逆变换/作用域/3变异预检通过，converted consumer切片已启动，尚无cut/真实LSU/IPC/PPA结论；357MHz参考仅复用，不重跑。

该consumer切片随后131074项/3策略变异passed，额外延后536/选择变化432不是整核周期损失。新真实LSU夹具按字节、完整owner、真实提交/flush及有界进度检查，不做旧生产同拍请求差分；保原多owner/同tag取消回归。严格整核静态lint及两响应配置converted前端通过后，完整筛选`frequency400-selective-address-full-screen-20261112-r01`已启动。仅候选新原六比较九架构字段序列、允许cycle/lane变化并实测IPC；架构比较器5负向通过。当前尚无完整动态/IPC/PPA结论，生产和两软件不变，参考0重跑。

该完整screen r01随后实际LSU在t2880有界进度断言失败，原六/PPA未开始；原failure/模型/源码及全部SHA保留。仅在新converted诊断副本原断言前加打印，保持刺激、原断言和40拍上限，确认是否有未解除Store屏障后再决定窄修；当前未归因为RTL或夹具，未放宽门禁，生产357MHz不变。

只打印诊断随后确认SQ tag8/valid/地址未知，对Load2较年轻、对Load16却较老；Load2已完成，Load16被正确unknown屏障阻塞。r02仅在原边界检查后补原SQ的真实地址事件，不改候选RTL/原oracle/40拍上限，成功静态lint和cut复用。新夹具converted静态检查过后接续完整真实LSU→候选原六/架构审计；当前尚无完整动态或IPC结论。PPA入口只做源码准备并修为按双方实测IPC计算损失，未启动PPA，生产/参考保持。

该条件化请求边界r02完整功能及独立架构审计通过：两真实响应配置各576场景/896结果、3个实际策略变异和原owner回归过，候选原六答案/374104九字段架构序列匹配。**几何IPC1.112876428071（−0.834350%），仍>1.1**；周期8401/13124/3173/5555/164080/163202，较生产+60/+5/+72/+24/+1726/+792，六项均回退，非零代价。需360.345694MHz才抵消IPC×Fmax估算损失，非频率承诺。随后才准备并启动唯一候选PPA`frequency400-selective-address-ppa-20261112-r01`，原工具库/2.5ns-5fF/全组/232宏/post保持，参考0重跑；当前尚无新面积/Fmax，未采用，生产357MHz及两软件不变。

条件化请求边界唯一PPA/全组/后测最终完成：**359.062021MHz（+0.482139%）/32129.978699μm²（−0.391977%）/IPC1.112876428071（−0.834350%）**；IPC×Fmax估算−0.356234%，频率收益不足以抵消IPC损失。DC地址WNS改善13.834ps、DC控制改善231.556ps/66→0违例，但FF TNS退170.180481ns、PRF数据退34.612ps及其他组退化，4129稳定退化/missing0；**全组拒绝、不采用**。302753叶/232宏/全部SHA保持，参考0重跑。继续只读核本轮保存路径，不扩大延后或叠加候选，生产357MHz不变。

随后选择性请求边界的只读保存路径脚本因DC控制代表已转正slack、原脚本却仅从负slack详情索引代表而KeyError退出；原失败/已认证reference路径保留，研究未完成，不是PPA失败或端点缺失，未重跑EDA。用户接着明确选择**采用LQ新地址行插入预选择364.899777MHz版本**，覆盖其此前未采用状态，但原I$新增16违例/其他组退化/全组拒绝不改写。

采用入口`sync/adopt_frequency400_lq_insertion_20261112.py`只核精确已测单LSU（其余43RTL/SRAM和两软件126输入不变），闭合workflow沿既有严格尾段收据认证；不叠加后续rank/唤醒/年龄或条件边界。新软件Release/断言四构建及两外部退休PC/周期资格已启动，根`frequency400-lq-insertion-production-adoption-20261112-r01`；通过后才备份/审阅补丁/原子发布指针。**此时尚未发布**，当前仍357MHz；采用不重建RTL模型或重复综合/ABC/STA，不清理提交推送。

### 11月12日：364.900MHz正式采用完成；按新关键路径持续优化

上述软件资格随后全部通过，审阅补丁后仅替换精确LSU并发布正式指针。`sync/evidence/frequency400-lq-insertion-production-adoption-20261112-r01/finalization.json`及发布后复验passed；当前生产**364.899777MHz / 32143.129859μm² / IPC1.122239838632**，原六8341/13119/3101/5531/162354/162410不变。指针SHA `6d7abc8f649663a85284bc58d639714c0715d9930e23d6041cacc19d9487af8e`，采用证书SHA `6883c178e8e00ac538b8bcaabcabcdf6b3a5f20e76415d6daea3c173f22e5374`。真实旧指针/单LSU/文档备份保持；原I$新增16违例/3222稳定端点退化/全组拒绝不回写。采用无RTL模型/native动态/sv2v/EDA重跑，无提交推送或清理。

用户明确“采纳后继续根据最新关键路径持续优化不能停”，持续授权无自行设定时间/候选数终点。按本次精确备份映射认证复用既有路径、侧输入、反馈支持和I$负载四项研究，不重复分析工具或修改旧manifest。新版全局FF为DCache writer→LSU writer75门/−0.240110ns，与PRF反馈支路相关；DC地址独立LSU writer起点70门/−0.225989ns，I$独立21门/−0.122452ns。具体匿名FF字段bit仍未知，侧锥103截断仍标明，保守支持不是逐门归因/敏化或时序收益。后续优先检查DCache响应资格/事务选择到LSU/CDB反馈的源契约，兼顾DC地址和I$；此刻尚无下一RTL模型或综合启动，不自动叠加未采用旧补丁。400MHz、面积<36000、IPC>1.1和未来候选全组非退化要求保持。

下一独立hit-owner旁带目前仅准备五文件可逆源码helper/生产者与消费者切片夹具，尚未转换/构建/验证或排综合。原预览端口含invalid保持，新旁带仅由旧readIndex选事务号、真实hit route最后授权；缓冲/fallback晚路径仍在，不能宣称切完整主链。用户追加“用之前综合的结果，看有什么可以互补当前生产关键路径缺陷”，优先新只读七版比较：当前364.900、前生产357.339、DC地址347.266、地址rank330.723、Load-index353.103、年龄344.564、条件边界359.062MHz。`sync/compare_frequency400_current_complements_20261112.py`已后台单次提交，根`frequency400-current-complements-20261112-r01`，复用完整保存STA/已认证代表，仅新增当前同名弱端点的逐pin核对，不合并RTL或测新PPA；独立重数检查器已准备。更旧FQ旧信用/I$地址选择/I$行匹配原mapped已不存在，不恢复、不把历史摘要冒充可重审网表。当前尚无完整比较结论，不据源码无冲突自动叠加或将端点乐观拼接称组合频率。

七版比较随后完成，独立重数/共同门弧/输入SHA审查亦passed，无模型/sv2v/EDA。最强互补线索为**Load-index唤醒**：对当前FF/PRF数据/控制组WNS好71.545/39.122/71.382ps、IPC不变、FF TNS好593.570775ns；但DC地址/控制差105.547/81.302ps，6043稳定端点中4163改善/1880退化。其与当前LQ插入源码区间无冲突仍不当组合资格，未合并/综合。当前同名最弱DC地址锚点在该版好36.014ps，但其组最差转到其他端点，不能只挑原最差宣布DC改善。条件化边界能关闭当前57个DC控制违例，却有IPC−0.834350%/4112稳定退化等代价，不作首选。rank/年龄/DC预选择均不补当前FF/DC主链，不机械叠加。

当前FF/PRF代表共享前52弧，DC地址/控制共享44弧，两组及I$代表间无共同弧，仅代表非全图/敏化。当前16个I$ addr[3]违例在旧版均转正，但七版I$源码未改、地址pin负载同80fF，属全核共享/驱动形状线索，不存在可凭这些结果直接合入的I$补丁。10对旧版稳定端点乐观取较好仍至少1545退化，不是实际组合/Fmax或不可能改善证明。报告`sync/FREQUENCY400-CURRENT-COMPLEMENTS-20261112.md`。先保留Load-index为互补对照，继续当前DCache响应身份链的窄旁带合同验证；不自动将旧候选叠加或采用，生产364.900MHz/两软件/指针保持。

独立hit-owner合同r01在任何工具前被正向专用提取锚点拒绝故意错readIndex的变异；失败/partial/冻结脚本封存，不当RTL失败或有效反例。r02只修切片提取以保留输入实际变异赋值，五文件候选/全部writer/刺激保持；新严格native静态lint及两个保断言converted前端已过。`cpu2026-frequency400-hit-owner-contract-20261112-r02.service`已确认active/running/MainPID291787，单次退出通知已附加，根`frequency400-hit-owner-contract-20261112-r02`。仅执行生产者切片262144/消费者完整packet切片98304计划及三有效变异，不运行参考模型、原六或PPA；实际DCache/LSU模块合同及整核资格仍须后续验证，当前不能称完整候选通过或已提频。持续授权保持，此服务退出不是整体任务结束。

该r02生产者262144（hit352/multi1024/未选旁带不同225520）及消费者完整packet98304（live36680）正向过，错readIndex反例有效。错selected-owner亦实际−6被完整packet oracle检出，但脚本预期另一条更窄合同assert报错而停止，原failure/13步/全部模型日志保留。r03按实际原converted行/top/精确三行abort/−6认证该有效反例，改top/消息/退出码三负向拒绝，未改候选/刺激或旧收据。`sync/resume_frequency400_hit_owner_contract_20261112_r03.py`复用上述全部已完工具，仅补原未做的leak-unselected-owner反例；新unit确认active/running/MainPID293130/单次通知附加，根`frequency400-hit-owner-contract-20261112-r03`。实际模块/原六/PPA仍未开始，不将切片通过当整核资格。

该r03切片合同已完整passed、三有效converted反例均结束，通知不再等待。随后新实际模块阶段已准备：真实DCache+SRAM整行/寄存早字两环境保原全部公开含invalid gold差分及字节owner oracle，并新查raw read-owner/selected-hit合同；真实LSU/gold两响应配置保原取消/同tag复用/posted/地址插入回归，另每配置384例三route/全destination/invalid旁带差异/缓冲年龄/flush的全部公开差分。只复用候选精确44源的已过严格native静态lint，不重复切片或参考模型；两个新保断言converted实际前端过。`sync/run_frequency400_hit_owner_actual_20261112.py`及根`frequency400-hit-owner-actual-20261112-r01`已启动，unit确认active/running/MainPID295591/单次通知附加。当前仅实际正向阶段，真实模块负向/候选原六/独立audit及PPA尚待，不提前称完整功能或提频；生产/软件/指针364.900MHz保持。

真实模块正向阶段随后完整passed/通知结束：DCache两环境各742接受/398响应/185行读/47脏写，hit-owner选中检查313/315；LSU两配置各384新例/35770全公开差分/1280未选旁带差异，原取消/同tag复用/posted等回归保持。源/步骤/日志原SHA再验过，不重跑。接续`sync/run_frequency400_hit_owner_full_20261112.py`仅补真实DCache错read-owner与LSU未选owner泄漏两反例（精确原oracle/top/converted行/−6门禁）后，才候选-only新converted原六374104退休/全部raw/周期严格同当前364.900参考及独立audit。原切片/模块正向/候选strict native静态lint和参考模型/raw明确复用，不带旧Load-index、不运行native动态。

新根`frequency400-hit-owner-full-screen-20261112-r01`，两个真实反例保断言converted前端通过；unit `cpu2026-frequency400-hit-owner-full-screen-20261112-r01.service`确认active/running/MainPID299056/单次退出通知附加。此时尚无新原六/IPC或完整audit结论，PPA未准备/启动；独立审计入口`sync/audit_frequency400_hit_owner_20261112.py`已写，过后才同364.900基线新候选唯一PPA/232宏/完整全组。用户持续授权保持，任何单阶段退出不是总任务停止，不自动采用/叠加/清理提交推送。

该完整screen和独立audit现已passed、服务通知结束：两个真实模块反例均有效（DCache错read-owner、LSU未选owner泄漏），新converted原六374104退休/全部完整raw及周期严格保持，IPC**1.122239838632（0%）**；已有切片/模块正向/候选strict native静态lint和参考模型0重跑。原completion保留审计前pending字段，最终另看`independent-audit.json`（SHA `b40a03975ec5e04e4c2ae289a7b534d6ac2b6bbc2527058308e119aba5c5beca`），不回写旧收据。

已新增`sync/measure_frequency400_hit_owner_20261112.py`/launcher，首次候选PPA根`frequency400-hit-owner-ppa-20261112-r01`。明确以**当前364.899777MHz**原PPA/完整端点作为比较基线，不误用357MHz；只读reference适配器将原授权中旧LSU/旧正式指针两项按本次精确采用备份映射认证，其余618原输入保持，不改旧manifest或重测reference。实际make/inside-stats绑定、五文件逆变换/全部writer、screen全部原SHA及baseline364.9检查已过；实际AppImage工具库/显式sv2v/INVx1-5fF/2.5ns dry-run准备已单次后台提交。**此时只是PPA准备执行中，尚未启动综合**，无候选面积/Fmax；准备通过后才独立服务唯一新PPA/232宏/全组/后测。新后测输出另捕获且SHA绑定，避免原workflow自哈希后追加成功行，不忽略原工具日志。

PPA准备随后完整passed，原工具库/232同形状宏/显式前端与2.5ns-5fF dry-run绑定通过，reference零重跑。首次PPA独立unit `cpu2026-frequency400-hit-owner-ppa-20261112-r01.service`已确认active/running/MainPID304178，单次全链退出通知已附加；根仍`frequency400-hit-owner-ppa-20261112-r01`。当前只是首次候选测量服务启动，尚无新面积/Fmax/全组结果，不当提频成功。后续看本根completion/post/measurement-handoff，禁止另起重复PPA、重跑原screen/prepare或采用叠加；本项全链完成后按新实际路径继续持续任务，不将它当整体停止。生产364.899777MHz/32143.129859μm²/IPC1.122239838632及两软件/正式指针保持。

### 11月12日：hit-owner完整测量349.115704MHz，拒绝；继续保存路径研究

上述首次且唯一PPA/ABC/STA、独立232宏/完整全组/只读后测/handoff现均完成，服务success/inactive/dead，所有旧通知结束。面积**32297.371679μm²（+0.479859%）**、Fmax**349.115704MHz（−4.325591%）**、IPC**1.122239838632（不变）**，面积/IPC过、未400MHz、全组拒绝，不采用。28160 timed/11101违例/WNS−0.364202ns/TNS−2969.201041ns，4269稳定端点退化/missing0、匿名FF逐个对应未建。

对当前364.900生产，FF/PRF数据/PRF控制/DC地址/DC控制WNS分别退124.092/149.914/147.637/34.687/67.868ps；FF TNS退1213.615671ns，其他SRAM控制0→8违例。I$地址16→0违例/WNS改善944.896ps、DC地址TNS改善5.816164ns均不抵消其他组退化。304889叶/232同形状宏、全部source/raw/steps/lib/report/端点/mapped SHA及374104退休/全部原周期保持，生产/两软件/指针不改。

handoff已核completion SHA `9310a5261ae60bce43da53a21d18111a95a06f176cd32a5228fa908bbb47c34c`、post SHA `ed4a20ae77292e2aca128a1ffa0f7e2d8b0d0e7eb186a36276f33d9964eb17c6`及post-verifier-exit SHA `72e46a9b216b6f4b6fda1b216030ba692aa159d51bf700f88fe46ead9d937729`，不重跑任何工具/后测。报告`sync/FREQUENCY400-CURRENT-COMPLEMENTS-20261112.md`已补负结果；后续只读保存路径，复用已认证生产代表，正slack组无负路径详情明确标记，不能凭编号/门数/过程归属宣称目标依赖移走。持续授权保持，无下一RTL或EDA启动，不自动采用/叠加/软件变更/清理提交推送。

新`sync/study_frequency400_hit_owner_paths_20261112.py`已后台单次提交，根`frequency400-hit-owner-path-study-20261112-r01`；仅认证hit-owner保存mapped/负路径逐pin及FF/PRF/DC/其他SRAM控制代表与同名锚点，完整正/负端点表分别重算。364.900生产路径从七版认证结果精确复用，不重复解码；正slack代表明确无负路径详情，不新STA。独立算术/覆盖检查器`sync/verify_frequency400_hit_owner_paths_20261112.py`已写，此时研究尚未宣称通过，无下一RTL/模型/EDA。

该路径研究和独立算术/覆盖/SHA审查随后均passed、通知结束。新9条代表/稳定锚点逐pin认证、11101负详情全枚举；生产路径不重复解码。新FF DCache writer `_584447_/QN`→LSU writer `_573726_/D`74门/−0.364202ns，与PRF数据/控制代表共享前52弧，50ps内FF2871/PRF控制25/PRF数据1022。新DC地址/控制均LSU writer `_579737_/QN`起点、61门/−0.260676/−0.122544ns、共享前39弧，与FF/PRF代表无共同弧。RAS架构SRAM控制新最差45门/−0.030794ns，I$最差已正+0.822444ns且无保存正路径逐门详情。仅同版代表/过程身份，未识别FF字段bit或跨版匿名对应，不据此证明hit-owner依赖被切除，亦不从门数/局部延迟推新收益。

### 11月12日：新独立LSU旧owner资格表，先完整packet切片合同

继续当前生产单LSU独立候选，仅把返回owner→FIFO索引→完整LQ身份/flush/相对buffer年龄比较重排为8物理旧owner先算一位资格，晚返回owner选bit；forward优先/完整packet含invalid/所有writer/级数/实际grant及其他43RTL保持。不是hit-owner旁带扩大，不带旧Load-index/年龄/rank/条件边界；复制8组相较3 route有面积/扇出与重合并风险，尚无动态/IPC/时序资格，不声称一定快。

helper `sync/frequency400_owner_qualification_table_20261112.py`及入口`sync/run_frequency400_owner_qualification_cut_20261112.py`；源码逆变换/全writer和原packet后缀字节保持。首纯源码TB空白锚点失败/原helper封存`frequency400-owner-qualification-development-20261112-r01`，随后只修夹具移除旧无关旁带激励的空白，源RTL不变；初诊空白方向错误由追加diagnosis-correction明确更正，不回写原failure。

新严格native静态lint和保断言converted cut前端过；合同根`frequency400-owner-qualification-cut-20261112-r01`，独立unit确认active/running/MainPID316088，单次全链通知附加。计划98304完整packet任意旧态cut/错owner选择、漏epoch身份、反转buffer等龄tie三个有效converted反例，尚未宣称动态过；真实LSU/原六/独立audit/PPA均未启动。生产364.899777MHz/32143.129859μm²/IPC1.122239838632/指针6d7abc8f...保持。400/面积<36000/IPC>1.1/全组不放宽，持续授权保持，不自动采用/叠加/软件变更/清理提交推送。

上述cut随后完整passed：98304完整packet检查、三个变异均由原oracle实际−6检出，旧合同服务及通知结束，不重跑。`drop-epoch-identity`实际变异是移除整条LQtag==FIFOtag（含epoch）检查，不只是高位epoch，名称不扩大为高位专项穷举；有限切片非全状态形式证明。随后新实际LSU/gold两response配置夹具保原多owner取消/同tag复用/posted/reset/地址插入，另每配置384例三route/全destination/缓冲竞争与flush，已去掉旧hit-owner新接口/激励，不引入新生产者合同。

完整入口`sync/run_frequency400_owner_qualification_full_20261112.py`、实际夹具/独立audit同名已写，三个保断言converted实际前端过；`cpu2026-frequency400-owner-qualification-full-screen-20261112-r01.service`确认active/running/MainPID317981，单次完整退出通知附加，根`frequency400-owner-qualification-full-screen-20261112-r01`。依次真实LSU正向→错owner/无视buffer年龄两个实际反例→仅候选新converted原六374104/全部raw周期须同生产→独立audit，全部通过才准备唯一新匹配PPA。旧cut/三反例/strict native静态lint和364.900参考模型/raw均精确复用不重跑。当前只是完整screen启动，无新真实模块/原六/IPC/PPA资格；生产/两软件/正式指针保持，不把单服务退出当持续授权结束。

上述完整screen所有工具均完成：真实LSU两配置各384新增例/全部原public含invalid/取消同tag/posted/reset回归及两个实际变异有效，新converted原六374104退休/全部raw/周期严格同生产，IPC1.122239838632（0%）。原服务最终exit1发生在独立审计：`ignore-buffer-age`有效三行abort前先打印两行原定向用例PASS，审计错误要求整个文件恰三行，原失败及completion.pending均保留，不能当完整资格已过或RTL失败。

`sync/audit_frequency400_owner_qualification_20261112_r02.py`仅对该一个反例精确鉴权`PASS LQ insertion real directed PREVIEW=0/1`两行前缀，再执行原三行fatal/top/源行/消息/−6及全部原审计；额外/改字/缺前缀/零退出四负向拒绝。原失败/关闭workflow/所有模型raw/脚本封存同根`failure-finalization-r02.json`，另写`negative-prefix-review-r02.json`，未改RTL/刺激/原收据，未重跑模型/局部/反例/原六/EDA。r02只读完整独立audit现已passed、通知结束，同根`independent-audit.json`为最终资格。

新PPA入口`sync/measure_frequency400_owner_qualification_20261112.py`/launcher只绑定此独立单LSU候选，复用已完成hit-owner测量所用原匹配框架，但不复用其候选网表或叠加其五文件。以真实364.899777MHz生产原PPA/完整端点为基线，旧授权LSU/指针仅按精确采用备份映射，reference不重测；r02audit/全部raw/关闭失败及actual make/inside-stats绑定无工具预检通过。首次候选PPA准备已后台单次提交，根`frequency400-owner-qualification-ppa-20261112-r01`；**此时尚未启动综合**，准备通过后才一次新PPA/232宏/完整全组/后测。无新面积/Fmax、不自动采用/组合/软件变更/清理提交推送，持续授权保持。

首次PPA准备随后完整passed：单LSU差异/全部writer与其余RTL-SRAM-script同源、实际AppImage三工具/五库/显式sv2v/2.5ns-INVx1-5fF dry-run通过，参考0重跑。独立unit `cpu2026-frequency400-owner-qualification-ppa-20261112-r01.service`已确认active/running/MainPID324350，单次完整退出通知附加；根仍`frequency400-owner-qualification-ppa-20261112-r01`，只此一次新候选综合/ABC/STA/232宏/全组/后测。r02完整screen审计SHA `67b6aa3abc41e3733613fbd381323bd4db7ed1e38f0dbbbff3f94d3872f37e78`；真实LSU两配置各384例/35770次公开差分、6周期和374104退休保持。**当前只是PPA服务启动，尚无新面积/Fmax/全组结论**。后续看本根completion/post/measurement-handoff，不重复PPA/后测/screen或原六；原审计失败保持，不自动采用/叠加/软件指针/清理提交推送，持续授权无自行停止线。

### 11月12日：旧owner资格表356.949891MHz完整测量拒绝，转保存路径研究

上述唯一PPA/ABC/STA、独立逐叶232宏/完整全组/后测/handoff现均完成，服务success/inactive/dead，旧通知结束。面积**32296.846799μm²（+0.478226%）**、Fmax**356.949891MHz（−2.178649%）**、IPC**1.122239838632（不变）**；面积/IPC过、未400MHz、全组拒绝、不采用。28160 timed/10680违例/WNS−0.301046ns/TNS−1757.403335ns，2958稳定端点退化/missing0，匿名FF对应未建。

相对当前364.900MHz生产，DC地址WNS退75.057ps、FF退25.652ps/PRF数据73.098ps/PRF控制57.275ps；DC控制WNS退5.541ps，虽57→44违例/TNS好0.265105ns，不能抵消。FF TNS退178.108671ns，其他SRAM控制0→8违例，真实输入FF退89.474ps；I$地址16→0/WNS好564.186ps、DC地址TNS好11.138271ns亦不能代替全组通过。305642叶/232同形状宏、所有输入/raw/步骤/库/report/端点/mapped SHA及374104退休/原六周期保持，生产/两软件/正式指针未改。

通知后仅认证原完成/后测/handoff与关闭SHA，不重跑工具：completion SHA `f9cd5d5bc7528d61c0ecbef245597b1b86a0ec945abc39da1b237490fb5af0e1`，post SHA `bd16e2fcc376f02ffce13a81a6104d6dc8066f582d7f28e6b4587891b1ecef86`。8物理owner身份/年龄资格前移未获得整核收益，不继续机械扩大同类比较复制。新保存路径入口`sync/study_frequency400_owner_qualification_paths_20261112.py`与独立算术/覆盖检查器已准备，仍复用已认证364.900生产代表，仅对新candidate的代表/同名锚点逐pin；正slack组无负路径详情明确标记，不新STA/模型/EDA。研究结果待后再选不同切点，持续授权/400/面积<36000/IPC>1.1/完整全组保持，不自动采用/叠加/软件变更/清理提交推送。

该保存路径研究已单次后台提交并附带完整退出通知，根`frequency400-owner-qualification-path-study-20261112-r01`；此时尚无研究完成结论。所有旧screen/PPA/审计通知结束，不重复等待或重启；当前只有该只读研究待通知。

该保存路径研究及独立算术/覆盖/SHA审查现均passed，通知全部结束；9条新代表/具名锚点逐pin/net认证，10680负端点详情完整枚举，生产代表精确复用，无模型/sv2v/EDA重跑。FF代表AXI owner writer `_581354_/QN`→RS writer `_577846_/D`73门/−0.265762ns，与PRF数据/控制代表共享前48弧（任意位置54弧）；DC地址/控制代表LSU writer `_589829_/QN`起点64/62门、−0.301046/−0.060217ns，共享前40弧，与FF/PRF代表无共同弧。10ps近关键4个全DC地址，50ps内DC地址8/FF30/PRF数据100/PRF控制1。RAS架构SRAM ce新最差55门/−0.010999ns；I$最差+0.441734ns，无保存正slack逐门详情。仅同版代表/过程归属，未识别具体字段bit或跨版匿名FF对应，不当目标依赖移除或敏化证明。completion SHA `28a55f8b29a6c82cc935b5e897c2f814dfc721190f4bc28d257545f4f7500d03`，原pending字段不回写，最终独立审查另存。

接续不同的共享物理目的tag one-hot编码源码契约研究：生产者先解码、真实shared grant最后选mask，RS仍取原完整包/最低port优先，Load须包含三route的response/buffered cofactor。完整PHY_TAG_W编码（含P0及48..63）保持，SV仅ALU issue前缀不扩源；非法preview=11不能将OR tag解码冒充OR掩码，明确研究边界。当前尚无新候选RTL/动态资格/综合，64bit宽掩码/源tag动态索引/全核共享与扇出代价待评价，不带旧Load-index或owner表补丁；生产364.900MHz/两软件/正式指针保持。

### 11月12日：共享PHY编码代数完成；独立三文件候选合同准备

`frequency400-shared-phy-decode-research-20261112-r01`已passed，仅源码绑定两态分解代数：4096完整tag对、1048576三候选tag/真实grant掩码、8192 response/buffered选择、786432合法route、16384完整WB优先级/前缀例，7错误逻辑见证/3源码锚点负向。非法preview11另262144组中258048不等价，明确只在原onehot0合同内重组，不声称无约束等价；无RTL模型/sv2v/EDA。

选定新独立LSU/core/RS三文件helper `sync/frequency400_shared_phy_mask_20261112.py`：只shared端口共用64bit目的匹配mask，LSU旧LQ解码→三route response/buffered mask→真实shared grant，RS仅四个早issue池开启；ALU比较、SV/乘除RS路径、完整包含invalid/最低port优先、全部writer/级数/grant保持。精确逆回三文件/顺序writer/其余硬件保持通过，不套旧Load-index。逻辑8×64解码bit/64位共享线不是面积结果，源tag多路选择、扇出及重合并可能退化，不预判提频。

纯Python切片提取首次因localparam行空白锚点0匹配失败，在工具前封存`frequency400-shared-phy-mask-development-20261112-r01`原helper/driver和诊断（非伪造原raw）；只修锚点，候选RTL不改，后续正负实际提取预检过。新入口`sync/run_frequency400_shared_phy_mask_cut_20261112.py --prepare`已单次后台提交，根`frequency400-shared-phy-mask-cut-20261112-r01`，执行严格native静态lint及两保断言converted切片前端。计划生产者98304完整packet-mask/真实arbiter+RS匹配65536例和三有效变异，**尚无动态/真实模块/原六/PPA资格，尚未启动综合**。文档`sync/FREQUENCY400-SHARED-PHY-MASK-20261112.md`；生产/软件/指针364.900MHz保持，持续授权无停止线，不自动采用叠加/清理提交推送。

该prepare随后完整退出0：严格native静态lint及两个保断言converted前端均过。独立unit `cpu2026-frequency400-shared-phy-mask-cut-20261112-r01.service`确认active/running/MainPID346307，单次完整退出通知已附加，仅新converted合同正向/三变异阶段；不重复prepare/转换或参考成功资产。此时尚无动态完整结论，真实模块/原六/独立audit/PPA仍待后续，不将启动当提频/面积收益。所有此前owner表研究/测量通知已结束，不再等待或重启。

r01通知随后结束：首producer converted构建被2条PROCASSWIRE拒绝，动态/真实模块/原六/EDA0。错误是提取切片把由always_comb写的loadPhyMaskOutput声明为wire；实际候选LSU output为logic且严格静态lint过，不归因为已证RTL功能失败。原failure/全部产物/冻结helper-driver封存r01 `failure-finalization-r02.json`不回写。

r02新helper/接续入口仅提取夹具内部wire→logic，正向/两producer变异均可精确逆回，三文件候选RTL/全部刺激/oracle/消费者切片保持。原strict native静态lint和不受影响consumer转换按原命令/日志/源码SHA复用，只有受影响producer转换新做且通过；不重跑原成功工具。新独立unit `cpu2026-frequency400-shared-phy-mask-cut-20261112-r02.service`确认active/running/MainPID347564，根同r02、单次完整退出通知附加。当前仍仅合同动态阶段，尚无完整动态/真实模块/原六/PPA结论，生产364.900MHz/两软件/指针保持；r01旧通知结束不再等待或重启，持续授权保持。

r02动态正向生产者98304/消费者65536例和丢buffer反例有效，丢P0反例退出0被门禁拒绝。只读实际变异LSU/生成cut确认：LSU含`phy!=0`但cut没有，生成器插回原DECODE常量而非从变异源提取。是切片绑定缺口，不能当有效反例或笼统归因覆盖不足；原r02failure/模型raw/全部脚本封存`failure-finalization-r03.json`。

r03仅将decoder块改从实际候选/变异源码提取，正向/丢buffer切片逐字节同r02，成功正向/有效反例/native静态/转换全部精确复用不重跑；只补正确P0与未做grant泄漏反例。根`frequency400-shared-phy-mask-cut-20261112-r03/completion.json`现passed/3有效converted反例，top/源行/精确三行abort/−6均过。独立`sync/audit_frequency400_shared_phy_mask_cut_20261112.py`只读源码绑定/16步骤日志/复用链/正负来源/逆变换writer/保护Git审计passed，同根`independent-audit.json`，原pending字段不回写。合同通知全部结束，无EDA。

接续实际模块**正向阶段** `sync/run_frequency400_shared_phy_mask_actual_20261112.py`，两新保断言converted前端prepare已后台单次提交，根`frequency400-shared-phy-mask-actual-20261112-r01`；此时尚无实际动态完整结论。真实LSU/gold两响应配置保全部公开含invalid及原owner/取消/同tag/posted/reset/新地址插入，每配置384新route/全64tag/缓冲/flush例并查完整mask；真实arbiter+实际RS/gold六配置各512 source/合成索引例，检查分配捕获/旧行唤醒/全公开含信用和无效载荷/优先级/未grant/freeze/flush/短issue前缀。RS Load掩码为夹具合成输入，不能冒称真实LSU-RS整合；core接线仍须新候选整核。只复用夹具代码不套旧模型资格，真实模块反例/原六/完整独立audit及PPA均待后续；生产/软件/指针364.900MHz保持，不自动采用/叠加/清理提交推送。

该实际prepare随后完整退出0，两保断言converted前端过；独立正向unit `cpu2026-frequency400-shared-phy-mask-actual-20261112-r01.service`确认active/running/MainPID354347，单次完整退出通知附加。当前只是实际模块正向运行，无新实际完整结论/IPC/PPA，旧合同与审计不重复；后续看本根实际完成/失败通知再补真实变异和候选原六/独立audit，不将此阶段退出当整体停止。

实际正向现已passed/通知结束：LSU两配置各384新例、各35770次全公开差分/mask检查、全64目的tag覆盖`ffffffffffffffff`；RS六配置各512例，标量26624次检查，其余各30208次检查，完整公开含无效payload/信用/操作数oracle通过。该完成只代表正向，未冒称真实LSU-RS整合/原六或新PPA，原产品SHA保持不重跑。

新完整入口`sync/run_frequency400_shared_phy_mask_full_20261112.py`/独立审计同名已写，根`frequency400-shared-phy-mask-full-screen-20261112-r01`；真实LSU丢P0与RS错source bit两有效converted反例前端prepare已单次后台提交，过后才独立screen服务。后续只补两反例→候选-only新converted原六374104/完整raw周期与当前生产严格同→独立audit；原静态/正向模块/切片及364.900参考成功资产不重跑，不运行native动态。**此时尚无新原六/IPC/PPA结论，尚未启动综合**。生产/两软件/指针保持，持续授权无停止线，不自动采用/叠加/清理提交推送。

该prepare随后完整退出0，两真实变异保断言converted前端过；完整screen unit `cpu2026-frequency400-shared-phy-mask-full-screen-20261112-r01.service`确认active/running/MainPID360832，单次完整退出通知附加。当前仅依次真实反例→候选原六→独立审计运行，尚无此完整动态/IPC/面积/Fmax结论，PPA未启动。当前唯一待通知是该完整screen，旧合同/实际正向通知全部结束，不重复成功工具或将单项退出当持续任务终点。

共享PHY完整screen随后完成，独立`independent-audit.json`passed、通知结束：两个真实模块反例有效，候选新converted原六374104退休/全部完整raw SHA和周期8341/13119/3101/5531/162354/162410严格同当前生产，几何IPC**1.122239838632（0%）**。三文件inverse/全部writer、切片3反例、真实LSU两配置/RS六配置/2实际反例、full raw/source保护Git和同源参考完整鉴权；参考模型构建运行0、native动态0。原completion审计前pending字段不回写，最终看新增独立audit，不能因pending旧字段再重跑成功功能或审计。

首次PPA入口`sync/measure_frequency400_shared_phy_mask_20261112.py`及匹配launcher已写，新根`frequency400-shared-phy-mask-ppa-20261112-r01`。无工具实际make/inside-stats/三文件范围/launcher及显式sv2v/2.5ns/INVx1-5fF绑定预检过，实际AppImage工具五库/dry-run准备已单次后台提交。仍仅复用已采用364.899777MHz原PPA/完整全端点，原授权旧LSU和正式指针两项按精确采用备份映射、其余原SHA不放宽，不套旧owner/hit-owner网表或重测reference。**此时只是首次准备执行中，尚未启动综合/ABC/STA，无新面积/Fmax或全组结论**；准备过后才唯一新PPA/232宏/完整全组/只读后测。生产/两软件/指针364.900MHz保持，持续授权无停止线，不自动采用/叠加/清理提交推送。

该准备现已完整passed：真实AppImage三工具/五库/原脚本/显式sv2v与2.5ns/INVx1-5fF dry-run绑定通过，reference0重跑。首次独立PPA unit `cpu2026-frequency400-shared-phy-mask-ppa-20261112-r01.service`确认active/running/MainPID370714，单次完整退出通知已附加；根仍`frequency400-shared-phy-mask-ppa-20261112-r01`。仅此一次新候选综合/ABC/STA、独立逐叶232宏/完整全组/后测，当前尚无新面积/Fmax/全组结论，不能把启动/IPC不变当提频成功。后续看本根completion/post/measurement-handoff，禁止重复prepare/成功功能/审计/PPA或手工再启动。当前唯一待通知是该完整PPA，所有旧screen/合同/实际通知已结束；生产364.899777MHz/32143.129859μm²/IPC1.122239838632/两软件/正式指针保持。完整退出后按实际新路径继续持续任务，不自动采用/叠加/清理提交推送。

### 11月12日：共享PHY掩码345.508224MHz完整测量拒绝；继续保存路径研究

上述首次且唯一PPA/ABC/STA、独立逐叶232宏/完整全组/只读后测/handoff现均完成，服务success/inactive/dead，旧通知结束。面积**32716.648739μm²（+1.784266%）**、Fmax**345.508224MHz（−5.314213%）**、IPC**1.122239838632（不变）**；面积/IPC过、未400MHz、全组拒绝，不采用。28160 timed/11016违例/WNS−0.394153ns/TNS−2844.861512ns，3000稳定端点退化/missing0，匿名FF对应未建。

相对364.900生产，DC地址/控制WNS退168.164/179.480ps、FF退119.093ps、PRF数据/控制退136.980/131.424ps，FF TNS退1052.805740ns；其他SRAM控制0→8违例，真实输入FF退55.790ps。I$地址16→0/WNS好661.534ps等局部改善不抵消全组退化。309375叶/232同形状宏、全部source/raw/steps/lib/report/端点/mapped SHA、374104退休及六周期保持，生产/两软件/正式指针不改。

通知后仅核原completion/post/handoff及关闭SHA，无工具重跑：completion SHA `9bbba08f1e5423fa41fc2f72ccf374f729d3efcdb87ca0d285b4119d6aec9cea`，post SHA `c5756ca33bcc4210361e3ae9273d6532b3f41f4e39170b0a2dfd4c13fdd6665a`。共享64bit目的编码这一具体版本无整核收益，不继续机械放大解码/比较器；不把代数等价当提频，也不单因归为扇出或永久否决所有编码实现。新只读入口`sync/study_frequency400_shared_phy_mask_paths_20261112.py`及独立算术/覆盖检查器已准备，根`frequency400-shared-phy-mask-path-study-20261112-r01`；复用生产代表，只新candidate代表/同名锚点逐pin/net，完整端点与负详情覆盖重算，正slack缺详情标缺，不新STA。持续授权保持，无下一RTL或EDA启动，不自动采用/叠加/清理提交推送。

该保存路径研究现已单次后台提交并附加完整退出通知，尚无完成结论；当前唯一待通知是此只读研究。原共享PHY PPA/功能/审计服务全部已结束，不再等待或重启。

共享PHY保存路径和独立算术/覆盖/SHA复核现均passed，所有旧通知结束：新10条代表/锚点逐pin/net认证、11016负详情完整枚举，生产代表精确复用，模型/STA/EDA0重跑。FF为AXI owner过程起点81门/−0.359203ns，与PRF数据/控制代表共享前62弧，PRF76/75门、−0.324082/−0.328091ns；DC地址/控制LSU过程起点68/64门、−0.394153/−0.234156ns，共享前55弧，与FF/PRF代表无共同弧。10ps内32个全DC地址，50ps内DC地址40/FF189；RAS架构SRAM ce47门/−0.170129ns，I$+0.539082ns无保存正路径详情。仍只同版代表/过程归属，不识别具体字段bit或据此宣称敏化/全图独立/跨版匿名对应，也不把退化单因归为mask扇出。

下一不同方向先研究**Load重复flush准入消去**：LSU输出有效包已以包自身robTag鉴权同一global flush，而core在CDB准入又比较一次。新`sync/research_frequency400_load_flush_fusion_20261112.py`仅源码绑定两态代数/错误见证，保完整ROB lookup身份、全部LSU身份/flush/forward/age、真实grant/完整payload/优先级与恢复门控，不用未证明可达性或删除安全检查。原preview onehot0合同须保持，非法11另记录反例，不冒称无约束等价。尚无该方向候选RTL/转换/动态/原六/EDA，编译器可能已化简重复项且其他晚链仍在，不预判提频。生产364.900MHz/两软件/指针与持续授权保持，不自动采用/叠加/清理提交推送。

该新源码代数研究已单次后台提交，根`frequency400-load-flush-fusion-research-20261112-r01`，完成结果尚待通知；这是当前唯一待通知任务，不重等已结束共享PHY路径/PPA/审计。

Load重复flush研究r01在源码锚点检查因两续行各多写一个空格而拒绝，代数/模型/sv2v/EDA均未开始；实际core原字节与预期语义相同，未改RTL。原failure/inputs/冻结脚本封存r01 `failure-finalization-r02.json`。新`sync/research_frequency400_load_flush_fusion_20261112_r02.py`只修精确缩进锚点并改独立r02根，保全部研究算法/覆盖/错误见证；已单次后台提交，尚无完成结论，不重复任何工具或改生产。

该r02源码代数现已passed/通知结束：16384全部32×32 tag对/valid/flush/recovery/ROB-live例、1572864组三route组成例、3源码绑定拒绝及producer缺flush/非法11/丢ROB/丢恢复错误见证。组成例第四flushTag为确定公式而非全部第四tag穷举，任意flushTag由逐packet引理覆盖；仅源码两态代数非实际RTL/形式/IPC/PPA资格。

选定新独立**单core表达式**候选：`sync/frequency400_load_flush_fusion_20261112.py`只删Load准入中已被未改LSU有效packet蕴含的同一flush重复项，保完整ROBlive lookup、恢复、LSU所有身份/flush/forward/age、原实际仲裁/grant/完整invalid payload和全部writer/级数；新core仿真断言仍检查producer合同及旧准入全方程。不叠加共享PHY掩码或旧Load-index；单core逆回/原always_ff与真实producer+consumer片段/三变异提取静态过。新入口`sync/run_frequency400_load_flush_fusion_cut_20261112.py --prepare`已单次后台提交，根`frequency400-load-flush-fusion-cut-20261112-r01`，严格native静态lint/保断言converted前端准备，尚无动态结果。

计划98304完整packet/准入合同、丢ROB身份/丢恢复门控/缺producer flush三有效converted反例；最后一项同时破坏两producer副本以显露必要合同，不冒称候选改LSU。还须独立审计/真实core集成新原六374104退休及完整raw/最终独立audit才PPA，不能以源码删重复项预判提频，综合器可能已吸收且其他晚链仍在。报告`sync/FREQUENCY400-LOAD-FLUSH-FUSION-20261112.md`；生产364.900MHz/两软件/指针及400/面积<36000/IPC>1.1/完整全组不改，持续授权不设停止线，不自动采用/叠加/清理提交推送。

该prepare随后完整退出0，严格native静态lint/保断言converted前端通过；新独立unit `cpu2026-frequency400-load-flush-fusion-cut-20261112-r01.service`确认active/running/MainPID402909，单次完整退出通知附加。当前只是converted合同及三反例运行，尚无完整动态/真实core原六/独立audit/PPA结论；此前共享PHY/新代数研究通知全部结束，不再等待或重启。生产/两软件/指针保持。

### 11月12日：Load重复flush合同98304/三有效反例与独立审计过；新整核converted原六启动

上述合同现已完整退出：98304完整packet/准入例通过；live字段36993是原切片计数，不当退休或省拍数。丢ROB身份/丢恢复门控/缺producer flush三变异均指定oracle真实−6、准确三行abort及converted行号/原始SHA通过。独立审计r01误把flush端口锚点要求在整个core唯一，实际11个原消费者同接global flush，非候选失败；原失败`audit-r01-failure.json`和冻结脚本保留。r02仅限定实际LSU实例，保其余规则，独立passed；重建producer/consumer/三变异、原converted来源/断言、13步骤、单core逆回/全部writer/生产保护/Git，模型/转换/EDA0重跑。缺producer flush仍是合同依赖反例，不冒称候选改LSU。

新入口`sync/run_frequency400_load_flush_fusion_full_20261112.py`及独立audit，根`frequency400-load-flush-fusion-full-screen-20261112-r01`。prepare无新工具通过，精确复用合同/严格native静态lint和现364.900参考源码/原六raw；参考模型构建/运行0。新候选完整student_top直接集成实际core/LSU/ROB/arbiter并保两条新合同断言，不称独立真实core夹具或重跑旧未改LSU模块资格。只新converted完整原六374104退休/全部raw周期必须等同生产，最终独立audit过才后续唯一同生产PPA/232宏/完整全组。

独立unit `cpu2026-frequency400-load-flush-fusion-full-screen-20261112-r01.service`确认active/running/MainPID409239，单次完整退出通知附加。此时尚无新完整动态/IPC/面积/Fmax结论，PPA未启动；原合同/源码研究/共享PHY通知全部结束，不重等或重启。生产364.899777MHz/32143.129859μm²/IPC1.122239838632/两软件/指针保持，400/面积<36000/IPC>1.1/全组非退化及持续授权不放宽，不自动采用/叠加/清理提交推送。

整核等待期间仅静态准备`sync/measure_frequency400_load_flush_fusion_20261112.py`及对应PPA launcher，实际导入/launcher→measure→configure、仅单core差异与逆变换、完整screen独立audit/98304及三有效反例门禁绑定通过。沿用364.900参考原PPA的精确采用备份映射和2.5ns/INVx1-5fF/232宏/完整全组/后测；当前未调用PPA prepare、PPA根尚未创建、EDA0。仍只等当前整核完整退出通知，通过后才正式准备/唯一启动，不把静态接口检查当原六或PPA资格。

### 11月12日：Load重复flush新原六/完整raw/独立审计过；首次PPA准备提交

上述完整screen现已退出且独立audit passed。新候选converted原六374104退休/全部完整raw及周期8341/13119/3101/5531/162354/162410严格等同当前364.900生产，几何IPC1.1222398386316592/变化0%；实际core/LSU/ROB/arbiter整核中两条producer合同与旧完整准入oracle断言均保留。参考构建/运行0、成功合同/静态lint精确复用，通知后只核关闭SHA与全部保护，无工具重跑。completion SHA `61e73ba8166e313a111bbc69daf76dc684d600b406f10582d71536ddae6eb132`，audit SHA `dc68abd11a3d82b1423e0ecc24fdffc3fea540bccdafc34f9351b518205a65ac`。

已单次后台提交`sync/measure_frequency400_load_flush_fusion_20261112.py --prepare`，首次PPA根`frequency400-load-flush-fusion-ppa-20261112-r01`，核现成功screen及364.900参考/采用备份映射/工具库/原约束。当前仅prepare提交，尚未确认通过或实际综合启动，无新面积/Fmax/全组结论；唯一待通知为prepare，原screen/合同通知全部结束，不重等或重复成功工具。生产/两软件/指针保持，不自动采用/叠加/清理提交推送，持续400MHz/面积<36000/IPC>1.1/完整全组保持。

上述prepare现已完整passed：资格与364.900参考采用备份映射、真实AppImage工具/五库/原脚本及2.5ns/INVx1-5fF dry-run绑定通过，reference0重测。首次PPA unit `cpu2026-frequency400-load-flush-fusion-ppa-20261112-r01.service`确认active/running/MainPID413202，单次完整退出通知已附加；根仍`frequency400-load-flush-fusion-ppa-20261112-r01`，仅该单core候选一次新综合/ABC/STA、独立逐叶232宏/完整全组/只读后测。此时尚无新面积/Fmax/全组结论，不把启动或IPC不变当提频成功；后续看本根completion/post/measurement-handoff，禁止重复prepare/成功功能/audit/PPA。当前唯一待通知是完整PPA，所有旧prepare/整核/合同通知结束；生产364.899777MHz/32143.129859μm²/IPC1.122239838632/两软件/正式指针保持。完整退出后审阅真实新路径继续持续优化，不自动采用/叠加/清理提交推送。

### 11月12日：Load重复flush354.708811MHz完整拒绝；继续保存路径研究

上述首次且唯一PPA/ABC/STA、独立逐叶232宏/完整全组/后测/handoff均完成，服务success/inactive/dead。面积32322.770039μm²（+0.558876%）/Fmax354.708811MHz（−2.792812%）/IPC1.122239838632（不变）；面积/IPC过、未400MHz、全组拒绝，不采用。28160 timed/10693违例/WNS−0.318641ns/TNS−1495.537120ns，2333稳定端点退化/missing0，匿名FF对应未建。

DC地址WNS退92.652ps/TNS退10.493624ns、PRF数据退11.731ps/TNS退14.580914ns；其他SRAM控制0→8违例/WNS退132.499ps，真实input-from FF退72.928ps。FF WNS好14.929ps/DC控制好14.176ps/I$地址16→0/WNS好531.075ps及全局TNS好22.046118ns，不抵消上述退化；不由源码重复检查删去宣称提频。305040叶/232同形状宏、全部source/raw/steps/lib/report/完整端点/mapped SHA与374104退休/六周期保持；通知后只核关闭completion/post/handoff和保护，无工具重跑。completion SHA `dbfea4f98f50aacc58904a9ad5dcf0fa2495ed85d8f7a7d7a578368f3af3b703`，post SHA `ccef99e68c32df49868c36556f5f2611d74763732a36106374b6d07080dd8e7a`。

持续授权继续，不叠加或采用本项。新`sync/study_frequency400_load_flush_fusion_paths_20261112.py`及独立检查器已准备，根`frequency400-load-flush-fusion-path-study-20261112-r01`；生产代表精确复用，只新candidate代表/锚点逐pin/net和完整表/负详情覆盖，正slack缺详情标缺、不新STA、不冒认字段/敏化。当前尚无下一RTL/EDA，生产364.900MHz/两软件/指针及400/面积<36000/IPC>1.1/全组非退化保持，不清理提交推送。

上述保存路径与独立重数/共享弧/覆盖/SHA复核随后均passed，通知结束：新10条代表/锚点逐pin/net、10693负详情全枚举；DC地址/控制LSU writer起点63/60门、−0.318641/−0.040500ns、前41弧共享。FF DCache writer起点72门/−0.225181ns，PRF数据/控制69/68门，和FF共享前34弧/共有37弧；10/50ps内4/24条全DC地址，100ps内DC208/FF99。I$+0.408623ns无保存正路径详情；仍仅同版代表/过程身份，不是字段bit/敏化/全图独立/跨版匿名对应。无模型或EDA重跑。

### 11月12日：转请求侧完整输入边界研究，不再机械扩大比较器

新`sync/study_frequency400_request_boundary_edges_20261112.py`已完整passed，根`frequency400-request-boundary-edges-20261112-r01`，只用当前364.900生产原展开，不用拒绝flush候选作基线，不恢复缺失旧357MHz metadata资产或重跑旧查询。实际DCache cpuRequestInput每个消费者输入边在离线图隔离为透明身份节点，假想寄存只替换这些边，不全局删共享producer网；小图核另一消费者必须保持。透明节点会多一层图算子，非硬件门/时序，新假想Q单独及合并旧LSU/DCache/AGU源均计入。

只valid1bit/valid+write2bit/只address32bit，旧LSU→DC地址仍112/112逻辑目标；control+address34bit/除writeData外43bit/完整75bit才0/112。34bit只是结构前沿非正确协议，完整75bit含3bit不可变运输owner及一致size/strobe/data。完整packet下DCache状态仍支持112 DC地址及PRF全部组，LSU仍支持1504 PRF数据/47 PRF控制，新Q仍支持112 DC地址，不能说切完整全核或400MHz可达。保守202/88等算子深度不换算ps，LSU D逻辑集合非物理端点/匿名对应。Ready/信用其余接口保持原图，未虚构已处理背压、flush/取消/实际Store接受。

新独立检查`sync/verify_frequency400_request_boundary_edges_20261112.py`已后台单次提交，仅读保存图独立BFS/拓扑重算覆盖/深度/环/新源与非切点扇出；此时尚待结果。当前唯一待通知为该检查；旧路径/PPA通知全部结束。后续须先评估请求稳定性/IPC预算及定义owner预留、真实下游接受、Store FIFO、flush/reset/同槽再用/退出排空合同，再决定是否实现，当前无新RTL/模型/IPC/EDA。不复活已否决LSU返回寄存或整体延迟CDB，不盲排综合、不叠加未采用候选。报告`sync/FREQUENCY400-REQUEST-BOUNDARY-EDGES-20261112.md`，生产364.900MHz/两软件/指针与持续授权保持，不清理提交推送。

上述消费者边界独立保存图检查现已全部passed，原通知结束：7场景覆盖/深度/环/字段位布局、新源数及未切producer扇出保持由独立BFS/拓扑重算，无原图重解析/模型/EDA。没有因此获得stage或IPC资格，不将34bit前沿当安全半包时序边界。

下一新被动请求稳定性观察`sync/profile_frequency400_request_stability_20261112.py`已后台单次提交，根`frequency400-request-stability-profile-20261112-r01`。仅重链接现有364.900生产converted archive外部observer，内存调度/刺激/模型不改，新sidecar测完整75bit packet是否前拍已是同完整Load/SQ身份/运输owner的未接受proposal、连续接受间距、背压后变化/消失、旧地址与同拍地址事件、flush。实际模型头字段/75bit/72bit/9bit宽度、observer精确逆回及6个事件公式边界预检通过，独立raw/sidecar重数audit已先写好。原六所有raw SHA/答案/周期及374104退休必须保持；事件不是候选IPC或可省/损拍数，proposal变化不预判原协议错误。当前结果尚待通知，唯一待通知是此观察；生产/两软件/指针保持，新RTL模型/sv2v/EDA0，不复活返回寄存/自动叠加或清理提交推送。

该观察与独立raw/sidecar重数审计随后均passed，通知结束：131404实际请求接受中7469次前拍已有同完整包/源身份且未接受，median/multiply0、vvadd3/1502、towers48/3169、qsort3/57043、rsort7415/66547。原六raw SHA/答案/周期与374104退休保持，只有外部observer链接一次，无模型/sv2v/EDA。不能把其余请求当固定损一拍或预测buffer后IPC；当前到严格IPC1.1的几何周期余量约2.021804%。

新离线分类`sync/classify_frequency400_request_stability_20261112.py`/根`frequency400-request-stability-classes-20261112-r01`已完成，无重复观察：rsort642背压后变化**全部是Load/Store kind切换**，owner-only/payload-only/消失均0；此前owner漂移只是待区分假设，不当实测结论。qsort2次包相同而完整源身份不同；flush拍合计10Load/708Store真实接受，不能统一丢弃已接受stage。分类不构成真实stage的年龄/owner安全证明或IPC估计。

### 11月12日：请求侧完整包寄存级，先新独立局部时序合同

新`sync/frequency400_request_stage_20261112.py`只提供实验模块和独立深度1队列oracle，未接整核/改生产。完整75bit DCache请求，明确无组合fallthrough；实际入队应转移buffer容量并预留运输owner，同拍旧包真实出队可接新包，全包背压持有，不随源proposal撤回/变化而丢弃。无flush输入/清包口，已入队Load/Store持续递交，取消Load将沿原LSU drop身份真实排空；reset是协调清空，退出仍等原Cache/总线。不是恢复已否决的返回寄存/整体延迟CDB，不含旧未采用候选。

新入口`sync/run_frequency400_request_stage_local_20261112.py`，局部根`frequency400-request-stage-local-20261112-r01`。计划65573拍时序oracle（reset/全包含invalid/持有/源撤回与变化/连续同拍出入）和背压覆盖、源撤回清包、丢同拍替换、错owner、组合fallthrough五有效converted反例。源码/锚点预检过，严格native仅模块静态lint/保断言converted prepare已后台提交，尚未宣称通过。夹具没有真实LSU owner ledger/Store hazard/flush，不冒称实际子系统资格；后续局部通过才新真实子系统/反例、候选原六架构/实测IPC与独立audit，全部合格才PPA。当前唯一待通知为此prepare，所有旧观察/审计/分类通知结束；无整核候选/PPA，生产364.900MHz/两软件/指针及400/面积<36000/IPC>1.1/完整全组保持，不清理提交推送。

请求stage局部r01 prepare随后仅strict静态lint失败：37公共package UNUSEDPARAM及1新增断言SYNCASYNCNET，转换/模型/EDA0。原failure/全部partial/冻结driver和recipe封存r01 `failure-finalization-r02.json`，不冒称动态失败或成功。r02去无必要wildcard import、错owner变异类型全限定、新断言敏感列表与异步复位统一，stage原always_ff方程及65573拍TB/oracle字节保持。严格模块静态lint用原package精确类型依赖闭包（DATA_REQUEST_ENTRIES/宽度/transport typedef/完整75bit结构），非告警豁免；实际动态转换仍完整原package，未来完整整核strict lint不豁免。新`sync/run_frequency400_request_stage_local_20261112_r02.py`/根r02经实际导入/所有stage writer/依赖闭包/TB/五变异锚点静态检查过，prepare已单次后台提交、尚无通过结论。当前唯一待通知是r02 prepare，旧r01通知结束；无整核候选/IPC/PPA/生产变更，不重复成功工具或清理提交推送。

该r02 prepare随后完整passed，strict模块静态lint零告警、完整原package保断言converted前端通过。独立unit `cpu2026-frequency400-request-stage-local-20261112-r02.service`确认active/running/MainPID443968，单次完整退出通知附加。当前仅新65573拍局部队列时序oracle/五变异运行，动态完成与真实LSU owner/Store/flush、候选原六IPC/PPA均未形成资格；独立源/转换/19步骤/精确原始abort审计器已先准备。不重跑成功lint/转换或原生产模型；当前唯一待通知为该局部服务，旧prepare/观察/研究通知均结束，生产/两软件/指针保持。

## 关键采用与指标

以下是各次精确版本的历史整核认证，不表示当前工作树重新测量。Fmax均为理想时钟、无寄生STA估计，不是后布局频率。

| 版本 | 面积 μm² | Fmax MHz | 原六几何IPC |
|---|---:|---:|---:|
| ROB载荷复位分离 | 34238.371507 | 313.341493 | 1.010966177065 |
| Load下一行预取 | 34417.443067 | 307.138572 | 1.035819497011 |
| SQ≤4/owner=0安全让行 | 34506.745567 | 314.399754 | 1.043690365779 |
| 标准同link JALR只push | 34614.841687 | 313.437404 | 1.059446088949 |
| SQ完成事件旁路 | 34465.105087 | 306.770521 | 1.063329023912 |
| LSU通知资格提前计算 | 34699.405687 | 316.146959 | 1.063329023912 |
| 跨16B四取指，旧ROB32/PRF64 | 34947.061567 | 319.301528 | 1.137201912621 |
| ROB16/PRF48最初采用 | 当时未测 | 当时未测 | 1.122239838632 |
| ＋DCache读地址优化 | 31764.108179 | 317.617866 | 1.122239838632 |
| ＋整数双发RS直接行选择 | 31793.603519 | 327.784891 | 1.122239838632 |
| 历史16 KiB DCache | 35107.695801 | 331.498867 | 1.184086472112 |
| 新8 KiB epoch：三项HDL组合 | 32111.330879 | 333.346897 | 1.122239838632 |
| ＋完整CDB包（已含响应预览） | 32193.460019 | 346.311562 | 1.122239838632 |
| ＋双队列反向信用，当前生产 | 32256.416459 | 357.339149 | 1.122239838632 |

16 KiB版本相对当时8 KiB版IPC提高5.511000%，但`Fmax²×IPC/Area`下降2.271463%，用户知情采用；不能将其IPC拼入后续8 KiB结果。三项组合采用时两软件容量头由256组同步回128组；后两次仅HDL组合拓扑改变，两软件126项构建输入不变。

### 当前采用身份

2026-11-12正式采用双队列反向信用三RTL版本，保留此前三项组合和完整CDB包。原六周期仍为8341/13119/3101/5531/162354/162410；converted原六374104条架构退休、局部oracle及有效反例、两软件Release/断言四构建和两个外部副本各374104退休PC/周期资格通过。

面积<36000、IPC>1.1通过；**未400MHz，全组非退化仍失败**，527个稳定命名端点退化，匿名FF跨版本对应未建立。用户明确采用不改写原拒绝结论。25项独立PPA与当前瓶颈详见[频率分析](频率分析.md)。

- [正式生产指针](../../sync/evidence/current-production.json)
- [三项组合采用证书](../../sync/evidence/frequency400-triple-production-adoption-20261111-r03/adoption.json)
- [完整CDB包采用证书](../../sync/evidence/frequency400-payload-production-adoption-20261111-r01/adoption.json)
- [双队列反向信用采用证书](../../sync/evidence/frequency400-queue-backward-production-adoption-20261112-r01/adoption.json)

采用链只按真实记录保存：三项组合入口当时缺少旧指针，没有伪造前驱；后续两次保存了实际前驱。证书不随文档整理重写。

## 重要否决与无效结果

| 方向 | 决定或边界 |
|---|---|
| PRF重定时、并行分配排名 | 前者面积代价被拒绝；后者Fmax退7.199562%，用户明确否决，不同于已采用的目的tag旁带。 |
| Store地址→Load数据通知、接受沿回填字复用、DCache miss接续 | 已删除或明确否决，不自动恢复。 |
| 前端部分接受、最老可发出Load、Store数据RS扩至4项 | 分别为六项周期持平、IPC微降、IPC退1.461943%；用户不采用。 |
| I$扩至2/4 KiB、4行寄存器victim cache | 前者当时仅towers少46拍，决定不扩；后者Fmax293.157744MHz，用户明确否决。 |
| 11月4日旧16/32 KiB DCache | 旧16 KiB面积38112.641969μm²超限，32 KiB仅IPC筛选；不等同11月8日已采用的另一同源版本。 |
| ROB载荷SRAM | 更省面积但Fmax268.414155MHz，未采用，非用户永久否决全部SRAM化。 |
| 单发RS提前资格/直接信用 | RTL筛选过，但综合存在三个RS信用无驱动，PPA无效；工具退出0及后续check成功不能补救。 |
| DCache同读沿tag快照、静态端口方案 | 用户明确不采用；功能资格不等于提频。 |
| LSU返回寄存边界 | Fmax338.288735MHz但IPC退5.273834%，用户明确否决。 |
| 独立postmap插buffer/换驱动 | 用户只认可RTL优化，不计作有效RTL提频成果，不采用。 |
| 提前Load地址旁带、ROB普通查询、Branch共享CDB切链及后期失败组合 | 测过的具体版本未采用；不是对所有同类实现的永久否决，详见三份分析。 |

## 清理与证据边界

<a id="unused-frequency400-checkpoints-20261111"></a>

**2026-11-11定界清理已完成。**先记录后删除14份已完成PPA中各一份`ppa/opt/elaborated.json`及`ppa/opt/ram/prepared.json`，共28文件、8,463,174,430逻辑字节（约7.88GiB），不是删除14个目录。当时逐文件意图/删除日志配对、目标不存在及1878份保留PPA文件核验通过；保留全部最终mapped/STA、源码、模型、日志、证书及活跃任务依赖。原证书未回写，删除后展开/准备链已不能完整重审。入口为工作区`sync/clear_unused_frequency400_checkpoints_20261111.py`。

**2026-11-12用户要求清空旧实验根前做好历史记录，并指定直接记录在本页。**本次整理检查时，`.cpu2026-synthesis/`仅见`tmp/`，旧实验工作集已不可用；这不是本次执行了删除，也不据此推算整根删除文件数或释放空间。

- 硬件/两软件工作树及`sync/evidence/`不在旧实验工作集内；持久证书与文档不等于完整工件备份。
- 指向旧实验目录的路径、SHA只保留历史归属；不篡改manifest，也不把引用缺失误判为过去工具未完成。
- 不能再声称旧模型可直接运行、raw可重数、mapped可逐pin复核或checkpoint可接续。未来测量从当前生产和实际可用输入建立新工作集，不伪称缓存复用或恢复旧数据。
- 历史文字中的“已保留、可重审”仅属当时状态；原完成、失败、否决与采用结论不因工件清理而改写。

## 原始计划（历史）

12周路线为：W1模型，W2—3单发射，W4—6扩宽，W7中期验证，W8—9性能/面积权衡，W10—11时序收敛，W12参数实验与交付。最初IPC≥1.12、面积≤34000μm²、频率≥525MHz是余量计划，不是测量结果或现行门槛；后续目标与验证口径见[评估说明](assessment.md)。

### 11月12日：请求stage局部资格完成；真实LSU两配置时序夹具启动

局部r02已完整退出，65573拍独立队列时序oracle、五有效converted变异及独立只读审计全部passed。未重复局部模型/转换/审计；原r01静态失败和冻结脚本保持。此局部资格不包含真实LSU、Store顺序、flush或候选IPC/PPA。

新`sync/frequency400_request_stage_actual_20261112.py`与`sync/run_frequency400_request_stage_actual_20261112.py`完成实际导入/生成/packed驱动/端口/变异锚点预检，独立审计器`sync/audit_frequency400_request_stage_actual_20261112.py`先写好并绑定输入SHA。原LSU/完整package与已合格stage原字节复用，不改生产。计划PREVIEW=0/1各352例：192取消Load/同tag槽复用、96已提交Store跨flush/停止排空、32部分字节Store后word Load、32背压Load后Store优先切换；各192取消返回、256有效Load返回、256真实Store递交。独立深度1 packet FIFO及owner预留/递交/响应ledger不读DUT内部状态，flush不清ledger。两配置当前均走preview route00回退，不冒称已测route01/10或真实DCache/SRAM。

prepare首次完整通过，保断言转换及环/锁存静态lint成功。独立unit `cpu2026-frequency400-request-stage-actual-20261112-r01.service`确认active/running/MainPID450125，已附加单次完整退出通知；根`frequency400-request-stage-actual-20261112-r01`。正向后才错owner、源撤回清包、跳过LSU入队owner预留三实际反例。当前只是动态启动，尚无完整实际LSU资格、整核IPC或PPA结论；唯一待通知为此服务，所有局部/观察/图任务均结束。生产364.899777MHz/32143.129859μm²/IPC1.122239838632/两软件/指针保持，持续授权和400/面积<36000/IPC>1.1/完整全组不放宽，不自动采用叠加/清理提交推送。

### 11月12日：真实LSU＋stage704例/三反例/独立审计过；新整核周期可变筛选启动

上述实际服务完整退出。PREVIEW=0/1各352例/5920检查，分别192取消返回、256有效Load返回、256Store真实递交、352同拍出入及192背压kind切换检查；三实际变异均指定时序oracle真实−6。独立审计passed，核原LSU/package/合格stage精确字节、原13步骤/转换来源/断言、两配置覆盖、独立不读DUT内部的owner/FIFO账本及原始三行abort/行号。没有重跑成功动态；两配置route00范围保持，不冒称真实Cache/SRAM或所有preview route覆盖。

新`sync/frequency400_request_stage_full_20261112.py`只在隔离student_top接完整75bit请求寄存级，新增原已合格module与filelist一行。backend真正ready只送stage，stage入队ready送原core/LSU；原LSU、DCache、原全部writer/其余源和两软件保持，不混入任何未采用补丁。原stage无flush清包口，真实Load在入队时预留owner；Store先后出入顺序保持，周期/owner压力允许变化但须实测。

新整核入口r01在任何工具前因snapshot函数依赖shutil未导入而停止，partial/原failure/冻结driver封存`frequency400-request-stage-full-screen-20261112-r01/failure-finalization-r02.json`。r02仅补导入和新根，所有RTL/刺激/门禁不变。实际namespace/精确top及filelist逆回/原writer、九字段退休parser正向及错误字段/格式/时序自测、独立parser与现参考raw交叉通过。`sync/run_frequency400_request_stage_full_20261112_r02.py --prepare`已完整passed，新完整整核strict native静态lint零告警，非局部type闭包替代。

新unit `cpu2026-frequency400-request-stage-full-screen-20261112-r02.service`确认active/running/MainPID457722，单次完整退出通知附加，根同名r02。只新候选converted模型及原六；复用现364.900参考模型/raw不重跑。允许cycle/lane变化，九个架构字段逐条等同参考/374104退休、每例ordinary与observer原始日志自身一致，全部六项完成后判断几何IPC严格>1.1；即使IPC不过也完整保存实测与独立审计，不带病PPA。独立整核源码/raw/真实IPC审计器已先写并绑定。此时尚无新整核功能/IPC/面积/Fmax结论，PPA0；当前唯一待通知是完整screen，所有actual/local/观察旧通知已结束。生产/两软件/指针及400/面积<36000/IPC>1.1/全组非退化保持，不自动采用或叠加/清理提交推送。

### 11月12日：完整请求寄存级功能正确，但IPC1.069942未过，不综合

上述完整screen现已结束，原六374104条九字段架构退休均保持，ordinary与observer自身raw一致，独立审计passed。周期8472/13230/3476/5715/174534/169563，相对生产+131/+111/+375/+184/+12180/+7153；逐项IPC−1.546270%/−0.839002%/−10.788262%/−3.219598%/−6.978583%/−4.218491%。几何IPC1.069941911803（−4.660138%），严格>1.1失败，completion passed=false保持；独立audit passed只表示测量/功能审阅可靠，eligible_for_PPA=false，不偷换为候选整体合格。

无参考模型/运行或成功local/actual重复，综合/ABC/STA0，无候选面积/Fmax，不拼接364.900生产PPA，不采用或叠加。通知后只核现关闭completion/audit及全部verified hashes，没有重跑审计。completion SHA `6f878f05e457b9656353c15b0fad8f8720213abf06f9c1d97da3c99846e97d9e`，audit SHA `265d900f33618d66ce8ac874cd3ea309d6f2d25ec7fc65ab88a3dfa6644ddc2c`。所有本stage通知完整结束，无PPA待启动；持续任务继续研究不增加Load请求周期的内部边界，不由此恢复已否决返回寄存/放宽IPC。生产364.899777MHz/32143.129859μm²/IPC1.122239838632/软件/指针保持，不清理提交推送。

### 11月12日：新旧地址重叠影子元数据引理完成，仅研究非RTL资格

新`sync/research_frequency400_registered_overlap_20261112.py`/根`frequency400-registered-overlap-research-20261112-r01`只读研究：在原地址捕获沿同步缓存8LQ×8SQ的64bit overlap，旧已就绪Load/Store才可读缓存，新Load地址保原组合旁路，不新加请求级。实际生产原address/size/addressReady全部writer源码及完整函数/指针绑定。2688000单对状态转移/66560字节模型比较过，五错误见证（漏Load/Store更新、同拍分配用旧size、忽略停止、flush统一清表）有效；不是实际RTL/使能接线/动态/IPC/STA证明。

独立符号归纳144义务和writer/计数/五见证检查passed。首独立检查r01错误将读取sqSize且含<=比较的行算writer，冻结脚本及`verifier-r01-failure.json`保留；r02只限定赋值LHS，无重跑原成功研究/模型/EDA。引理要求双方旧addressReady真才缓存等于旧地址/size关系；分配清ready，最后地址写必须用有效分配后size更新缓存，原停止/flush/地址写优先级保留。复杂实际完整身份/allocator使能目前仅抽象输入，尚未证明实际接线。新增64bit与更新逻辑/AGU扇出、新FF D路径/旧FF-PRF-Cache分支风险明确，不把缓存Q当免费或承诺零IPC损失。

当前无新RTL候选/模型/sv2v/EDA，不叠加本次失败请求stage或已拒绝返回级，不自动采用/清理提交推送。下一先查实际overlap消费者范围与行/列更新的共享边界再决定立项；报告`sync/FREQUENCY400-REGISTERED-OVERLAP-20261112.md`。生产364.900MHz/两软件/指针与400/面积<36000/IPC>1.1/完整全组保持。

### 11月12日：独立影子overlap候选真实两响应配置筛选启动

新helper `sync/frequency400_registered_overlap_20261112.py`只在实验LSU加入64bit影子overlap payload，Load/Store原地址捕获沿更新一列/行，16个RTL源函数调用（不是mapped比较器数保证）；旧addressReady双方真才可用，未知Store/同拍新Load地址仍原检查。有效capture size保原allocation写优先级，原完整身份/flush/停止/真实grant、所有旧writer及转发/通知/最老Load/owner不变。精确逆回生产且剥新region的原writer保持，不包含请求stage或任何未采用候选。首次纯文本posted锚点写反参数/缺换行在工具前拒绝，源码及说明冻结development-r01，修正确切原调用后预检过。

新actual保生产gold全部公开输出与原owner/取消/同tag复用/flush/reset回归，增加PREVIEW0/1各256例（32tag×4size×Load/Store同拍allocation+address）、重复已就绪地址、存活flush和停止禁止地址更新，内部blocked/posted亦差分；每个旧ready pair有缓存等于原byte_overlap的断言。三变异为漏Load写、漏Store写、capture旧size。动态分配宽度此阶段仅RENAME4，不由此冒称标量/双路或所有preview route已测。

actual r01新完整整核strict native静态lint已零告警成功，sv2v随后因继承夹具原已接yield=1、新夹具再加一次同端口而失败，模型/原六/EDA0；不是候选RTL功能判定。原日志/partial/steps/冻结driver-fixture-auditor封存r01 failure-finalization-r02；原failure.json未由CLI生成，因为prepare()由前台预检直接调用，明确记录不伪造旧失败收据。r02只移除重复yield端口及无用变量，保原constant1和全部刺激/oracle，精确逆回原夹具；候选RTL全部字节不变。原strict整核静态lint按原SHA/命令/所有源复用，无重跑，实际转换及环/锁存静态lint通过。

新入口`sync/run_frequency400_registered_overlap_actual_20261112_r02.py`/独立audit-r02已绑定；unit `cpu2026-frequency400-registered-overlap-actual-20261112-r02.service`确认active/running/MainPID475012，单次完整退出通知附加，根同名r02。此时仅实际动态/三反例运行，尚无完整实际/整核IPC/面积Fmax资格，PPA未启动。当前唯一待通知是此服务，所有失败请求stage/源代数/独立检查通知均已结束，不重等或重跑成功工具。生产364.899777MHz/32143.129859μm²/IPC1.122239838632/软件/正式指针及400/面积<36000/IPC>1.1/完整全组保持，不自动采用叠加/清理提交推送。

### 11月12日：影子overlap实际512新增例/三反例/自动审计过；新整核原六启动

actual r02完整退出，PREVIEW0/1各256新增案例、原生产gold所有公开输出/owner/取消同tag复用/flush/reset回归及三有效converted变异完成，自动独立audit passed。关闭workflow明确两条最终成功；通知后仅读关闭completion/audit和全部verified hashes，无重跑成功审计/模型。audit SHA `82950b9fea63aa31928c7c7f9e37e885a743a46391ec4490b25217921483ed93`。completion的independent_audit_pending=true是审计前不可变字段，不据此误报未审计。实际RENAME4及route00范围不扩大为其他配置资格。

新full入口`sync/run_frequency400_registered_overlap_full_20261112.py`及独立audit先写好，source精确复制actual r02，LSU新增64bit状态/原writer分开鉴权；其余所有生产RTL/SRAM/框架保持。原strict native静态lint按源/命令/SHA复用，现364.900参考原六raw/model不重跑。prepare实际导入/两入口语法/候选精确逆回/原writer/launcher namespace和静态命令同源绑定通过，新增模型/sv2v/EDA0。

独立unit `cpu2026-frequency400-registered-overlap-full-screen-20261112-r01.service`确认active/running/MainPID486832，单次完整退出通知已附加。新候选converted整核原六必须374104条九字段架构退休/全部raw与周期同生产、IPC严格>1.1及独立audit过才准备该方向首次PPA；不将实际夹具资格当整核已过。当前尚无新整核功能/IPC/面积Fmax结论，PPA未启动，唯一待通知是此full screen；所有actual/研究/请求stage旧通知已结束。生产364.899777MHz/32143.129859μm²/IPC1.122239838632/软件/正式指针与400/面积<36000/IPC>1.1/完整全组保持，不自动采用叠加/清理提交推送。

等待本screen期间仅source-only准备影子overlap首次PPA适配/launcher：复用原364.900参考关闭PPA及真实采用前备份身份映射，不重测参考，原2.5ns/INVx1-5fF/232宏/全组/逐叶/后测保持。明确允许新增64bit状态并用original_writers鉴权原writer，严格仅一LSU差异，不错套所有时序文本相同。实际导入/launcher→新measure→configure/inside-stats命令绑定预检过，未调用prepare/无PPA根/未启动排队或EDA。首helper清单精确空白锚点在导入时拒绝，源码/失败封存ppa-development-r01，仅修空白锚点；未修改当前screen任何冻结输入，不重复成功工具。原六及自动独立audit完整退出后再审阅资格，不能提前称IPC保持或提频成功。

### 11月12日：影子overlap整核原六/审计过，IPC保持；首次匹配PPA启动

full screen完整退出，全部六项ordinary/observer自身一致、完整trace/raw/周期逐字节匹配364.900生产参考，374104条九字段架构退休保持。周期8341/13119/3101/5531/162354/162410，几何IPC1.1222398386316592/变化0%/严格>1.1通过。自动独立audit passed且关闭workflow有两条最终成功，failure不存在；通知后只核关闭audit/全部verified hashes，无模型/原六/成功审计重跑。audit SHA `dc61a06dac720c56b62f90a1fedb2b62a7198d0a81165851019db2c7bc67e6ab`，原completion中independent_audit_pending是写入时状态，不误报未审计。

新`sync/measure_frequency400_registered_overlap_20261112.py --prepare`完整通过实际AppImage工具/五库SHA、显式sv2v/原2.5ns-INVx1-5fF dry-run、一LSU候选源/新增64bit状态与原writer、原364.900参考关闭测量/真实采用前备份路径绑定。没有参考模型/转换/EDA重跑，不把原LSU所有时序文本等同（新增影子FF明确计入），不叠加请求stage/owner等未采用方案。

首次独立PPA unit `cpu2026-frequency400-registered-overlap-ppa-20261112-r01.service`启动确认active/running/MainPID491021，单次完整退出通知附加；根`frequency400-registered-overlap-ppa-20261112-r01`。流程为本候选首次综合/ABC/STA、独立逐叶232同形状宏、全部端点/真实输入/全组非退化及只读后测，当前仅启动，无新面积/Fmax/全组结论，不把IPC保持称提频成功。所有actual/full screen旧通知已结束，唯一待通知为本PPA全链，不重启screen/prepare/重复综合。生产364.899777MHz/32143.129859μm²/IPC1.122239838632/两软件/正式指针保持，400/面积<36000/IPC>1.1/全组非退化不放宽，不自动采用叠加/改mapped/清理提交推送；本项结束后仍按实测继续持续授权。

### 11月12日：影子overlap348.966986MHz完整拒绝，转新路径只读归因

首次唯一PPA/ABC/STA、独立232宏/完整全组/只读后测和handoff均完整结束，unit success/inactive/dead。面积32448.143458977μm²（+0.948923149%）、Fmax348.966986155MHz（−4.366347178%）、IPC1.122239838632/原六全部raw周期不变。新增64bit状态明确计入，新28224 timed端点（原28160）/11574违例/WNS−.365413/TNS−2720.194936ns，TNS退1202.611698ns。FF WNS退125.303ps/TNS退989.254084ns，DC地址/控制退99.074/72.891ps，PRF数据/控制退107.132/98.351ps，其他SRAM控制0→8违例、输出退140.921ps，真实输入FF退77.815ps。其他SRAM地址16→0违例/WNS改善518.084ps及数据组正slack改善不抵消。3541稳定端点退化/missing0，匿名FF跨版对应未建立，完整全组拒绝、不采用、不叠加。

只读post passed，独立307186叶/232同形状宏及全部源/raw/步骤/报告/库/端点/mapped SHA、374104退休/生产两软件指针保持。通知后只核已有关闭handoff/post和verified hashes，无EDA/功能/成功后测重跑。completion SHA `da34ef0230ddf9c211734c72cb6937193df33d087e8ef4a58871337bbeb00761`，post SHA `e6b8cf1aaf06a45b3598deb777df67ee9386e5e04144a12ad387a8c26dc9c7e4`。面积/IPC过、未400MHz/全组失败，原completion passed仅测量完整，不冒称候选合格。

继续持续授权，新增只读`sync/study_frequency400_registered_overlap_paths_20261112.py`已后台提交：复用原生产代表路径，只补新候选实际逐pin/net与端点分档/共享弧，先区分原反馈writer与新影子状态writer，不凭门数或源进程推断敏化/字段bit/时序改善。独立review入口已准备，尚无该只读研究完成结论。当前无新RTL或EDA、唯一待通知是本只读研究，所有PPA/screen旧通知已结束；生产364.900MHz/32143.129859μm²/IPC1.122239838632/软件/正式指针保持，400/面积<36000/IPC>1.1/完整全组不放宽，不自动采用/叠加/清理提交推送。

### 11月12日：影子最差终点鉴权为新增cache writer；更新反馈支持研究启动

只读registered-overlap路径研究与独立verify均passed，10条候选代表/稳定锚点逐pin/net认证，完整11574负端点详情枚举与表一致。FF `_589500_/QN`（DCache主writer，具体字段bit未知）→`_580781_/D`，75门/slack−.365413ns，终点src只写cachedOverlapRowsInner，明确是新影子状态writer；不是具体SQ/LQ索引已识别或跨版匿名对应。PRF数据/控制与FF代表同起点，共享前53/57门。DC地址/控制仍原LSU主writer起点，68/62门/共享44门，与FF-PRF代表无共同门弧。10ps内3全FF；50ps316=FF252/DC地址64，100ps5061=FF3587/DC168/PRF控制17/数据1289；正slack I$地址没有负路径详情，不新STA或推测。

下一只读`sync/study_frequency400_overlap_update_feedback_20261112.py`已后台提交，根`frequency400-overlap-update-feedback-20261112-r01`：原保存elaborated图检查DCache旧态→新shadow D、capture值、effective size、完整鉴权写使能和index支持/组合虚拟边界，不把保守支持当75门映射对应/敏化/频率收益。独立反向reachability检查器先写好，导入/分支边界/有环遍历小自测过；当前新研究尚无完成结果，不立刻复制更大缓存或追加RTL综合。旧路径研究/PPA通知均已结束，当前唯一待通知为此支持研究；生产364.900MHz/软件/指针保持，400/面积<36000/IPC>1.1/全组不放宽，不自动采用叠加/清理提交推送。

### 11月12日：影子更新双反馈已核；转原生产分配元数据早形成研究

overlap-update支持研究完整结束，独立2646反向目标检查passed：原图/仅隔离size/仅隔离write-enable/仅隔离capture值均64/64影子D可达，size+write-enable同时虚拟隔离才0/64。AGU addressInput39bit/index3bit本来无本次DCache旧态支持；新的反馈同时经有效分配size和兼容allocation+address的真实鉴权写使能。结论仅保守支持，不当75门映射逐门对应/敏化/可实现切点或提频，无EDA/模型重跑。旧支持研究通知已结束，不再等，不继续基于本未采用缓存叠加小修。

新独立源码合同`research_frequency400_allocation_meta_preview_20261112.py`及独立verify均passed：当前planner的nextRobTag+lane、decoded size/unsigned可研究独立旁带早给LSU，但只允许原真实fire授权五个字段writer和两个同拍地址匹配消费者，原packet/valid/slot/公开invalid载荷保持。393216样本/完整5bit tag及回绕/四lane/四size码/全部fire-credit-query、四错误见证和七原源码消费者核对，独立packet oracle真值SHA一致；仅有限代数/source合同非RTL资格。默认四lane32条wire、无新状态，未改生产/实现候选，不把已采用PRF旁带收益套到这里。

立项前新只读`sync/study_frequency400_allocation_meta_sources_20261112.py`已后台启动，根`frequency400-allocation-meta-source-study-20261112-r01`：只用现364.900生产原elaborated图，查询raw nextROBtag/decoded size/unsigned相对原gated metadata/actualFire/addressMatch的支持；字段布局绑定真实package和展开宽度，不套旧6bit tag。独立反向review已写好；当前新结构查询尚未完成、无下一RTL/模型/EDA。即便raw支持0也不等于实际enable及全链已切。当前唯一待通知为新source study，其他旧通知均结束；报告`sync/FREQUENCY400-ALLOCATION-META-PREVIEW-20261112.md`。生产364.900MHz/32143.129859μm²/IPC1.122239838632/软件/指针与400/面积<36000/IPC>1.1/全组保持，不自动采用/叠加/清理提交推送。

### 11月12日：分配元数据早旁带源图独立过；两文件候选actual四配置启动

生产raw元数据支持研究完整结束，独立87目标反向检查passed：DCache旧态可达bit统计为raw nextROBtag0/5、decoded size0/8、unsigned0/4；原gated Load tag20/20、size/unsigned12/12，Store tag20/20、size8/8均可达；实际Load/Store fire各4/4和地址match各1/1仍在。这里“0/总数”明确无支持，不等于真实enable或所有受限分支已断，不预测Fmax。source合同393216样本及独立真值SHA仍保持。

新独立helper `sync/frequency400_allocation_meta_preview_20261112.py`仅实验core/LSU两文件：core32bit原next-tag+lane/decoded size/unsigned候选wire，LSU60bit候选输入pin共享tag/size连线，无新状态/always_ff/级。新增ALLOCATION_META_PREVIEW默认0，core仅四宽打开；原公开分配packet/valid/实际fire/slot/flush/owner/请求周期保留。只七个metadata RHS替换，core原writer字节同、LSU原writer控制和优先级精确逆回，不伪称有意改变的RHS文本也相同。不叠加未采用shadow/request stage/owner等。

新actual保原gold全部公开输出含invalid和owner/取消同tag/flush/reset/四lane稀疏回归；PREVIEW0/1×META0/1各514新增例（32tag×4size×2unsigned×Load/Store同拍allocation-address512、未接受候选不得鉴权两例），META0毒化候选数据检查fallback。三变异为错Loadtag、错Storesize、忽略关闭参数。实际fire时新断言核候选字段与原packet相同；关闭时原fallback核对。该夹具仍只RENAME4/route00，真实core原候选producer运行时绑定/整核IPC须后续新full验证，不扩大局部范围。

r01新完整strict native整核静态lint零告警成功，actual sv2v因夹具新类型声明先于package import无法解析rob_tag_t而失败，动态模型/原六/EDA0。原failure/partial/steps及冻结driver-fixture-auditor封存failure-finalization-r02。r02只移动原DECL到import/输入声明后和DUT前，候选/刺激/oracle字节保持；原成功strict静态lint按源/命令/SHA复用，新actual转换和环/锁存静态lint过。

unit `cpu2026-frequency400-allocation-meta-actual-20261112-r02.service`启动确认active/running/MainPID524682，单次完整退出通知附加，根同名r02。入口/auditor-r02均预写绑定，当前仅实际动态四配置/三变异运行，尚无完整actual/core绑定/原六IPC或PPA结论。当前唯一待通知是该actual，旧source合同/结构图/影子更新/拒绝PPA通知均已结束，不重等或重复成功工具。生产364.899777MHz/32143.129859μm²/IPC1.122239838632/两软件/指针与400/面积<36000/IPC>1.1/全组保持，不自动采用叠加/清理提交推送。

### 11月12日：分配meta actual2056新增例/三反例/审计过；真实core整核原六启动

actual r02完整退出，PREVIEW0/1×META0/1各514新增例（合2056）、原gold全部公开输出/地址match/owner/取消同tag/flush/reset稀疏分配回归、三有效converted变异和自动独立audit均passed。关闭workflow明确最终两成功，failure不存在；通知后只核原关闭audit和verified hashes，没有重复成功模型/变异/审计。audit SHA `6ea5286b2aa3368aa62cdff93f202f143732bcc28b006d19f030e5c86a5548d8`，不把completion审计前pending字段当作未执行。

新full入口`sync/run_frequency400_allocation_meta_full_20261112.py`/同名独立audit先写好，精确复制actual两文件candidate源，原strict完整native静态lint按源/命令/SHA复用，现364.900参考model/raw不重跑。新整核启用真实core nextTag+lane/decoded候选wire并保实际fire下与原gated packet一致的断言，补齐producer→LSU运行绑定；core原writer字节同，LSU只七RHS改写、控制/优先级逆回，无新状态/级，不伪称有意变化的RHS文本全同。导入/生成/真实两文件逆回/launcher namespace和prepare无工具检查passed。

独立unit `cpu2026-frequency400-allocation-meta-full-screen-20261112-r01.service`启动确认active/running/MainPID545283，单次完整退出通知附加，根同名full-screen-r01。当前仅新converted整核原六，须374104条九字段退休/全部raw/周期同生产、IPC>1.1和自动独立audit过才准备首次PPA；尚无完整core绑定/IPC/面积Fmax结论。

等待期间仅source-only准备新meta measure/launcher：真实二文件逆回/无新FF/七RHS有意变化/实际configure与inside-stats绑定预检passed，复用已采用364.900参考/原2.5ns-INVx1-5fF/232宏/完整全组/后测；未调用PPA prepare、无PPA根/未排队或启动EDA，不修改当前full冻结输入。唯一待通知是此full screen，所有actual/旧研究/影子PPA通知均结束。生产364.899777MHz/32143.129859μm²/IPC1.122239838632/两软件/正式指针与400/面积<36000/IPC>1.1/完整全组保持，不自动采用叠加/改mapped/清理提交推送。
