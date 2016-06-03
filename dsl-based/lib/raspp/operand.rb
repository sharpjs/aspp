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

require_relative 'refinements'

module Raspp
  using self

  class Term
    def to_term(ctx)
      self
    end

    def for_inst
      raise "invalid assembly operand: #{inspect}"
    end
  end

  class Operand < Term
    def for_inst
      self
    end
  end

  class Register < Operand
    def to_term(ctx)
      #if ctx._reg_available?(self)
        self 
      #else
      #  raise "register not available in this context: #{self}"
      #end
    end
  end

  class Expression < Term
    define_asm_unary_ops
    define_asm_binary_ops
  end

  class Constant < Expression
    struct :expr

    def to_s
      @expr.to_asm
    end

    #def prec
    #  100
    #end
  end

  class UnaryOp < Expression
    struct :op, :expr

    def to_term(ctx)
      expr = @expr.to_term(ctx)
      expr.equal?(@expr) \
        ? self
        : self.class.new(op, expr)
    end

    def to_s
      "#{@op}#{@expr.to_asm}"
    end

    #def prec
    #  op.prec
    #end
  end

  class BinaryOp < Expression
    struct :op, :lhs, :rhs

    def to_term(ctx)
      lhs = @lhs.to_term(ctx)
      rhs = @rhs.to_term(ctx)
      lhs.equal?(@lhs) && rhs.equal?(@rhs) \
        ? self
        : self.class.new(op, lhs, rhs)
    end

    def to_s
      "(#{@lhs.to_asm} #{@op} #{@rhs.to_asm})"
    end

    #def prec
    #  op.prec
    #end
  end
end

