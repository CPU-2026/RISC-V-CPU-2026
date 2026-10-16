// Real, unmodified main-tree DCache/DMEM vs RTL. No private/friend access, no
// software BTB migration. Compare combinational events, every SRAM port, replies,
// and actual backing memory. An independent acceptance-order byte oracle checks
// Loads as well, so two implementations sharing a value bug cannot pass.
#include "Vdcache_sync_top.h"
#include "verilated.h"
#include "CPU.hpp"
#include <algorithm>
#include <array>
#include <deque>
#include <iostream>
#include <memory>
#include <random>
#include <stdexcept>
#include <vector>

static uint64_t cycle = 0;
static void equal(uint64_t actual, uint64_t expected, const char* field) {
    if (actual != expected) throw std::runtime_error(std::string(field) + " cycle=" +
        std::to_string(cycle) + " actual=" + std::to_string(actual) + " expected=" + std::to_string(expected));
}
static uint32_t word(const std::vector<uint8_t>& memory, unsigned address) {
    uint32_t result = 0;
    for (unsigned b = 0; b < 4; ++b)
        if (address+b < memory.size()) result |= uint32_t(memory[address+b]) << (b*8);
    return result;
}

int main(int argc, char** argv) { try {
    auto context = std::make_unique<VerilatedContext>();
    context->commandArgs(argc, argv);
    auto top = std::make_unique<Vdcache_sync_top>(context.get());
    std::mt19937 random(20261016);
    unsigned full = 0, lastCredit = 0, both = 0, held = 0, writesPastRead = 0;
    unsigned merges = 0, hitUnderMiss = 0, fourMisses = 0, early = 0, outOfOrder = 0, loads = 0;
    unsigned backingWrites = 0, accepted = 0;
    for (unsigned phase = 0; phase < 2; ++phase) {
        auto state = std::make_unique<systemState>();
        std::vector<uint8_t> memory(MEM_SIZE), expected(MEM_SIZE);
        for (unsigned a = 0; a < MEM_SIZE; ++a) {
            memory[a] = uint8_t(a ^ (a >> 8) ^ 0x5a);
            state->DMEMModule.write_data(a, memory[a]);
        }
        expected = memory;
        std::array<bool,4> owners{};
        std::array<uint32_t,4> expectedLoad{};
        std::deque<unsigned> order;
        std::deque<std::pair<bool,bool>> directOwners; // isWrite, consumed
        top->cpuValid = 0;
        top->directMemory = phase == 0;
        top->directRead = top->directWrite = top->directReadConsume = top->directWriteConsume = 0;
        top->reset = 1;
        top->clock = 0; top->eval();
        top->clock = 1; top->eval();
        top->clock = 0; top->eval();
        top->reset = 0;
        const unsigned duration = phase == 0 ? 5000 : 30000;
        for (unsigned n = 0; n < duration; ++n, ++cycle) {
            const bool drain = n >= duration-500;
            DCache oldCache = state->DCacheModule;
            DMEM oldMemory = state->DMEMModule;
            DCacheInput cacheInput(oldMemory);
            DMEMInput memoryInput{};
            top->clock = 0;
            if (phase == 0) {
                // Fill all 16, hold the oldest read, allow younger writes to
                // complete/ack past it, then release. Repeat with random stalls.
                memoryInput.request.readValid = !drain && (n < 24 || random()%3 != 0);
                memoryInput.request.writeValid = !drain && (n < 24 || random()%3 != 0);
                memoryInput.request.read.address = (random()%512)*32;
                memoryInput.request.write.address = (random()%512)*32;
                memoryInput.request.read.transaction = random()&3;
                memoryInput.request.write.transaction = random()&3;
                for (unsigned b = 0; b < 32; ++b) memoryInput.request.write.lineData[b] = uint8_t(random());
                top->directRead = memoryInput.request.readValid;
                top->directWrite = memoryInput.request.writeValid;
                top->directReadAddress = memoryInput.request.read.address;
                top->directWriteAddress = memoryInput.request.write.address;
                top->directReadTransaction = memoryInput.request.read.transaction;
                top->directWriteTransaction = memoryInput.request.write.transaction;
                for (unsigned w = 0; w < 8; ++w) {
                    uint32_t value = 0;
                    for (unsigned b = 0; b < 4; ++b) value |= uint32_t(memoryInput.request.write.lineData[w*4+b])<<(b*8);
                    top->directWriteData[w] = value;
                }
                memoryInput.replyConsumed = oldMemory.isReplyReady() && n >= 60 && (drain || random()%4 != 0);
                memoryInput.writeConsumed = oldMemory.isWriteReplyReady() && (drain || random()%3 != 0);
                top->directReadConsume = memoryInput.replyConsumed;
                top->directWriteConsume = memoryInput.writeConsumed;
                equal(top->cpuValid, 0, "direct CPU disabled");
            } else {
                unsigned token = 0;
                while (token < 4 && owners[token]) ++token;
                const bool store = n >= 600 && (random()%4 == 0);
                // Warm a hit line, then force four independent cold misses and
                // same-line merges. The remaining stream stresses aliasing and
                // overlapping byte Stores/Loads with deterministic randomness.
                unsigned address = ((random()%160)*32) + random()%29;
                if (n < 200) address = 0x4000;
                else if (n < 204) address = 0x6000 + (n-200)*32;
                else if (n < 250) address = 0x4000;
                else if (n < 500) address = 0x7000 + random()%4;
                else if (n%512 < 32) address = 0x4000 + random()%4;
                unsigned size = random()%3;
                unsigned bytes = 1u<<size;
                bool offer = !drain && (token < 4 || store) && (n < 600 || random()%5 != 0);
                top->cpuValid = offer;
                top->cpuWrite = store;
                top->cpuAddress = address;
                top->cpuData = random();
                top->cpuSize = size;
                top->cpuTransaction = token & 3;
                cacheInput.decision.valid = offer && !oldCache.isRequestFull();
                cacheInput.decision.request = {store ? Operation::Store : Operation::Load,
                    int32_t(top->cpuData), address, false, int(bytes), 1, uint8_t(token&3)};
                oldCache.plan(cacheInput);
                memoryInput.request = cacheInput.memoryRequest;
                memoryInput.replyConsumed = cacheInput.fillFire;
                memoryInput.writeConsumed = cacheInput.writeAck >= 0;
            }
            memoryInput.completedRead = oldMemory.sampleReadCompletion();
            top->eval();
            for (unsigned w = 0; w < 8; ++w) top->backingReadData[w] = word(memory,top->backingReadAddress+w*4);
            top->eval();
            equal(top->readReady, oldMemory.canAcceptRead(memoryInput.request.writeValid), "DMEM read credit");
            equal(top->writeReady, oldMemory.canAcceptWrite(), "DMEM write credit");
            equal(top->readValid, oldMemory.isReplyReady(), "DMEM read ready");
            equal(top->writeValid, oldMemory.isWriteReplyReady(), "DMEM write done");
            equal(top->readConsume, memoryInput.replyConsumed, "read consume");
            equal(top->writeConsume, memoryInput.writeConsumed, "write consume");
            if (oldMemory.isReplyReady()) {
                const auto& reply = oldMemory.reply();
                equal(top->readAddress, reply.address, "read address");
                equal(top->readTransaction, reply.transaction, "read MSHR ID");
                for (unsigned w = 0; w < 8; ++w) {
                    uint32_t value = 0;
                    for (unsigned b = 0; b < 4; ++b) value |= uint32_t(reply.lineData[w*4+b])<<(b*8);
                    equal(top->readData[w],value,"persistent read payload");
                }
                if (!memoryInput.replyConsumed) ++held;
                if (memoryInput.writeConsumed && !memoryInput.replyConsumed) ++writesPastRead;
            }
            if (oldMemory.isWriteReplyReady()) {
                equal(top->writeAddress, oldMemory.writeReply().address, "write address");
                equal(top->writeTransaction, oldMemory.writeReply().transaction, "write MSHR ID");
            }
            if (phase == 0) {
                equal(top->memoryCount, directOwners.size(), "shared occupancy");
                if (directOwners.size() == 16) ++full;
                if (directOwners.size() == 15 && memoryInput.request.readValid && memoryInput.request.writeValid) {
                    ++lastCredit;
                    equal(top->readReady,0,"last credit write priority");
                }
            } else {
                equal(top->cpuReady, !oldCache.isRequestFull(), "CPU admission");
                std::array<int,10> events{cacheInput.lookup,cacheInput.response,cacheInput.store,cacheInput.allocate,
                    cacheInput.mergeSlot,cacheInput.mergeMiss,cacheInput.fillMiss,cacheInput.writeAck,
                    cacheInput.fillBeat,cacheInput.fillFire};
                for (unsigned i = 0; i < events.size(); ++i) equal(top->events[i],uint32_t(events[i]),"DCache event");
                equal(top->responseValid,cacheInput.loadResp.valid,"Load response");
                if (cacheInput.loadResp.valid) {
                    unsigned token = top->responseTransaction;
                    equal(token,cacheInput.loadResp.memIndex,"CPU owner ID");
                    equal(top->responseData,uint32_t(cacheInput.loadResp.value),"software Load data");
                    equal(owners[token],true,"live Load owner");
                    equal(top->responseData,expectedLoad[token],"independent Load byte oracle");
                    if (!order.empty() && order.front() != token) ++outOfOrder;
                    order.erase(std::find(order.begin(),order.end(),token));
                    owners[token] = false;
                    ++loads;
                }
                if (cacheInput.decision.valid) {
                    ++accepted;
                    unsigned bytes = 1u<<top->cpuSize;
                    if (top->cpuWrite) {
                        for (unsigned b = 0; b < bytes; ++b) expected[top->cpuAddress+b] = uint8_t(top->cpuData>>(b*8));
                    } else {
                        unsigned token = top->cpuTransaction;
                        equal(owners[token],false,"unique accepted Load ID");
                        owners[token] = true;
                        expectedLoad[token] = 0;
                        for (unsigned b = 0; b < bytes; ++b) expectedLoad[token] |= uint32_t(expected[top->cpuAddress+b])<<(b*8);
                        order.push_back(token);
                    }
                }
                for (unsigned w = 0; w < 2; ++w) {
                    const auto& meta = cacheInput.InputDCacheMetadataSRAMInput[w];
                    equal((top->metaEnable>>w)&1,meta.enable,"metadata enable");
                    equal((top->metaWrite>>w)&1,meta.writeEnable,"metadata write");
                    if (meta.enable) equal(top->sramAddress,meta.addr,"metadata address");
                    if (meta.writeEnable) equal(top->metaPort[w],meta.writeData[0],"metadata payload");
                    for (unsigned b = 0; b < 8; ++b) {
                        const auto& port = cacheInput.InputDCacheDataSRAMInput[w][b];
                        unsigned p = w*8+b;
                        equal((top->dataEnable>>p)&1,port.enable,"data enable");
                        equal((top->dataWrite>>p)&1,port.writeEnable,"data write");
                        if (port.enable) equal(top->sramAddress,port.addr,"data address");
                        if (port.writeEnable) for (unsigned lane = 0; lane < 4; ++lane) {
                            equal((top->dataMask[p]>>lane)&1,port.writeMask[lane],"byte mask");
                            if (port.writeMask[lane]) equal((top->dataPort[p]>>(lane*8))&255,port.writeData[lane]&255,"SRAM byte");
                        }
                    }
                }
                if (cacheInput.mergeSlot >= 0) ++merges;
                if (top->missCount == 4) ++fourMisses;
                if (cacheInput.loadResp.valid && top->missCount && !cacheInput.fillBeat) ++hitUnderMiss;
                if (cacheInput.fillBeat && cacheInput.response >= 0 && !cacheInput.fillFire) ++early;
            }
            if (memoryInput.request.readValid && top->readReady && memoryInput.request.writeValid && top->writeReady) ++both;
            if (phase == 0) {
                for (bool write : {false,true}) {
                    bool consume = write ? memoryInput.writeConsumed : memoryInput.replyConsumed;
                    if (consume) {
                        auto found = std::find_if(directOwners.begin(),directOwners.end(),[&](const auto& e) {
                            return e.first == write && !e.second;
                        });
                        if (found == directOwners.end()) throw std::runtime_error("owner model underflow");
                        found->second = true;
                    }
                }
                while (!directOwners.empty() && directOwners.front().second) directOwners.pop_front();
                if (memoryInput.request.writeValid && top->writeReady) directOwners.push_back({true,false});
                if (memoryInput.request.readValid && top->readReady) directOwners.push_back({false,false});
            }
            // Backing read already sampled. Apply writes without resampling it.
            if (top->backingWrite) {
                ++backingWrites;
                for (unsigned w = 0; w < 8; ++w) for (unsigned b = 0; b < 4; ++b)
                    if (top->backingWriteAddress+w*4+b < MEM_SIZE)
                        memory[top->backingWriteAddress+w*4+b] = uint8_t(top->backingWriteData[w]>>(b*8));
            }
            oldMemory.tick(memoryInput,*state);
            if (phase != 0) oldCache.tick(cacheInput,*state);
            top->clock = 1; top->eval();
            if (n%64 == 0 || drain) for (unsigned a = 0; a < MEM_SIZE; ++a)
                equal(memory[a],state->DMEMModule.read_data(a),"actual backing memory");
        }
        equal(top->memoryCount,0,"final DMEM empty");
        equal(state->DCacheModule.isEmpty(),true,"final DCache empty");
        equal(order.size(),0,"all Loads completed");
    }
    if (!full || !lastCredit || !both || !held || !writesPastRead || !merges || !hitUnderMiss || !fourMisses || !outOfOrder)
        throw std::runtime_error("missing directed coverage: full="+std::to_string(full)+" last="+std::to_string(lastCredit)+
          " both="+std::to_string(both)+" held="+std::to_string(held)+" past="+std::to_string(writesPastRead)+
          " merge="+std::to_string(merges)+" hum="+std::to_string(hitUnderMiss)+" four="+std::to_string(fourMisses)+
          " ooo="+std::to_string(outOfOrder));
    std::cout << "PASS software/RTL data-side lockstep cycles="<<cycle<<" requests="<<accepted<<" loads="<<loads
              <<" full="<<full<<" last_credit="<<lastCredit<<" parallel_rw="<<both<<" held="<<held
              <<" writes_past_read="<<writesPastRead<<" merges="<<merges<<" hit_under_miss="<<hitUnderMiss
              <<" four_mshrs="<<fourMisses<<" out_of_order="<<outOfOrder<<" early="<<early<<" writes="<<backingWrites<<'\n';
    return 0;
} catch(const std::exception& error) { std::cerr<<error.what()<<'\n'; return 1; } }
