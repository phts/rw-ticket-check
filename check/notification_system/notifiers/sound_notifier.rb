require_relative "../../console"

module NotificationSystem
  module Notifiers
    class SoundNotifier
      begin
        require 'win32/sound'
        include Win32
      rescue LoadError => e
        Console.puts "#{self.name} is unavailable"
        Console.debug(e)
      end

      DEFAULTS = {file: "c:\\Windows\\Media\\chimes.wav"}

      def notify(params)
        params = DEFAULTS.merge(params)
        Sound.play(params[:file])
      rescue Exception => e
        Console.puts "Unable to play a file #{params[:file]}: #{e}"
        Console.debug(e)
      end
    end
  end
end
