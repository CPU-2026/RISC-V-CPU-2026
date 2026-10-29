// Existing external Slave and verbatim independent ISA. No software CPU timing.
#include "Vfour_course_top.h"
#include "verilated.h"
#include "CPU.hpp"
#include <algorithm>
#include <array>
#include <fstream>
#include <iostream>
#include <memory>
#include <stdexcept>

static uint64_t cycle;
static void equal(uint32_t actual,uint32_t expected,const std::string &name) {
  if(actual!=expected)throw std::runtime_error(name+" cycle="+std::to_string(cycle)+
    " actual="+std::to_string(actual)+" expected="+std::to_string(expected));
}
#include "decode_isa.inc"

int main(int argc,char **argv) { try {
  if(argc!=4)return 2;
  auto memory=std::make_unique<Memory>();
  std::ifstream image(argv[1]);
  if(!image)throw std::runtime_error("cannot open image");
  auto old=std::cin.rdbuf(image.rdbuf());memory->load_ins();std::cin.rdbuf(old);
  auto state=std::make_unique<systemState>(*memory);Slave snapshot;Isa isa{*memory};
  auto context=std::make_unique<VerilatedContext>();
  auto top=std::make_unique<Vfour_course_top>(context.get());
  top->reset=1;
  for(unsigned n=0;n<5;++n){top->clock=0;top->eval();top->clock=1;top->eval();}
  top->reset=0;
  uint64_t retired=0,core=0,dual=0,maxRob=0,above16=0,fullRob=0;
  std::array<uint64_t,5> decodes{},issues{},loads{},stores{};
  std::array<uint64_t,8> events{};
  uint64_t trace=14695981039346656037ull;
  auto hash=[&](uint32_t value){trace^=value;trace*=1099511628211ull;};
  for(cycle=0;cycle<100000000;++cycle){
    snapshot.snapshotFrom(state->SlaveModule);const auto slave=snapshot.port();
    top->arready=slave.arReady;top->awready=slave.awReady;top->wready=slave.wReady;
    top->rvalid=slave.rValid;top->rdata=slave.rData;top->rresp=slave.rResp;
    top->bvalid=slave.bValid;top->bresp=slave.bResp;
    top->clock=0;top->eval();equal(top->observe[10],0,"unexpected trap");
    unsigned count=0;
    for(unsigned lane=0;lane<COMMIT_WIDTH;++lane){
      const auto *observe=&top->observe[57+9*lane];
      if(observe[0]){++retired;++count;isa.retire(observe);}
    }
    dual+=count==2;
    if(top->decodeCountOutput>4 || top->issueCountOutput>4 ||
       top->loadAllocCountOutput>4 || top->storeAllocCountOutput>4)
      throw std::runtime_error("wide count outside 0..4");
    ++decodes[top->decodeCountOutput];++issues[top->issueCountOutput];
    ++loads[top->loadAllocCountOutput];++stores[top->storeAllocCountOutput];
    maxRob=std::max(maxRob,uint64_t(top->robCountOutput));
    above16+=top->robCountOutput>16;fullRob+=top->robCountOutput==32;
    for(unsigned bit=0;bit<events.size();++bit)events[bit]+=(top->renameEventsOutput>>bit)&1u;
    hash(top->arvalid);if(top->arvalid)hash(top->araddr);
    hash(top->rready);hash(top->awvalid);if(top->awvalid)hash(top->awaddr);
    hash(top->wvalid);if(top->wvalid){hash(top->wdata);hash(top->wstrb);}hash(top->bready);
    for(unsigned lane=0;lane<COMMIT_WIDTH;++lane){
      const auto *observe=&top->observe[57+9*lane];hash(observe[0]);
      if(observe[0])for(unsigned field=1;field<9;++field)hash(observe[field]);
    }
    const AXIMaster master{bool(top->arvalid),bool(top->rready),bool(top->awvalid),
      bool(top->wvalid),bool(top->bready),top->araddr,top->awaddr,top->wdata,uint8_t(top->wstrb)};
    snapshot.tick(master,*state);top->clock=1;top->eval();
    if(!core && top->observe[9])core=cycle;
    if(state->SlaveModule.isDone()){
      equal(state->SlaveModule.exitResult(),uint32_t(std::stoull(argv[2])),"full exit result");
      equal(uint32_t(retired),uint32_t(std::stoull(argv[3])),"independent retirement count");
      std::cout<<"PASS cycles="<<cycle<<" core="<<core<<" retired="<<retired<<" dual="<<dual<<" trace="<<trace;
      for(unsigned n=1;n<=4;++n)std::cout<<" decode"<<n<<"="<<decodes[n]<<" issue"<<n<<"="<<issues[n]
        <<" load"<<n<<"="<<loads[n]<<" store"<<n<<"="<<stores[n];
      std::cout<<" max_rob="<<maxRob<<" above16="<<above16<<" full_rob="<<fullRob
        <<" raw1="<<events[0]<<" raw2="<<events[1]<<" waw="<<events[2]<<" link_raw="<<events[3]
        <<" rob_limit="<<events[4]<<" prf_limit="<<events[5]<<" lsq_limit="<<events[6]<<" flush="<<events[7]<<'\n';
      return 0;
    }
  }
  throw std::runtime_error("timeout");
}catch(const std::exception &error){std::cerr<<error.what()<<'\n';return 1;}}
