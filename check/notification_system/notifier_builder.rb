require_relative "notifiers"

module NotificationSystem
  class NotifierBuilder
    NOTIFIERS = {
                   msg: Notifiers::MsgNotifier,
                   email: Notifiers::EmailNotifier,
                   sound: Notifiers::SoundNotifier,
                   beep: Notifiers::BeepNotifier,
                }

    def self.get(type)
      NOTIFIERS[type].new
    end
  end
end
