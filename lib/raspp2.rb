#!/usr/bin/env ruby
# encoding: UTF-8
# frozen_string_literal: true
#
# raspp.rb - Assembly Preprocessor in Ruby
# Copyright (C) 2016 Jeffrey Sharp
#
# FEATURES:
#
# Comments
#   ; foo   --> // foo
#
# Function Labels
#   foo():  --> #declare SCOPE foo
#               .fn SCOPE
#
# Non-Function Labels
#   foo:    --> #declare SCOPE foo
#               SCOPE:
#
# Local Symbols
#   .bar    --> .L.SCOPE.bar
#
# Local Token Aliases
#   foo => d0
#   foo     --> TOK(foo, d0)
#
# Special Symbol Aliases
#   $foo    --> ARG(foo)
#   @bar    --> VAR(bar)
#
# Bracket Replacement
#   [x, y]  --> (x, y)
#   [--x]   --> -(x)
#   [x++]   --> (x)+
#

module Raspp
  def self.process(input, file = "(stdin)", line = 1)
    scope = nil

    input.gsub!(MACROS) do
      p $~
      if (text = $~[:skip])
        # Text protected from expansions
        text.scan(EOL) { line += 1 }
        text
      elsif (text = $~[:eol])
        # End of line
        line += 1
        "\n"
      elsif (text = $~[:comment])
        # Comment
        "//#{text}"
      elsif (text = $~[:id])
        if (alt = $~[:def])
          scope and scope[text] = alt
          alt
        else
          scope and scope[text] or text
        end
      elsif (text = $~[:label])
        # Function label
        scope = Scope.new(text)
        fn = $~[:fn]
        "\n// #{$~}\n" +
        "#ifdef SCOPE\n" +
        "#undef SCOPE\n" +
        (fn ? "# #{line} #{file}\n" : "") +
        (fn ? ".endfn\n"            : "") +
        "#endif\n" +
        "\n" +
        "#define SCOPE #{text}\n" +
        "# #{line} #{file}\n" +
        (fn ? ".fn SCOPE\n" : "SCOPE:" )
      elsif (text = $~[:local])
        # Local symbol
        scope ? ".L.#{scope.name}.#{text}" : ".L#{text}"
      end
    end
    print input
  end

  private

  ID0  = %Q{[[:alpha:]_]}
  IDN  = %Q{[[:alnum:]_.$]}

  ID_  = %r{ #{ID0} #{IDN}*+ }mx
  MARG = %r{ \\ (?: #{ID_} | \(\) ) }mx
  ID   = %r{
    (?: #{ID0} | #{MARG} )
    (?: #{IDN} | #{MARG} )*+
  }mx

  CHAR = %r{ ' (?: [^\\'] | \\.?+ )*+ '? }mx
  STR  = %r{ " (?: [^\\"] | \\.?+ )*+ "? }mx
  RUBY = %r{ ` (?: [^`]           )*+ `? }mx
  PROT = %r{ #{CHAR} | #{STR} | #{RUBY}  }mx

  EOL  = %r{ \n | \r\n?+      }mx
  EOLF = %r{ \n | \r\n?+ | \z }mx
  REST = %r{ [^\r\n]*+        }mx

  WS   = %r{ [ \t]   | \\ #{EOL} }mx
  ANY  = %r{ [^\r\n] | \\ #{EOL} }mx

  SEP  = %r{ (?>#{WS}+) (?!;|//) }mx
  CODE = %r{ [^ \t\r\n;] | #{SEP} | \\ #{EOL} | #{PROT} }mx

  MACROS = %r{
      (?<skip> #{STR}
      |        ^ \# #{ANY}*+
      )
    |          (?<eol>     #{EOL}  )
    | ;        (?<comment> #{REST} )
    |          (?<id> #{ID} )
               (?! [(:] )
               (?: [ \t]* => [ \t]* (?<def>#{ID}) )?+
    | ^ [ \t]* (?<label>   #{ID}   ) (?<fn>\(\))?+ :
    | \.       (?<local>   #{ID}   )
  }mx

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

