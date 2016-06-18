#!/usr/bin/env ruby
# encoding: UTF-8
# frozen_string_literal: true
#
# vasmpp - A Preprocessor for VASM
# Copyright (C) 2016 Jeffrey Sharp
#
# vasmpp is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published
# by the Free Software Foundation, either version 3 of the License,
# or (at your option) any later version.
#
# vasmpp is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See
# the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with vasmpp.  If not, see <http://www.gnu.org/licenses/>.
#
# FEATURES
#
# - Line continuation
#
#     all  \          => all one line
#       one line    
#
# - Number Rewrite
# 
#     0x => $
#     0o => @
#     0b => %
# 
# - Addressing mode rewrite
# 
#     [ => (
#     ] => )
#     prepend # unless
#               - arg starts with ( or [
#               - arg is special name (e.g. register)
#               - op is not an instruction
#
# - Inline Ruby code
#
#     `code`
#
# - Preprocessor directive
# 
#     #foo bar baz    => pp.foo("bar baz")
# 
#     #foo bar baz    => pp.foo("bar baz", "qux\nzot")
#         qux
#         zot
#     #end
# 
# - Expression aliases
# 
#     alias@original       (reset after every non-local label)
#
# - Inline macros
#
#     FOO(x, y)
#
# - Directive macros
#
#     foo x, y
# 
# Tokens
# - whitespace    [ \t]
# - quotations    `..` '..' ".."
# - identifiers   abcd
# - numbers       0x1234
# - comma         ,
# - [ ] ( )       [ ] ( )
# - # (at bol)    #
# - @             #
# - other
# - eol           \n
#
# Process
# - Lines assembled into logical lines
# - Pass line to handler
#
# Regular handler
# - Process as directive if % symbol, else continue
# - Replace inline ruby
# - Replace inline macros and aliases
# - Replace statement-like macro
# - Character replacements
# - Auto-immediate
#

