#
# Author:: Noah Kantrowitz <noah@opscode.com>
# Cookbook Name:: application_python
# Provider:: django
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

require 'chef/mixin/shell_out'
include Chef::Mixin::LanguageIncludeRecipe
include Chef::Mixin::ShellOut

def make_python_command(commands)
  if not commands.respond_to? 'join'
    commands = [commands]
  end
  commands.map! {|cmd| "#{::File.join(new_resource.virtualenv, "bin", "python")} #{cmd}"}
  commands.join " && "
end

# -----------
# the actions below look like they should automatically happen
# but they rely on hack in application/providers/default.rb to
# get them called when 'django' is used as a sub-resource
# -----------

action :before_compile do
  include_recipe 'python'

  migration_cmd = (new_resource.migration_command) ? new_resource.migration_command : "manage.py syncdb --noinput"
  new_resource.migration_command make_python_command(migration_cmd)

  new_resource.symlink_before_migrate.update({
    new_resource.local_settings_base => new_resource.local_settings_file,
  })
end

action :before_deploy do
  install_packages
  created_settings_file
end

action :before_migrate do
  install_requirements
end

action :before_symlink do
  if new_resource.collectstatic
    cmd = new_resource.collectstatic.is_a?(String) ? new_resource.collectstatic : "collectstatic --noinput"
    execute "#{::File.join(new_resource.virtualenv, "bin", "python")} manage.py #{cmd}" do
      user new_resource.owner
      group new_resource.group
      cwd new_resource.release_path
    end
  end

  ruby_block "remove_run_migrations" do
    block do
      if node.role?("#{new_resource.application.name}_run_migrations")
        Chef::Log.info("Migrations were run, removing role[#{new_resource.name}_run_migrations]")
        node.run_list.remove("role[#{new_resource.name}_run_migrations]")
      end
    end
  end
end

# these blocks need to be here to avoid spurious errors
# although currently they don't need to do anything

action :before_restart do
end

action :after_restart do
end

protected

def install_packages
  python_virtualenv new_resource.virtualenv do
    path new_resource.virtualenv
    action :create
  end

  new_resource.packages.each do |name, ver|
    python_pip name do
      version ver if ver && ver.length > 0
      virtualenv new_resource.virtualenv
      action :install
    end
  end

  if new_resource.packages
    new_resource.updated_by_last_action(true)
  end
end

def install_requirements
  if new_resource.requirements.nil?
    # look for requirements.txt files in common locations
    [
      ::File.join(new_resource.release_path, "requirements", "#{node.chef_environment}.txt"),
      ::File.join(new_resource.release_path, "requirements.txt")
    ].each do |path|
      Chef::Log.info("Trying requirements path: " + path)
      if ::File.exists?(path)
        new_resource.requirements path
        break
      end
    end
  end
  if new_resource.requirements
    # The cleanest way to use pip here would be to use the python/pip resource but
    # that is a package-centric resource not a generic wrapper on pip so we can't
    # use it to just `pip install -r requirements.txt`
    # So, we copy and paste some relevant bits of code instead...
    timeout = 900
    Chef::Log.info("Running: pip install -r #{new_resource.requirements}")
    cmd = shell_out!("#{pip_cmd(new_resource)} install -r #{new_resource.requirements}", :timeout => timeout)
    if cmd
      new_resource.updated_by_last_action(true)
    end
  else
    Chef::Log.info("No requirements file found")
  end
end

def created_settings_file
  host = new_resource.find_database_server(new_resource.database_master_role)

  template "#{new_resource.path}/shared/#{new_resource.local_settings_base}" do
    source new_resource.settings_template || "settings.py.erb"
    cookbook new_resource.settings_template ? String(new_resource.cookbook_name) : "application_python"
    owner new_resource.owner
    group new_resource.group
    mode "644"
    variables new_resource.settings.clone
    variables.update :debug => new_resource.debug, :databases => new_resource.databases,
      :legacy_database_settings => new_resource.legacy_database_settings,
      :default_database_host => host
  end
end

# copy and pasted from 'python' cookbook 'pip' provider, because Chef sucks
def pip_cmd(nr)
  if (nr.respond_to?("virtualenv") && nr.virtualenv)
    ::File.join(nr.virtualenv,'/bin/pip')
  elsif "#{node['python']['install_method']}".eql?("source")
    ::File.join("#{node['python']['prefix_dir']}","/bin/pip")
  else
    'pip'
  end
end
