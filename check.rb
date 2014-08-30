#!/usr/bin/ruby
# encoding: utf-8

require 'yaml'
require 'optparse'
require_relative "check/console"

options = OptionParser.new do |opts|
  opts.banner = "Usage: #{$0} [options] [<config_file>]"

  opts.on( '-v', '--verbose', 'Run verbosely' ) do
    Console.level = :debug
  end

  opts.on( '-h', '--help', 'Show this message' ) do
    puts opts
    exit
  end

  opts.on('-t', '--test', 'Test configured notifications and exit') do
    $TEST = true
  end

  opts.on('-d', '--debug', 'Debug mode: stop on "broken page" errors') do
    $DEBUG_MODE = true
  end
end

begin
  options.parse!
rescue OptionParser::InvalidOption
  puts options
  exit 1
end


DEFAULT_FILE = "config.yml"
config_file = ARGV[-1] || DEFAULT_FILE

app = if $TEST
        require_relative "check/test_app"
        TestApp.new(config_file, $DEBUG_MODE)
      else
        require_relative "check/app"
        App.new(config_file, $DEBUG_MODE)
      end
app.start
