require "singleton"

class Console
  include Singleton

  attr_accessor :level

  def self.method_missing(sym, *args, &block)
    self.instance.send(sym, *args, &block)
  end

  def initialize
    self.level = :info
  end

  def puts(text = nil)
    text.nil? ? STDOUT.puts : STDOUT.puts(encode(text))
  end

  def print(text)
    STDOUT.print(encode(text))
    STDOUT.flush
  end

  def debug(text)
    return unless level == :debug
    if text.is_a?(Exception)
      STDOUT.puts(text.message)
      STDOUT.puts(text.backtrace.join("\n"))
    else
      puts(text)
    end
  end

  private

  def encode(text)
    text.encode('CP866', invalid: :replace, undef: :replace, replace: '?')
  end
end
