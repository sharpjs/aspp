# frozen_string_literal: true
# encoding: utf-8
#
# RAS - Ruby ASsembler
# Copyright (C) 2019 Jeffrey Sharp
#
# RAS is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published
# by the Free Software Foundation, either version 3 of the License,
# or (at your option) any later version.
#
# RAS is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See
# the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with RAS.  If not, see <http://www.gnu.org/licenses/>.

require_relative '../base'

module RAS
  module CF
    refine Object do
      def to_cf_mode
        raise Error, "invalid addressing mode: #{inspect}"
      end
    end

    refine Integer do
      def to_cf_mode
        Immediate.new(self)
      end
    end

    refine Array do
      def +@
        case mode = to_cf_mode
        when AddrInd then AddrIndInc.new(mode.reg)
        else raise Error, "invalid addressing mode: +#{inspect}"
        end
      end

      def w
        case mode = to_cf_mode
        when Absolute32 then Absolute16.new(mode.addr)
        else raise Error, "invalid addressing mode: +#{inspect}"
        end
      end

      def to_cf_mode
        # Initialize
        base  = nil
        disp  = nil
        index = nil
        scale = 1

        # Classify terms
        each do |term|
          case term
          when Integer
            disp = (disp || 0) + term; next
          when AddrReg
            (base  = term; next) unless base
            (index = term; next) unless index
          when AddrRegDec, PcReg
            (base  = term; next) unless base
          when DataReg
            (index = term; next) unless index
          when ScaledIndex
            (index = term.index;
             scale = term.scale; next) unless index
          end
          super # raises
        end

        # Interpret
        case base
        when AddrReg
          case
          when index then AddrDispIdx.new(base, disp || 0, index, scale)
          when disp  then AddrDisp   .new(base, disp)
          else            AddrInd    .new(base)
          end
        when PcReg
          case
          when index then PcDispIdx.new(disp || 0, index, scale)
          when disp  then PcDisp   .new(disp)
          end
        when AddrRegDec
          AddrIndDec.new(base) unless disp || index
        when nil
          Absolute32.new(disp) unless index
        end or super
      end
    end

    using self

    # Addressing Modes

    # Single
    #                daipmoxwlIOX
    MODE_DATA    = 0b100000000000 # data register direct
    MODE_ADDR    = 0b010000000000 # address register direct
    MODE_IND     = 0b001000000000 # address register indirect
    MODE_IND_INC = 0b000100000000 # address register indirect, post-increment
    MODE_IND_DEC = 0b000010000000 # address register indirect, pre-decrement
    MODE_DISP    = 0b000001000000 # base + displacement
    MODE_IDX     = 0b000000100000 # base + displacement + scaled index
    MODE_ABS16   = 0b000000010000 # absolute signed word
    MODE_ABS32   = 0b000000001000 # absolute unsigned long
    MODE_IMM     = 0b000000000100 # immediate
    MODE_PC_DISP = 0b000000000010 # pc-relative + displacement
    MODE_PC_IDX  = 0b000000000001 # pc-relative + displacement + scaled index

    # Composite
    #                           daipmoxwlIOX
    MODES_READ              = 0b111111111111
    MODES_READ_NON_ADDR     = 0b101111111111
    MODES_WRITE             = 0b111111111000
    MODES_WRITE_NON_ADDR    = 0b101111111000
    MODES_WRITE_NON_REG     = 0b001111111000
    MODES_NON_EXT_WORD      = 0b111110000000
    MODES_IND_IPMO          = 0b001111000000
    MODES_IND_XWL           = 0b000000111000
    MODES_JUMP              = 0b001001111011
    #...more...

    module Mode
      def to_cf_mode
        self
      end

      def require(mask)
        if self.mask.nobits?(mask)
          raise Error, "unsupported addressing mode: #{inspect}"
        end
        self
      end

      #mask        => Integer
      #encode(ctx) => Integer
    end

    # Immediate

    class Immediate
      include Mode
      attr_reader :expr

      def initialize(expr)
        @expr = expr
      end

      def mask
        MODE_IMM
      end

      def encode(ctx)
        0b111_100
        # and set up to add extension word
      end

      def inspect
        expr.inspect
      end
    end

    # Absolute

    class Absolute
      include Mode
      attr_reader :addr

      def initialize(addr)
        @addr = addr
      end
    end

    class Absolute16 < Absolute
      def mask
        MODE_ABS16
      end

      def encode(ctx)
        0b111_000
        # and set up to add extension word
      end

      def inspect
        "[#{addr.inspect}].w"
      end
    end

    class Absolute32 < Absolute
      def mask
        MODE_ABS32
      end

      def encode(ctx)
        0b111_001
        # and set up to add extension word
      end

      def inspect
        "[#{addr.inspect}]"
      end
    end

    # Register

    class Register
      attr_reader :name

      def initialize(name)
        @name = name
      end

      def inspect
        name
      end
    end

    class GenReg < Register
      include Mode
      attr_reader :number_u3, :number_u4

      def initialize(name, num3, num4)
        super(name)
        @number_u3 = num3
        @number_u4 = num4
        freeze
      end

      def *(scale)
        ScaledIndex.new(self, scale)
      end
    end

    class DataReg < GenReg
      def initialize(name, num)
        super(name, num, num)
      end

      def mask
        MODE_DATA
      end

      def encode(ctx)
        0b000_000 | number_u3
      end
    end

    class AddrReg < GenReg
      def initialize(name, num)
        super(name, num, num + 8)
      end

      def -@
        AddrRegDec.new(self)
      end

      def mask
        MODE_ADDR
      end

      def encode(ctx)
        0b001_000 | number_u3
      end
    end

    class AddrRegDec
      attr_reader :reg

      def initialize(reg)
        @reg = reg
      end
    end

    class AuxReg < Register
    end

    class CtlReg < Register
    end

    class PcReg < Register
      def initialize
        super(:pc)
      end
    end

    DATA_REGS = (0..7).map { |n| DataReg.new(:"d#{n}", n) }.freeze
    ADDR_REGS = (0..7).map { |n| AddrReg.new(:"a#{n}", n) }.freeze
    PC        = PcReg.new.freeze

    # Indirect

    class ScaledIndex
      attr_reader :index, :scale

      SCALES = [1, 2, 4]

      def initialize(index, scale)
        if !index.is_a?(GenReg)
          raise Error, "not a valid index register: #{index.inspect}"
        end
        if !SCALES.include?(scale)
          raise Error, "not a valid index scale: #{scale.inspect}"
        end
        @index = index
        @scale = scale
      end

      def inspect
        "#{index.inspect}*#{scale.inspect}"
      end
    end

    class AddrInd
      include Mode
      attr_reader :reg

      def initialize(reg)
        @reg = reg
      end

      def mask
        MODE_IND
      end

      def encode(ctx)
        0b010_000 | reg.number_u3
      end

      def inspect
        "[#{reg.inspect}]"
      end
    end

    class AddrIndInc # post-increment
      include Mode
      attr_reader :reg

      def initialize(reg)
        @reg = reg
      end

      def mask
        MODE_IND_INC
      end

      def encode(ctx)
        0b011_000 | reg.number_u3
      end

      def inspect
        "+[#{reg.inspect}]"
      end
    end

    class AddrIndDec # pre-decrement
      include Mode
      attr_reader :reg

      def initialize(reg)
        @reg = reg
      end

      def mask
        MODE_IND_DEC
      end

      def encode(ctx)
        0b100_000 | reg.number_u3
      end

      def inspect
        "[-#{reg.inspect}]"
      end
    end

    class AddrDisp
      include Mode
      attr_reader :base, :disp

      def initialize(base, disp)
        @base = base
        @disp = disp
      end

      def mask
        MODE_DATA
      end

      def encode(ctx)
        0b101_000 | base.number_u3
        # plus u16 displacement in extension word
      end

      def inspect
        "[#{base.inspect}, #{disp.inspect}]"
      end
    end

    class AddrDispIdx
      include Mode
      attr_reader :base, :disp, :index, :scale

      def initialize(base, disp, index, scale)
        @base  = base
        @disp  = disp
        @index = index
        @scale = scale
      end

      def mask
        MODE_IDX
      end

      def encode(ctx)
        0b110_000 | base.number_u3
        # plus u8 displacement and index in extension word
      end

      def inspect
        "[#{base.inspect}, #{disp.inspect}, #{index.inspect}*#{scale.inspect}]"
      end
    end

    class PcDisp
      include Mode
      attr_reader :disp

      def initialize(disp)
        @disp = disp
      end

      def mask
        MODE_PC_DISP
      end

      def encode(ctx)
        0b111_010
        # plus u16 displacement in extension word
      end

      def inspect
        "[pc, #{disp.inspect}]"
      end
    end

    class PcDispIdx
      include Mode
      attr_reader :disp, :index, :scale

      def initialize(disp, index, scale)
        @disp  = disp
        @index = index
        @scale = scale
      end

      def mask
        MODE_PC_IDX
      end

      def encode(ctx)
        0b111_011
        # plus u8 displacement and index in extension word
      end

      def inspect
        "[pc, #{disp.inspect}, #{index.inspect}*#{scale.inspect}]"
      end
    end

    # Code Generation

    module CodeGen
      private

      def dr(r)
        unless r.is_a?(DataReg)
          raise Error, "Invalid data register: #{r.inspect}"
        end
        r.number_u3
      end

      def ar(r)
        unless r.is_a?(AddrReg)
          raise Error, "Invalid address register: #{r.inspect}"
        end
        r.number_u3
      end

      def q8(v)
        unless v.is_a?(Integer) && v.bit_length < 8
          raise Error, "Invalid 8-bit signed integer: #{v.inspect}"
        end
        v
      end

      def mode(x, mask)
        x.to_cf_mode.require(mask).encode(nil)
      end

      def word(w); puts w.to_s(8); end
    end

    class Code
      # General-purpose registers
      DATA_REGS.each do |r| define_method(r.name) {r} end
      ADDR_REGS.each do |r| define_method(r.name) {r} end
      alias fp a6
      alias sp a7

      # Other registers
      def pc    () PC        end

      # Instructions
      def add   () Add  .new end
      def ext   () Ext  .new end
      def moveq () Moveq.new end
    end

    class Add
      include CodeGen
      def l(s, d)
        if d.is_a?(DataReg)
          word 0o150200 | dr(d) << 9 | mode(s, MODES_READ)
        elsif s.is_a?(DataReg)
          word 0o150600 | dr(s) << 9 | mode(d, MODES_WRITE_NON_REG)
        else
          raise Error, "invalid operands for add.l: #{s.inspect}, #{d.inspect}"
        end
      end
    end

    class Ext
      include CodeGen
      def bw(d) word 0o044200 | dr(d) end # replaces ext.w
      def wl(d) word 0o044300 | dr(d) end # replaces ext.l
      def bl(d) word 0o044700 | dr(d) end # replaces extb.l
    end

    class Moveq
      include CodeGen
      def l(s, d) word 0o030000 | dr(d) << 9 | q8(s) end
    end

    # temp testing junk
    Code.new.instance_eval do
      moveq.l 127, d4
      add.l [0, pc, a3*4, 42, 43], d0
    end
  end
end

