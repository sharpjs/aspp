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

require_relative '../../refinements'
require_relative '../../operand'
require_relative '../../context'

module Aex
  using self

  class Function < Context
    SAVEABLE_REGS = [*DATA_REGS, *ADDR_REGS].freeze
    MOVE_OPS = { 1 => :moveb, 2 => :movew, 4 => :movel }

    attr_reader :_name, :_frame_reg, :_frame_disp, :_regs_used, :_regs_saved,
      :_regs_offset, :_vars_offset, :_args_offset, :_args_length

    def initialize(parent, name)
      super(parent, name, parent._out_stream)
      @_name        = name.freeze
      @_frame_reg   = sp  # frame pointer register
      @_frame_disp  = 0   # offset of frame from frame pointer  (+, 0 if fp used)
      @_regs_offset = 0   # offset of register 0 from variables (-)
      @_vars_offset = 0   # offset of variable 0 from frame     (-)
      @_args_offset = 4   # offset of argument 0 from frame     (+)
      @_args_length = 0   # length of arguments in bytes
      @_regs_used   = {}  # registers available for use
      @_regs_saved  = nil # registers to be saved/restored (!nil => entered)
      @_on_enter    = []  # procs to run on enter
      use! sp
    end

    def define(&body)
      raise "function already defined: #{@_name}" if @_defined
      @_defined = true
      sym = at @_name
      instance_exec &body
      sym
    end

    def argb(name = nil, reg = nil) arg(1, 3, name, reg) end
    def argw(name = nil, reg = nil) arg(2, 2, name, reg) end
    def argl(name = nil, reg = nil) arg(4, 0, name, reg) end

    def arg(size, disp, name = nil, reg = nil)
      require_not_entered
      offset = @_args_length + disp
      -> { AddrDisp.new(@_frame_reg, @_frame_disp + @_args_offset + offset) }
      .tap do |arg|
        if name
          instance_variable_set(:"@#{name}", arg)
          if reg
            op = MOVE_OPS[size] or raise "cannot enregister arg of size #{size}"
            use reg
            define_singleton_method(name) { reg }
            @_on_enter << -> { send op, arg, reg }
          end
        end
        @_args_length += (disp + size + 3) & ~3 # pad to long-sized
      end
    end

    def varb(name = nil) var(1, 3, name) end
    def varw(name = nil) var(2, 2, name) end
    def varl(name = nil) var(4, 0, name) end

    def var(size, disp, name = nil)
      require_not_entered
      offset = -@_vars_offset + disp
      -> { AddrDisp.new(@_frame_reg, @_frame_disp + @_vars_offset + offset) }
      .tap do |var|
        instance_variable_set(:"@#{name}", var) if name
        @_vars_offset -= (disp + size + 3) & ~3 # pad to long-sized
      end
    end

    def use(*regs)
      require_not_entered
      regs.flat_map do |x|
        Range === x ? x.to_a : x
      end
      .each do |reg|
        unless @_regs_used.key?(reg)
          @_regs_used[reg] = true # to be saved on enter
          @_regs_offset -= 4
        end
      end
      .unwrap
    end

    def use!(*regs)
      require_not_entered
      regs.flat_map do |x|
        Range === x ? x.to_a : x
      end
      .each do |reg|
        @_regs_used[reg] = false # used but not saved on enter
      end
      .unwrap
    end

    def out(*regs)
      use! *regs
    end

    def _reg_available?(reg)
      case reg
      when DataReg, AddrReg
        @_regs_used.key?(reg)
      else
        true
      end
    end

    def linkw(reg, disp = 0)
      use! reg
      super(reg, @_vars_offset + disp)
      @_args_offset += @_frame_disp + 4
      @_frame_reg    = reg
      @_frame_disp   = 0
    end

    def entered?
      !!@_regs_saved
    end

    def _regs_saved
      @_regs_saved ||= SAVEABLE_REGS.reduce([]) do |a, r|
        @_regs_used[r] ? a << r : a
      end
    end

    def require_not_entered
      raise "frame is frozen" if entered?
    end

    def enter
      raise "must be provided by derived class"
    end

    def leave
      raise "leave without enter"
    end

    def _on_enter
      @_on_enter.each { |p| p.call }
    end
  end

  class AppFunction < Function
    def define(&body)
      align
      use! d0, d1, a0, a1
      super(&body)
    end

    def enter
      linkw fp
      count = _regs_saved.length
      if count > 2
        lea [sp, _regs_offset], sp
        moveml regs(*_regs_saved), [sp]
      elsif count > 0
        push *_regs_saved
      end
      _on_enter
    end

    def leave
      count = _regs_saved.length
      if count > 1
        moveml [fp, _regs_offset + _vars_offset], regs(*_regs_saved)
      elsif count > 0
        movel [fp, _regs_offset + _vars_offset], _regs_saved[0]
      end
      unlk fp
    end
  end

  class LibcFunction < Function
    def define(&body)
      align
      use! d0, d1, a0, a1
      super(&body)
    end

    def enter
      if _vars_offset != 0
        linkw fp
      else
        @_frame_disp -= _regs_offset
      end

      count = _regs_saved.length
      if count > 2
        lea [sp, _regs_offset], sp
        moveml regs(*_regs_saved), [sp]
      elsif count > 0
        push *_regs_saved
      end
      _on_enter
    end

    def leave
      count = _regs_saved.length
      if count > 2
        moveml [sp], regs(*_regs_saved)
        lea [sp, -_regs_offset], sp
      elsif count > 0
        pop *_regs_saved
      end

      if _vars_offset != 0
        unlk fp
      else
        @_frame_disp += _regs_offset
      end
    end
  end

  class SimpleFunction < Function
    def define(&body)
      use! d0, d1, a0, a1
      super(&body)
    end

    def enter
      if _vars_offset != 0
        lea [sp, _vars_offset], sp
      end
      if _regs_saved.length > 0
        push *_regs_saved
      end
      @_frame_disp -= _vars_offset + _regs_offset
      _on_enter
    end

    def leave
      @_frame_disp += _vars_offset + _regs_offset
      if _regs_saved.length > 0
        pop *_regs_saved
      end
      if _vars_offset != 0
        lea [sp, -_vars_offset], sp
      end
    end
  end
end

