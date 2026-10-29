// One real software CPU and the real course DUT, sharing the software slave's
// pre-edge pins. Only a private HEADER COPY grants this external test access.
#include "Vcourse_sync_top.h"
#include "verilated.h"
#include "CPU.hpp"
#include <array>
#include <fstream>
#include <iostream>
#include <memory>
#include <stdexcept>

static uint64_t cycle;
static void equal(uint32_t actual, uint32_t expected, const std::string& name) {
    if (actual != expected) throw std::runtime_error(name + " cycle=" + std::to_string(cycle) +
        " RTL=" + std::to_string(actual) + " software=" + std::to_string(expected));
}
static uint32_t mask(bool valid, uint32_t value) { return valid ? value : 0; }

// Independent architectural interpreter. Host multiply/divide are intentional:
// this test must not reuse the production ALU/MUL/DIV/LSQ implementation.
struct Isa {
    Memory& memory;
    std::array<uint32_t,32> x{};
    uint32_t pc=0;
    static uint32_t sx(uint32_t value,unsigned bits) {
        const uint32_t sign=1u<<(bits-1);return (value^sign)-sign;
    }
    uint32_t word(uint32_t addr,unsigned bytes) {
        uint32_t value=0;
        for(unsigned b=0;b<bytes;++b)value|=uint32_t(memory.read_data(addr+b))<<(b*8);
        return value;
    }
    void retire(const uint32_t* observe) {
        equal(observe[1],pc,"independent ISA PC");
        const uint32_t insn=word(pc,4),opcode=insn&127,rd=(insn>>7)&31;
        const uint32_t kind=(insn>>12)&7,a=x[(insn>>15)&31],b=x[(insn>>20)&31];
        uint32_t next=pc+4,value=0,addr=0,size=0;
        bool writes=true,store=false;
        switch(opcode) {
        case 0x37:value=insn&0xfffff000;break;
        case 0x17:value=pc+(insn&0xfffff000);break;
        case 0x6f:
            value=pc+4;
            next=pc+sx(((insn>>31)<<20)|(insn&0xff000)|(((insn>>20)&1)<<11)|(((insn>>21)&1023)<<1),21);
            break;
        case 0x67:value=pc+4;next=(a+sx(insn>>20,12))&~1u;break;
        case 0x63: {
            writes=false;
            bool taken=false;
            switch(kind) {
            case 0:taken=a==b;break;case 1:taken=a!=b;break;
            case 4:taken=int32_t(a)<int32_t(b);break;case 5:taken=int32_t(a)>=int32_t(b);break;
            case 6:taken=a<b;break;case 7:taken=a>=b;break;
            default:throw std::runtime_error("independent illegal branch");
            }
            if(taken)next=pc+sx(((insn>>31)<<12)|(((insn>>7)&1)<<11)|(((insn>>25)&63)<<5)|(((insn>>8)&15)<<1),13);
            break;
        }
        case 0x03:
            addr=a+sx(insn>>20,12);size=1u<<(kind&3);value=word(addr,size);
            if(!(kind&4)&&size<4)value=sx(value,size*8);
            break;
        case 0x23:
            writes=false;store=true;size=1u<<kind;
            addr=a+sx(((insn>>25)<<5)|((insn>>7)&31),12);
            equal(observe[6],addr,"independent Store address");
            equal(observe[7],b,"independent Store data");
            equal(observe[8],(1u<<size)-1,"independent Store mask");
            if(addr!=AXI_EXIT_ADDR)for(unsigned i=0;i<size;++i)memory.write_data(addr+i,uint8_t(b>>(i*8)));
            break;
        case 0x13: {
            const uint32_t imm=sx(insn>>20,12);
            switch(kind) {
            case 0:value=a+imm;break;case 1:value=a<<((insn>>20)&31);break;
            case 2:value=int32_t(a)<int32_t(imm);break;case 3:value=a<imm;break;
            case 4:value=a^imm;break;case 5:value=(insn&(1u<<30))?uint32_t(int32_t(a)>>((insn>>20)&31)):a>>((insn>>20)&31);break;
            case 6:value=a|imm;break;case 7:value=a&imm;break;
            }
            break;
        }
        case 0x33:
            if((insn>>25)==1) {
                switch(kind) {
                case 0:value=uint32_t(uint64_t(a)*b);break;
                case 1:value=uint32_t(uint64_t(int64_t(int32_t(a))*int64_t(int32_t(b)))>>32);break;
                case 2:value=uint32_t(uint64_t(int64_t(int32_t(a))*int64_t(b))>>32);break;
                case 3:value=uint32_t((uint64_t(a)*b)>>32);break;
                case 4:value=b==0?~0u:(a==0x80000000&&b==~0u)?a:uint32_t(int32_t(a)/int32_t(b));break;
                case 5:value=b==0?~0u:a/b;break;
                case 6:value=b==0?a:(a==0x80000000&&b==~0u)?0:uint32_t(int32_t(a)%int32_t(b));break;
                case 7:value=b==0?a:a%b;break;
                }
            } else switch(kind) {
            case 0:value=(insn&(1u<<30))?a-b:a+b;break;case 1:value=a<<(b&31);break;
            case 2:value=int32_t(a)<int32_t(b);break;case 3:value=a<b;break;
            case 4:value=a^b;break;case 5:value=(insn&(1u<<30))?uint32_t(int32_t(a)>>(b&31)):a>>(b&31);break;
            case 6:value=a|b;break;case 7:value=a&b;break;
            }
            break;
        default:throw std::runtime_error("independent unsupported instruction "+std::to_string(insn));
        }
        equal(observe[2],writes&&rd!=0,"independent destination valid");
        equal(observe[5],store,"independent Store valid");
        if(writes&&rd!=0){equal(observe[3],rd,"independent rd");equal(observe[4],value,"independent rd value");x[rd]=value;}
        pc=next;
    }
};

