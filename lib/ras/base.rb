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

module RAS

  # ----------------------------------------------------------------------------

  class CleanObject < BasicObject
    # public  methods: __send__, __eval__, __exec__, __id__
    # private methods: initialize, method_missing, singleton_method_added,
    #                  singleton_method_removed, singleton_method_undefined

    define_method :__send__, ::Object.instance_method(:public_send)
    define_method :__eval__,          instance_method(:instance_eval)
    define_method :__exec__,          instance_method(:instance_exec)

    undef_method :!, :!=, :==, :equal?, :instance_eval, :instance_exec

    freeze
  end

  # ----------------------------------------------------------------------------

  class Sandbox < CleanObject
    undef_method :__id__
    private

    def initialize(context)
      raise "required: context" unless CleanObject === context
      @__context__ = context
    end

    def method_missing(name, *args, &block)
      # Redirect all invocations to internal context.
      @__context__.__send__(name, *args, &block)
    end

    def respond_to_missing?(name, all)
      # Redirect all invocations to internal context.
      @__context__.respond_to?(name, false)
    end

    def self.const_missing(name)
      # Make 'uninitialized constant' errors prettier.
      ::Object.const_get(name)
    end

    freeze
  end

  # ----------------------------------------------------------------------------

  class Error < RuntimeError
  end

end # module RAS

