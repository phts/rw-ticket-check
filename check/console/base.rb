module Console
  class Base
    attr_accessor :level

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

    protected

    def encode(text)
      raise "Should be overriden"
    end
  end
end
