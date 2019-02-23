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
  class AliasMapTests < Minitest::Test
    def test_parent_nil
      map = AliasMap.new
      assert map.__parent__.nil?
    end

    def test_parent_not_nil
      map0 = AliasMap.new
      map1 = AliasMap.new map0
      assert_equal map0.__id__, map1.__parent__.__id__
    end

    def test_to_h_initial
      map = AliasMap.new
      assert map.__to_h__.empty?
    end

    def test_to_h_after_set
      map = AliasMap.new
      map.foo = :a
      map.bar = :b
      assert_equal map.__to_h__, { "foo" => :a, "bar" => :b }
    end

    def test_get_unset
      map = AliasMap.new
      assert_raises(NoMethodError) { map.foo }
    end

    def test_get_set
      map = AliasMap.new
      map.foo = :a
      assert_equal :a, map.foo
    end
  end
end

