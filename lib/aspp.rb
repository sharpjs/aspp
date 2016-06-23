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
# - Label macro invocation
#
#     foo:              .label foo;
#
# - Global labels
#
#     foo::             .label foo; .global foo;
#
# - Local scopes (nestable)
#
#     foo: // optional
#     {                 #define SCOPE foo
#       ...             .scope foo
#       ...
#       ...             .endscope foo
#     }                 #undef SCOPE
#
# - Local symbols
#
#     .foo              L(foo)
#
# - Local identifier aliases
#
#     op foo = a0       _(foo)a0  // foo aliased to a0
#     op foo            _(foo)a0
#     op bar = a0       _(bar)a0  // bar aliased to a0, foo unaliased
#
# - Brackets replaced with parentheses
#
#     [8, fp]           (8, fp)
#
# - Immediate-mode prefix removal (pseudo-ops only)
#
#     foo$.l #42, d0     foo$.l _(#)42, d0
#
# - Predefined macros
#
#     #define _(x)                          // inline comment
#     #define L(name)        .L$SCOPE$name  // ref to symbol in current scope
#     #define S(scope, name) .L$scope$name  // ref to symbol in given scope
#
#     .macro .label name:req                // default label behavior
#       \name\():
#     .endm
#
#     .macro .scope name:req, depth:req     // default begin-scope behavior
#     .endm
#
#     .macro .endscope name:req, depth:req  // default end-scope behavior
#     .endm
#

module Aspp
  class Processor
    def initialize(file)
      @file    = file         # source file name
      @line    = 1            # line number in source file
      @bol     = true         # if at beginning of line in output

      @aliases = Aliases.new  # identifier aliases
      @scopes  = []           # scope name stack
      @gensym  = 0            # number of next anonymous scope

      print Aspp::preamble(file)
      sync
    end

    def process(input)
      input.scan(STATEMENT) do |ws, name, colon, args, rest, brace|
        if    colon then on_label      ws, name, colon
        elsif args  then on_statement  ws, name, args, rest
        elsif brace then on_block      brace
        else             on_other      $&
        end

        @line += $&.count("\n")
      end
    end

    private

    WS   = %r{ (?: [ \t] | \\\n )++ }x
    ID   = %r{ (?!\d) [\w.$]++ }x
    STR  = %r{ " (?: [^\\"] | \\.?+ )*+ "?+ }x
    ARGS = %r{ (?: #{STR} | /(?!/) | \\.?+ | [^/\n;] )*+ }x

    STATEMENT = %r< \G
      (#{WS})?+
      (?:
        (?# label or op #)
        (#{ID})
        (?: (::?+) | (#{ARGS}) ( ; | (?://.*+)?+ \n?+ ) )
      |
        (?# block begin or end #)
        ({|})
      |
        (?# unrecognized #)
        .*+ \n?+
      )
    >x

    SPECIAL = %r{
      (?: (#{ID}) (?: #{WS}?+ = #{WS}?+ (#{ID}) )?+   (?# identifier or alias #)
        | @ (#{ID})                                   (?# verbatim identifier #)
        | \[                                          (?# indirect mode begin #)
        | \]                                          (?# indirect mode end  #)
        | \#                                          (?# immediate mode prefix #)
        | #{STR}                                      (?# string #)
      )
    }x

    RESERVED = %w{
      .s .b .w .l
    }
    .reduce({}) { |h, i| h[i] = true; h }

    def on_label(ws, name, sigil)
      if local?(name)
        print ws, localize(name), ":"
      else
        print ws, ".label ", name, ";"
      end

      if global?(sigil)
        print " .global ", name, ";"
      end

      @label = name
      @bol   = false
    end

    def on_statement(ws, name, args, rest)
      args.gsub!(SPECIAL) do |s|
        case s[0]
        when "["  then "("
        when "]"  then ")"
        when "#"  then pseudo?(name) ? "_(#)" : "#"
        when '"'  then s
        when '@'  then $3
        else           on_identifier $1, $2
        end
      end

      print ws, name, args, rest

      @label = nil
      @bol   = rest.end_with?("\n")
    end

    def on_block(char)
      puts unless @bol
      puts

      case char
      when '{'
        old      = @scopes.last
        new      = @label || gensym
        new      = old ? "#{old}$#{new}" : new
        depth    = @scopes.length

        @aliases = Aliases.new(@aliases)
        @scopes.push new

        set_scope old, new
        puts ".scope #{new}, #{depth}"
      when '}'
        old      = @scopes.pop
        new      = @scopes.last
        depth    = @scopes.length

        @aliases = @aliases.parent

        puts ".endscope #{old}, #{depth}"
        set_scope old, new
      end

      sync
      @label = nil
      @bol   = true
    end

    def set_scope(old, new)
      puts "#undef SCOPE"         if old
      puts "#define SCOPE #{new}" if new
    end

    def on_other(line)
      print line
      @bol = true
    end

    def on_identifier(id, val)
      return id if RESERVED[id]

      name = if val
               @aliases[id] = val
             else
               val = @aliases[id] or id
             end

      name = localize(name) if local?(name)

      val ? "_(#{id})#{name}" : name
    end

    def sync
      puts "# #{@line} \"#{@file}\""
    end

    def local?(id)
      id.start_with?(".")
    end

    def localize(id)
      "L(#{id[1..-1]})"
    end

    def global?(sigil)
      sigil == "::"
    end

    def gensym
      @gensym.tap { @gensym += 1 }
    end

    def pseudo?(id)
      id.start_with?(".") || id.include?("$")
    end
  end # Processor

  def self.preamble(name)
    <<~EOS
      # 1 "(aspp)"
 
      #define _(x)                          // inline comment
      #define L(name)        .L$SCOPE$name  // ref to symbol in current scope
      #define S(scope, name) .L$scope$name  // ref to symbol in given scope
 
      .macro .label name:req                // default label behavior
        \\name\\():
      .endm
 
      .macro .scope name:req, depth:req     // default begin-scope behavior
      .endm
 
      .macro .endscope name:req, depth:req  // default end-scope behavior
      .endm

    EOS
  end

  # A scope for aliases:
  # - An alias/key maps to a value.
  # - One value has one alias/key.
  # - On insert conflicts, older mappings are deleted.
  # - A child scope overrides its parent.
  #
  class Aliases
    attr_reader :parent

    def initialize(parent = nil)
      @parent = parent
      @k2v    = {}
      @v2k    = {}
    end

    def [](key)
      @k2v[key] or @parent &.[] key
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
  loop do
    Aspp::Processor
      .new(ARGF.filename)
      .process(ARGF.file.read)
    ARGF.skip
    break if ARGV.empty?
  end
end

