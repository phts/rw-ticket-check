require 'watir-webdriver'
require_relative "console"
require_relative "notification_system"

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

  def initialize(config_file, debug_mode)
    console.puts "Reading configuration file #{config_file.inspect}"
    YAML::ENGINE.yamler = 'psych'
    File.open(config_file) do |f|
      @config = DEFAULTS.merge(YAML::load(f))
    end
    console.debug config.to_yaml
    @debug_mode = debug_mode
  end

  def start
    console.puts "Starting the browser"
    client = Selenium::WebDriver::Remote::Http::Default.new
    client.timeout = TIMEOUT # seconds – default is 60
    @browser = Watir::Browser.new(:firefox, :http_client => client)
    start_main_loop
  end

  private

  def start_main_loop
    loop do
      begin
        console.puts "Navigating to the start page #{config[:start_page].inspect}"
        go_to_route_page

        console.puts "Entering data"
        enter_data

        console.puts "Working..."
        start_working_loop

      rescue Errno::ECONNREFUSED => e
        console.puts "Browser was closed. Exiting"
        console.debug(e)
        break
      rescue Timeout::Error => e
        console.puts "Timeout #{TIMEOUT} sec. Starting from scratch in #{config[:delay]} sec"
        console.debug(e)
        sleep(config[:delay])
        retry
      rescue => e
        console.puts "Page is broken. Starting from scratch in #{config[:delay]} sec"
        console.debug(e)
        sleep(config[:delay])
        if @debug_mode
          console.puts("Debug mode: Stopped. Press Enter to continue")
          STDIN.gets
        end
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

      console.puts "#{Time.new.to_s} sleep #{config[:delay]} seconds and then reload"
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
    console.print "  #{train}"
    train_row = find_train_row(train)
    unless train_row
      console.puts " not found"
      return
    end

    @previous_numbers ||= {}
    @previous_numbers[train] ||= {}

    types.each do |type|
      current_number = ticket_count(train_row, type)
      console.print "  #{type}:#{current_number}"
      if current_number > @previous_numbers[train][type].to_i
        console.puts
        yield(type) if block_given?
      end
      @previous_numbers[train][type] = current_number
    end
    console.puts
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
    console.debug(e)
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
