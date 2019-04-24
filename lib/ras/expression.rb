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
  module Operators
    # Unary operators
    %i[ -@ ~@ ].each do |op|
      define_method(op) { UnaryOp(op, self) }
    end

    # Binary operators
    %i[ * / % + - << >> & ^ | == != < <= > >= && || ].each do |op|
      define_method(op) { |rhs| BinaryOp(op, self, rhs) }
    end

    # Aliases to invoke && || operators, which Ruby cannot override.
    alias_method :and, :'&&'
    alias_method :or,  :'||'
  end

  class Expression
    include Operators
    #resolve(ctx) => Integer|Relocation
  end

  class Constant < Expression
    attr_reader :value

    def initialize(val)
      @value = val
    end

    def resolve(ctx)
      value
    end
  end

  class UnaryOp < Expression
    attr_reader :op, :expr

    def initialize(op, expr)
      @op   = op
      @expr = expr
    end

    def resolve(ctx)
      expr = expr.resolve(ctx)
      expr.send(op)
    end
  end

  class BinaryOp < Expression
    attr_reader :op, :lhs, :rhs

    def initialize(op, lhs, rhs)
      @op  = op
      @lhs = lhs
      @rhs = rhs
    end

    def resolve(ctx)
      lhs = lhs.resolve(ctx)
      rhs = rhs.resolve(ctx)
      lhs.send(op, rhs)
    end
  end

  class Relocation
    # Equivalent to SHT_RELA in ELF
    attr_reader :offset, :symbol, :type, :addend
  end
end

