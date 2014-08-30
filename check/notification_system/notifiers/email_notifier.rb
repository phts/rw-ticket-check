require_relative "../../console"

module NotificationSystem
  module Notifiers
    class EmailNotifier
      require 'net/smtp'

      def notify(params)
        params = params.merge({body: "#{params[:ticket_from]} - #{params[:ticket_to]}\n#{params[:ticket_when]}\n\nНовые #{MESSAGES[params[:type]]} билеты на поезд #{params[:train]}"})
        params[:subject] ||= "Уведомление: Новые билеты #{params[:ticket_from]} - #{params[:ticket_to]} (#{params[:ticket_when]})"
        begin
          send_email(params)
        rescue Exception => e
          console.puts "Unable to send email to #{params[:to]}: #{e}"
          console.debug(e)
        else
          console.puts "Email was sent to #{params[:to]}"
        end
      end

      private

      def send_email(params = {})
        raise RuntimeError.new("Wrong params: #{params.inspect}") unless params[:to] && params[:from] && params[:body] && params[:server]

        message = <<MESSAGE
From: #{params[:from_alias]} <#{params[:from]}>
To: <#{params[:to]}>
Subject: #{params[:subject]}

#{params[:body]}
MESSAGE

        Net::SMTP.start(params[:server], 25, params[:server], params[:login], params[:password], params[:authtype]) do |smtp|
          smtp.send_message(message, params[:from], params[:to])
        end
      end
    end
  end
end
