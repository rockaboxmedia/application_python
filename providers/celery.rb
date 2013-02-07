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

include Chef::Provider::ApplicationBase
include Chef::Mixin::LanguageIncludeRecipe
include Chef::Mixin::ShellOut

action :before_compile do

  include_recipe "supervisor"

  raise "You must specify config_module for your celery resource" unless new_resource.config_module

  if !new_resource.restart_command
    new_resource.restart_command do
      run_context.resource_collection.find(:supervisor_service => "#{new_resource.application.name}-celeryd").run_action(:restart) if new_resource.celeryd
      run_context.resource_collection.find(:supervisor_service => "#{new_resource.application.name}-celerybeat").run_action(:restart) if new_resource.celerybeat
      run_context.resource_collection.find(:supervisor_service => "#{new_resource.application.name}-celerycam").run_action(:restart) if new_resource.celerycam
      run_context.resource_collection.find(:supervisor_service => "#{new_resource.application.name}-flower").run_action(:restart) if new_resource.flower
    end
  end

  new_resource.symlink_before_migrate.update({
    new_resource.config_base => new_resource.config_module,
  })

end

action :before_deploy do
  python_virtualenv new_resource.virtualenv do
    path new_resource.virtualenv
    options new_resource.virtualenv_options
    action :create
  end

  # execute the before_deploy block defined in user recipe if present
  callback(:before_deploy, new_resource.before_deploy)

  if new_resource.django
    django_resource = new_resource.application.sub_resources.select{|res| res.type == :django}.first
    raise "No Django deployment resource found" unless django_resource
  end

  template ::File.join(new_resource.application.path, "shared", new_resource.config_base) do
    source new_resource.template || "celeryconfig.py.erb"
    cookbook new_resource.template ? new_resource.cookbook_name : "application_python"
    owner new_resource.owner
    group new_resource.group
    mode "644"
    variables :config => new_resource.config
  end

  cmds = {}
  cmds[:celeryd] = "celery worker #{new_resource.celerycam ? "-E" : ""}" if new_resource.celeryd
  cmds[:celerybeat] = "celerybeat" if new_resource.celerycam
  if new_resource.celerycam
    if new_resource.django
      cmd = "celerycam"
    else
      raise "No camera class specified" unless new_resource.camera_class
      cmd = "celeryev --camera=\"#{new_resource.camera_class}\""
    end
    cmds[:celerycam] = cmd
  end

  if new_resource.flower
    python_pip "flower" do
      if new_resource.django
        virtualenv django_resource.virtualenv
      else
        # how to resolve which virtualenv to use...?
        virtualenv new_resource.virtualenv
      end
      action :install
    end
    cmds[:flower] = "celery flower"# default port is 5555
    if new_resource.flower_port
      cmds[:flower] += " --port=#{new_resource.flower_port}"
    end
  end

  cmds.each do |type, cmd|
    supervisor_service "#{new_resource.application.name}-#{type}" do
      action :enable
      if new_resource.django
        command "#{::File.join(django_resource.virtualenv, "bin", "python")} manage.py #{cmd}"
      else
        command ::File.join(new_resource.virtualenv, "bin", cmd)
        environment({
          'CELERY_CONFIG_MODULE' => new_resource.config_module,
          'PYTHONPATH' => ::File.join(new_resource.release_path, "python")
        })
      end
      directory ::File.join(new_resource.path, "current")
      autostart false
      user new_resource.owner
    end
  end
end

action :before_migrate do
  install_requirements
end

action :before_symlink do
end

action :before_restart do
end

action :after_restart do
end

# copy and pasted from Django recipe, because Chef sucks
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
    # if it's a relative path, use the release_path in front to make absolute
    # (because we'll be running from in shared/env/)
    req_path = new_resource.requirements
    if not req_path.start_with? '/'
      req_path = ::File.join(new_resource.release_path, req_path)
    end
    # The cleanest way to use pip here would be to use the python/pip resource but
    # that is a package-centric resource not a generic wrapper on pip so we can't
    # use it to just `pip install -r requirements.txt`
    # So, we copy and paste some relevant bits of code instead...
    timeout = 1200
    Chef::Log.info("Running: pip install -r #{req_path}")
    cmd = shell_out!("#{pip_cmd} install -r #{req_path}", :timeout => timeout, :user => new_resource.owner)
    if cmd
      new_resource.updated_by_last_action(true)
    end
  else
    Chef::Log.info("No requirements file found")
  end
end

# copy and pasted from 'python' cookbook 'pip' provider, because Chef sucks
def pip_cmd
  if (new_resource.respond_to?("virtualenv") && new_resource.virtualenv)
    ::File.join(new_resource.virtualenv,'/bin/pip')
  elsif "#{node['python']['install_method']}".eql?("source")
    ::File.join("#{node['python']['prefix_dir']}","/bin/pip")
  else
    'pip'
  end
end