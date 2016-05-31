#
# This file is part of AEx.
# Copyright (C) 2015 Jeffrey Sharp
#
# AEx is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published
# by the Free Software Foundation, either version 3 of the License,
# or (at your option) any later version.
#
# AEx is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See
# the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with AEx.  If not, see <http://www.gnu.org/licenses/>.
#

module Aex
  refine Object do
    def to_term(ctx)
      raise "invalid assembly term: #{inspect}"
    end

    def to_symbol(ctx)
      raise "invalid assembly symbol: #{inspect}"
    end

    def to_asm
      to_s
    end
  end

  refine Proc do
    def to_term(ctx)
      call.to_term(ctx)
    end

    def to_symbol(ctx)
      call.to_symbol(ctx)
    end
  end

  refine Module do
    # Defines read-only accessor methods, corresponding instance variables,
    # and an initializer method that sets the instance variables.
    #
    def struct(*names)
      attr_reader *names

      class_eval <<-EOS
        def initialize(#{names.join(', ')})
          #{names.map { |n| "@#{n} = #{n}" }.join('; ')}
        end
      EOS
      nil
    end

    # Defines unary operators that produce assembler expressions.
    #
    def define_asm_unary_ops
      # Define operators
      define_method(:-@) { UnaryOp.new(:-, self) }
      define_method(:~ ) { UnaryOp.new(:~, self) }
      nil
    end

    # Defines binary operators that produce assembler expressions.
    #
    def define_asm_binary_ops
      # Returns true if +rhs+ can form a binary expression with the receiver.
      define_method(:binary_op_with?) do |rhs|
        case rhs
        when Numeric    then !self.is_a?(Numeric)
        when Symbol     then true
        when Expression then true
        end
      end

      # Define operators
      %i[* / % + - << >> & ^ | == != < <= > >= && ||]
      .each do |op|
        define_method(op) do |rhs|
          if binary_op_with?(rhs)
            BinaryOp.new(op, self, rhs)
          else
            super(rhs)
          end
        end
      end

      # Aliases to invoke && || operators, which Ruby cannot override.
      alias_method :and, :'&&'
      alias_method :or,  :'||'
      nil
    end
  end

  refine Fixnum do
    def to_term(ctx)
      Constant.new(self)
    end

    def to_asm
      self < 10 ? to_s : "0x#{to_s(16)}"
    end

    define_asm_binary_ops
  end

  refine Symbol do
    def to_term(ctx)
      Constant.new(to_symbol(ctx))
    end

    def to_symbol(ctx)
      local? ? ctx.local(self) : self
    end

    def local?
      to_s.start_with?('$', '@')
    end

    def end
      :"#{self}.end"
    end

    define_asm_unary_ops
    define_asm_binary_ops
  end

  refine String do
    def to_asm
      %{"#{
        gsub(/./m) do |c|
          case c.ord
          when 0x20..0x7E then c
          when 0x08 then '\b'
          when 0x09 then '\t'
          when 0x0A then '\n'
          when 0x0C then '\f'
          when 0x0D then '\n'
          when 0x22 then '\"'
          when 0x5C then '\\\\'
          else c.each_byte.reduce('') { |s, b| s << "\\#{b.to_s(8)}" }
          end
        end
      }"}
    end
  end
end

