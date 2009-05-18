require 'rubygems'
require 'xmpp4r'

module Commands
  class Admin
    attr_accessor :config, :logger

    def initialize(config, logger)
      @config = config
      @logger = logger
    end

    def process(client, msg)
      return false unless is_admin(msg)

      case msg.body
      when /^list$/
        users = ::User.find(:all, :conditions => { :active => "false" })
        txt = users.inject("") do |res, user| 
          res << "\n[#{user.id}] #{user.email}, #{user.created_at}"
        end.chomp

        if users.empty?
          txt = "No users need activation. Please try again later"
        end

        m = Jabber::Message.new(msg.from, txt)
        m.type = msg.type
        client.send(m)

        return true
      when /^accept (.+)$/
        begin
          user = ::User.find($1)
          user.active = "true"
          user.save

          txt = "#{user.email} is just activated"
          m = Jabber::Message.new(msg.from, txt)
          m.type = msg.type
          client.send(m)
        rescue CouchFoo::DocumentNotFound => e
          txt = "[erro] no user found with that id"
          m = Jabber::Message.new(msg.from, txt)
          m.type = msg.type
          client.send(m)
        end

        return true
      else
        return false
      end
    end

    private
    def is_admin(msg)
      msg.from.to_s.include?(@config['admin'])
    end
  end
end
