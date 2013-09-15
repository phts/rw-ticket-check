# encoding: utf-8

require 'watir-webdriver'
require 'yaml'
require 'optparse'

class Console
  require 'iconv'
  @@c = Iconv.new('CP866', 'UTF-8')
  @@level = :info

  def self.puts(text = nil)
    text.nil? ? STDOUT.puts : STDOUT.puts(@@c.iconv(text.to_s))
  end

  def self.print(text)
    STDOUT.print(@@c.iconv(text.to_s))
    STDOUT.flush
  end

  def self.level=(level)
    @@level = level
  end

  def self.debug(text)
    return unless @@level == :debug
    if text.is_a?(Exception)
      STDOUT.puts(text.message)
      STDOUT.puts(text.backtrace.join("\n"))
    else
      puts(text)
    end
  end
end

def go_through_login_page
  @browser.link(text: /Информация для пассажиров/).click
  @browser.text_field(id: 'login').set(@config[:login][:username])
  @browser.text_field(id: 'password').set(@config[:login][:password])
  @browser.button(name: '_login').click
  id_prefix = 'viewns_7_48QFVAUK6HA180IQAQVJU80004_'
  @browser.checkbox(id: id("form1:conf", id_prefix)).click
  @browser.button(id: id("form1:nextBtn", id_prefix)).click
  @id_prefix = id_prefix
end

def id(suffix, prefix = @id_prefix)
  "#{prefix}:#{suffix}"
end

def sleep_and_reload
  Console.puts "#{Time.new.to_s} sleep #{@config[:delay]} seconds and then reload"
  sleep(@config[:delay])
  @browser.button(id: id("change:buttonSearch")).click
  check_page_content
end

def check_page_content
  raise "Broken page" unless @browser.span(id: id("text1")).text == "Маршрут следования пассажира:" &&
                             @browser.span(id: id("textRoute")).text == "#{@config[:from]} - #{@config[:to]}" &&
                             @browser.span(id: id("text2")).text == "Дата отправления:" &&
                             @browser.span(id: id("textDate")).text == @config[:when]
end

