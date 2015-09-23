module NotificationSystem
  module Notifiers
    MESSAGES = {ob: "ОБЩИЕ", s: "СИДЯЧИЕ", p: "ПЛАЦКАРТНЫЕ", k: "КУПЕЙНЫЕ", sv: "СВ", m: "МЯГКИЕ"}
  end
end

require_relative "notifiers/beep_notifier"
require_relative "notifiers/email_notifier"
require_relative "notifiers/msg_notifier"
require_relative "notifiers/sound_notifier"
