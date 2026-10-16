#include "Vaxi_sync_top.h"
#include "verilated.h"
#include "CPU.hpp"
#include <array>
#include <deque>
#include <iostream>
#include <memory>
#include <random>
#include <stdexcept>

static unsigned cycle;
static void eq(uint32_t a,uint32_t b,const char* what) {
    if(a!=b) throw std::runtime_error(std::string(what)+" cycle="+std::to_string(cycle)+
      " RTL="+std::to_string(a)+" software="+std::to_string(b));
}
struct Read { uint32_t value; unsigned due; };
int main() { try {
    auto t=std::make_unique<Vaxi_sync_top>();
    auto next=std::make_unique<systemState>();
    AXIFetch fetch;
    AXIData data;
    AXIBus bus;
    std::mt19937 rng(20261016);
    std::deque<Read> reads;
    std::deque<unsigned> replies, aw;
    std::deque<std::pair<uint32_t,unsigned>> wd;
    unsigned accepted=0, returns=0, split=0, held=0, flushes=0, full=0, exits=0;
    bool holdAR=false, holdAW=false, holdW=false;
    uint32_t oldAR=0,oldAW=0,oldW=0,oldStrb=0;
    t->reset=1;t->clock=0;t->eval();t->clock=1;t->eval();t->reset=0;
    for(cycle=0;cycle<20000;++cycle) {
        bool drain=cycle>=19000;
        AXIFetchInput f{};
        AXIDataInput d{};
        f.squash=!drain && (cycle%211==19 || (holdAR && cycle%37==5));
        f.fetchValid=!drain && !f.squash && !fetch.isRequestFull() && rng()%3!=0;
        f.fetchPC=(rng()%1024)<<6;
        f.lineConsumed=fetch.getReturn().valid && (drain || rng()%4!=0);
        d.request.writeValid=!drain && data.canAcceptWrite() && rng()%3==0;
        d.request.readValid=!drain && data.canAcceptRead(d.request.writeValid) && rng()%3!=0;
        d.request.read.address=(rng()%2048)<<5;
        d.request.write.address=(rng()%2048)<<5;
        d.request.read.transaction=rng()&3;
        d.request.write.transaction=rng()&3;
        for(unsigned b=0;b<32;++b) d.request.write.lineData[b]=uint8_t(rng());
        d.replyConsumed=data.isReplyReady() && (drain || cycle%131>30) && rng()%4!=0;
        d.writeConsumed=data.isWriteReplyReady() && (drain || rng()%4!=0);
        d.exitValid=!drain && data.exitReady() && (cycle==0 || cycle%101==11);
        d.exitValue=0xdeadbeef;
        if(d.exitValid) d.request.readValid=d.request.writeValid=false;
        AXISlavePort s{};
        s.arReady=reads.size()<64 && (drain || (cycle%73>15 && rng()%4!=0));
        s.awReady=aw.size()<16 && (drain || cycle%43>17);
        s.wReady=wd.size()<16 && (drain || cycle%53>27);
        s.rValid=!reads.empty() && reads.front().due<=cycle;
        s.rData=reads.empty()?0:reads.front().value;
        s.bValid=!replies.empty() && replies.front()<=cycle;
        AXIBusInput input{fetch.port(),data.port(),s};
        auto p=bus.ports(input);
        f.bus=p.fetch;d.bus=p.data;
        t->clock=0;t->squash=f.squash;t->fetchValid=f.fetchValid;t->fetchAddress=f.fetchPC;t->fetchConsume=f.lineConsumed;
        t->readValid=d.request.readValid;t->readAddress=d.request.read.address;t->readId=d.request.read.transaction;
        t->writeValid=d.request.writeValid;t->writeAddress=d.request.write.address;t->writeId=d.request.write.transaction;
        t->readConsume=d.replyConsumed;t->writeConsume=d.writeConsumed;t->exitValid=d.exitValid;t->exitValue=d.exitValue;
        for(unsigned w=0;w<8;++w) {
            uint32_t value=0;for(unsigned b=0;b<4;++b)value|=uint32_t(d.request.write.lineData[w*4+b])<<(8*b);
            t->writeData[w]=value;
        }
        t->arready=s.arReady;t->awready=s.awReady;t->wready=s.wReady;t->rvalid=s.rValid;t->rdata=s.rData;t->bvalid=s.bValid;
        t->eval();
        const auto& m=p.slave;
        std::array<uint32_t,9> expected{unsigned(m.arValid),m.arAddr,unsigned(m.rReady),unsigned(m.awValid),
          m.awAddr,unsigned(m.wValid),m.wData,m.wStrb,unsigned(m.bReady)};
        for(unsigned i=0;i<9;++i)eq(t->pins[i],expected[i],"AXI pins");
        eq(t->fetchReady,!fetch.isRequestFull(),"fetch credit");
        eq(t->readReady,data.canAcceptRead(d.request.writeValid||d.exitValid),"read credit");
        eq(t->writeReady,data.canAcceptWrite(),"write credit");
        eq(t->exitReady,data.exitReady(),"MMIO ready");
        auto fr=fetch.getReturn();eq(t->fetchReplyValid,fr.valid,"I$ reply valid");
        if(fr.valid) {eq(t->fetchReplyAddress,fr.lineAddr,"I$ reply address");for(unsigned w=0;w<16;++w)eq(t->fetchReplyData[w],fr.data[w],"I$ reply data");}
        eq(t->readReplyValid,data.isReplyReady(),"D$ reply valid");
        if(data.isReplyReady()) {
            auto r=data.reply();eq(t->readReplyAddress,r.address,"D$ address");eq(t->readReplyId,r.transaction,"D$ MSHR");
            for(unsigned w=0;w<8;++w){uint32_t v=0;for(unsigned b=0;b<4;++b)v|=uint32_t(r.lineData[w*4+b])<<(b*8);eq(t->readReplyData[w],v,"D$ reply data");}
        }
        eq(t->writeReplyValid,data.isWriteReplyReady(),"write completion valid");
        if(data.isWriteReplyReady()){auto r=data.writeReply();eq(t->writeReplyAddress,r.address,"write completion address");eq(t->writeReplyId,r.transaction,"write completion MSHR");}
        if(holdAR){eq(m.arValid,1,"held AR valid");eq(m.arAddr,oldAR,"held AR address");++held;}
        if(holdAW){eq(m.awValid,1,"held AW valid");eq(m.awAddr,oldAW,"held AW address");}
        if(holdW){eq(m.wValid,1,"held W valid");eq(m.wData,oldW,"held W data");eq(m.wStrb,oldStrb,"held W strobe");}
        holdAR=m.arValid&&!s.arReady;oldAR=m.arAddr;
        holdAW=m.awValid&&!s.awReady;oldAW=m.awAddr;
        holdW=m.wValid&&!s.wReady;oldW=m.wData;oldStrb=m.wStrb;
        split+=m.awValid&&m.wValid&&(s.awReady!=s.wReady);
        flushes+=f.squash;full+=!data.canAcceptWrite();exits+=d.exitValid;
        if(s.rValid&&m.rReady){reads.pop_front();++returns;}
        if(s.bValid&&m.bReady)replies.pop_front();
        if(!aw.empty()&&!wd.empty()&&replies.size()<64){aw.pop_front();wd.pop_front();replies.push_back(cycle+1+unsigned(rng()%15));}
        if(m.arValid&&s.arReady){reads.push_back({m.arAddr^0xa55ac33c,cycle+1+unsigned(rng()%17)});++accepted;}
        if(m.awValid&&s.awReady)aw.push_back(m.awAddr);
        if(m.wValid&&s.wReady)wd.emplace_back(m.wData,m.wStrb);
        fetch.tick(f,*next);data.tick(d,*next);bus.tick(input,*next);
        fetch=next->AXIFetchModule;data=next->AXIDataModule;bus=next->AXIBusModule;
        t->clock=1;t->eval();
    }
    if(!(accepted&&returns&&split&&held&&flushes&&full&&exits))throw std::runtime_error("missing required coverage");
    std::cout<<"PASS AXI software/RTL 20000 cycles accepted="<<accepted<<" returned="<<returns<<" AW/W split="<<split
      <<" AR held="<<held<<" flush="<<flushes<<" full16="<<full<<" MMIO="<<exits<<'\n';
    return 0;
}catch(const std::exception& e){std::cerr<<e.what()<<'\n';return 1;}}
