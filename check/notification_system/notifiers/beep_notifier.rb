require_relative "../../console"

module NotificationSystem
  module Notifiers
    class BeepNotifier
      begin
        require 'win32/sound'
        include Win32
      rescue LoadError => e
        Console.puts "#{self.name} is unavailable"
        Console.debug(e)
      end

      DEFAULTS = {frequency: 2000, duration: 1000, times: 1}

      def notify(params)
        params = DEFAULTS.merge(params)
        params[:times].times do
          Sound.beep(params[:frequency], params[:duration])
          sleep(params[:duration] / 1000.0)
        end
      rescue Exception => e
        Console.puts "Unable to beep: #{e}"
        Console.debug(e)
      end
    end
  end
end
