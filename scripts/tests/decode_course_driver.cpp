// Real RTL, existing course-compatible Slave, and an independent retirement ISA.
// No software CPU clock or software cycle equality is used in this test.
#include "Vdecode_course_top.h"
#include "verilated.h"
#include "CPU.hpp"
#include <array>
#include <fstream>
#include <iostream>
#include <memory>
#include <stdexcept>

static uint64_t cycle;
static void equal(uint32_t actual, uint32_t expected, const std::string &name) {
  if (actual != expected)
    throw std::runtime_error(name + " cycle=" + std::to_string(cycle) +
      " actual=" + std::to_string(actual) + " expected=" + std::to_string(expected));
}
// Staged verbatim by check_decode_width.py from the existing independent ISA
// in course_sync_driver.cpp. It does not call production execution functions.
#include "decode_isa.inc"

int main(int argc, char **argv) { try {
  if (argc != 4) return 2;
  auto memory = std::make_unique<Memory>();
  std::ifstream image(argv[1]);
  if (!image) throw std::runtime_error("cannot open image");
  auto old = std::cin.rdbuf(image.rdbuf());
  memory->load_ins();
  std::cin.rdbuf(old);
  auto state = std::make_unique<systemState>(*memory);
  Slave snapshot;
  Isa isa{*memory};
  auto context = std::make_unique<VerilatedContext>();
  auto top = std::make_unique<Vdecode_course_top>(context.get());
  top->reset = 1;
  for (unsigned n = 0; n < 5; ++n) {
    top->clock = 0; top->eval(); top->clock = 1; top->eval();
  }
  top->reset = 0;
  uint64_t retired = 0, core = 0, dual = 0, dualDecode = 0;
  uint64_t dualIssue = 0, dualLoad = 0, dualStore = 0;
  std::array<uint64_t,8> renameEvents{};
  uint64_t trace = 14695981039346656037ull;
  auto hash = [&](uint32_t value) { trace ^= value; trace *= 1099511628211ull; };
  for (cycle = 0; cycle < 100000000; ++cycle) {
    snapshot.snapshotFrom(state->SlaveModule);
    const auto slave = snapshot.port();
    top->arready = slave.arReady; top->awready = slave.awReady; top->wready = slave.wReady;
    top->rvalid = slave.rValid; top->rdata = slave.rData; top->rresp = slave.rResp;
    top->bvalid = slave.bValid; top->bresp = slave.bResp;
    top->clock = 0; top->eval();
    equal(top->observe[10], 0, "unexpected trap");
    unsigned count = 0;
    for (unsigned lane = 0; lane < COMMIT_WIDTH; ++lane) {
      const auto *observe = &top->observe[57 + 9*lane];
      if (observe[0]) { ++retired; ++count; isa.retire(observe); }
    }
    dual += count == 2;
    dualDecode += top->decodeCountOutput == 2;
    dualIssue += top->issueCountOutput == 2;
    dualLoad += top->loadAllocCountOutput == 2;
    dualStore += top->storeAllocCountOutput == 2;
    for (unsigned bit = 0; bit < renameEvents.size(); ++bit)
      renameEvents[bit] += (top->renameEventsOutput >> bit) & 1u;
    hash(top->arvalid); if (top->arvalid) hash(top->araddr);
    hash(top->rready); hash(top->awvalid); if (top->awvalid) hash(top->awaddr);
    hash(top->wvalid); if (top->wvalid) { hash(top->wdata); hash(top->wstrb); }
    hash(top->bready);
    // Invalid payload is deliberately masked, not treated as architectural state.
    for (unsigned lane = 0; lane < COMMIT_WIDTH; ++lane) {
      const auto *observe = &top->observe[57 + 9*lane];
      hash(observe[0]);
      if (observe[0]) for (unsigned field = 1; field < 9; ++field) hash(observe[field]);
    }
    const AXIMaster master{bool(top->arvalid), bool(top->rready), bool(top->awvalid),
      bool(top->wvalid), bool(top->bready), top->araddr, top->awaddr, top->wdata, uint8_t(top->wstrb)};
    snapshot.tick(master, *state);
    top->clock = 1; top->eval();
    if (!core && top->observe[9]) core = cycle;
    if (state->SlaveModule.isDone()) {
      equal(state->SlaveModule.exitResult(), uint32_t(std::stoull(argv[2])), "full exit result");
      equal(uint32_t(retired), uint32_t(std::stoull(argv[3])), "independent retirement count");
      std::cout << "PASS cycles=" << cycle << " core=" << core << " retired=" << retired
                << " dual=" << dual << " dual_decode=" << dualDecode << " trace=" << trace
                << " dual_issue=" << dualIssue << " dual_load=" << dualLoad << " dual_store=" << dualStore
                << " raw1=" << renameEvents[0] << " raw2=" << renameEvents[1] << " waw=" << renameEvents[2]
                << " link_raw=" << renameEvents[3] << " rob_limit=" << renameEvents[4]
                << " prf_limit=" << renameEvents[5] << " lsq_limit=" << renameEvents[6]
                << " flush=" << renameEvents[7] << '\n';
      return 0;
    }
  }
  throw std::runtime_error("timeout");
} catch (const std::exception &error) { std::cerr << error.what() << '\n'; return 1; } }