struct CourseSyncProbe {
    static void clock(CPU& c) { c.clock(); }
    static const systemState& state(CPU& c) { return c.CPUstate; }
    static void compare(CPU& c, Vcourse_sync_top& t) {
        const auto& bus = c.slaveInput;
        equal(t.arvalid, bus.arValid, "AXI AR valid");
        equal(mask(t.arvalid,t.araddr), mask(bus.arValid,bus.arAddr), "AXI AR address");
        equal(t.rready,bus.rReady,"AXI R ready");
        equal(t.awvalid,bus.awValid,"AXI AW valid");
        equal(mask(t.awvalid,t.awaddr),mask(bus.awValid,bus.awAddr),"AXI AW address");
        equal(t.wvalid,bus.wValid,"AXI W valid");
        equal(mask(t.wvalid,t.wdata),mask(bus.wValid,bus.wData),"AXI W data");
        equal(mask(t.wvalid,t.wstrb),mask(bus.wValid,bus.wStrb),"AXI W strobe");
        equal(t.bready,bus.bReady,"AXI B ready");
        const auto& r = c.ROBModule;
        const auto& plan = c.robInput.commits;
        const bool commit = plan.count != 0;
        equal(t.observe[0],commit,"commit valid");
        if (commit) {
            const unsigned row = robSlot(r.getHead());
            equal(t.observe[1],uint32_t(r.getPC(row)),"commit PC");
            const bool writes = (r.headType() == ROBType::REGISTER || r.headType() == ROBType::LINK) && r.headDest() != 0;
            equal(t.observe[2],writes,"commit destination valid");
            if (writes) {
                equal(t.observe[3],r.headDest(),"commit rd");
                equal(t.observe[4],uint32_t(c.PRFModule.getValue(r.getNewPhy(row))),"commit value");
            }
            equal(t.observe[5],r.headType() == ROBType::STORE,"commit store");
        }
        for (unsigned lane = 0; lane < COMMIT_WIDTH; ++lane) {
            const unsigned n = 57 + 9*lane;
            equal(t.observe[n],lane < plan.count,"retirement lane valid");
            if (lane >= plan.count) continue;
            const auto row = robSlot(plan.tags[lane]);
            const bool writes = r.getNewPhy(row) != InvalidPhy && r.getRd(row) != 0;
            equal(t.observe[n+1],uint32_t(r.getPC(row)),"retirement lane PC");
            equal(t.observe[n+2],writes,"retirement lane destination valid");
            if (writes) {
                equal(t.observe[n+3],r.getRd(row),"retirement lane rd");
                equal(t.observe[n+4],uint32_t(c.PRFModule.getValue(r.getNewPhy(row))),"retirement lane value");
            }
            equal(t.observe[n+5],r.getType(row) == ROBType::STORE,"retirement lane Store");
        }
        equal(t.observe[9],c.exitCommitted,"exit committed");
        equal(t.observe[10],r.isTrapCommitted(),"trap");
        const auto& f = c.fetchDecision;
        equal(t.observe[11],f.valid,"fetch accepted");
        equal(t.observe[12],c.FetchUnitModule.getPC(),"fetch PC");
        if (f.valid) {
            equal(t.observe[13],f.predictedPC,"prediction PC");
            equal(t.observe[14],f.ckptId,"prediction checkpoint");
        }
        equal(t.observe[15],c.issuePacket.valid,"issue valid");
        if (c.issuePacket.valid) {
            equal(t.observe[16],uint32_t(c.issuePacket.robEntry.pc),"issue PC");
            equal(t.observe[17],c.issuePacket.robTag,"issue tag");
        }
        equal(t.observe[18],c.squashDetect.needSquash,"flush valid");
        if (c.squashDetect.needSquash) {
            equal(t.observe[19],c.squashDetect.SquashTag,"flush tag");
            equal(t.observe[20],c.squashDetect.SquashPC,"flush PC");
        }
        equal(t.observe[21],r.getHead(),"ROB head");
        equal(t.observe[22],r.getNextTag(),"ROB tail");
        equal(t.observe[25],c.BPUModule.snapshotCheckPoint(),"GHR");
        equal(t.observe[26],c.BPUModule.getNextCkptId(),"next checkpoint");
        const auto& d = c.dcacheInput;
        equal(t.observe[28],uint32_t(int(d.lookup)),"D$ lookup");
        equal(t.observe[29],uint32_t(int(d.response)),"D$ response");
        equal(t.observe[30],uint32_t(int(d.store)),"D$ Store");
        equal(t.observe[31],uint32_t(int(d.mergeSlot)),"D$ merge");
        equal(t.observe[32],uint32_t(int(d.allocate)),"D$ allocate MSHR");
        equal(t.observe[33],uint32_t(int(d.fillMiss)),"D$ fill MSHR");
        equal(t.observe[34],d.fillFire,"D$ fill complete");
        equal(t.observe[35],uint32_t(int(d.writeAck)),"D$ write complete");
        equal(t.observe[36],d.exitValid,"MMIO issue");
        auto wb = [&](unsigned n, const auto& w) {
            const bool live = w.valid && r.matchesTag(w.robTag);
            equal(t.observe[n],live,"WB valid lane " + std::to_string(n));
            if (live) {
                equal(t.observe[n+1],w.robTag,"WB tag");
                equal(t.observe[n+2],uint32_t(w.value),"WB value");
            }
        };
        wb(37,c.cdbOfALU); wb(40,c.cdbOfLQ); wb(43,c.cdbOfMul); wb(46,c.cdbOfDiv);
        equal(t.observe[49],d.decision.valid,"D$ accepted CPU request");
        if (d.decision.valid) {
            equal(t.observe[50],d.decision.request.address,"D$ CPU address");
            const bool store = d.decision.request.op == Operation::Store;
            equal(t.observe[51],store,"D$ CPU write");
            if (store) equal(t.observe[52],uint32_t(d.decision.request.value),"D$ CPU data");
            equal(t.observe[53],d.decision.request.nBytes == 1 ? 0 : d.decision.request.nBytes == 2 ? 1 : 2,"D$ CPU size");
        }
        equal(t.observe[54],d.response >= 0,"D$ Load transport complete");
        if (d.loadResp.valid) equal(t.observe[55],uint32_t(d.loadResp.value),"D$ Load value");
        equal(t.observe[56],d.fillFire,"line reply consumption");
    }
    static void drive(CPU& c, Vcourse_sync_top& t) {
        const auto& s = c.axiBusInput.slave;
        t.arready=s.arReady; t.awready=s.awReady; t.wready=s.wReady;
        t.rvalid=s.rValid; t.rdata=s.rData; t.rresp=s.rResp;
        t.bvalid=s.bValid; t.bresp=s.bResp;
    }
};

