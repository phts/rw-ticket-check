require_relative "notifier_builder"
require_relative "../console"

module NotificationSystem
  class Notifier
    def notify(config, type, train, from, to, wwhen)
      timestamp = Time.new
      console.puts("#{timestamp.to_s} - New #{type} tickets in #{train}")
      config.each do |item|
        notifier = item.first[0]
        params = item.first[1] || {}
        begin
          NotifierBuilder.get(notifier).notify(params.merge({type: type, train: train, timestamp: timestamp, ticket_from: from, ticket_to: to, ticket_when: wwhen}))
        rescue => e
          console.puts "Failed to notify via #{notifier.inspect}"
          console.debug(e)
          next
        end
      end
    end
  end
end
