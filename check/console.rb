module Console; end

require_relative "utils"

def console
  $console ||= if Utils.windows?
                 require_relative "console/windows_console"
                 Console::WindowsConsole.new
               else
                 require_relative "console/linux_console"
                 Console::LinuxConsole.new
               end
end
