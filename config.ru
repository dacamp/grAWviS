require 'rubygems'
require 'bundler'
Bundler.require(:default)
require 'sass/plugin/rack'
require './grawsviz_app'

# use scss for stylesheets
Sass::Plugin.options[:style] = :expanded
use Sass::Plugin::Rack

run Sinatra::Application