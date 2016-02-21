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
# FEATURES
#
# * Comments
#     ; foo   --> // foo
#
# * Function Labels
#     foo():  --> #declare SCOPE foo
#                 .fn SCOPE
#
# * Non-Function Labels
#     foo:    --> #declare SCOPE foo
#                 SCOPE:
#
# * Local Symbols
#     .bar    --> .L.SCOPE.bar
#
# * Local Token Aliases
#     foo => d0
#     foo     --> TOK(foo, d0)
#
# * Indirect Addressing
#     [x, y]  --> (x, y)
#     [--x]   --> -(x)
#     [x++]   --> (x)+
#

module Raspp
  def self.process(input, file = "(stdin)", line = 1)
    Preprocessor.new(file, line).process(input)
  end

  private

  # Identifiers
  ID0 = %r{ [[:alpha:]_]         }mx  # first char
  IDN = %r{ [[:alnum:]_$.]       }mx  # remaining chars
  ID_ = %r{ (?> #{ID0} #{IDN}* ) }mx  # identifier

  # Identifiers, allowing macro arguments inside
  ARG = %r{ \\ (?: #{ID_} | \(\) | @ ) }mx
  ID  = %r{ (?> (?: #{ID0} | #{ARG} ) (?: #{IDN} | #{ARG} )* ) }mx

  # Line begin/end
  BOL = %r{ (?<= \A | \A[\r\n] | \A\r\n | [^\\][\r\n] | [^\\]\r\n ) }mx
  EOL = %r{ \n | \r\n?+ }mx

  # Character classes
  WS  = %r{ [ \t]     | \\ #{EOL}   }mx # whitespace
  ANY = %r{ [^\r\n\\] | \\ #{EOL}?+ }mx # any except eol

  # Quoted chunks
  STR = %r{
    " (?: [^\\"] | \\ (?: [^\r\n] | #{EOL} | \z ) )*+ "?+
  }mx
  IND = %r{
    (?: [^\r\n\]\\";] | \\ #{EOL}?+ | #{STR} )++
  }mx

  # Main pattern
  EXPAND = %r{
      # verbatim text
      (?<skip> #{STR}                           # string literal
             | #{BOL} \# #{ANY}*+               # cpp directive
             | #{BOL} #{WS}* \. #{ID} (?![(:])  # asm directive at bol
             )
    |
      # end of line
      (?<eol>#{EOL})
    |
      # line comment
      (;|//) (?<comment>[^\r\n]*+)
    |
      # identifier
      (?<id>#{ID_}) (?![(:])
      # alias definition
      (?: #{WS} => #{WS} (?<def>#{ID}) )?+
    |
      # public label
      #{BOL} #{WS}* (?<label>#{ID}) (?<fn>\(\))?+ :
    |
      # local symbol
      \. (?!L) (?<local>#{ID})
    |
      # indirect addressing
      \[
        (?: (?<pre> [-+]) \k<pre>  )?+ (?<ind>#{IND})
        (?: (?<post>[-+]) \k<post> )?+
      \]
  }mx

  EXPAND_IND = %r{
      # verbatim text
      (?<skip>#{STR})
    |
      # identifier
      (?<id>#{ID_}) (?![(:])
      # alias definition
      (?: #{WS} => #{WS} (?<def>#{ID}) )?+
    |
      # local symbol
      \. (?!L) (?<local>#{ID})
  }mx

  class Preprocessor
    def initialize(file = "(stdin)", line = 1)
      @file, @line, @aliases, @script = file, line, {}, ''
    end

    def process(input)
      @scope = nil

      input.gsub!(EXPAND) do
        expand $~
      end

      print input
    end

    def expand(m)
      if (text = m[:skip])
        # Text protected from expansions
        text.scan(EOL) { @line += 1 }
        text
      elsif (text = m[:eol])
        # End of line
        @line += 1
        "\n"
      elsif (text = m[:comment])
        # Comment
        "//#{text}"
      elsif (text = m[:id])
        if (alt = m[:def])
          @scope and @scope[text] = alt
          alt
        else
          rep = (@scope and @scope[text] or text)
          if rep != text
            "T(#{text}, #{rep})"
          else
            text
          end
        end
      elsif (text = m[:label])
        # Function label
        @scope = Scope.new(text)
        fn = m[:fn]
        "\n// #{m}\n" +
        "#ifdef SCOPE\n" +
        "#undef SCOPE\n" +
        (fn ? "# #{@line} #{@file}\n" : "") +
        (fn ? ".endfn\n"            : "") +
        "#endif\n" +
        "\n" +
        "#define SCOPE #{text}\n" +
        "# #{@line} #{@file}\n" +
        (fn ? ".fn SCOPE\n" : "SCOPE:" )
      elsif (text = m[:local])
        # Local symbol
        @scope ? ".L.#{@scope.name}.#{text}" : ".L#{text}"
      elsif (text = m[:ind])
        "#{m[:pre]}(#{text})#{m[:post]}"
      end
    end
  end

  class Scope
    attr_reader :name, :parent

    def initialize(name, parent = nil)
      @name, @parent, @k2v, @v2k = name, parent, {}, {}
    end

    def subscope
      Scope.new(self)
    end

    def [](key)
      @k2v[key] || (@parent ? @parent[key] : key)
    end

    def []=(key, val)
      @v2k.delete(@k2v[key]) # Remove map: new key <- old val
      @k2v.delete(@v2k[val]) # Remove map: old key -> new val
      @k2v[key] = val
      @v2k[val] = key
    end
  end
end

if __FILE__ == $0
  # Running as script
  trap "PIPE", "SYSTEM_DEFAULT"
  loop do
    Raspp::process(ARGF.file.read, ARGF.filename)
    ARGF.skip
    break if ARGV.empty?
  end
end

