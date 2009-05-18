require 'rubygems'
require 'xmpp4r'
require 'newzbin'
require 'erb'

include ERB::Util

module Commands
  class User
    attr_accessor :config, :logger

    def initialize(config, logger)
      @config = config
      @logger = logger
    end

    def process(client, msg)
      unless is_user(msg)
        report_non_user(client, msg)
        return false
      end

      case msg.body
      when /^help/
        return true
      else
        @logger.info "Searching for \"#{msg.body}\""
        m = Jabber::Message.new(msg.from, "Searching for #{msg.body}...")
        m.type = msg.type
        client.send(m)

        n = Newzbin::Connection.new(@config['newzbin_username'], @config['newzbin_password'])
        res = n.search(:q => msg.body).first(5)
        m = prepare_results(res, msg)
        client.send(m)

        return true
      end
    end

    private
    def is_user(msg)
      return true if msg.from.bare.to_s == @config['admin']

      begin
        u = ::User.find(:first, :conditions => { :email => msg.from.bare.to_s, :active => "true" })
        return u
      rescue CouchFoo::DocumentNotFound => e
        return false
      end
    end

    def report_non_user(client, msg)
      txt = "You're not allowed to use this service yet. Please wait for authorization"
      m = Jabber::Message.new(msg.from, txt)
      m.type = msg.type
      client.send(m)
    end

    def prepare_results(nzbs, msg)
      if nzbs.empty?
        m = Jabber::Message.new(msg.from, "No results found")
        m.type = msg.type
        return m
      end

      txt = nzbs.inject("") do |res, nzb|
        res << "\n#{nzb.title} [#{nzb.category}] [#{nzb.size_in_bytes.to_i.to_human}]"
      end.chomp
      m = Jabber::Message.new(msg.from, txt)
      m.type = msg.type

      h = REXML::Element::new("html")
      h.add_namespace('http://jabber.org/protocol/xhtml-im')
      b = REXML::Element::new("body")
      b.add_namespace('http://www.w3.org/1999/xhtml')

      template = %q{
          <% nzbs.each do |nzb| %>
            <p>
              <%= h nzb.title %>
              [<%= h nzb.category %>]
              [<%= h nzb.size_in_bytes.to_i.to_human %>]
              [<a href="http://www.newzbin.com/browse/post/<%= nzb.id %>">link</a>]
            </p>
          <% end %>
      }
      html = ERB.new(template).result(binding)
      t = REXML::Text.new(html, false, nil, true, nil, %r/.^/)
      b.add(t)
      h.add(b)
      m.add_element(h)
      m
    end
  end
end

class Numeric
  def to_human
    units = %w{B KB MB GB TB}
    e = (Math.log(self)/Math.log(1024)).floor
    s = "%.1f" % (to_f / 1024**e)
    s.sub(/\.?0*$/, units[e])
  end
end
