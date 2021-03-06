# encoding: utf-8

require 'cinch'
require 'bunny'
require 'time'

class HAL
    include Cinch::Plugin

    set :help, "Indique ce qui se passe au hackerspace"

    TRIGGERS_TEXTS = {
        'door' => "La porte des escaliers s'ouvre...",
        'bell' => "On sonne à la porte !",
        'radiator' => "Le radiateur est allumé",
        'hs_open' => "Le hackerspace est ouvert ! RAINBOWZ NSA PONEYZ EVERYWHERE \\o/",
        'hs_close' => "Le hackerspace est fermé ! N'oubliez pas d'éteindre les lumières et le radiateur."
    }

    def speakMessage msg
        msgtime = Time.parse msg['time']

        #Drop messages older than 2 mins
        if Time.now-msgtime > 120 || ! TRIGGERS_TEXTS.key?(msg['trigger'])
            bot.info "Drop message #{msg}"
            return
        end

        bot.channels.first.send TRIGGERS_TEXTS[msg['trigger']]
    end

    listen_to :connect, :method => :start
    def start *args
        begin
            amq_conn = Bunny.new config[:amq_server]
            amq_conn.start
            bot.info "Got connection to AMQ server"

            chan = amq_conn.create_channel
            queue = chan.queue config[:amq_queue]
            bot.info "Got queue #{config[:amq_queue]}"

            queue.subscribe do |delivery_info, metadata, payload|
                data = JSON.parse payload
                if data.key?('trigger') && data.key?('time')
                    speakMessage data
                  end
            end
        rescue Bunny::TCPConnectionFailed, Bunny::AuthenticationFailureError
              bot.debug "Unable to connect to RabbitMQ server. No events for this instance !"
        end
    end
end