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
    class GenReg
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
    end

    class AddrReg < GenReg
      def initialize(name, num)
        super(name, num, num + 8)
      end
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

      def word(w); puts w.to_s(8); end
    end

    class Code
      DATA_REGS.each do |r| define_method(r.name) {r} end
      ADDR_REGS.each do |r| define_method(r.name) {r} end

      alias fp a6
      alias sp a7

      def ext  () Ext  .new end
      def moveq() Moveq.new end
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
    end
  end
end

