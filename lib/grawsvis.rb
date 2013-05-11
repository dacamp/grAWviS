#!/usr/bin/env ruby

require 'rubygems'
require 'aws-sdk'
require 'graphviz'
require 'json'

$LOAD_PATH.unshift(File.expand_path(File.dirname(__FILE__)))
require 'constants'

class GrAWSViz
  def initialize(access_key, secret_key)
    ec2      = AWS::EC2.new(:access_key_id => access_key, :secret_acces_key => secret_key)
    @sg_info = ec2.client.describe_security_groups()[:security_group_info]
    @graph   = GraphViz.new( :G )
    File.open('/tmp/sg_info', 'w') { |f| f.puts JSON.pretty_generate(@sg_info) }
  end

  def generate_graph
    generate_nodes
    parse
    @graph.output( :png => png_name )
  end

  def owner_id
    @owner_id ||= @sg_info.collect{ |g| g[:owner_id] }.uniq
  end

  def compiled_groups
    @sg_info.collect { |g|
      [{:node => "#{g[:group_name] || find_name(g[:user_id]) || g[:user_id]} (#{g[:group_id]})", :owner_id => g[:owner_id]}] +
      g[:ip_permissions].collect{ |p|
        p[:groups].map { |gg|
          { :node => "#{gg[:group_name] || find_name(g[:user_id])} (#{gg[:group_id]})", :owner_id => gg[:user_id] }
        }
        p[:ip_ranges].map  { |ip|
          { :node => ip[:cidr_ip], :owner_id => ip[:cidr_ip] }
        }
      }
    }.flatten.uniq { |a| a[:node] }
  end

  def generate_nodes
    compiled_groups.map { |g|
      @graph.add_node( find_name(g[:node]), create_style(g[:owner_id].to_s, {:style => "filled,rounded", :shape => :box } ) )
    }
  end

  def parse
    seen = []
    @sg_info.each do |sg|
      owner_id = sg[:owner_id]
      sg_node  = "#{sg[:group_name]} (#{sg[:group_id]})"

      sg[:ip_permissions].each do |p|
        port_range = [p[:from_port], p[:to_port]].uniq.join("-")
        port_range = '*' if port_range.empty?

        p[:groups].each do |g|
          if g_node  = "#{g[:group_name] || find_name(g[:user_id])} (#{g[:group_id]})"
            @graph.add_edge(g_node, sg_node, create_style( g[:user_id], {:color => 'red', :style => 'filled, rounded', :label => port_range} ) )
          end
        end

        p[:ip_ranges].each do |cidr|
          from, to = find_name(cidr[:cidr_ip]), sg_node
          next if seen.include? [from, to, port_range]
          seen.push([from, to, port_range])
          @graph.add_edge(from, to, create_style( from, { :label => port_range } ) )
        end
      end
    end
  end

  def create_style(v, opts = {})
    opts.merge!(KNOWN_STYLES[find_name(v)])
  end

  def find_name(val)
    KNOWN_NAMES[val.to_s] || val.to_s
  end
  private :find_name

  def png_name
    file_increment("#{owner_id}-security-groups.png")
  end
  private :png_name

  def file_increment(path)
    while File.exists?(path)
      _, fn, c, fe = *path.match(/(\A.*?)(?:\.(\d+))?(\.[^.]*)?\Z/)
      c = (c || '0').to_i + 1
      path = "#{fn}.#{c}#{fe}"
    end
    return path
  end
  private :file_increment

end

access_key = ARGV[0] || ENV['AWS_ACCESS_KEY_ID']
secret_key = ARGV[1] || ENV['AWS_SECRET_ACCESS_KEY']
GrAWSViz.new(access_key, secret_key).generate_graph
