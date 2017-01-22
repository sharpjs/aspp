#!/usr/bin/env ruby
# frozen_string_literal: true
#
# arch-cf - ColdFire Architecture for SRB
# Copyright (C) 2016 Jeffrey Sharp
#
# SRB is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published
# by the Free Software Foundation, either version 3 of the License,
# or (at your option) any later version.
#
# SRB is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See
# the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with SRB.  If not, see <http://www.gnu.org/licenses/>.
#

module SRB
  using self

  module Mode
    # Resolves context-dependent data.  Idempotent.
    def resolve(context)
      self
    end
  end

  # Registers

  class Register
    include Mode, Resolved

    # Writes assembly output.
    def write(syntax)
      syntax.write_reg(self)
    end

    # Treat x <op> reg as reg <op> x
    def coerce(lhs)
      [self, lhs]
    end
  end

  module Base
    def +(x)
      case x
      when Index       then BaseIdx .new(self, x*1)
      when ScaledIndex then BaseIdx .new(self, x)
                       else BaseDisp.new(self, x)
      end
    end
  end

  module Index
    def *(scale)
      ScaledIndex.new(self, scale)
    end
  end

  class DataReg < Register
    include Index
    struct :name, :num
  end

  class AddrReg < Register
    include Base, Index
    struct :name, :num

    def -@
      Predecrement.new(self)
    end

    def +@
      Postincrement.new(self)
    end
  end

  class MiscReg < Register
    struct :name
  end

  # Indirect Modes

  class Indirect
    include Resolved
    struct :ea

    def write(syntax)
      ea.write(syntax)
    end
  end

  class Predecrement
    include Mode
    struct :reg

    def write(syntax)
      syntax.write_predec(reg)
    end
  end

  class Postincrement
    include Mode
    struct :reg

    def write(syntax)
      syntax.write_postinc(reg)
    end
  end

  class ScaledIndex
    struct :index, :scale

    def resolve(context)
      index = @index.resolve(context)
      scale = @scale.resolve(context)
      same  = index == @index && scale == @scale
      same  ? self : self.class.new(index, scale)
    end

    def write(syntax)
      syntax.write_index(index, scale)
    end
  end

  class BaseDisp
    include Mode
    struct :base, :disp

    def [](index)
      BaseDispIdx.new(base, disp, index)
    end

    def resolve(context)
      base = @base.resolve(context)
      disp = @disp.resolve(context)
      same = base == @base && disp == @disp
      same ? self : self.class.new(base, disp)
    end

    def write(syntax)
      syntax.write_ind(base, nil, disp, nil)
    end
  end

  class BaseIdx
    include Mode
    struct :base, :index

    def +(disp)
      BaseDispIdx.new(base, disp, index)
    end

    def resolve(context)
      base  = @base .resolve(context)
      index = @index.resolve(context)
      same  = base == @base && index == @index
      same  ? self : self.class.new(base, index)
    end

    def write(syntax)
      syntax.write_ind(base, nil, nil, index)
    end
  end

  class BaseDispIdx
    include Mode
    struct :base, :disp, :index

    def resolve(context)
      base  = @base .resolve(context)
      disp  = @disp .resolve(context)
      index = @index.resolve(context)
      same  = base == @base && disp == @disp && index == @index
      same  ? self : self.class.new(base, disp, index)
    end

    def write(syntax)
      syntax.write_ind(base, nil, disp, index)
    end
  end

  class Context
    # Data Registers
    DATA_REGS = [*:d0..:d7]
      .each_with_index
      .map  { |name, num| DataReg.new(name, num).freeze }
      .each { |reg| define_method(reg.name) { reg } }
      .freeze

    # Address Registers
    ADDR_REGS = [*:a0..:a5, :fp, :sp]
      .each_with_index
      .map { |name, num| AddrReg.new(name, num).freeze }
      .each { |reg| define_method(reg.name) { reg } }
      .freeze

    # Misc Registers
    %i[pc sr ccr bc vbr cacr acr0 acr1 mbar rambar]
      .map { |name| MiscReg.new(name).freeze }
      .each { |reg| define_method(reg.name) { reg } }
      .freeze

    # Indirect addressing
    def ptr(ea)
      Indirect.new(ea.resolve(self))
    end

    # Instructions
    # 0 operands
    def nop     ;         op :i, :'nop'       ;         end
    def halt    ;         op :i, :'halt'      ;         end
    def illegal ;         op :i, :'illegal'   ;         end
    def pulse   ;         op :i, :'pulse'     ;         end
    def rte     ;         op :i, :'rte'       ;         end
    def rts     ;         op :i, :'rts'       ;         end
    def tpf     ;         op :i, :'tpf'       ;         end
    # 1 operand
    def clrb    a;        op :i, :'clr.b',    a;        end
    def clrw    a;        op :i, :'clr.w',    a;        end
    def clrl    a;        op :i, :'clr.l',    a;        end
    def beqs    a;        op :i, :'beq.s',    a;        end
    def beqw    a;        op :i, :'beq.w',    a;        end
    def bnes    a;        op :i, :'bne.s',    a;        end
    def bnew    a;        op :i, :'bne.w',    a;        end
    def bmis    a;        op :i, :'bmi.s',    a;        end
    def bmiw    a;        op :i, :'bmi.w',    a;        end
    def bpls    a;        op :i, :'bpl.s',    a;        end
    def bplw    a;        op :i, :'bpl.w',    a;        end
    def bccs    a;        op :i, :'bcc.s',    a;        end
    def bccw    a;        op :i, :'bcc.w',    a;        end
    def bcss    a;        op :i, :'bcs.s',    a;        end
    def bcsw    a;        op :i, :'bcs.w',    a;        end
    def bvcs    a;        op :i, :'bvc.s',    a;        end
    def bvcw    a;        op :i, :'bvc.w',    a;        end
    def bvss    a;        op :i, :'bvs.s',    a;        end
    def bvsw    a;        op :i, :'bvs.w',    a;        end
    def blos    a;        op :i, :'blo.s',    a;        end
    def blow    a;        op :i, :'blo.w',    a;        end
    def blss    a;        op :i, :'bls.s',    a;        end
    def blsw    a;        op :i, :'bls.w',    a;        end
    def bhis    a;        op :i, :'bhi.s',    a;        end
    def bhiw    a;        op :i, :'bhi.w',    a;        end
    def bhss    a;        op :i, :'bhs.s',    a;        end
    def bhsw    a;        op :i, :'bhs.w',    a;        end
    def bgts    a;        op :i, :'bgt.s',    a;        end
    def bgtw    a;        op :i, :'bgt.w',    a;        end
    def bges    a;        op :i, :'bge.s',    a;        end
    def bgew    a;        op :i, :'bge.w',    a;        end
    def blts    a;        op :i, :'blt.s',    a;        end
    def bltw    a;        op :i, :'blt.w',    a;        end
    def bles    a;        op :i, :'ble.s',    a;        end
    def blew    a;        op :i, :'ble.w',    a;        end
    def bzs     a;        op :i, :'bz.s',     a;        end
    def bzw     a;        op :i, :'bz.w',     a;        end
    def bnzs    a;        op :i, :'bnz.s',    a;        end
    def bnzw    a;        op :i, :'bnz.w',    a;        end
    def bsrs    a;        op :i, :'bsr.s',    a;        end
    def bsrw    a;        op :i, :'bsr.w',    a;        end
    def bras    a;        op :i, :'bra.s',    a;        end
    def braw    a;        op :i, :'bra.w',    a;        end
    def extbw   a;        op :i, :'ext.w',    a;        end
    def extwl   a;        op :i, :'ext.l',    a;        end
    def extbl   a;        op :i, :'extb.l',   a;        end
    def jmp     a;        op :i, :'jmp',      a;        end
    def jsr     a;        op :i, :'jsr',      a;        end
    def negl    a;        op :i, :'neg.l',    a;        end
    def negxl   a;        op :i, :'negx.l',   a;        end
    def notl    a;        op :i, :'not.l',    a;        end
    def pea     a;        op :i, :'pea',      a;        end
    def seqb    a;        op :i, :'seq.b',    a;        end
    def sneb    a;        op :i, :'sne.b',    a;        end
    def smib    a;        op :i, :'smi.b',    a;        end
    def splb    a;        op :i, :'spl.b',    a;        end
    def sccb    a;        op :i, :'scc.b',    a;        end
    def scsb    a;        op :i, :'scs.b',    a;        end
    def svcb    a;        op :i, :'svc.b',    a;        end
    def svsb    a;        op :i, :'svs.b',    a;        end
    def slob    a;        op :i, :'slo.b',    a;        end
    def slsb    a;        op :i, :'sls.b',    a;        end
    def shib    a;        op :i, :'shi.b',    a;        end
    def shsb    a;        op :i, :'shs.b',    a;        end
    def sgtb    a;        op :i, :'sgt.b',    a;        end
    def sgeb    a;        op :i, :'sge.b',    a;        end
    def sltb    a;        op :i, :'slt.b',    a;        end
    def sleb    a;        op :i, :'sle.b',    a;        end
    def szb     a;        op :i, :'sz.b',     a;        end
    def snzb    a;        op :i, :'snz.b',    a;        end
    def sfb     a;        op :i, :'sf.b',     a;        end
    def stb     a;        op :i, :'st.b',     a;        end
    def swapw   a;        op :i, :'swap.w',   a;        end
    def tpfw    a;        op :i, :'tpf.w',    a;        end
    def tpfl    a;        op :i, :'tpf.l',    a;        end
    def trap    a;        op :i, :'trap',     a;        end
    def tstb    a;        op :i, :'tst.b',    a;        end
    def tstw    a;        op :i, :'tst.w',    a;        end
    def tstl    a;        op :i, :'tst.l',    a;        end
    def unlk    a;        op :i, :'unlk',     a;        end
    def wddatab a;        op :i, :'wddata.b', a;        end
    def wddataw a;        op :i, :'wddata.w', a;        end
    def wddatal a;        op :i, :'wddata.l', a;        end
    def wdebugl a;        op :i, :'wdebug.l', a;        end
    # 2 operands
    def addl    a, b;     op :i, :'add.l',    a, b;     end
    def addal   a, b;     op :i, :'adda.l',   a, b;     end
    def addil   a, b;     op :i, :'addi.l',   a, b;     end
    def addql   a, b;     op :i, :'addq.l',   a, b;     end
    def addxl   a, b;     op :i, :'addx.l',   a, b;     end
    def andl    a, b;     op :i, :'and.l',    a, b;     end
    def andil   a, b;     op :i, :'andi.l',   a, b;     end
    def asll    a, b;     op :i, :'asl.l',    a, b;     end
    def asrl    a, b;     op :i, :'asr.l',    a, b;     end
    def bchgb   a, b;     op :i, :'bchg.b',   a, b;     end
    def bchgl   a, b;     op :i, :'bchg.l',   a, b;     end
    def bclrb   a, b;     op :i, :'bclr.b',   a, b;     end
    def bclrl   a, b;     op :i, :'bclr.l',   a, b;     end
    def bsetb   a, b;     op :i, :'bset.b',   a, b;     end
    def bsetl   a, b;     op :i, :'bset.l',   a, b;     end
    def btstb   a, b;     op :i, :'btst.b',   a, b;     end
    def btstl   a, b;     op :i, :'btst.l',   a, b;     end
    def cmpl    a, b;     op :i, :'cmp.l',    a, b;     end
    def cmpal   a, b;     op :i, :'cmpa.l',   a, b;     end
    def cmpil   a, b;     op :i, :'cmpi.l',   a, b;     end
    def cpushl  a, b;     op :i, :'cpushl',   a, b;     end
    def divsw   a, b;     op :i, :'divs.w',   a, b;     end
    def divsl   a, b;     op :i, :'divs.l',   a, b;     end
    def divuw   a, b;     op :i, :'divu.w',   a, b;     end
    def divul   a, b;     op :i, :'divu.l',   a, b;     end
    def eorl    a, b;     op :i, :'eor.l',    a, b;     end
    def eoril   a, b;     op :i, :'eori.l',   a, b;     end
    def lea     a, b;     op :i, :'lea',      a, b;     end
    def link    a, b;     op :i, :'link.w',   a, b;     end
    def lsll    a, b;     op :i, :'lsl.l',    a, b;     end
    def lsrl    a, b;     op :i, :'lsr.l',    a, b;     end
    def moveb   a, b;     op :i, :'move.b',   a, b;     end
    def movew   a, b;     op :i, :'move.w',   a, b;     end
    def movel   a, b;     op :i, :'move.l',   a, b;     end
    def moveaw  a, b;     op :i, :'movea.w',  a, b;     end
    def moveal  a, b;     op :i, :'movea.l',  a, b;     end
    def movecl  a, b;     op :i, :'movec.l',  a, b;     end
    def moveml  a, b;     op :i, :'movem.l',  a, b;     end
    def moveql  a, b;     op :i, :'moveq.l',  a, b;     end
    def mulsw   a, b;     op :i, :'muls.w',   a, b;     end
    def mulsl   a, b;     op :i, :'muls.l',   a, b;     end
    def muluw   a, b;     op :i, :'mulu.w',   a, b;     end
    def mulul   a, b;     op :i, :'mulu.l',   a, b;     end
    def orl     a, b;     op :i, :'or.l',     a, b;     end
    def oril    a, b;     op :i, :'ori.l',    a, b;     end
    def subl    a, b;     op :i, :'sub.l',    a, b;     end
    def subal   a, b;     op :i, :'suba.l',   a, b;     end
    def subil   a, b;     op :i, :'subi.l',   a, b;     end
    def subql   a, b;     op :i, :'subq.l',   a, b;     end
    def subxl   a, b;     op :i, :'subx.l',   a, b;     end
    # 3 operands
    def remsl   a, b, c;  op :i, :'rems.l',   a, b, c;  end
    def remul   a, b, c;  op :i, :'remu.l',   a, b, c;  end
  end
end

