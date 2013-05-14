require 'sinatra'

$LOAD_PATH.unshift(File.expand_path(File.dirname(__FILE__)))
require 'grawsviz'

@access_key = ARGV[0] || ENV['AWS_ACCESS_KEY_ID']
@secret_key = ARGV[1] || ENV['AWS_SECRET_ACCESS_KEY']

get '/' do
  gr = GrAWSViz.new(@access_key, @secret_key)
  gr.generate_graph
  redirect to("/view?file=#{gr.file_name}")
end

get '/view' do
  type="image/svg+xml"
  File.read(File.join(File.expand_path(File.dirname(__FILE__)) << "/../", params[:file]))
end

get '/node/:n' do
  gr = GrAWSViz.new(@access_key, @secret_key, {:group_names => [params[:n]].flatten})
  gr.generate_graph
  redirect to("/view?file=#{gr.file_name}")
end

