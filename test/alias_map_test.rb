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
    def setup
      @top = AliasMap.new       # top-level
      @sub = AliasMap.new @top  # subscope
    end

    def test_get_undefined
      assert_raises(NoMethodError) { @top.foo }
      assert_raises(NoMethodError) { @sub.foo }
    end

    def test_get_inherited
      @top.foo = :a
      assert_equal :a, @sub.foo
    end

    def test_get_assigned
      @sub.foo = :a
      assert_equal :a, @sub.foo
    end

    def test_set_other_attr_equal_value
      @map.foo = +"a"
      @map.bar = +"a"
      assert_raises(NoMethodError) { @map.foo }
      assert_equal "a", @map.bar
    end

    class TestAliasMap < AliasMap
      define_method :respond_to?, ::Object.instance_method(:respond_to?)
    end

    def test_respond_to_unset
      assert  @map.respond_to?(:[])
      assert !@map.respond_to?(:**)
      assert  @map.respond_to?(:foo=)
      assert !@map.respond_to?(:foo)
    end

    def test_respond_to_set
      @map.foo = :a
      assert  @map.respond_to?(:[])
      assert !@map.respond_to?(:**)
      assert  @map.respond_to?(:foo=)
      assert  @map.respond_to?(:foo)
    end
  end
end

