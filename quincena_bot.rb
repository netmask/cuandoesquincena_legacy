require './app.rb'
require 'slack-ruby-bot'


def silly_message
  SILLY_MESSAGES[rand(0..SILLY_MESSAGES.size - 1 )]
end

class QuincenaBot < SlackRubyBot::Bot
  command 'cuando es quincena?' do |client, data, match|
    quincena = Quincena.new Date.today
    client.say(text: "Faltan #{quincena.left_days} dias. #{silly_message}", channel: data.channel)
  end
end


QuincenaBot.run
