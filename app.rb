require 'bundler/setup'
Bundler.require *[:default, ENV['RACK_ENV']].compact

require 'digest/sha1'

### Settings

enable :logging

configure :development do
  use BetterErrors::Middleware
  BetterErrors.application_root = __dir__
end

set :cache, Dalli::Client.new(nil, expires_in: 60 * 60 * 24) # == 1 day

### Helpers and Utilities

helpers do
  def app_url(id='')
    "#{request.scheme}://#{request.host_with_port}/#{id}"
  end
end

def generate_id
  chars = ('A'..'Z').to_a + ('a'..'z').to_a
  (3..20).each do |length|
    10.times do
      id = chars.sample(length).join
      return id unless settings.cache.get(id)
    end
  end
  nil
end

### Filters

before do
  content_type :text
end

# For CUI friendliness
after do
  if response.body && response.body.last !~ /\n$/
    response.body << "\n"
  end
end

### Actions

get '/' do
  resp = <<-END
VAPORBIN(1)                        exsen.org                       VAPORBIN(1)

NAME
        vaporbin - a pastebin its contents evaporate

SYNOPSIS
        <command> | curl -F 'text=<-' #{app_url}
        curl #{app_url('<key>')}
        curl -X DELETE #{app_url('<key>')}

DESCRIPTION
        Vaporbin is a command line pastebin. A paste will be stored no longer
        than 24 hours and deleted occasionally to fit within the disk quota,
        which is currently 25MB, on a least-recently-used basis.

EXAMPLES
        $ echo Hello | curl -F 'text=<-' #{app_url}
        #{app_url('FoO')}
        $ curl #{app_url('FoO')}
        Hello
        $ curl -X DELETE #{app_url('FoO')}
        Deleted

        Or, with handy functions,

        $ eval `curl #{app_url('--function')}`
        $ echo Hello | netcopy
        #{app_url('bAR')}
        $ netpaste bAR
        Hello

AUTHOR
        @uasi

SEE ALSO
        #{app_url('--function')}

ACKNOWLEDGMENTS
        Vaporbin is inspired by sprunge.us.
  END
  # Poor browser detection
  if request.user_agent =~ /Mozilla|Lynx|w3m/
    content_type :html
    resp = <<-END
      <body><pre><samp>#{Rack::Utils.escape_html(resp)}</samp></pre></body>
    END
  end
  resp
end

get %r{^/(?:-f|--?function)$} do
  <<-END
netcopy() { curl -F "text=<-" "#{app_url}"; }
netpaste() { curl "#{app_url}$1"; }
  END
end

get '/:id' do
  settings.cache.get(params[:id]) || [404, 'Not Found']
end

post '/' do
  content = params[:text] || params[:file]
  if content.length > 100 * 1024 # == 100KB
    halt 413, 'Content Length Must Be Less Than 100KB'
  end
  id = generate_id or halt 500, 'You Overwhelmed The Randomness'
  settings.cache.set(id, content)
  [201, "#{request.scheme}://#{request.host_with_port}/#{id}"]
end

post '/:id/delete' do
  delete_entry(params[:id])
end

delete '/:id' do
  delete_entry(params[:id])
end

def delete_entry(id)
  settings.cache.delete(id) ? 'Deleted' : [404, 'Not Found']
end
