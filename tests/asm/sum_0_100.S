  .section .text
  .globl _start
  .option norvc

_start:
  lui   x2, 0x20000
  jal   x1, main
  .word 0x0ff00513

main:
  addi  x5, x0, 0
  addi  x6, x0, 0
  addi  x7, x0, 101
1:
  add   x5, x5, x6
  addi  x6, x6, 1
  blt   x6, x7, 1b
  addi  x10, x5, 0
  jalr  x0, 0(x1)
