#
# This file is part of raspp.
# Copyright (C) 2016 Jeffrey Sharp
#
# raspp is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published
# by the Free Software Foundation, either version 3 of the License,
# or (at your option) any later version.
#
# raspp is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See
# the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with raspp.  If not, see <http://www.gnu.org/licenses/>.
#

require 'minitest/autorun'
require 'stringio'

require_relative '../lib/raspp'

module Raspp
  class RasppTest <  Minitest::Test
    def assert_pp(input, output)
      input  = unindent input
      output = unindent output
      actual = capture do
        Raspp::process(input, 'test', 1)
      end
      assert_equal output, actual
    end

    private

    def capture
      begin
        _stdout = $stdout
        $stdout = StringIO.new('','w')
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

  class GeneralTest < RasppTest
    def test_foo
      assert_pp '
        a
      ', '
        a
      '
    end
  end
end

