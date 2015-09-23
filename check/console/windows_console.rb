require_relative "base"

module Console
  class WindowsConsole < Base

    protected

    def encode(text)
      text.encode('CP866', invalid: :replace, undef: :replace, replace: '?')
    end

  end
end
