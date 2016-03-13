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
# IMPLEMENTED FEATURES
#
# - Scopes with local labels
#
#     foo:          #define scope foo
#     {             .fn scope
#
#     bar:          L$bar:      (bar is local to scope foo)
#       jmp bar     jmp L$bar
#
#     }             .endfn
#
# - Inline unique aliases
#
#     foo@a0        _(foo)a0
#     foo           _(foo)a0
#     bar@a0        _(bar)a0  (this undefines foo)
#     foo           *ERROR*
#
# - Sigils for arguments and local variables
#
#     @foo          ARG(foo)
#     $bar          VAR(bar)
#
# FUTURE FEATURES
#
# - Nested scopes
#
# - Transform character literals
#
#     'a'           'a
#

module Raspp
  class Processor
    def initialize
      @handlers = collect_handlers
    end

    def process(input, file = "(stdin)", line = 1)
      @input    = input
      @file     = file
      @line     = line
      @scope    = Scope.new(nil)

      input.scan(TOKENS) do
        #p $~
        @handlers[$&[0]].call($~)
      end
    end

    private

    # Identifiers
    ID = %r{ (?!\d) [\w.$]++ }x

    # Tokens - chunks of text to transform or ignore
    TOKENS = %r{ \G
      (?: \n                                    # end of line, then:
          (?: (?<scope>#{ID}): \n\{ (?=\n)      # - scope begins
            | (?<scope>     )  \}\n (?=\n)      # - scope ends
          )?+
        | (?<id>#{ID}) (?: @ (?<def>#{ID}) )?+  # aliasable identifier
        | [@$] (?<id>#{ID})                     # argument or variable
        | // [^\n]*+                            # ignored: comment
        | (?: [^\w\n@$./\\"]                    # ignored: misc
            | \d \w*+                           # ignored: numbers
            | [@$] (?=\d|[^\w.$]|\z)            # ignored: bare sigils
            | / (?!/)                           # ignored: bare slashes
            | \\ \n?+                           # ignored: escaped newlines
            | " (?: [^\\"] | \\.?+ )*+ "?+      # ignored: string literal (")
          )++
      )
    }mx

    LABELS = %r{ ^(#{ID}): | ^\}\n }x

    def collect_handlers
      handlers = Hash.new(method(:on_other))
      {
        #Name   Starting Characters
        on_id:  [*?a..?z, *?A..?Z, ?_, ?., ?$],
        on_arg: [?@ ],
        on_var: [?$ ],
        on_eol: [?\n],
      }
      .each do |name, chars|
        chars.each { |c| handlers[c] = method(name) }
      end
      handlers
    end

    def on_id(match)
      id   = match[:id]
      deƒ  = match[:def]
      used = nil

      if deƒ
        @scope.aliases[id] = "_(#{id})#{deƒ}"
        id = deƒ
        used = { id => true }
      end

      while (deƒ = @scope.aliases[id])
        id = deƒ
        (used ||= {})[id] = true
      end

      if (deƒ = @scope.labels[id])
        id = deƒ
        (used ||= {})[id] = true
      end

      print id
    end

    def on_arg(match)
      print "ARG(#{match[:id]})"
    end

    def on_var(match)
      print "VAR(#{match[:id]})"
    end

    def on_eol(match)
      puts
      scope = match[:scope] or return
      if scope.empty?
        pop_scope
      else
        push_scope scope
        scan_labels match.post_match
      end
    end

    def on_other(match)
      print match[0]
    end

    def push_scope(name)
      @scope = @scope.subscope(name)
      print "#define scope #{name}\n.fn scope;"
    end

    def pop_scope
      print "#undef scope\n.endfn\n"
      @scope = @scope.parent unless @scope.root?
    end

    def scan_labels(text)
      text.scan(LABELS) do
        id = $1 or break
        @scope.labels[id] = "L$#{id}"
      end
    end
  end # Processor

  class Scope
    attr_reader :name, :parent, :labels, :aliases

    def initialize(name, parent = nil)
      @name    = name
      @parent  = parent
      @labels  = ManyToOneLookup.new(parent&.labels )
      @aliases =  OneToOneLookup.new(parent&.aliases)
    end

    def subscope(name)
      Scope.new(name, self)
    end

    def root?
      parent.nil?
    end
  end

  class ManyToOneLookup
    attr_reader :parent

    def initialize(parent = nil)
      @parent = parent
      @k2v    = {}
    end

    def [](key)
      @k2v[key] or @parent&.[](key)
    end

    def []=(key, val)
      @k2v[key] = val
    end
  end

  class OneToOneLookup
    attr_reader :parent

    def initialize(name, parent = nil)
      @parent = parent
      @k2v    = {}
      @v2k    = {}
    end

    def [](key)
      @k2v[key] or @parent&.[](key)
    end

    def []=(key, val)
      @v2k.delete(@k2v[key]) # Remove map: new key <- old val
      @k2v.delete(@v2k[val]) # Remove map: old key -> new val
      @k2v[key] = val
      @v2k[val] = key
      val
    end
  end
end # Raspp

if __FILE__ == $0
  # Running as script
  trap "PIPE", "SYSTEM_DEFAULT"
  processor = Raspp::Processor.new
  loop do
    processor.process(ARGF.file.read, ARGF.filename)
    ARGF.skip
    break if ARGV.empty?
  end
end

