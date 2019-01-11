#!/usr/bin/env ruby
# frozen_string_literal: true
#
# syntax-mot - Motorola Syntax Target for SRB
# Copyright (C) 2017 Jeffrey Sharp
#
# SRB is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published
# by the Free Software Foundation, either version 3 of the License,
# or (at your option) any later version.
#
# SRB is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See
# the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with SRB.  If not, see <http://www.gnu.org/licenses/>.
#

module SRB
  using self

  class TopLevel
    def section name
    end
  end

  class Syntax
    MAX_PREC = 0xFFFF

    attr_accessor :eol

    attr_reader :col, :line

    def initialize(out = nil)
      @out  = out || $stdout
      @col  = 1
      @line = 1
      @eol  = "\n"
      @prec = MAX_PREC
    end

    protected

    def write(str)
      @out << str
      @col += str.length
      self
    end

    def newline!
      @out  << @eol
      @col   = 1
      @line += 1
      self
    end

    def newline
      newline! if @col > 1
    end

    def align(col)
      count = col - @col
      write ' ' * (count > 1 ? count : 1)
    end

    def write_lines(str)
      str.scan /\G([^\r\n]*+)(\r\n?|\n)?/ do |line, eol|
        break if !eol
        write line
        newline!
      end
      self
    end

    public

    def write_empty
      newline
      newline!
    end

    def write_unary(expr)
      write_grouped expr do |e|
        write e.op.to_s.chomp('@')
        e.expr.write(self)
      end
    end

    def write_binary(expr)
      write_grouped expr do |e|
        e.lhs.write(self)
        write ' '
        write e.op.to_s
        write ' '
        e.rhs.write(self)
      end
    end

    def write_grouped(expr)
      _prec = @prec
      @prec = prec(expr.op)
      group = @prec > _prec
      write '(' if group
      yield expr
      write ')' if group
    ensure
      @prec = _prec
    end

    def write_str(str)
      write '"'
      write escape_str(str)
      write '"'
    end

    def escape_str(str)
      str.gsub(/./m) do |c|
        case c.ord
        when 0x20..0x7E then c
        when 0x08 then '\b'
        when 0x09 then '\t'
        when 0x0A then '\n'
        when 0x0C then '\f'
        when 0x0D then '\r'
        when 0x22 then '\"'
        when 0x5C then '\\\\'
        else c.each_byte.reduce('') { |s, b| s << "\\#{b.to_s(8)}" }
        end
      end
    end
  end

  class MotorolaSyntax < Syntax
    MNEMONIC_COLUMN =  5
    OPERANDS_COLUMN = 13
    COMMENTS_COLUMN = 45

    LABEL_SUFFIX      = ':'
    IMMEDIATE_PREFIX  = '#'
    OPERAND_SEPARATOR = ', '

    PRECEDENCE = {}
    [
      %i[ -@ ~ !    ], # unary
      %i[ << >>     ], # bitwise shift
      %i[ &         ], # bitwise and
      %i[ ^         ], # bitwise xor
      %i[ |         ], # bitwise or
      %i[ * / %     ], # multiplicative
      %i[ + -       ], # additive
      %i[ < > <= >= ], # comparison
      %i[ == !=     ], # equality
      %i[ &&        ], # logical and
      %i[ ||        ], # logical or
    ]
    .each_with_index do |ops, prec|
      ops.each { |op| PRECEDENCE[op] = prec }
    end

    def prec(op)
      PRECEDENCE[op] || -1
    end

    # Formats an assembler symbol.
    #   scope: name of scope containing symbol; nil => top-level
    #   name:  name of symbol
    #   local: true  => make a local symbol
    #          false => make a normal symbol
    #          nil   => normal at top-level; local if in a subscope
    #
    def symbolize(scope, name, local=nil)
      raise 'symbolize: name is required' if name.nil?
      local = !!scope if local.nil?
      :"#{'.' if local}#{scope}#{'$' if scope}#{name}"
    end

    def write_sym(sym)
      write sym.to_s
    end

    def write_int(val)
      if val < 10
        write val.to_s
      else
        write '$'
        write '%X' % val
      end
    end

    def write_label(id)
      newline
      id.write(self)
      write LABEL_SUFFIX
      newline!
    end

    def write_global(sym)
      write_op :pseudo, :global, sym
    end

    def write_op(kind, op, *args)
      newline
      align MNEMONIC_COLUMN
      write op.to_s
      args.each_with_index do |arg, idx|
        write_arg arg, idx, kind
      end
      newline!
    end

    def write_arg(arg, idx, kind)
      if idx == 0
        align OPERANDS_COLUMN
      else
        write OPERAND_SEPARATOR
      end
      if kind.equal?(:i) && Expr === arg
        write IMMEDIATE_PREFIX
      end
      arg.write(self)
    end

    def write_reg(reg)
      write reg.name.to_s
    end

    def write_predec(reg)
      write '-('
      reg.write(self)
      write ')'
    end

    def write_postinc(reg)
      write '('
      reg.write(self)
      write ')+'
    end

    def write_ind(base, auto, disp, index)
      if disp && disp != 0
        disp.write(self)
      end
      write '-' if auto.equal?(:-)
      write '('
      base.write(self)
      if index
        write ', '
        index.write(self)
      end
      write ')'
      write '-' if auto.equal?(:+)
    end

    def write_index(index, scale)
      index.write(self)
      if scale != 1
        write '*'
        scale.write(self)
      end
    end
  end
end

