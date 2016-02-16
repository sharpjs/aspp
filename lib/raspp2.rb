#!/usr/bin/env ruby
# encoding: UTF-8
# frozen_string_literal: true
#
# raspp.rb - Assembly Preprocessor in Ruby
# Copyright (C) 2016 Jeffrey Sharp
#

module Raspp
  def self.process(input, file = "(stdin)", line = 1)
    print input
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

