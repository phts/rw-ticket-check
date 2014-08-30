module NotificationSystem
  module Notifiers
    class MsgNotifier
      require 'dl'

      def notify(params)
        params = params.merge({text: "#{params[:ticket_from]} - #{params[:ticket_to]}\n#{params[:ticket_when]}\n\nНовые #{MESSAGES[params[:type]]} билеты на поезд #{params[:train]}"})
        show_message_box(params)
      end

      private

      def show_message_box(params = {})
        user32 = DL.dlopen('user32')
        msgbox = DL::CFunc.new(user32['MessageBoxA'], DL::TYPE_LONG, 'MessageBox')
        msgbox.call([0, encode(params[:text]), encode(params[:title] || "#{params[:timestamp].to_s}"), params[:buttons] || 0].pack('L!ppL!').unpack('L!*'))
      end

      def encode(text)
        text.encode('WINDOWS-1251', invalid: :replace, undef: :replace, replace: '?')
      end
    end
  end
end
