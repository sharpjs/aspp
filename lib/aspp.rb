#!/usr/bin/env ruby
# encoding: UTF-8
# frozen_string_literal: true
#
# aspp - Assembly Preprocessor in Ruby
# Copyright (C) 2016 Jeffrey Sharp
#
# aspp is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published
# by the Free Software Foundation, either version 3 of the License,
# or (at your option) any later version.
#
# aspp is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See
# the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with aspp.  If not, see <http://www.gnu.org/licenses/>.
#
# FEATURES
#
# Label processing
# - Local scopes between non-local labels
# - Global labels indicated by extra : suffix
# - Invoke macro for each label
#
#     foo:              #ifdef scope
#     foo::             #undef scope
#                       #endif
#                       #define scope foo
#                       # 42 "file.s"
#                       .label scope;
#                       .global scope     // if :: was used
#                       # 42 "file.s"
#
# Local symbols
#
#     .foo              L(foo)
#
# Local aliases
#
#     foo@a0            _(foo)a0
#     foo               _(foo)a0
#     bar@a0            _(bar)a0            // undefines foo
#
# Square brackets for indirect addressing
#
#     [a0, 42]          (a0, 42)
#
# Immediate-mode prefix removal for certain macros
#
#     cmp$.l #4, d0     cmp$.l _(#)4, d0
#
# Assembler macros
#
#     .macro .label name:req              // default .macro label
#       \name\():
#     .endm
#
# C preprocessor macros
#
#     #define _(x)                        // inline comment
#     #define SCOPE(name) .L$name         // reference to scope
#     #define L           .L$scope$name   // reference to local symbol
#

require 'strscan'

module Aspp
  class Processor
    def initialize
      @aliases = Aliases.new
    end

    def process(input, file = "(stdin)", line = 1)
      @input  = StringScanner.new(input)
      @file   = file
      @line   = line
      @height = 0
      @aliases.clear

      write_preamble

      # Process lines
      until @input.eos?
        if op = scan_labels
          print "\t", op
          scan_operands op
        else
          print scan(REST_OF_LINE)
        end

        @line  += @height
        @height = 0
      end
    end

    private

    def scan_labels
      while scan(LABEL_OR_OP)
        # Get captures
        id   = @input[:id]
        punc = @input[:punc]

        # Op is first unpunctuated id
        return id unless punc

        # Write transformed label
        if local?(id)
          id = localize(id)
          label id
        else
          start_scope id
          id = :scope
        end

        # Export label
        export id if global?(punc)

        @aliases.clear
        sync
      end
    end

    def scan_operands(op)
      pseudo = pseudo?(op)

      while tok = @input.scan(OPERAND_TOKEN)
        case tok[0]
        when "["  then print "("
        when "]"  then print ")"
        when "#"  then print pseudo ? "_(#)" : "#"
        when "\n" then puts; return
        else # identifier
          if id = @input[:id]
            print idref(id, @input[:as])
          else
            print tok
          end
        end
      end
    end

    def scan(re)
      @input.scan(re).tap do |s|
        s and @height += s.count("\n")
      end
    end

    def local?(id)
      id.start_with?(".")
    end

    def localize(id)
      "L(#{id})"
    end

    def global?(punc)
      punc == "::"
    end

    def pseudo?(id)
      id.start_with?(".") || id.include?("$")
    end

    def sync
        puts %{# #{@line} "#{@file}"}
    end

    def write_preamble
      puts <<~EOS
        # 1 "(asmpp-preamble)"
        .macro .label name:req              // default label behavior
          \\name\\():
        .endm
        #define _(x)                        // inline comment
        #define SCOPE(name) .L$name         // reference to scope
        #define L           .L$scope$name   // reference to local symbol

        # #{@line} "#{@file}"
      EOS
    end

    def start_scope(id)
      puts <<~EOS
        ; SCOPE: #{id}
        #ifdef scope
        #undef scope
        #endif
        #define scope #{id}

        # #{@line} "#{@file}"
        .label scope

      EOS
    end

    def label(id)
      puts "#{id}:"
    end

    def export(id)
      puts ".global #{id}"
    end

    def idref(id, as)
      if as
        @aliases[id] = as
      else
        as = @aliases[id]
      end
      as ?  "_(#{id})#{as}" : id
    end

    WS  = %r{ (?: [ \t] | \\\n )*+ }x
    ID  = %r{ (?!\d) [\w.$]++ }x
    STR = %r{ " (?: [^\\"] | \\.?+ )*+ "?+ }x

    REST_OF_LINE = %r{ .*+ \n?+ }x

    LABEL_OR_OP = %r{ #{WS} (?<id>#{ID}) (?<punc>::?+)?+ }x

    OPERAND_TOKEN = %r{
        (?: [^#"\[\]\\\n\w]
          | \\ (?:[^\n]|\z)
          | \d (?: [\w.] | [Ee][+-] )++
        )++
      |
        (?<id>#{ID}) (?: #{WS} @ #{WS} (?<as>#{ID}) )?+
      |
        " (?: [^\\"] | \\.?+ )*+ "?+
      |
        .
    }x
  end # Processor

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
      @k2v[key]
    end

    def []=(key, val)
      @v2k.delete(@k2v[key]) # Remove map: new key <- old val
      @k2v.delete(@v2k[val]) # Remove map: old key -> new val
      @k2v[key] = val
      @v2k[val] = key
      val
    end
  end
end # Aspp

if __FILE__ == $0
  # Running as script
  trap "PIPE", "SYSTEM_DEFAULT"
  processor = Aspp::Processor.new
  loop do
    processor.process(ARGF.file.read, ARGF.filename)
    ARGF.skip
    break if ARGV.empty?
  end
end

