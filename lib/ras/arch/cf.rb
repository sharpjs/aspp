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

module RAS
  module CF
    # Addressing Modes
    #        mask bit         nickname  description
    #        --------------   --------  ---------------------------
    MODE_D = 0b100000000000 # data      data register direct
    MODE_A = 0b010000000000 # address   address register direct
    MODE_I = 0b001000000000 # indirect  address register Indirect
    MODE_P = 0b000100000000 # plus      address register indirect, post-increment
    MODE_M = 0b000010000000 # minus     address register indirect, pre-decrement
    MODE_O = 0b000001000000 # offset    base + displacement
    MODE_X = 0b000000100000 # index     base + displacement + scaled index
    MODE_W = 0b000000010000 # word      absolute signed word
    MODE_L = 0b000000001000 # long      absolute unsigned long
    MODE_V = 0b000000000100 # value     immediate
    MODE_R = 0b000000000010 # relative  pc-relative + displacement
    MODE_T = 0b000000000001 # table     pc-relative + displacement + scaled index

    # Mode Combinations
    #                  DAIPMOXWLVRT
    M_DAIPMOXWLVRT = 0b111111111111
    M____PMOXWL___ = 0b000111111000

    module Mode
      #mode_mask   #=> Integer
      #encode_mode #=> Integer
    end

    class GenReg
      include Mode
      attr_reader :name, :number_u3, :number_u4

      def initialize(name, num3, num4)
        @name      = name
        @number_u3 = num3
        @number_u4 = num4
        freeze
      end
    end

    class DataReg < GenReg
      def initialize(name, num)
        super(name, num, num)
      end

      def mode_mask;   MODE_D;           end
      def encode_mode; 0o10 | number_u3; end
    end

    class AddrReg < GenReg
      def initialize(name, num)
        super(name, num, num + 8)
      end

      def mode_mask;   MODE_A;           end
      def encode_mode; 0o10 | number_u3; end
    end

    DATA_REGS = (0..7).map { |n| DataReg.new(:"d#{n}", n) }.freeze
    ADDR_REGS = (0..7).map { |n| AddrReg.new(:"a#{n}", n) }.freeze

    module CodeGen
      private

      def dr(r)
        unless r.is_a?(DataReg)
          raise "Invalid data register: #{r.inspect}"
        end
        r.number_u3
      end

      def ar(r)
        unless r.is_a?(AddrReg)
          raise "Invalid address register: #{r.inspect}"
        end
        r.number_u3
      end

      def q8(v)
        unless v.is_a?(Integer) && v.bit_length < 8
          raise "Invalid 8-bit signed integer: #{v.inspect}"
        end
        v
      end

      def mode(x, mask)
        if !x.is_a?(Mode)
          raise "Invalid addressing mode: #{x.inspect}"
        elsif x.mode_mask.nobits?(mask)
          raise "Unsupported addressing mode: #{x.inspect}"
        end
        x.encode_mode
      end

      def word(w); puts w.to_s(8); end
    end

    class Code
      DATA_REGS.each do |r| define_method(r.name) {r} end
      ADDR_REGS.each do |r| define_method(r.name) {r} end

      alias fp a6
      alias sp a7

      def add  () Add  .new end
      def ext  () Ext  .new end
      def moveq() Moveq.new end
    end

    class Add
      include CodeGen
      def l(s, d)
        if d.is_a?(DataReg)
          word 0o150200 | dr(d) << 9 | mode(s, M_DAIPMOXWLVRT)
        elsif s.is_a?(DataReg)
          word 0o150600 | dr(s) << 9 | mode(d, M___IPMOXWL___)
        else
          raise "Invalid operands for add.l."
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
      add.l d3, d4
    end
  end
end

