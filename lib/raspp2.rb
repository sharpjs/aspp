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
      elsif (text = $~[:label])
        # Function label
        scope = text
        if $~[:fn]
          "#ifdef SCOPE\n" +
          "#undef SCOPE\n" +
          "# #{line} #{file}\n" +
          ".endfn\n" +
          "#endif\n" +
          "\n" +
          "#define SCOPE #{text}\n" +
          "# #{line} #{file}\n" +
          ".fn SCOPE\n"
        else
          "#ifdef SCOPE\n" +
          "#undef SCOPE\n" +
          "#endif\n" +
          "\n" +
          "#define SCOPE #{text}\n" +
          "# #{line} #{file}\n" +
          "SCOPE:"
        end
      elsif (text = $~[:local])
        # Local symbol
        scope ? ".L.#{scope}.#{text}" : ".L#{text}"
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
      (?<skip> #{ID} (?![(:])
      |        #{STR}
      |        ^ \# #{ANY}*+
      )
    |          (?<eol>     #{EOL}  )
    | ;        (?<comment> #{REST} )
    | ^ #{WS}* (?<label>   #{ID}   ) (?<fn>\(\))?+ :
    | \.       (?<local>   #{ID}   )
  }mx
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

