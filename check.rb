# encoding: utf-8

require 'watir-webdriver'
require 'yaml'
require 'optparse'

class Console
  include Singleton

  attr_accessor :level

  def self.method_missing(sym, *args, &block)
    self.instance.send(sym, *args, &block)
  end

  def initialize
    level = :info
  end

  def puts(text = nil)
    text.nil? ? STDOUT.puts : STDOUT.puts(encode(text))
  end

  def print(text)
    STDOUT.print(encode(text))
    STDOUT.flush
  end

  def debug(text)
    return unless level == :debug
    if text.is_a?(Exception)
      STDOUT.puts(text.message)
      STDOUT.puts(text.backtrace.join("\n"))
    else
      puts(text)
    end
  end

  private

  def encode(text)
    text.encode('CP866', invalid: :replace, undef: :replace, replace: '?')
  end
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

class App
  TIMEOUT = 300

  DEFAULTS = {
    delay: 30,
    start_page: "http://poezd.rw.by",
    notify: [],
  }

  CELL_INDECES = {ob: 7, s: 8, p: 9, k: 10, sv: 11, m: 12}

  LOGGED_IN_ID_PREFIX = 'viewns_7_48QFVAUK6HA180IQAQVJU80004_'
  NOT_LOGGED_IN_ID_PREFIX = 'viewns_7_48QFVAUK6P5060ISJLKGLD2007_'

  attr_reader :config

  def initialize(config_file)
    YAML::ENGINE.yamler = 'psych'
    File.open(config_file) do |f|
      @config = DEFAULTS.merge(YAML::load(f))
    end
    Console.debug config.to_yaml
  end

  def start
    Console.puts "Starting the browser"
    client = Selenium::WebDriver::Remote::Http::Default.new
    client.timeout = TIMEOUT # seconds – default is 60
    @browser = Watir::Browser.new(:firefox, :http_client => client)
    start_main_loop
  end

  private

  def start_main_loop
    loop do
      begin
        Console.puts "Navigating to the start page #{config[:start_page].inspect}"
        go_to_route_page

        Console.puts "Entering data"
        enter_data

        Console.puts "Working..."
        start_working_loop

      rescue Errno::ECONNREFUSED => e
        Console.puts "Browser was closed. Exiting"
        Console.debug(e)
        break
      rescue Timeout::Error => e
        Console.puts "Timeout #{TIMEOUT} sec. Starting from scratch in #{config[:delay]} sec"
        Console.debug(e)
        sleep(config[:delay])
        retry
      rescue => e
        Console.puts "Page is broken. Starting from scratch in #{config[:delay]} sec"
        Console.debug(e)
        sleep(config[:delay])
        retry
      end
    end
  end

  def start_working_loop
    loop do
      config[:check].each do |item|
        train = item.first[0].strip
        types = item.first[1]
        check_tickets(train, types) do |type|
          NotificationSystem::Notifier.new.notify(config[:notify], type, train, config[:from], config[:to], config[:when])
        end
      end

      Console.puts "#{Time.new.to_s} sleep #{config[:delay]} seconds and then reload"
      sleep(config[:delay])
      reload
      check_page_content
    end
  end

  def go_to_route_page
    @browser.goto(config[:start_page])

    if config[:login]
      @id_prefix = LOGGED_IN_ID_PREFIX
      go_through_login_page
    else
      @id_prefix = NOT_LOGGED_IN_ID_PREFIX
      @browser.link(text: /Расписание движения и стоимость проезда/).click
    end
  end

  def go_through_login_page
    @browser.link(text: /Вход в систему/).click
    @browser.text_field(id: 'login').set(config[:login][:username])
    @browser.text_field(id: 'password').set(config[:login][:password])
    @browser.button(name: '_login').click
    @browser.checkbox(id: id("form1:conf")).click
  end

  def enter_data
    @browser.text_field(id: id("form1:textDepStat")).set(config[:from])
    @browser.text_field(id: id("form1:textArrStat")).set(config[:to])
    @browser.text_field(id: id("form1:dob")).set(config[:when])
    @browser.button(id: id("form1:buttonSearch")).click
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

  def reload
    # go back to the first page and then reenter data
    @browser.link(id: id('viewFragmentT:linkSel1')).click
    enter_data
  end

  def check_page_content
    raise "Broken page" unless @browser.span(id: id("text1")).text == "Маршрут следования пассажира:" &&
                               @browser.span(id: id("textRoute")).text == "#{config[:from]} - #{config[:to]}" &&
                               @browser.span(id: id("text2")).text == "Дата отправления:" &&
                               @browser.span(id: id("textDate")).text == config[:when]
  end

  def id(suffix)
    "#{@id_prefix}:#{suffix}"
  end

  def find_train_row(train)
    link = @browser.link(:onclick, /#{train}/)
    link.parent.parent
  rescue => e
    Console.debug(e)
    nil
  end

  def ticket_count(train_row, type)
    cell_index = CELL_INDECES[type]
    cell = train_row.cell(index: cell_index)
    span = cell.span(id: /#{ id("form2:tableEx1:.:text2#{ cell_index-7 }") }/) # . is for row index
    begin
      text = span.text
      text.strip.to_i
    rescue => e
      0
    end
  end
end

class TestApp < App
  def start
    NotificationSystem::Notifier.new.notify(config[:notify], :m, '42 МИНСК - МЕЛЬБУРН', 'Минск', 'Мельбурн', 'Сегодня')
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

  opts.on('-t', '--test', 'Test configured notifications and exit') do
    $TEST = true
  end
end

begin
  options.parse!
rescue OptionParser::InvalidOption
  puts options
  exit 1
end

Console.puts "Reading configuration file"
config_file = ARGV[-1]
unless config_file
  puts options
  exit 1
end

app = if $TEST
        TestApp.new(config_file)
      else
        App.new(config_file)
      end
app.start
