#
# This file is part of Raspp.
# Copyright (C) 2016 Jeffrey Sharp
#
# Raspp is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published
# by the Free Software Foundation, either version 3 of the License,
# or (at your option) any later version.
#
# Raspp is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See
# the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Raspp.  If not, see <http://www.gnu.org/licenses/>.
#

require_relative '../../refinements'
require_relative '../../operand'

module Raspp
  using self

  module Term
    def for_jump
      for_inst
    end
  end

  class Expression
    def for_inst
      Immediate.new(self)
    end

    def for_jump
      Absolute32.new(self)
    end
  end

  # Immediate

  Immediate = Struct.new :expr do
    include ReadOnly, Operand

    def to_s
      "##{expr}"
    end
  end

  # Absolute

  module Absolute; end

  Absolute16 = Struct.new :addr do
    include Absolute, Operand

    def to_s
      "#{addr}:w"
    end
  end

  Absolute32 = Struct.new :addr do
    include Absolute, Operand

    def to_s
      "#{addr}:l"
    end
  end

  # Register

  module Register
    def to_s
      "%#{reg}"
    end
  end

  module Index
    def *(scale)
      ScaledIndex.new(self, scale)
    end
  end

  module Numbered
    def <=>(that)
      self.class === that &&
      number <=> that.number
    end

    def succ
      self.class.all[number + 1]
    end

    alias next succ
  end

  module Listable
    def -(reg)
      RegList.new(["#{self}-#{reg}"])
    end

    def |(reg)
      RegList.new([self]) | reg
    end
  end

  class DataReg
    include Numbered, Listable, Index, Register, Operand
    struct :reg, :number

    def self.all
      Context::DATA_REGS
    end
  end

  class AddrReg
    include Numbered, Listable, Index, Register, Operand
    struct :reg, :number

    def self.all
      Context::ADDR_REGS
    end

    def -@
      AddrRegDec.new reg
    end

    def +@
      AddrRegInc.new reg
    end
  end

  AddrRegDec = Struct.new :reg do
    include Register, Term
  end

  AddrRegInc = Struct.new :reg do
    include Register, Term
  end

  AuxReg = Struct.new :reg do
    include Register, Operand
  end

  CtlReg = Struct.new :reg do
    include Register, Operand
  end

  RegList = Struct.new :regs do
    include Operand

    def to_s
      "#{regs.join("/")}"
    end

    def |(reg)
      regs << reg; self
    end
  end

  # Indirect

  module Indirect  end
  module Displaced end
  module Indexed   end

  SCALES = [1, 2, 4]

  ScaledIndex = Struct.new :index, :scale do
    include Term

    def to_s
      "#{index}*#{scale}"
    end
  end

  AddrInd = Struct.new :reg do
    include Indirect, Operand

    def to_s
      "#{reg}@"
    end
  end

  AddrIndInc = Struct.new :reg do
    include Indirect, Operand

    def to_s
      "#{reg}@+"
    end
  end

  AddrIndDec = Struct.new :reg do
    include Indirect, Operand

    def to_s
      "#{reg}@-"
    end
  end

  AddrDisp = Struct.new :base, :disp do
    include Displaced, Indirect, Operand

    def to_s
      "#{base}@(#{disp})"
    end
  end

  AddrIndex = Struct.new :base, :disp, :index, :scale do
    include Indexed, Displaced, Indirect, Operand

    def to_s
      "#{base}@(#{disp}, #{index}*#{scale})"
    end
  end

  PcDisp = Struct.new :disp do
    include ReadOnly, Displaced, Indirect, Operand

    def to_s
      "%pc@(#{disp})"
    end
  end

  PcIndex = Struct.new :disp, :index, :scale do
    include ReadOnly, Indexed, Displaced, Indirect, Operand

    def to_s
      "%pc@(#{disp}, #{index}*#{scale})"
    end
  end

  class Reference
    struct :addr

    def to_term(ctx)
      addr = self.addr.to_term(ctx)
      unless addr.is_a?(Expression)
        raise "invalid absolute reference: #{self}"
      end
      term_type.new(addr)
    end

    def to_s
      "[#{addr.to_asm}].#{suffix}"
    end
  end

  class Near < Reference
    def term_type ; Absolute16 ; end
    def suffix    ; :w         ; end
  end

  class Far < Reference
    def term_type ; Absolute32 ; end
    def suffix    ; :l         ; end
  end

  refine Array do
    def to_term(ctx)
      case length
      when 0
        nil
      when 1
        case addr = self[0].to_term(ctx)
        when Expression then Absolute32.new(addr)
        when AddrReg    then AddrInd   .new(addr)
        when AddrRegDec then AddrIndDec.new(addr)
        when AddrRegInc then AddrIndInc.new(addr)
        end
      when 2
        case base = self[0].to_term(ctx)
        when AddrReg
          case x = self[1].to_term(ctx)
          when Expression  then AddrDisp .new(base, x)
          when Index       then AddrIndex.new(base, 0, x, 1)
          when ScaledIndex then AddrIndex.new(base, 0, x.index, x.scale)
          end
        when ctx.pc
          case x = self[1].to_term(ctx)
          when Expression  then PcDisp .new(x)
          when Index       then PcIndex.new(0, x, 1)
          when ScaledIndex then PcIndex.new(0, x.index, x.scale)
          end
        end
      when 3, 4
        disp = self[1].to_term(ctx) and Expression === disp and
        begin
          case index = self[2].to_term(ctx)
          when Index
            scale = self[3] || 1
          when ScaledIndex
            scale = index.scale
            index = index.index.to_term(ctx) \
              and Index === index and self[3].nil?
          end
        end and
        SCALES.include?(scale) and
        begin
          case base = self[0].to_term(ctx)
          when AddrReg then AddrIndex.new(base, disp.expr, index, scale)
          when ctx.pc  then PcIndex  .new(      disp.expr, index, scale)
          end
        end
      end.freeze or
        raise "invalid addressing mode: [#{join(', ')}]"
    end

    def w
      Near.new(self[0])
    end

    def l
      Far.new(self[0])
    end

    def unwrap
      length > 1 ? self : self[0]
    end
  end
end

