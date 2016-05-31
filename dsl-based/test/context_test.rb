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

require "minitest/autorun"
require "stringio"

require_relative "../lib/aex/top_level"
require_relative "../lib/aex/targets/mcf5307"

module Aex
  class ContextTest < Minitest::Test
    def asm(input, expected)
      output = StringIO.new
      Aex::TopLevel.new(output).instance_eval(input, "test")
      assert_equal expected, output.string
    end

    def test_inst_imm
      asm "tstl 1\n", "\ttstl\t#1\n"
    end

#    def test_inst_imm_add
#      asm "tstl :x+1\n", "\ttstl\t#1\n"
#    end

    def test_inst_abs
      asm "tstl [1]\n", "\ttstl\t1:l\n"
    end

    def test_inst_absw
      asm "tstl [1].w\n", "\ttstl\t1:w\n"
    end

    def test_inst_absl
      asm "tstl [1].l\n", "\ttstl\t1:l\n"
    end

    def test_inst_reg
      asm "tstl d0\n", "\ttstl\t%d0\n"
    end

    def test_inst_reg_ind
      asm "tstl [a0]\n", "\ttstl\t%a0@\n"
    end

    def test_inst_reg_inc
      asm "tstl [+a0]\n", "\ttstl\t%a0@+\n"
    end

    def test_inst_reg_dec
      asm "tstl [-a0]\n", "\ttstl\t%a0@-\n"
    end

    def test_inst_disp
      asm "tstl [a0, 1]\n", "\ttstl\t%a0@(1)\n"
    end

    def test_inst_disp_index
      asm "tstl [a0, 1, d0]\n", "\ttstl\t%a0@(1, %d0*1)\n"
    end

    def test_inst_disp_index_scale
      asm "tstl [a0, 1, d0*4]\n", "\ttstl\t%a0@(1, %d0*4)\n"
    end

    def test_inst_reglist
      asm "tstl d0|d2\n", "\ttstl\t%d0/%d2\n"
    end

    def test_inst_reglist_range
      asm "tstl d0-d2\n", "\ttstl\t%d0-%d2\n"
    end

    def test_inst_reglists_ranges
      asm "tstl d0-d2|a0-a2\n", "\ttstl\t%d0-%d2/%a0-%a2\n"
    end
  end
end

