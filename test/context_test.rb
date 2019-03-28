#!/usr/bin/env ruby
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
#

require_relative "ras"
require "minitest/autorun"

module RAS
  class ContextTests < Minitest::Test
    def test_int_in_range
      assert_equal   42, int(  42, 8)
      assert_equal -128, int(-128, 8)
      assert_equal  255, int( 255, 8)
    end

    def test_int_string
      assert_equal -42, int( "-42", 8)
      assert_equal 100, int("0x64", 8)
    end

    def test_int_inconvertible
      assert_raises TypeError do
        int(:foo, 8)
      end
    end

    def test_int_underflow
      assert_raises RangeError do
        int(-129, 8)
      end
    end

    def test_int_overflow
      assert_raises RangeError do
        int(256, 8)
      end
    end

    def int(*args)
      Context.new(nil, nil, nil).__exec__ { int(*args) }
    end
  end
end