module Vasmpp
  class Processor
    def initialize(output)
      @output = output
      @inputs = []
      @states = []
      begin_line
    end

    def process(input, name = "(stdin)")
      @inputs.push(Input.new(input, name))
      @states.push(NORMAL)

      loop do
        input = @inputs.last
        state = @states.last
        break unless state.dispatch(input, self)
      end
    end

    private

    def on_id(m)
      @text << m[0]
      :continue
    end

    def on_num(m)
      @text << m[0]
      :continue
    end

    def on_other(m)
      @text << m[0]
      :continue
    end

    def on_at(m)
      @text << m[0]
      :continue
    end

    def on_bq(m)
      @ruby = ''.dup
      @states.push(RUBY)
      :continue
    end

    def on_sq(m)
      @text << m[0]
      :continue
    end

    def on_enter(m)
      @text << m[0]
      :continue
    end

    def on_leave(m)
      @text << m[0]
      :continue
    end

    def on_comment(m)
      # ignore
      :continue
    end

    def on_escape(m)
      @text << m[0]
      :continue
    end

    # Quoted Strings

    def on_string_begin(m)
      @text << m[:ws]
      @string = ''.dup
      @states.push STRING
    end

    def on_string_text(m)
      @string << m[0]
    end

    def on_string_escape(m)
      if m[:eol]
        @height += 1
      else
        on_string_text(m)
      end
    end

    def on_string_eol(m)
      raise "Unterminated string"
    end

    def on_string_end(m)
      @text << @string.inspect
      @string = nil
      @states.pop
    end

    # Quoted Characters

    def on_bq_end(m)
      ruby  = @ruby
      @ruby = nil
      @states.pop
      @text << eval(ruby, TOPLEVEL_BINDING).to_s
      nil
    end

    def on_sq_end(m)
      @text << m[0]
      nil
    end

    def on_sq_esc(m)
      @text << m[0]
      :continue
    end

    # Quoted Ruby

    def on_ruby_text(m)
      @ruby << m[0]
      :continue
    end

    def on_eol(m)
      # expand instruction-like macros here
      # else...
      @output.puts @text
      @inputs.last.eol(@height)
      begin_line
      :continue
    end

    def begin_line
      @text   = "".dup
      @height = 1
    end
  end

  private

  # ----------------------------------------------------------------------------

  class State
    def initialize(pattern, index, default, **actions)
      @pattern = pattern
      @index   = index
      @actions = Hash.new(default).tap do |h|
        actions.each do |name, chars|
          chars.each { |c| h[c] = name }
        end
      end
    end

    def dispatch(input, target)
      input.match(@pattern) do |match|
        token  = match[@index]
        action = @actions[token[0]]
        $stderr.puts "#{token.inspect} -> #{action}"
        target.send(action, match)
      end
    end
  end

  # Whitespace
  WS  = / [ \t]       /x
  EOL = / \n | \r\n?+ /x

  NORMAL = State.new \
    %r{
      \G (?!\z)
      (?<ws>  #{WS}*+ )
      (?<tok> #{EOL}                            (?# end of line  )
            | (?> \b (?!\d) [\w.]++ \$?+ )      (?# identifier   )
            | (?> \d (?: [\w.] | [eE][+-] )*+ ) (?# number       )
            | [@`'"\[\](){}]                    (?# punctuator   )
            | ; [^\r\n]*+                       (?# comment      )
            | \\ (?: #{EOL} #{WS}*+ )?+         (?# espaced eol  )
            | [^ \t\r\n\w.@`'"\[\](){}\\;]++    (?# other        )
      )
    }x,
    :tok, :on_other,
    {
      on_id:       [*?a..?z, *?A..?Z, ?_, ?.],
      on_num:      [*?0..?9],
      on_at:       %W| @     |,
      on_bq:       %W| `     |,
      on_sq:       %W| '     |,
      on_string_begin:       %W| "     |,
      on_enter:    %W| [ ( { |,
      on_leave:    %W| ] ) } |,
      on_comment:  %W| ;     |,
      on_escape:   %W| \\    |,
      on_eol:      %W| \r \n |,
    }

  RUBY = State.new \
    %r{
      \G (?!\z)
      (?: [^`\r\n]++
        | ` (`)?+
        | #{EOL}
      )
    }x,
    0, :on_ruby_text,
    {
      on_bq_end:   %W| `     |,
      on_eol:      %W| \r \n |,
    }

  CHAR = State.new \
    %r{
      \G (?!\z)
      (?: [^`'\\\r\n]++
        | [`']
        | \\ (?: (?<eol> #{EOL} #{WS}*+ ) | . )?+
        | #{EOL}
      )
    }x,
    0, :on_char_text,
    {
      on_bq:       %W| `     |,
      on_sq_end:   %W| "     |,
      on_sq_esc:   %W| \\    |,
      on_eol:      %W| \r \n |,
    }

  STRING = State.new \
    %r{
      \G (?!\z)
      (?: [^`"\\\r\n]++
        | [`"]
        | \\ (?: (?<eol> #{EOL} #{WS}*+ ) | . )?+
        | #{EOL}
      )
    }x,
    0, :on_string_text,
    {
      on_bq:       %W| `     |,
      on_string_end:   %W| "     |,
      on_string_escape:   %W| \\    |,
      on_eol:      %W| \r \n |,
    }


  # ----------------------------------------------------------------------------

  class Scanner
    attr_accessor :pos

    def initialize(input)
      @input = input
      @pos   = 0
    end

    def match(pattern)
      match = pattern.match(@input, @pos)
      if match
        @pos = match.end(0)
        yield match
        true
      end
    end
  end

  # ----------------------------------------------------------------------------

  class Input < Scanner
    attr_reader :name, :line, :parent

    def initialize(input, name, parent = nil)
      super(input)
      @name   = name
      @line   = 1
      @parent = parent
    end

    def eol(n = 1)
      @line += n
    end
  end
end # Vasmpp

if __FILE__ == $0
  # Running as script
  trap "PIPE", "SYSTEM_DEFAULT"
  processor = Vasmpp::Processor.new($stdout)
  loop do
    processor.process(ARGF.file.read, ARGF.filename)
    ARGF.skip
    break if ARGV.empty?
  end
end

