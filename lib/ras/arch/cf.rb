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

#require_relative '../refinements'

module RAS
  #using self

  module CF
    class GenReg
      attr_reader :name, :number_3bit, :number_4bit

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

    DATA_REGS = (0..7).map { |n| DataReg.new(:"d#{n}", n) }
    ADDR_REGS = (0..7).map { |n| AddrReg.new(:"a#{n}", n) }

    class Code
      def d0; DATA_REGS[0]; end
      def d1; DATA_REGS[1]; end
      def d2; DATA_REGS[2]; end
      def d3; DATA_REGS[3]; end
      def d4; DATA_REGS[4]; end
      def d5; DATA_REGS[5]; end
      def d6; DATA_REGS[6]; end
      def d7; DATA_REGS[7]; end

      def a0; ADDR_REGS[0]; end
      def a1; ADDR_REGS[1]; end
      def a2; ADDR_REGS[2]; end
      def a3; ADDR_REGS[3]; end
      def a4; ADDR_REGS[4]; end
      def a5; ADDR_REGS[5]; end
      def a6; ADDR_REGS[6]; end
      def a7; ADDR_REGS[7]; end

      alias fp a6
      alias sp a7
    end

  end
end

