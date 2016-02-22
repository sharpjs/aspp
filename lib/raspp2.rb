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
             | #{BOL} #{WS}* \.? #{ID} (?![(:]) # asm directive at bol
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
      # address begin
      (?<ea_begin>\[) (?: (?<pre>[-+]) \k<pre> )?+
    |
      # address end
      (?: (?<post>[-+]) \k<post> )?+ (?<ea_end>\])
  }mx

  # Expansion in indirect addressing ([...])
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

  KINDS = %i[ skip eol comment id label local ea_begin ea_end ]

  class Preprocessor
    def initialize(file = "(stdin)", line = 1)
      @file, @line, @scope = file, line, Scope.new(nil)
      @root = @scope
    end

    def process(input)
      $stdout << input.gsub(EXPAND) do |text|
        kind = KINDS.find { |h| text = $~[h] }
        if kind
          send(:"on_#{kind}", text, $~)
        else
          text
        end
      end
    end

    # Text exempt from expansion
    def on_skip(text, _)
      # Text might have internal newlines, possibly escaped.
      # Count these newlines to keep line numbers in sync.
      text.scan(EOL) { @line += 1 }
    end

    # End of line
    def on_eol(_, _)
      # Normalize to LF, keep line numbers in sync.
      @line += 1
      "\n"
    end

    # Comment
    def on_comment(text, match)
      # Normalize to C++ line comments
      "//#{text}"
    end

    # Identifier
    def on_id(id, match)
      if not (real = match[:def]).nil?
        # Alias definition
        @scope[id] = real
      elsif not (real = @scope[id]) == id
        # Alias reference
        "ALIAS(#{id}, #{real})"
      else
        # Plain identifier
        id
      end
    end

    # Label, static or global
    def on_label(text, match)
      # Start a new local scope
      @scope = @root.subscope(text)

      # Detect if this is a function label
      fn = !!match[:fn]

      # Redefine scope with CPP, possibly start function with asm macro
      <<~END
        // #{match}
        #ifdef SCOPE
        #undef SCOPE
        #endif
        #define SCOPE #{text}
        # #{@line} #{@file}
        #{fn ? ".fn SCOPE" : "SCOPE:"}
      END
    end

    # Local symbol
    def on_local(text, match)
      if @scope.name
        ".L.#{@scope.name}.#{text}"
      else
        ".L#{text}"
      end
    end

    # Effective Address Begin
    def on_ea_begin(text, match)
      "#{match[:pre]}("
    end

    # Effective Address End
    def on_ea_end(text, match)
      ")#{match[:post]}"
    end
  end

  class Scope
    attr_reader :name, :parent

    def initialize(name, parent = nil)
      @name, @parent, @k2v, @v2k = name, parent, {}, {}
    end

    def subscope(name)
      Scope.new(name, self)
    end

    def [](key)
      @k2v[key] || (@parent ? @parent[key] : key)
    end

    def []=(key, val)
      @v2k.delete(@k2v[key]) # Remove map: new key <- old val
      @k2v.delete(@v2k[val]) # Remove map: old key -> new val
      @k2v[key] = val
      @v2k[val] = key
      val
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

