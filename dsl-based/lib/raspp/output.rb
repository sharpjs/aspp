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

class Output
  attr_reader :out, :err

  def initialize(out=nil, err=nil)
    @out = out || $stdout
    @err = err || $stdout
  end

  def message(*args)
    loc = source_location
    @out.puts *args.map { |arg| "#{loc}: #{arg}" }
  end

  def write_label(sym)
    raise 'method not implemented'
  end

  def write_instruction(opcode, *args)
    write_directive opcode, *args
  end

  def write_directive(name, *args)
    @out.puts args.empty? \
      ? "\t#{op}"
      : "\t#{op}\t#{args.join(', ')}"
  end

  def source_location(depth = 0)
    loc = ::Kernel.caller_locations(depth + 5, 1).first;
    "#{loc.path}:#{loc.lineno}"
  end
end

##
# GNU Assembler
#
class Gas < Output
  def local_prefix
    '.L.'
  end

  def write_label(sym)
    @out.puts "#{sym}:"
  end

  def define_symbol(name, value)
    write_directive :'.equ', name, value
  end
end

##
# vasm with Motorola syntax
#
class VasmMot < Output
  def local_prefix
    '._'
  end

  def write_label(sym)
    @out.puts sym
  end

  def define_symbol(name, value)
    @out.puts 
    write_directive :'equ', name, value
  end
end

