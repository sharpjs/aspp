#
# This file is part of raspp.
# Copyright (C) 2015 Jeffrey Sharp
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

require "minitest/autorun"

require_relative "../lib/raspp"

module Raspp
  refine String do
    def unindent
      gsub(/^#{self[/\A +/]}/, '')
    end
  end
  using Raspp

  class GeneralTest < Minitest::Test
    def test_foo
      Raspp::process(<<-END.unindent, 'test', 1)
        a
      END
    end
  end
end

