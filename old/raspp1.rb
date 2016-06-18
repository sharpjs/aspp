#!/usr/bin/env ruby
# encoding: UTF-8
# frozen_string_literal: true
#
# raspp.rb - Assembly Preprocessor in Ruby
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
# Ruby code:
#
#   @ puts "a ruby line"
#
#   move.l `inline_ruby`, d0
#
# Aliases (inline token macros)
#
#   move.l v@(8, fp), x@d0
#   add.l  #3, x
#   move.l x, v
#
# Comment removal
#
#   ; this is a comment
#
# Line continuation:
#
#   this is \
#   all one line
#

module Raspp
  def self.process(input, file = "(stdin)", line = 1)
    Preprocessor.new(file, line).process(input)
  end

  private

  WS  = '[ \t]*+'
  ANY = '[^\r\n]*+'
  BOL = '(?<=\n|\r|\r\n|\A)'
  EOL = '(?:\n|\r\n?+|\z)'

  TOKENS = %r{ \G
    (?:
      #{BOL} #{WS} @ (?<ruby> #{ANY} #{EOL} )   # ruby line
    |
      (?<ws> #{WS} )                            # whitespace
      (?<tok>                                   # token:
        (?: \n | \r\n?+                         # - end of line
          | (?!\d) [\w.]++ \$?+                 # - identifier
          | [\d$%] [\w.]*+                      # - number literal
          | ` (?: [^`]           )*+ `?+        # - inline ruby    (`)
          | ' (?: [^\\'] | \\.?+ )*+ '?+        # - string literal (')
          | " (?: [^\\"] | \\.?+ )*+ "?+        # - string literal (")
          | ; #{ANY}                            # - comment
          | \\ #{WS} (?:;#{ANY})? #{EOL} #{WS}  # - continued line
          | [@\[\](){}]                         # - punctuators
          | [^ \t\r\n\w.$%`'";@\[\](){}]++      # - other
        )
      )
    )
  }mx

  TOKEN_TYPES = {}.tap do |types|
    {
      # Type      # Starting Characters
      on_id:      [*?a..?z, *?A..?Z, ?_, ?.],
      on_ruby_ex: %W| `       |,
      on_chunk:   %W| ' " $ % | + [*?0..?9],
      on_enter:   %W| [ ( {   |,
      on_leave:   %W| ] ) }   |,
      on_alias:   %W| @       |,
      on_comment: %W| ;       |,
      on_eol_esc: %W| \\      |,
      on_eol:     %W| \n \r   |,
    }
    .each do |type, chars|
      chars.each { |c| types[c] = type }
    end
  end

  class Preprocessor
    def initialize(file = "(stdin)", line = 1)
      @file, @line, @aliases, @script = file, line, {}, ''.dup
    end

    def process(input)
      input.scan(TOKENS) do |ruby, ws, tok|
        if ruby
          on_ruby(ruby)
        else
          send(TOKEN_TYPES[tok[0]] || :on_chunk, ws, tok)
        end
      end
      flush_id
      flush_text
      $stderr.puts @script
      Environment.new.instance_eval @script
    end

    def on_comment(ws, tok)
      flush_id
      # Suppress comment
    end

    def on_eol_esc(ws, tok)
      print ' '
    end

    def on_eol(ws, tok)
      flush_id
      print tok
      update_aliases 0
      flush_text
    end

    def on_id(ws, tok)
      flush_id
      print ws
      @id = tok
    end

    def on_alias(ws, tok)
      if @id
        raise "Recursive alias definition" if @aliases.key?(@id)
        @aliases[@id] = { text: '', depth: 0 }
        @id = nil
      else
        print ws, tok
      end
    end

    def on_chunk(ws, tok)
      flush_id
      print ws, tok
      update_aliases 0, ws, tok
    end

    def on_enter(ws, tok)
      flush_id
      print ws, tok
      update_aliases +1, tok
    end

    def on_leave(ws, tok)
      flush_id
      print ws, tok
      update_aliases -1, ws, tok
    end

    def flush_id
      if @id
        @text << %(\#{scope[#{@id.inspect}]})
        update_aliases 0, @id
        @id = nil
      end
    end

    def update_aliases(depth, *toks)
      @aliases.delete_if do |name, a|
        text = toks.reduce(a[:text].dup, :<<)

        #scope[name] = text.lstrip if (a[:depth] += depth) <= 0
        flush_text
        @script << %(scope[#{name.inspect}] = #{text.inspect}\n) if
          (a[:depth] += depth) <= 0
      end
    end

    def on_ruby(ruby)
      flush_text
      @script << ruby
    end

    def on_ruby_ex(ws, ruby)
      print ws
      @text << %(\#{#{ruby}})
    end

    def print(*strs)
      strs.reduce(@text ||= ''.dup) { |t, s| t << s.inspect[1..-2] }
    end

    def flush_text
      @script << %{print("#{@text}")\n} if @text
      @text = nil
    end
  end

  class Environment
    attr_reader :scope

    def initialize
      @scope = Scope.new
    end

    def subscope
      @scope = @scope.subscope
      yield
    ensure
      @scope = @scope.parent
    end
  end

  class Scope
    attr_reader :parent

    def initialize(parent = nil)
      @parent, @k2v, @v2k = parent, {}, {}
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
  loop do
    Raspp::process(ARGF.file.read, ARGF.filename)
    ARGF.skip
    break if ARGV.empty?
  end
end

