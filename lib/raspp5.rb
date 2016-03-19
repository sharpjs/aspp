#!/usr/bin/env ruby
# encoding: UTF-8
# frozen_string_literal: true
#
# raspp - Assembly Preprocessor in Ruby
# Copyright (C) 2016 Jeffrey Sharp
#
# raspp is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published
# by the Free Software Foundation, either version 3 of the License,
# or (at your option) any later version.
#
# raspp is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See
# the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with raspp.  If not, see <http://www.gnu.org/licenses/>.
#

module Raspp
  # ----------------------------------------------------------------------------
  # Refinements

  refine Object do
    def to_term(ctx)
      raise "invalid assembly term: #{inspect}"
    end

    def to_symbol(ctx)
      raise "invalid assembly symbol: #{inspect}"
    end

    def to_asm
      raise "cannot format for assembly: #{inspect}"
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
      :"#{self}$end"
    end

    def to_asm
      to_s
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
          else c.each_byte.reduce(''.dup) { |s, b| s << "\\#{b.to_s(8)}" }
          end
        end
      }"}
    end
  end

  # ----------------------------------------------------------------------------
  # Target-Specific Refinements

  refine Array do
    def to_term(ctx)
      case length
      when 0
        nil
      when 1
        case addr = self[0].to_term(ctx)
        when Expression then Absolute32.new(addr)
        when AddrReg    then AddrInd   .new(addr)
        when AddrRegDec then AddrIndDec.new(addr)
        when AddrRegInc then AddrIndInc.new(addr)
        end
      when 2
        case base = self[0].to_term(ctx)
        when AddrReg
          case x = self[1].to_term(ctx)
          when Expression  then AddrDisp .new(base, x)
          when Index       then AddrIndex.new(base, 0, x, 1)
          when ScaledIndex then AddrIndex.new(base, 0, x.index, x.scale)
          end
        when ctx.pc
          case x = self[1].to_term(ctx)
          when Expression  then PcDisp .new(x)
          when Index       then PcIndex.new(0, x, 1)
          when ScaledIndex then PcIndex.new(0, x.index, x.scale)
          end
        end
      when 3, 4
        disp = self[1].to_term(ctx) and Expression === disp and
        begin
          case index = self[2].to_term(ctx)
          when Index
            scale = self[3] || 1
          when ScaledIndex
            scale = index.scale
            index = index.index.to_term(ctx) \
              and Index === index and self[3].nil?
          end
        end and
        SCALES.include?(scale) and
        begin
          case base = self[0].to_term(ctx)
          when AddrReg then AddrIndex.new(base, disp.expr, index, scale)
          when ctx.pc  then PcIndex  .new(      disp.expr, index, scale)
          end
        end
      end.freeze or
        raise "invalid addressing mode: [#{join(', ')}]"
    end

    def w
      Near.new(self[0])
    end

    def l
      Far.new(self[0])
    end

    def unwrap
      length > 1 ? self : self[0]
    end
  end

  # ----------------------------------------------------------------------------
  # Generic Classes

  # Apply refinements
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

  # ----------------------------------------------------------------------------

  class Context
    attr_reader :_parent, :_local_prefix, :_local_index, :_out_stream

    def initialize(parent = nil, name = nil, out = nil)
      @_parent       = parent
      @_local_prefix = parent ? "#{parent.local(name)}$" : ".L$"
      @_local_index  = 0
      #@_out_stream   = out || parent && parent._out_stream || $stdout
    end

    def eval(text, filename, lineno = 1)
      context = self
      proxy   = Object.new

      proxy.define_singleton_method(:method_missing) do
        |sym, *args, &block|
        context.public_send(sym, *args, &block)
      end

      proxy.define_singleton_method(:respond_to_missing?) do
        |sym, all|
        context.respond_to?(sym, all)
      end

      proxy.instance_eval(text, filename, lineno)
      self
    end

    def note(text)
      puts <<~END
        /*
         * #{text.gsub("\n", "\n * ")}
         */
      END
    end

    def set(dst, src)
      putd "move.l",
        src.to_term(self).for_inst,
        dst.to_term(self).for_inst
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

    private

    def putd(op, *args)
      args.compact!
      args.map! { |a| a.to_term(self).for_inst.to_asm }
      print ?\t, op
      print ?\t, args.join(', ') unless args.empty?
      puts
    end

#    def method_missing(sym, *args, &block)
#      @_parent ? @_parent.send(sym, *args, &block) : super
#    end
#
#    def respond_to_missing?(sym, all)
#      @_parent && @_parent.respond_to?(sym, all)
#    end
#
#    def printf (*args) @_out_stream.printf *args end
#    def print  (*args) @_out_stream.print  *args end
#    def puts   (*args) @_out_stream.puts   *args end
#    def putc   (*args) @_out_stream.putc   *args end
#
#    def equ (sym, val) dir :".equ", sym, val; sym end
#    def eqv (sym, val) dir :".eqv", sym, val; sym end
#    def set (sym, val) dir :".set", sym, val; sym end
#
#    ##
#    # Defines a label.
#    #
#    # If +sym+ is given, it is used as the label name.
#    # Otherwise, a unique local label is generated.
#    #
#    # If a block is given, this method defines a code block
#    # with both start and end labels.
#    #
#    def at(sym = nil)
#      sym = sym ? sym.to_symbol(self) : local
#      puts "#{sym}:"
#      if block_given?
#        yield block = Block.new(sym)
#        puts "#{block.end}:" if block.end_used?
#      end
#      sym
#    end
#
#    def global(sym)
#      sym = sym.to_symbol(self)
#      puts ".global #{sym}"
#      sym
#    end

