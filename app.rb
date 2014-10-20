# encoding: utf-8

require 'bundler'
Bundler.require

require 'webrick'
require 'webrick/httpproxy'
require 'pathname'
require 'erb'
require 'pp'

def target_uri? uri
  uri.host =~ %r`gbf\..+\.mbga\.jp`
end

def target_content? res
  res['content-type'] =~ /image/ || res['content-type'] =~ /audio/
end

def valid_content? res
  res.body
end

def cache_path uri
  Pathname.new "./cache/#{ ERB::Util.url_encode uri.to_s }"
end


def h str, color
  @h ||= HighLine.new
  @h.color str, color
end

handler = Proc.new() {|req, res|
  if target_uri?(req.request_uri) && target_content?(res) && valid_content?(res)
    cache_path = cache_path req.request_uri
    File.write(cache_path, res.body) unless File.exists? cache_path
    puts h "cache created: #{ req.unparsed_uri }", :blue
  end
}

callback = Proc.new {|req, res|
  cache_path = cache_path req.request_uri
  if target_uri?(req.request_uri) && File.exists?(cache_path)
    puts h "cache found: #{ req.unparsed_uri }", :green
    res.body = File.read cache_path
    raise WEBrick::HTTPStatus::OK
  end
}

s = WEBrick::HTTPProxyServer.new(
  BindAddress: '127.0.0.1',
  Port: 8080,
  Logger: WEBrick::Log::new(nil, 0),
  AccessLog: WEBrick::Log.new(nil, 0),
  ProxyVia: false,
  ProxyContentHandler: handler,
  RequestCallback: callback
)

Signal.trap(:INT) { s.shutdown }
Signal.trap(:TERM) { s.shutdown }

s.start

puts :hi

