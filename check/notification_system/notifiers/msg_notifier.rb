module NotificationSystem
  module Notifiers
    class MsgNotifier
      require 'fiddle'

      def notify(params)
        params = params.merge({text: "#{params[:ticket_from]} - #{params[:ticket_to]}\n#{params[:ticket_when]}\n\nНовые #{MESSAGES[params[:type]]} билеты на поезд #{params[:train]}"})
        show_message_box(params)
      end

      private

      def show_message_box(params = {})
        text = encode(params[:text])
        title = encode(params[:title] || "#{params[:timestamp].to_s}")
        buttons = params[:buttons] || 0
        func_args = [0, text, title, buttons].pack('L!ppL!').unpack('L!*')

        user32 = Fiddle.dlopen('user32')
        msgbox = Fiddle::Function.new(user32['MessageBoxA'],
                                      [Fiddle::TYPE_LONG, Fiddle::TYPE_LONG, Fiddle::TYPE_LONG, Fiddle::TYPE_LONG],
                                      Fiddle::TYPE_VOIDP)
        msgbox.call(*func_args)
      end

      def encode(text)
        text.encode('WINDOWS-1251', invalid: :replace, undef: :replace, replace: '?')
      end
    end
  end
end
