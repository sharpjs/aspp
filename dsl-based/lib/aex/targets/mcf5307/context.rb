#
# This file is part of AEx.
# Copyright (C) 2015 Jeffrey Sharp
#
# AEx is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published
# by the Free Software Foundation, either version 3 of the License,
# or (at your option) any later version.
#
# AEx is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See
# the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with AEx.  If not, see <http://www.gnu.org/licenses/>.
#

require_relative '../../refinements'
require_relative '../../context'
require_relative 'operand'

module Aex
  using self

  class Context
    # Registers

    DATA_REGS = [*:d0..:d7]
      .each_with_index.map { |s, n| DataReg.new(s, n) }
      .freeze

    ADDR_REGS = [*:a0..:a5, :fp, :sp]
      .each_with_index.map { |s, n| AddrReg.new(s, n) }
      .freeze

    ALL_REGS =
      [
        *DATA_REGS, *ADDR_REGS,
        *%i[pc sr ccr bc]                   .map { |s| AuxReg.new(s) },
        *%i[vbr cacr acr0 acr1 mbar rambar] .map { |s| CtlReg.new(s) }
      ]
      .reduce({}) { |h, r| h[r.reg] = r.freeze; h }
      .each { |s, r| define_method(s) { r } }
      .freeze

    alias a6 fp
    alias a7 sp

    # Operands

    def regs(*regs)
      regs.map! { |reg| reg.to_term(self).for_inst }
      RegList.new(regs).freeze
    end

    # Normal Instructions

    # Arity 3
    %i[
      remsl remul
    ]
    .each { |sym| define_method(sym) { |s, d, r| inst sym, s, r, d } }

    # Arity 2
    %i[
      addl    subl    cmpl    mulsw   divsw
      addal   subal   cmpal   mulsl   divsl
      addil   subil   cmpil   muluw   divuw
      addql   subql           mulul   divul
      addxl   subxl

      andl    eorl    orl     asll    lsll
      andil   eoril   oril    asrl    lsrl

      bchgb   bclrb   bsetb   btstb
      bchgl   bclrl   bsetl   btstl

      moveb   movel   moveal  moveml  lea
      movew   moveaw  movecl  moveql  linkw   cpushl
    ]
    .each { |sym| define_method(sym) { |a, b| inst sym, a, b } }

    # Arity 1
    %i[
      clrb    tstb    extw    negl    jmp     swapw   tpfl    wddatab wdebugl
      clrw    tstw    extl    negxl   jsr     tpf     trap    wddataw
      clrl    tstl    extbl   notl    pea     tpfw    unlk    wddatal
    ]
    .each { |sym| define_method(sym) { |a| inst sym, a } }

    # Arity 0
    %i[
      nop     rts     rte     halt    pulse   illegal
    ]
    .each { |sym| define_method(sym) { inst sym } }

    alias addq  addql
    alias addx  addxl
    alias subq  subql
    alias subx  subxl
    alias moveq moveql

    # Forms to force immediate mode
    {
      addl: 0xD0BC,
      subl: 0x90BC,
      cmpl: 0xB0BC,
      andl: 0xC0BC,
      orl:  0x80BC
    }
    .each do |sym, opcode|
      define_method(:"#{sym}!") do |src, dst|
        src = src.to_term(self).for_inst
        dst = dst.to_term(self).for_inst
        if Immediate === src && DataReg === dst
          word opcode + (dst.number << 9)
          long src.expr
        else
          __send__(:sym, src, dst)
        end
      end
    end

    # Branch and Jump Instructions

    %i[eq ne mi pl cs cc vs vc lo ls hi hs gt ge lt le ra sr]
    .product([:s, :w])
    .each do |cc, sz|
      define_method(:"b#{cc}#{sz}") do |loc|
        dir :"b#{cc}.#{sz}", loc.to_term(self)
      end
    end

    %i[eq ne mi pl cs cc vs vc lo ls hi hs gt ge lt le ra]
    .each do |cc|
      define_method(:"b#{cc}") do |loc|
        dir :"j#{cc}", loc.to_term(self)
      end
    end

    %i[eq ne mi pl cs cc vs vc lo ls hi hs gt ge lt le f t]
    .each do |cc|
      define_method(:"s#{cc}b") do |loc|
        dir :"s#{cc}.b"
      end
    end

    %i[jsr jmp].each do |j|
      define_method(j) do |loc|
        dir j, loc.to_term(self).for_jump
      end
    end

    def bsr(loc)
      dir :jbsr, loc.to_term(self)
    end

    alias bz   beq 
    alias bzs  beqs
    alias bzw  beqw
    alias bnz  bne
    alias bnzs bnes
    alias bnzw bnew
    alias szb  seqb
    alias snzb sneb

    # Convenience Instructions

    def push(*srcs)
      srcs.reverse_each do |src|
        movel src, [-sp]
      end
    end

    def pop(*dsts)
      dsts.each do |dst|
        movel [+sp], dst
      end
    end

    # Alignment

    def align
      puts "\t.balign  2, 0x00"
      puts "\t.balignw 4, 0x4E71"
    end

    # Helpers

    def _reg_available?(x)
      true
    end

    # Writes an instruction
    def inst(op, *args)
      args.map! { |a| a.to_term(self).for_inst }
      dir op, *args
    end
  end
end

