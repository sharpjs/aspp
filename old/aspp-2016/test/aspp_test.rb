# encoding: UTF-8
# frozen_string_literal: false
#
# aspp - Assembly Preprocessor in Ruby
# Copyright (C) 2016 Jeffrey Sharp
#
# aspp is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published
# by the Free Software Foundation, either version 3 of the License,
# or (at your option) any later version.
#
# aspp is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See
# the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with aspp.  If not, see <http://www.gnu.org/licenses/>.
#

require 'minitest/autorun'
require 'stringio'

require_relative '../lib/aspp'

module Aspp
  class AsppTest < Minitest::Test
    def assert_pp(input, output)
      input  = unindent input
      output = unindent output
      actual = capture do
        aspp   = Aspp::Processor.new('test')
        output = aspp.preamble + output
        aspp.process input
      end
      assert_equal output, actual
    end

    private

    def capture
      _stdout = $stdout
      begin
        $stdout = StringIO.new('', 'w')
        yield
        $stdout.string
      ensure
        $stdout = _stdout
      end
    end

    def unindent(text)
      text .sub!(/\A\n/,  '')
      text .sub!(/^ +\z/, '')
      text.gsub!(/^#{text[/\A +/]}/, '')
      text
    end
  end

  class GeneralTest < AsppTest
    def test_unchanged
      assert_pp '
        foo
      ', '
        foo
      '
    end

    def test_local_label
      assert_pp '
        .foo:
      ', '
        L(foo):
      '
    end

    def test_local_operand
      assert_pp '
        .foo .bar
      ', '
        .foo L(bar)
      '
    end

    def test_alias
      assert_pp '
        foo bar = qux
        foo bar
      ', '
        foo _(bar)qux
        foo _(bar)qux
      '
    end

    def test_alias_redef_lhs
      assert_pp '
        foo bar = qux
        foo bar = zot
        foo bar
      ', '
        foo _(bar)qux
        foo _(bar)zot
        foo _(bar)zot
      '
    end

    def test_alias_redef_rhs
      assert_pp '
        foo bar = qux
        foo vib = qux
        foo bar
        foo vib
      ', '
        foo _(bar)qux
        foo _(vib)qux
        foo bar
        foo _(vib)qux
      '
    end

    def test_alias_undef
      assert_pp '
        foo bar = qux
        foo bar
        snork:
        foo bar
      ', '
        foo _(bar)qux
        foo _(bar)qux
        .label snork;
        foo bar
      '
    end

    def test_alias_indirect
      assert_pp '
        foo bar = qux
        foo jig = bar
        foo bar
        foo jig
      ', '
        foo _(bar)qux
        foo _(jig)qux
        foo bar
        foo _(jig)qux
      '
    end

    def test_alias_raw
      assert_pp '
        foo bar = `not ``just`` an ident`
        foo bar
      ', '
        foo _(bar)not `just` an ident
        foo _(bar)not `just` an ident
      '
    end
  end
end