#    def skip(count, fill = nil)
#      dir :".skip", count, fill
#    end
#
#    def skip_to(offset, fill = nil)
#      dir :".org", offset, fill
#    end
#
#    def incbin(path, start, len)
#      dir :".incbin", path, start, len
#    end
#
#    [:byte, :word, :long].each do |type|
#      define_method type do |*values|
#        values = [0] if values.empty?
#        values.map! { |v| v.to_asm }
#        puts "\t.#{type}\t#{values.join(', ')}"
#      end
#    end
#
#    [:ascii, :string].each do |type|
#      define_method type do |*values|
#        unless values.empty?
#          values.map! { |v| v.to_s.to_asm }
#          puts "\t.#{type}\t#{values.join(', ')}"
#        end
#      end
#    end
#
#    def struct(sym = nil)
#      addr 0
#      yield if block_given?
#    end
#
#    # Writes a directive
#    def dir(op, *args)
#      args.compact!
#      args.map! { |a| a.to_asm }
#      puts args.empty? \
#        ? "\t#{op}"
#        : "\t#{op}\t#{args.join(', ')}"
#    end
  end

  class TopLevel < Context
  end

  # ----------------------------------------------------------------------------
  # Target-Specific Things

  module Term
    def for_jump
      for_inst
    end

    def to_asm
      to_s
    end
  end

  class Expression
    def for_inst
      Immediate.new(self)
    end

    def for_jump
      Absolute32.new(self)
    end
  end

  # Immediate

  Immediate = Struct.new :expr do
    include ReadOnly, Operand

    def to_s
      "##{expr}"
    end
  end

  # Absolute

  module Absolute; end

  Absolute16 = Struct.new :addr do
    include Absolute, Operand

    def to_s
      "#{addr}:w"
    end
  end

  Absolute32 = Struct.new :addr do
    include Absolute, Operand

    def to_s
      "#{addr}:l"
    end
  end

  # Register

  module Register
    def to_s
      "%#{reg}"
    end
  end

  module Index
    def *(scale)
      ScaledIndex.new(self, scale)
    end
  end

  module Numbered
    def <=>(that)
      self.class === that &&
      number <=> that.number
    end

    def succ
      self.class.all[number + 1]
    end

    alias next succ
  end

  module Listable
    def -(reg)
      RegList.new(["#{self}-#{reg}"])
    end

    def |(reg)
      RegList.new([self]) | reg
    end
  end

  class DataReg
    include Numbered, Listable, Index, Register, Operand
    struct :reg, :number

    def self.all
      Context::DATA_REGS
    end
  end

  class AddrReg
    include Numbered, Listable, Index, Register, Operand
    struct :reg, :number

    def self.all
      Context::ADDR_REGS
    end

    def -@
      AddrRegDec.new reg
    end

    def +@
      AddrRegInc.new reg
    end
  end

  AddrRegDec = Struct.new :reg do
    include Register, Term
  end

  AddrRegInc = Struct.new :reg do
    include Register, Term
  end

  AuxReg = Struct.new :reg do
    include Register, Operand
  end

  CtlReg = Struct.new :reg do
    include Register, Operand
  end

  RegList = Struct.new :regs do
    include Operand

    def to_s
      "#{regs.join("/")}"
    end

    def |(reg)
      regs << reg; self
    end
  end

  # Indirect

  module Indirect  end
  module Displaced end
  module Indexed   end

  SCALES = [1, 2, 4]

  ScaledIndex = Struct.new :index, :scale do
    include Term

    def to_s
      "#{index}*#{scale}"
    end
  end

  AddrInd = Struct.new :reg do
    include Indirect, Operand

    def to_s
      "#{reg}@"
    end
  end

  AddrIndInc = Struct.new :reg do
    include Indirect, Operand

    def to_s
      "#{reg}@+"
    end
  end

  AddrIndDec = Struct.new :reg do
    include Indirect, Operand

    def to_s
      "#{reg}@-"
    end
  end

  AddrDisp = Struct.new :base, :disp do
    include Displaced, Indirect, Operand

    def to_s
      "#{base}@(#{disp})"
    end
  end

  AddrIndex = Struct.new :base, :disp, :index, :scale do
    include Indexed, Displaced, Indirect, Operand

    def to_s
      "#{base}@(#{disp}, #{index}*#{scale})"
    end
  end

  PcDisp = Struct.new :disp do
    include ReadOnly, Displaced, Indirect, Operand

    def to_s
      "%pc@(#{disp})"
    end
  end

  PcIndex = Struct.new :disp, :index, :scale do
    include ReadOnly, Indexed, Displaced, Indirect, Operand

    def to_s
      "%pc@(#{disp}, #{index}*#{scale})"
    end
  end

  class Reference
    struct :addr

    def to_term(ctx)
      addr = self.addr.to_term(ctx)
      unless addr.is_a?(Expression)
        raise "invalid absolute reference: #{self}"
      end
      term_type.new(addr)
    end

    def to_s
      "[#{addr.to_asm}].#{suffix}"
    end
  end

  class Near < Reference
    def term_type ; Absolute16 ; end
    def suffix    ; :w         ; end
  end

  class Far < Reference
    def term_type ; Absolute32 ; end
    def suffix    ; :l         ; end
  end
end # Raspp

if __FILE__ == $0
  # Running as script
  trap "PIPE", "SYSTEM_DEFAULT"
  top_level = Raspp::TopLevel.new
  loop do
    top_level.eval(ARGF.file.read, ARGF.filename)
    ARGF.skip
    break if ARGV.empty?
  end
end

