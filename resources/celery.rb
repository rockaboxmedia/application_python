#
# Author:: Noah Kantrowitz <noah@opscode.com>
# Cookbook Name:: application_python
# Resource:: celery
#
# Copyright:: 2011, Opscode, Inc <legal@opscode.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

include Chef::Resource::ApplicationBase

attribute :config_module, :kind_of => [String, NilClass], :default => nil
attribute :template, :kind_of => [String, NilClass], :default => nil# for config file
attribute :django, :kind_of => [TrueClass, FalseClass], :default => false
attribute :celeryd, :kind_of => [TrueClass, FalseClass], :default => true
attribute :celerybeat, :kind_of => [TrueClass, FalseClass], :default => false
attribute :celerycam, :kind_of => [TrueClass, FalseClass], :default => false
attribute :camera_class, :kind_of => [String, NilClass], :default => nil
attribute :flower, :kind_of => [TrueClass, FalseClass], :default => false
attribute :flower_port, :kind_of => [Integer, NilClass], :default => nil
attribute :requirements, :kind_of => [NilClass, String, FalseClass], :default => nil
attribute :virtualenv_options, :kind_of => String, :default => "--distribute"

def config_base
  config_module.split(/[\\\/]/).last
end

def config(*args, &block)
  @config ||= Mash.new
  @config.update(options_block(*args, &block))
  @config
end

def virtualenv
  "#{path}/shared/env"
end

# make possible to define a before_deploy block in user recipe
def before_deploy(arg=nil, &block)
  arg ||= block
  set_or_return(:before_deploy, arg, :kind_of => [Proc, String])
end