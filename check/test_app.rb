require_relative "app"
require_relative "notification_system"

class TestApp < App
  def start
    NotificationSystem::Notifier.new.notify(config[:notify], :m, '42 МИНСК - МЕЛЬБУРН', 'Минск', 'Мельбурн', 'Сегодня')
  end
end
