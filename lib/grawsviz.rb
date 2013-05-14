require 'rubygems'
require 'aws-sdk'
require 'graphviz'
require 'json'

$LOAD_PATH.unshift(File.expand_path(File.dirname(__FILE__)))  unless
  $LOAD_PATH.include?(File.expand_path(File.dirname(__FILE__)))
require 'constants'

class GrAWSViz
  attr_accessor :title, :fmt, :force
  attr_reader :file_name, :owner_id

  def initialize(opts={})
    aws_keys( {:access_key_id => (opts[:access_key] || ENV['AWS_ACCESS_KEY_ID']),
               :secret_access_key => (opts[:secret_key] || ENV['AWS_SECRET_ACCESS_KEY']) })

    @force   = opts[:force]
    if (opts[:group_names] ||= []).any?
      params   = {:group_names => opts[:group_names]}
      @force = true
    end
    @sg_info = ec2.client.describe_security_groups(params)[:security_group_info]
    @title   = opts[:group_names].any? ?  opts[:group_names].join(', ') : owner_id
    @fmt     = (opts[:format] ||= :svg).to_s

    File.open('/tmp/sg_info', 'w') { |f| f.puts JSON.pretty_generate(@sg_info) } # debug-ish
  end

  def generate_graph
    cache_current? || _generate_graph
  end

  def cache_current?
    return nil if @force
    (Time.now - File.mtime(file_name)) < 3600.to_f
  rescue Errno::ENOENT
    return nil
  end

  def map_instances
    @sg_instances ||= _map_instances
  end

  def graph
    @graph ||= GraphViz.new( @title )
  end

  def owner_id
    @owner_id ||= @sg_info.find{ |g| g[:owner_id] }[:owner_id]
  end

  # This is really ugly
  def compiled_groups
    @sg_info.collect { |g|
      [{:node => "#{g[:group_name] || find_name(g[:user_id]) || g[:user_id]} (#{g[:group_id]})", :owner_id => g[:owner_id], :sg_id => g[:group_id]}] +
      g[:ip_permissions].collect{ |p|
        p[:groups].map { |gg|
          { :node => "#{gg[:group_name] || find_name(g[:user_id])} (#{gg[:group_id]})", :owner_id => gg[:user_id], :sg_id => gg[:group_id] }
        }
        p[:ip_ranges].map  { |ip|
          { :node => ip[:cidr_ip], :owner_id => ip[:cidr_ip] }
        }
      }
    }.flatten.uniq { |a| a[:node] }
  end

  def node_count(id)
    (@sg_instances[id] || []).count
  end

  def generate_nodes
    compiled_groups.map { |g|
      fontcolor = { :fontcolor => 'red' }  if node_count(g[:sg_id]) == 0 and g[:node] =~ /.*\(.*\)/
      graph.add_node( find_name(g[:node]), create_style(g[:owner_id].to_s, {:style => "filled,rounded", :shape => :box, "URL" => "/account/#{find_name(g[:owner_id])}/#{find_name(g[:node]).split(/\s+/).first}" }.merge!(fontcolor || {}) ) )
    }
  end

  # Also really ugly
  def parse
    seen = []
    @sg_info.each do |sg|
      o_id = sg[:owner_id]
      sg_node  = "#{sg[:group_name]} (#{sg[:group_id]})"

      sg[:ip_permissions].each do |p|
        port_range = [p[:from_port], p[:to_port]].uniq.join("-")
        port_range = '*' if port_range.empty?

        p[:groups].each do |g|
          if g_node  = "#{g[:group_name] || find_name(g[:user_id])} (#{g[:group_id]})"
            if ! graph.get_node(g_node)
              graph.add_node( find_name(g_node), create_style(g[:user_id].to_s, {:style => "filled,rounded", :shape => :box, "URL" => "/account/#{find_name(g[:user_id])}/#{g[:group_name]}" } ) )
            end

            if ! graph.get_node(sg_node)
              graph.add_node( find_name(sg_node), create_style(sg[:owner_id].to_s, {:style => "filled,rounded", :shape => :box, "URL" => "/account/#{find_name(g[:user_id])}/#{sg[:group_name]}"} ) )
            end

            graph.add_edge(g_node, sg_node, create_style( g[:user_id], {:color => 'red', :style => 'filled, rounded', :label => port_range} ) )
          end
        end

        p[:ip_ranges].each do |cidr|
          from, to = find_name(cidr[:cidr_ip]), sg_node
          next if seen.include? [from, to, port_range]
          seen.push([from, to, port_range])
          graph.add_edge(from, to, create_style( from, { :label => port_range } ) )
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

  def file_name
    @file_name ||= "images/#{_file_name}"
  end

  ## Private Methods
  def _generate_graph
    file_maintenance
    map_instances
    generate_nodes
    parse
    graph.output( @fmt => file_name )
  end

  def _map_instances
    sg = {}
    ec2.client.describe_instances[:reservation_set].map { |r|
      r[:instances_set].map{ |i|
        r[:group_set].map{ |s|
          (sg[s[:group_id]] ||= []) << i[:instance_id]
        }
      }
    }
    sg
  end
  private :_map_instances

  def file_maintenance
    return nil if ! File.exists?(file_name)
    File.exists?(base_dir + "/archive") || Dir.mkdir(base_dir + "/archive")
    File.rename "#{file_name}",
    "#{base_dir}/archive/#{_file_name}.#{File.mtime(file_name).strftime("%Y%M%d-%H%M")}"
  end
  private :file_maintenance

  def _file_name
    "#{@title}-security-groups.#{@fmt}"
  end
  private :_file_name

  def base_dir
    File.expand_path(File.dirname(file_name))
  end
  private :base_dir

  def ec2
    @ec2 ||= AWS::EC2.new
  end
  private :ec2

  def aws_keys(opts={})
    AWS.config(opts)
  end
  private :aws_keys


end
