$:.unshift File.dirname(__FILE__)

require 'rubygems'
require 'users'
require 'xmpp4r'
require 'xmpp4r/roster'
require 'commands'
require 'logger'
require 'yaml'

current_thread = Thread.current
config = YAML.load_file(File.join(File.dirname(__FILE__), 'config.yml'))
logger = Logger.new(File.join(File.dirname(__FILE__), config['log']))

Jabber.debug = true if ENV['DEBUG']
jid = Jabber::JID.new(config['jid'])
client = Jabber::Client.new(jid)
client.connect
client.auth(config['password'])
client.send(Jabber::Presence.new.set_status("newzbin robot"))

processors = [Commands::Admin.new(config, logger), Commands::User.new(config, logger)]
client.add_message_callback do |m|
  if m.type != :error
    logger.info "<< #{m.from.to_s}: '#{m.body}'"
    
    if m.body
      begin
        unless processors.any? { |p| p.process(client, m) }
          # couldn't process the message
          logger.info "[unknown message] couldn't process msg from #{m.from.to_s}: #{m.body}"
        end
      rescue => e
        logger.warn e
      end
    end
  else
    logger.warn [m.type.to_s, m.body].join(': ')
  end
end

client.add_presence_callback do |m|
  case m.type
  when nil # status :available
    logger.info "[presence] #{m.from} is available"
  when :unavailable
    logger.info "[presence] #{m.from} is unavailable"
  end
end

roster = Jabber::Roster::Helper.new(client)
roster.add_subscription_request_callback do |item, pres|
  logger.info "[roster] accepting authorization request from #{pres.from.to_s}"
  roster.accept_subscription(pres.from)
  item.subscribe

  u = ::User.find(:first, :conditions => { :email => pres.from.bare.to_s }) rescue nil
  unless u
    User.create(:email => pres.from.to_s, :active => "false", :created_at => Time.now)

    text = "Please authorize new user #{pres.from.to_s}"
    destination = Jabber::JID.new(config['admin'])
    msg = Jabber::Message.new(destination, text)
    client.send(msg)
  end
end

Thread.stop
client.close
