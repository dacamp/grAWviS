require 'sinatra'

$LOAD_PATH.unshift( File.join( File.dirname(__FILE__), 'lib' ) )
require 'grawsviz'

get '/' do
  erb :index
end

get '/index' do
  redirect to("/")
end

get '/account/:account/?:node?' do
  opts = {}
  var = ENV.select{ |e| e =~ /^#{params[:account]}.+AWS.*/i }
  var.map{ |k,v|
    if k =~ /secret/i
      opts[:secret_key] = v
    else
      opts[:access_key] = v
    end
  }

  if params[:node]
    opts.merge!({:group_names => [params[:node]].flatten})
  end

  gr = GrAWSViz.new(opts)
  gr.generate_graph
  erb :groups, :locals => { :file => gr.file_name }
end
