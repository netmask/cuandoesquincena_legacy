require 'active_support'
require 'sinatra'
require 'json'
require 'haml'
require 'business_time'


helpers do
  def class_by_days(days)
    style = case days
            when 11..15 then 'red'
            when 7..11 then 'orange'
            when 3..7 then 'yellow'
            when 0..3 then 'green'
            end

    "<div class='#{style} days-left'> #{days} </div>"
  end
end

class Quincena
  # 0 Is Sunday
  # 6 Is Sat
  NO_WORK_DAYS = {6 => 1, 0 => 2}

  def left_days
    (next_pay_date - Date.today).to_i
  end

  def weekends_left
   (Date.today..next_pay_date).to_a.select{ |day| NO_WORK_DAYS.keys.include?(day.wday) }.size / 2
  end

  def is_today?
    next_pay_date == Date.today
  end

  def next_pay_date
    date_time = DateTime.now
    canonical = Date.civil(date_time.year, date_time.month, next_canonical_day)

    if NO_WORK_DAYS.keys.include?(canonical.wday)
      canonical = Date.civil(date_time.year, date_time.month, next_canonical_day - NO_WORK_DAYS[canonical.wday])
    end

    canonical
  end

  def next_canonical_day
    Date.today.day > 15 ? -1 : 15
  end
end

get '/' do
  @quincena = Quincena.new
  haml :index
end

get '/api', provides:[:json] do
  quincena = Quincena.new
  {
    left_days: quincena.left_days,
      is_today: quincena.is_today?,
      next_pay_date: quincena.next_pay_date,
      weekends_left: quincena.weekends_left
  }.to_json
end
