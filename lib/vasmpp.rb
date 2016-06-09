#!/usr/bin/env ruby
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
#  Ruby Code
#
#     `code`      inline;       replaced with value.to_s
#
#     @code       single-line;  replaced with empty line
#
#     @{          multi-line;   replaced with empty lines
#       code
#     @}
#
# - Aliases
#
#     foo@bar     replace 'foo' with 'bar' until:
#                 - non-local label,
#                 - foo redefined, or
#                 - bar realiased
#

module Vasmpp
  class Processor
    def process(input, name = "(stdin)")
      @aliases = @aliases&.clear || Aliases.new
      @name    = name
      @line    = 1
      @height  = 1

      input.scan(TOKENS) do
        case $&[0]
        when ?@
          if (ruby = $~[:ruby])
            eval ruby
          else
            print $&
          end
        when ?`
          print eval(ruby).to_s
        when ?\s, ?\t
          if $~[:opcode] && !local?($~[:label])
            @aliases.clear
          end
          print $&
        when ?\n
          @line += @height
          print ?\n * @height
          @height = 1
        else
          if (label = $~[:label]) && !local?(label)
            @aliases.clear
            print $&
          else
            print (not id = $~[:id]) ? $&
                : (not as = $~[:as]) ? @aliases[id]
                :                      @aliases[id] = as
          end
        end
      end
      self
    end

    private

    WS   = '[ \t]*+'
    WS1  = '[ \t]++'
    ID   = '(?> (?!\d) [\w.]++ \$?+ )'
    LINE = '.*+'
    ANY  = '(?m:.*?)'

    TOKENS = %r{
      \G
      (?: ^@ruby (?<ruby>\n.*?  ) ^@end$
        | ^@     (?<ruby>[^\n]*+)
        | ^       (?<label>#{ID})              :?+ #{WS} (?:           #{ID}  #{WS} )?+
        | ^#{WS1} (?<label>#{ID}) (?: #{WS1} | :   #{WS} (?: (?<opcode>#{ID}) #{WS} )?+ )?+
        | (?<id>#{ID}) (?: #{WS} @ #{WS} (?<as>#{ID}) )?+
        | ` (?<ruby>[^`]*+) `?+
        | (?: [^`$@%\w.\n] | [$@%\d] (?: [\w.] | [eE][+-] )*+ )++
        | .
      )
    }mx

    #OPERANDS = %r{
    #  (?: ^ (?: (#{ID}) :?+ )?+ #{WS}
    #        (?: (#{ID}) #{WS} )?+
    #    | \G, #{WS}
    #  )
    #  (
    #    (?<code> [^\[\]\(\)\{\}'",]
    #           | \[ (?: , | \g<code>   )*+ \]
    #           | \( (?: , | \g<code>   )*+ \)
    #           | \{ (?: , | \g<code>   )*+ \}
    #           | '  (?: [^'\\] | \\.?+ )*+ '?+
    #           | "  (?: [^"\\] | \\.?+ )*+ "?+
    #    )++
    #  )
    #}x

    def local?(label)
      label.start_with?(".")
    end

    def eval(ruby)
      @height += ruby.count(?\n)
      ::Kernel.eval(ruby, TOPLEVEL_BINDING, @name, @line)
    end
  end

  private

  class Aliases
    def initialize
      @k2v = {}
      @v2k = {}
    end

    def clear
      @k2v.clear
      @v2k.clear
    end

    def [](key)
      @k2v[key] || key
    end

    def []=(key, val)
      @v2k.delete(@k2v[key]) # Remove map: new key <- old val
      @k2v.delete(@v2k[val]) # Remove map: old key -> new val
      @k2v[key] = val
      @v2k[val] = key
      val
    end
  end
end # Vasmpp

if __FILE__ == $0
  # Running as script
  trap "PIPE", "SYSTEM_DEFAULT"
  processor = Vasmpp::Processor.new
  loop do
    processor.process(ARGF.file.read)
    ARGF.skip
    break if ARGV.empty?
  end
end

