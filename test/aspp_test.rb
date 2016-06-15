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
      output = Aspp::preamble('test') + unindent(output)
      actual = capture do
        Aspp::Processor.new.process(input, 'test')
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
      ', "
        \tfoo
      "
    end
  end
end

