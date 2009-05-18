require 'rubygems'
require 'net/http'
require 'cgi'
require 'xmlsimple'

module Newzbin
  class NZBLimitError < StandardError
  end
  
  class Connection

    attr_accessor :host, :search_path
    

    def initialize(username, password)
      self.host = "http://#{username}:#{password}@www.newzbin.com"
      self.search_path = '/search/'
    end

    def http_get(path)
      Net::HTTP.get(URI.parse(path))
    end

    def request_url(params)
      params.delete_if {|key, value| (value == nil || value == '') }
      url = "#{self.host}#{self.search_path}?searchaction=Search&fpn=p&area=-1&order=desc&areadone=-1&feed=rss&u_nfo_posts_only=0&sort=ps_edit_date&order=desc&u_url_posts_only=0&u_comment_posts_only=0&u_v3_retention=9504000&commit=search"
      params.each_key do |key| url += "&#{key}=" + CGI::escape(params[key].to_s) end if params
      url
    end

    def search(params)
      nzbs = []
      response = XmlSimple.xml_in(http_get(request_url(params)), { 'ForceArray' => false })
      
      case response["channel"]["item"].class.name
      when "Array"
        response["channel"]["item"].each { |item| nzbs << Nzb.new(item)}
      when "Hash"
        nzbs << Nzb.new(response["channel"]["item"])
      end
      
      nzbs

    end
  end
  
  class Nzb
    attr_accessor :pub_date, :size_in_bytes, :category, :attributes, :title, :info_url, :id

    def initialize(details)
      self.pub_date = details["pubDate"]
      self.size_in_bytes = details["size"]["content"]
      self.category = details["category"]
      self.title = details["title"]
      self.id = details["id"]
      self.info_url = details["moreinfo"]
      self.attributes = {}
      

      case details["attributes"]["attribute"].class.name
      when "Array"
        details["attributes"]["attribute"].each do |attri|

          case self.attributes.has_key? attri["type"]
          when false
            self.attributes[attri["type"]] = attri["content"]
          when true
            self.attributes[attri["type"]] += ", #{attri["content"]}"
          end

        end
      end


    end
  end
    
end
