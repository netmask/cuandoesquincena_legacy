require 'active_support'
require 'sinatra'
require 'json'
require 'haml'
require 'business_time'
require 'net/http'
require 'uri'

I18n.load_path = Dir[File.join(settings.root, 'locales', '*.yml')]
I18n.backend.load_translations
I18n.default_locale = :es

configure :production do
  require 'newrelic_rpm'
end

SILLY_MESSAGES = ["¡Eso quisieras!",
                  "¡No hay para el abono de los zapatos!",
                  "¿Y el pago de Coppel?",
                  "Adivina: ¿Quién va a comer maruchanes los siguientes tres dias?"]

helpers do


  def silly_message
    SILLY_MESSAGES[rand(0..SILLY_MESSAGES.size - 1 )]
  end

  def class_by_days(days)
    style = case days
            when 11..15 then 'red'
            when 7..11 then 'orange'
            when 3..7 then 'yellow'
            when 0..3 then 'green'
            end

    "<div class='#{style} days-left'> #{days} </div>"
  end

  def class_for_times(quincena)
    style = case quincena.days
            when 13..14 then 'green'
            when 15..16 then 'orange'
            when 16..18 then 'red'
            end

    "<option class='#{style}'> #{quincena} </option>"

  end

  def quincena_animation
    ['<img src="http://static1.squarespace.com/static/517fecd4e4b051aa0c9066ee/t/51e40b73e4b046d0d00a0680/1373899638852/2012-02-15-651.gif?format=2500w" alt="Tunchis Tunchis Tunchis"/>',
          '<img src="/images/quincenabernygijon.jpg" alt="Tunchis Tunchis Tunchis"/>']
  end
end

class Quincena
  # 0 Is Sunday
  # 6 Is Sat
  NO_WORK_DAYS = {6 => 1, 0 => 2}

  attr_accessor :current_date, :days

  def initialize(current_date)
    self.current_date = current_date
  end

  def left_days
    (next_pay_date - self.current_date).to_i
  end

  def weekends_left
    (previews_pay_date..next_pay_date).to_a.select{ |day| NO_WORK_DAYS.keys.include?(day.wday) }.size / 2
  end

  def is_today?
    next_pay_date == Date.today
  end

  def past_month
    self.current_date.month - 1 == 0 ? 12 : (self.current_date.month - 1)
  end

  def previews_pay_date
    month = nil
    year = nil

    if past_canonical_day == -1
      month = past_month
      year = past_month == 12 ? self.current_date.year - 1 : self.current_date.year
    else
      month = self.current_date.month
      year = self.current_date.year
    end

    canonical = Date.civil(year, month , past_canonical_day)

    if NO_WORK_DAYS.keys.include?(canonical.wday)
      canonical = Date.civil(year, month, past_canonical_day - NO_WORK_DAYS[canonical.wday])
    end

    canonical
  end

  def next_pay_date
    canonical = Date.civil(self.current_date.year, self.current_date.month, next_canonical_day)

    if NO_WORK_DAYS.keys.include?(canonical.wday)
      canonical = Date.civil(self.current_date.year, self.current_date.month, next_canonical_day - NO_WORK_DAYS[canonical.wday])
    end

    canonical
  end

  def next_canonical_day
    current_date.day > 15 ? -1 : 15
  end

  def past_canonical_day
    current_date.day < 15 ? -1 : 15
  end

  def seconds_until
    next_pay_date.to_time.to_i - Time.now.to_i
  end

  def compare(quincena)
    self.days = (next_pay_date - quincena.next_pay_date).to_i
  end

  def silly
    (next_pay_date.to_time.to_i - Date.today.to_time.to_i) / 60 / 60 <= 96 && current_date.wday == 5
  end

  def to_s
    "Quincena #{I18n.l(next_pay_date, format: :human)} con #{self.weekends_left} fines de semana y #{self.days} dias"
  end
end

class DevilQuincenaCalculator
  def year_pay_dates
    today = Date.today

    dates = [Quincena.new(Date.civil(today.year.to_i - 1, 12, 16))]

    (1..12).step(1) do |month_number|
      [1, 16].each do |day|
        quincena = Quincena.new(Date.civil(today.year, month_number, day))
        quincena.compare(dates.last)

        dates << quincena
      end
    end

    dates.shift
    dates
  end
end

get '/' do
  @quincena = Quincena.new Date.today

  @year_quincenas = DevilQuincenaCalculator.new.year_pay_dates
  haml :index
end

get '/api', provides:[:json] do
  quincena = Quincena.new Date.today
  year_quincenas = DevilQuincenaCalculator.new.year_pay_dates

  {
    left_days: quincena.left_days,
      is_today: quincena.is_today?,
      next_pay_date: quincena.next_pay_date,
      weekends_left: quincena.weekends_left,
      year_pay_dates: year_quincenas
  }.to_json
end

get '/webhook/?' do
  if params['hub.verify_token'] == ENV['FACEBOOK_VERIFY_TOKEN']
    body params['hub.challenge']
  else
    status 404
    body 'nothing here!'
  end
end

post '/webhook/?' do
  payload = JSON.parse(request.body.read)
  payload['entry'].first['messaging'].each do | event |
    sender = event['sender']['id']

    if event['message'] && event['message']['text']
      reply(event['message']['text'], sender)
    end
  end
end


uri = URI.parse('https://graph.facebook.com/v2.6/me/messages')

def reply(text, sender)
  request = Net::HTTP::Post.new(uri, initheader = {'Content-Type' =>'application/json'})
  request.body = {
      recipient: {id: sender},
      message: { text: text }
  }

  response  = Net::HTTP.start(uri.hostname, uri.port) do |http|
    http.request(request)
  end

  puts response
end