int main(int argc,char** argv) { try {
    if (argc != 4) return 2;
    auto memory = std::make_unique<Memory>();
    std::ifstream image(argv[1]);
    if (!image) throw std::runtime_error("cannot open image");
    auto old = std::cin.rdbuf(image.rdbuf());
    memory->load_ins();
    std::cin.rdbuf(old);
    auto cpu = std::make_unique<CPU>(*memory);
    Isa isa{*memory};
    auto context = std::make_unique<VerilatedContext>();
    auto top = std::make_unique<Vcourse_sync_top>(context.get());
    top->reset=1;
    for (unsigned n=0;n<5;++n) { top->clock=0;top->eval();top->clock=1;top->eval(); }
    top->reset=0;
    uint64_t retired=0, core=0, dual=0;
    for (cycle=0;cycle<100000000;++cycle) {
        cpu->comb();
        CourseSyncProbe::drive(*cpu,*top);
        top->clock=0;top->eval();
        CourseSyncProbe::compare(*cpu,*top);
        if (cycle != 0) {
            unsigned count = 0;
            for (unsigned lane = 0; lane < COMMIT_WIDTH; ++lane) {
                const auto* observe = &top->observe[57 + 9*lane];
                if (observe[0]) { ++retired; ++count; isa.retire(observe); }
            }
            dual += count == 2;
        }
        CourseSyncProbe::clock(*cpu);
        top->clock=1;top->eval();
        if (!core && top->observe[9]) core=cycle;
        if (CourseSyncProbe::state(*cpu).SlaveModule.isDone()) {
            equal(CourseSyncProbe::state(*cpu).SlaveModule.exitResult(),uint32_t(std::stoull(argv[2])),"result");
            equal(uint32_t(retired),uint32_t(std::stoull(argv[3])),"independent retirement count");
            std::cout << "PASS cycles=" << cycle << " core=" << core << " retired=" << retired << " dual=" << dual << '\n';
            return 0;
        }
    }
    throw std::runtime_error("timeout");
} catch(const std::exception& e) { std::cerr<<e.what()<<'\n';return 1; } }
