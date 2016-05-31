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

require_relative 'block'
require_relative 'refinements'

module Raspp
  using self

  class Context
    attr_reader :_parent, :_local_prefix, :_local_index, :_out_stream

    def initialize(parent = nil, name = nil, out = nil)
      @_parent       = parent
      @_local_prefix = parent ? "#{parent.local(name)}." : ".L."
      @_local_index  = 0
      @_out_stream   = out || parent && parent._out_stream || $stdout
    end

    def method_missing(sym, *args, &block)
      @_parent ? @_parent.send(sym, *args, &block) : super
    end

    def respond_to_missing?(sym, all)
      @_parent && @_parent.respond_to?(sym, all)
    end

    def printf (*args) @_out_stream.printf *args end
    def print  (*args) @_out_stream.print  *args end
    def puts   (*args) @_out_stream.puts   *args end
    def putc   (*args) @_out_stream.putc   *args end

    def equ (sym, val) dir :".equ", sym, val; sym end
    def eqv (sym, val) dir :".eqv", sym, val; sym end
    def set (sym, val) dir :".set", sym, val; sym end

    ##
    # Defines a label.
    #
    # If +sym+ is given, it is used as the label name.
    # Otherwise, a unique local label is generated.
    #
    # If a block is given, this method defines a code block
    # with both start and end labels.
    #
    def at(sym = nil)
      sym = sym ? sym.to_symbol(self) : local
      puts "#{sym}:"
      if block_given?
        yield block = Block.new(sym)
        puts "#{block.end}:" if block.end_used?
      end
      sym
    end

    def global(sym)
      sym = sym.to_symbol(self)
      puts ".global #{sym}"
      sym
    end

    def local(sym = nil)
      if sym.nil?
        sym = @_local_index += 1
      else
        sym = sym.to_s
        sym.slice! /^[$@]/
      end
      :"#{@_local_prefix}#{sym}"
    end

    def skip(count, fill = nil)
      dir :".skip", count, fill
    end

    def skip_to(offset, fill = nil)
      dir :".org", offset, fill
    end

    def incbin(path, start, len)
      dir :".incbin", path, start, len
    end

    [:byte, :word, :long].each do |type|
      define_method type do |*values|
        values = [0] if values.empty?
        values.map! { |v| v.to_asm }
        puts "\t.#{type}\t#{values.join(', ')}"
      end
    end

    [:ascii, :string].each do |type|
      define_method type do |*values|
        unless values.empty?
          values.map! { |v| v.to_s.to_asm }
          puts "\t.#{type}\t#{values.join(', ')}"
        end
      end
    end

    def struct(sym = nil)
      addr 0
      yield if block_given?
    end

    # Writes a directive
    def dir(op, *args)
      args.compact!
      args.map! { |a| a.to_asm }
      puts args.empty? \
        ? "\t#{op}"
        : "\t#{op}\t#{args.join(', ')}"
    end
  end
end

