require_relative "../../console"

module NotificationSystem
  module Notifiers
    class SoundNotifier
      begin
        require 'win32/sound'
        include Win32
      rescue LoadError => e
        console.puts "#{self.name} is unavailable"
        console.debug(e)
      end

      DEFAULTS = {file: "c:\\Windows\\Media\\chimes.wav"}

      def notify(params)
        params = DEFAULTS.merge(params)
        Sound.play(params[:file])
      rescue Exception => e
        console.puts "Unable to play a file #{params[:file]}: #{e}"
        console.debug(e)
      end
    end
  end
end
