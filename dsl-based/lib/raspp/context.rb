# frozen_string_literal: true
#
# This file is part of Raspp.
# Copyright (C) 2016 Jeffrey Sharp
#
# Raspp is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published
# by the Free Software Foundation, either version 3 of the License,
# or (at your option) any later version.
#
# Raspp is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See
# the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Raspp.  If not, see <http://www.gnu.org/licenses/>.
#

#require_relative 'block'
require_relative 'refinements'

module Raspp
  using self

  class CleanObject < BasicObject
    # public  methods: __send__, __eval__, __exec__, __id__
    # private methods: initialize, method_missing

    define_method :__send__, ::Object.instance_method(:public_send)
    define_method :__eval__,          instance_method(:instance_eval)
    define_method :__exec__,          instance_method(:instance_exec)

    undef_method  :!, :!=, :==, :equal?, :instance_eval, :instance_exec,
                  :singleton_method_added,
                  :singleton_method_removed,
                  :singleton_method_undefined
  end

  class ContextProxy < CleanObject
    undef_method :__id__
    private
    
    def method_missing(name, *args, &block)
      RASPP_CONTEXT.__send__(name, *args, &block)
    end

    def respond_to_missing?(name, all)
      RASPP_CONTEXT.respond_to?(name, false)
    end

    def self.const_missing(name)
      ::Object.const_get(name)
    end
  end

  class Context < CleanObject
    def initialize(out, parent=nil, name=nil)
      @out          = out
      @parent       = parent
      @local_prefix = parent ? "#{parent.local(name)}." : out.local_prefix
      @local_index  = 0
    end

    def eval(ruby, name="(stdin)", line=1)
      ContextProxy
        .dup.tap { |c| c.const_set(:RASPP_CONTEXT, self) }
        .new.__eval__(ruby, name, line)
    end

    private

    def method_missing(name, *args, &block)
      @parent ? @parent.__send__(name, *args, &block) : super
    end

    def respond_to_missing?(name, all)
      @parent && @parent.respond_to?(name, all)
    end

    public

    # Messages

    def info *args
      @out.log_info *args
    end

    def warning *args
      @out.log_warning *args
    end

    def error *args
      @out.log_error *args
    end

    # Symbols

    def eq sym, val
      @out.define_symbol sym, val
    end

    ##
    # Defines a label.
    #
    # If +sym+ is given, it is used as the label name.
    # Otherwise, a unique local label is generated.
    #
    # If a block is given, this method defines a code block
    # with both start and end labels.
    #
    def at sym = nil
      sym = sym ? sym.to_symbol(self) : local
      @out.write_label "#{sym}:"
      #if block_given?
      #  yield block = Block.new(sym)
      #  puts "#{block.end}:" if block.end_used?
      #end
      sym
    end

    def global(sym)
      #sym = sym.to_symbol(self)
      puts ".global #{sym}"
      sym
    end

    def local(sym = nil)
      if sym.nil?
        sym = @local_index += 1
      else
        sym = sym.to_s
        sym.slice! /^[$@]/
      end
      :"#{@local_prefix}#{sym}"
    end

    #def skip(count, fill = nil)
    #  dir :".skip", count, fill
    #end

    #def skip_to(offset, fill = nil)
    #  dir :".org", offset, fill
    #end

    #def incbin(path, start, len)
    #  dir :".incbin", path, start, len
    #end

    #[:byte, :word, :long].each do |type|
    #  define_method type do |*values|
    #    values = [0] if values.empty?
    #    values.map! { |v| v.to_asm }
    #    puts "\t.#{type}\t#{values.join(', ')}"
    #  end
    #end

    #[:ascii, :string].each do |type|
    #  define_method type do |*values|
    #    unless values.empty?
    #      values.map! { |v| v.to_s.to_asm }
    #      puts "\t.#{type}\t#{values.join(', ')}"
    #    end
    #  end
    #end

    #def struct(sym = nil)
    #  addr 0
    #  yield if block_given?
    #end
  end
end

