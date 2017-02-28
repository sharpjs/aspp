#!/usr/bin/env ruby
# frozen_string_literal: true
#
# test - Tests for SRB
# Copyright (C) 2017 Jeffrey Sharp
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

require 'minitest/autorun'
require 'stringio'
load    'srb'

class SRBTest < Minitest::Test

  def process(input)
    stdout = StringIO.new
    syntax = SRB::MotorolaSyntax.new(stdout)
    buffer = SRB::Output.new(syntax)
    SRB::TopLevel.new(buffer).eval(input, 'test.srb')
    buffer.write
    stdout.string
  end

  def assert_pp(input, output)
    actual = process(input)
    assert_equal output, actual
  end

  def test_foo
    assert_pp <<~EXP, <<~END
      at :z
    EXP
      z:
          global  z
    END
  end

end