def find_train_row(train)
  link = @browser.link(:onclick, /#{train}/)
  link.parent.parent
rescue => e
  Console.debug(e)
  nil
end

CELL_INDECES = {ob: 7, s: 8, p: 9, k: 10, sv: 11, m: 12}
def ticket_count(train_row, type)
  cell = train_row.cell(index: CELL_INDECES[type])
  span = cell.span(class: "outputText")
  begin
    text = span.text
    text.strip.to_i
  rescue
    0
  end
end

def check_tickets(train, types)
  Console.print "  #{train}"
  train_row = find_train_row(train)
  unless train_row
    Console.puts " not found"
    return
  end

  @previous_numbers ||= {}
  @previous_numbers[train] ||= {}

  types.each do |type|
    current_number = ticket_count(train_row, type)
    Console.print "  #{type}:#{current_number}"
    if current_number > @previous_numbers[train][type].to_i
      Console.puts
      yield(type) if block_given?
    end
    @previous_numbers[train][type] = current_number
  end
  Console.puts
end

module NotificationSystem
  MESSAGES = {ob: "ОБЩИЕ", s: "СИДЯЧИЕ", p: "ПЛАЦКАРТНЫЕ", k: "КУПЕЙНЫЕ", sv: "СВ", m: "МЯГКИЕ"}

  class Notifier

    def notify(config, type, train, from, to, wwhen)
      timestamp = Time.new
      Console.puts("#{timestamp.to_s} - New #{type} tickets in #{train}")
      config.each do |item|
        notifier = item.first[0]
        params = item.first[1] || {}
        NotifierBuilder.get(notifier).notify(params.merge({type: type, train: train, timestamp: timestamp, ticket_from: from, ticket_to: to, ticket_when: wwhen}))
      end
    end

  end

  class EmailNotifier
    require 'net/smtp'

    def notify(params)
      params = params.merge({body: "#{params[:ticket_from]} - #{params[:ticket_to]}\n#{params[:ticket_when]}\n\nНовые #{MESSAGES[params[:type]]} билеты на поезд #{params[:train]}"})
      params[:subject] ||= "Уведомление: Новые билеты #{params[:ticket_from]} - #{params[:ticket_to]} (#{params[:ticket_when]})"
      begin
        send_email(params)
      rescue Exception => e
        Console.puts "Unable to send email to #{params[:to]}: #{e}"
        Console.debug(e)
      else
        Console.puts "Email was sent to #{params[:to]}"
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

  class MsgNotifier
    require 'dl'
    require 'iconv'

    def notify(params)
      params = params.merge({text: "#{params[:ticket_from]} - #{params[:ticket_to]}\n#{params[:ticket_when]}\n\nНовые #{MESSAGES[params[:type]]} билеты на поезд #{params[:train]}"})
      show_message_box(params)
    end

    private

    def show_message_box(params = {})
      c = Iconv.new('WINDOWS-1251', 'UTF-8')
      user32 = DL.dlopen('user32')
      msgbox = DL::CFunc.new(user32['MessageBoxA'], DL::TYPE_LONG, 'MessageBox')
      msgbox.call([0, c.iconv(params[:text]), c.iconv(params[:title] || "#{params[:timestamp].to_s}"), params[:buttons] || 0].pack('L!ppL!').unpack('L!*'))
    end
  end

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

  class NotifierBuilder
    NOTIFIERS = {msg: MsgNotifier, email: EmailNotifier, sound: SoundNotifier, beep: BeepNotifier}

    def self.get(type)
      NOTIFIERS[type].new
    end
  end

end

options = OptionParser.new do |opts|
  opts.banner = "Usage: #{$0} [options] <config_file>"

  opts.on( '-v', '--verbose', 'Run verbosely' ) do
    Console.level = :debug
  end

  opts.on( '-h', '--help', 'Show this message' ) do
    puts opts
    exit
  end
end

begin
  options.parse!
rescue OptionParser::InvalidOption
  puts options
  exit 1
end

Console.puts "Reading configuration file"
file = ARGV[-1]
unless file
  puts options
  exit 1
end
TIMEOUT = 300
DEFAULTS = {
  delay: 30,
  start_page: "https://poezd.rw.by/wps/portal/home/rp/schedule/!ut/p/c5/dY_LdoIwFEW_pR_QlctTHKZEQUVsBESYsEJ5lEcJJRro39eujj17uPfkoBQ9GJhsanZr-MB6dEWpmekW3V5wdDAV01jDLvDOYaQRxTJUtEdp3fP8UcYk4QsRx9nGpOq4s9R5J1k-pW0vBI1I0lXSKttpXEmCa6ua9wuhg-vLuCoaW57De_hNPw11Uvyfgq1p721YsIQ372DoDfsotdFy3osBjld4E3eRznxr6sNURP3pVc2ok9ksESj-e2BmtoNdfeUBnNQLgOobAYUo0GCn_Xt4MgzId_lXicYuh1bHL78fFsjL/dl3/d3/L2dJQSEvUUt3QS9ZQnZ3LzZfNDhRRlZBVUs2UEZMRDBJU1RDTEZIRTEwMTA!/",
  notify: [],
}
YAML::ENGINE.yamler = 'psych'
File.open(file) do |f|
  @config = DEFAULTS.merge(YAML::load(f))
end
Console.debug @config.to_yaml

Console.puts "Starting the browser"
client = Selenium::WebDriver::Remote::Http::Default.new
client.timeout = TIMEOUT # seconds – default is 60
@browser = Watir::Browser.new(:firefox, :http_client => client)

loop do
  begin
    Console.puts "Navigating to a start page"
    @browser.goto(@config[:start_page])

    @id_prefix = 'viewns_7_48QFVAUK6P5060ISJLKGLD2007_'
    go_through_login_page if @config[:login]

    Console.puts "Entering data"
    @browser.text_field(id: id("form1:textDepStat")).set(@config[:from])
    @browser.text_field(id: id("form1:textArrStat")).set(@config[:to])
    @browser.text_field(id: id("form1:dob")).set(@config[:when])
    @browser.button(id: id("form1:buttonSearch")).click

    Console.puts "Working..."
    loop do
      @config[:check].each do |item|
        train = item.first[0].strip
        types = item.first[1]
        check_tickets(train, types) do |type|
          NotificationSystem::Notifier.new.notify(@config[:notify], type, train, @config[:from], @config[:to], @config[:when])
        end
      end

      sleep_and_reload
    end

  rescue Errno::ECONNREFUSED => e
    Console.puts "Browser was closed. Exiting"
    Console.debug(e)
    break
  rescue Timeout::Error => e
    Console.puts "Timeout #{TIMEOUT} sec. Starting from scratch in #{@config[:delay]} sec"
    Console.debug(e)
    sleep(@config[:delay])
    retry
  rescue Exception => e
    Console.puts "Page is broken. Starting from scratch in #{@config[:delay]} sec"
    Console.debug(e)
    sleep(@config[:delay])
    retry
  end
end