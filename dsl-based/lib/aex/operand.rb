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

require_relative 'refinements'

module Aex
  using self

  module Term
    def to_term(ctx)
      self
    end

    def for_inst
      raise "invalid assembly operand: #{inspect}"
    end
  end

  module Operand
    include Term

    def for_inst
      self
    end
  end

  module Register
    include Operand

    def to_term(ctx)
      if ctx._reg_available?(self)
        self 
      else
        raise "register not available in this context: #{self}"
      end
    end
  end

  module ReadOnly end

  class Expression
    include ReadOnly, Term
    define_asm_unary_ops
    define_asm_binary_ops
  end

  class Constant < Expression
    struct :expr

    def to_s
      @expr.to_asm
    end
  end

  class UnaryOp < Expression
    struct :op, :expr

    def to_term(ctx)
      (expr = @expr.to_term(ctx)).equal?(@expr) \
        ? self
        : self.class.new(op, expr)
    end

    def to_s
      "#{@op}#{@expr.to_asm}"
    end
  end

  class BinaryOp < Expression
    struct :op, :lhs, :rhs

    def to_term(ctx)
      (lhs = @lhs.to_term(ctx)).equal?(@lhs) &
      (rhs = @rhs.to_term(ctx)).equal?(@rhs) \
        ? self
        : self.class.new(op, lhs, rhs)
    end

    def to_s
      "(#{@lhs.to_asm} #{@op} #{@rhs.to_asm})"
    end
  end
end

