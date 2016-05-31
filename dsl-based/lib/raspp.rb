#!/usr/bin/env ruby
# frozen_string_literal: true
#
# raspp - Assembly Preprocessor via Ruby DSL
#
# This file is part of Raspp.
# Copyright (C) 2016 Jeffrey Sharp
#
# Raspp is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published
# by the Free Software Foundation, either version 3 of the License,
# or (at your option) any later version.
#
# Raspp is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See
# the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Raspp.  If not, see <http://www.gnu.org/licenses/>.
#

require_relative "raspp/top_level"

if __FILE__ == $0
  # Running as a script

  # Don't print "broken pipe" error messages
  trap "PIPE", "SYSTEM_DEFAULT"

  # Parse Options
  #require_relative 'raspp/options'
  #RASPP_OPTS = Raspp::parse_options(ARGV).freeze
  #require_relative "raspp/targets/#{RASPP_OPTS[:cpu]}"

  # Process each specified file
  loop do
    Raspp::TopLevel.new.instance_eval(ARGF.file.read, ARGF.filename)
    ARGF.skip
    break if ARGV.empty?
  end
end

