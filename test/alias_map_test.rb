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

require_relative "../lib/ras"
require "minitest/autorun"

module RAS
  class AliasMapTests < Minitest::Test

    # TODO: There will be breakage when a child map tries to 'transfer' a value
    # that is already mapped in a parent map.  It's probably easy to fix, but I
    # want to work on something else now.

    class TestAliasMap < AliasMap
      # Need this to test respond_to_missing?
      define_method :respond_to?, ::Object.instance_method(:respond_to?)
    end

    def setup
      @top = TestAliasMap.new       # top-level
      @sub = TestAliasMap.new @top  # subscope
    end

    def test_attr_undefined
      assert_raises(NoMethodError) { @top.foo }
      assert_raises(NoMethodError) { @sub.foo }
    end

    def test_attr_inherited
      @top.foo = :a
      assert_equal :a, @sub.foo
    end

    def test_attr_assigned
      @sub.foo = :a
      assert_equal :a, @sub.foo
    end

    def test_attr_overridden
      @top.foo = :a
      @sub.foo = :b
      assert_equal :a, @top.foo
      assert_equal :b, @sub.foo
    end

    def test_attr_reassigned
      @sub.foo = :a
      @sub.foo = :b
      assert_equal :b, @sub.foo
    end

    def test_attr_transferred
      @sub.foo = :a
      @sub.bar = :a
      assert_raises(NoMethodError) { @sub.foo }
      assert_equal :a, @sub.bar
    end

    def test_index_undefined
      assert_nil @sub[:foo]
    end

    def test_index_inherited
      @top[:foo] = :a
      assert_equal :a, @sub[:foo]
    end

    def test_index_assigned
      @sub[:foo] = :a
      assert_equal :a, @sub[:foo]
    end

    def test_index_overridden
      @top[:foo] = :a
      @sub[:foo] = :b
      assert_equal :a, @top[:foo]
      assert_equal :b, @sub[:foo]
    end

    def test_index_reassigned
      @sub[:foo] = :a
      @sub[:foo] = :b
      assert_equal :b, @sub[:foo]
    end

    def test_index_transferred
      @sub[:foo] = :a
      @sub[:bar] = :a
      assert_nil       @sub[:foo]
      assert_equal :a, @sub[:bar]
    end

    def test_respond_to_undefined
      assert  @sub.respond_to?(:[])
      assert !@sub.respond_to?(:**)
      assert  @sub.respond_to?(:foo=)
      assert !@sub.respond_to?(:foo)
    end

    def test_respond_to_inherited
      @top.foo = :a
      assert  @sub.respond_to?(:[])
      assert !@sub.respond_to?(:**)
      assert  @sub.respond_to?(:foo=)
      assert  @sub.respond_to?(:foo)
    end

    def test_respond_to_assigned
      @sub.foo = :a
      assert  @sub.respond_to?(:[])
      assert !@sub.respond_to?(:**)
      assert  @sub.respond_to?(:foo=)
      assert  @sub.respond_to?(:foo)
    end
  end
end

