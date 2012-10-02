#
# Author:: Noah Kantrowitz <noah@opscode.com>
# Cookbook Name:: application_python
# Resource:: django
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

attribute :database_master_role, :kind_of => [String, NilClass], :default => nil
attribute :packages, :kind_of => [Array, Hash], :default => []
attribute :requirements, :kind_of => [NilClass, String, FalseClass], :default => nil
attribute :legacy_database_settings, :kind_of => [TrueClass, FalseClass], :default => false
attribute :settings, :kind_of => Hash, :default => {}
# Actually defaults to "settings.py.erb", but nil means it wasn't set by the user
attribute :settings_template, :kind_of => [String, NilClass], :default => nil
attribute :local_settings_file, :kind_of => String, :default => 'local_settings.py'
attribute :debug, :kind_of => [TrueClass, FalseClass], :default => false
attribute :collectstatic, :kind_of => [TrueClass, FalseClass, String], :default => false
attribute :settings_module, :kind_of => String, :default => "settings"
attribute :manage_py_migration_commands, :kind_of => Array, :default => ['syncdb --noinput']
attribute :virtualenv_options, :kind_of => String, :default => "--distribute"
attribute :django_superusers, :kind_of => Array, :default => []

def local_settings_base
  local_settings_file.split(/[\\\/]/).last
end

def virtualenv
  "#{path}/shared/env"
end

def database(db_name='default', &block)
  # add a new db to django settings
  # 
  # block attrs are turned into a hash and ultimately passed through
  # to the template as a hash of hashes under the :databases key
  # (see providers/django.rb create_settings_file method)
  @databases ||= {}
  db ||= Mash.new
  db.update(options_block(&block))
  @databases[db_name] = db
  db
end

def create_wsgi(path="conf/django.wsgi", &block)
  # optionally specify details for an auto-generated wsgi file
  # (defaults to django.wsgi.erb, or pass `template` via block)
  #
  # block attrs are turned into a hash and ultimately passed through
  # to the template under the :wsgi_vars key
  # (see providers/django.rb create_wsgi_file method)
  @wsgi ||= Mash.new
  @wsgi[:path] = path
  @wsgi.update(options_block(&block))
  @wsgi
end

# have to wrap @ attributes in getter methods if you want to
# be able to access them from inside the provider
# (some weird quirk of the Chef LWRP DSL)

def databases
  @databases
end

def wsgi
  @wsgi
end