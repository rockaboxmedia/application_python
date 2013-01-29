require 'chef/mixin/shell_out'
include Chef::Provider::ApplicationBase
include Chef::Mixin::LanguageIncludeRecipe
include Chef::Mixin::ShellOut

action :before_compile do
end

action :before_symlink do
  shell_out!("#{bin_cmd('pip')} install -r #{new_resource.release_path}/python/requirements.txt",
    :timeout => 1200, :user => new_resource.owner
  )
  callback(:before_symlink, new_resource.before_symlink)
end

action :after_restart do
  supervisor_service new_resource.name do
    action :restart
  end
end

action :before_deploy do
  python_virtualenv new_resource.virtualenv do
    path new_resource.virtualenv
    options new_resource.virtualenv_options
    action :create
  end

  supervisor_service new_resource.name do
  	action :enable
	  environment 'PYTHONPATH' => "#{new_resource.release_path}/#{new_resource.code_dir}"
    directory "#{new_resource.release_path}/#{new_resource.code_dir}"
	  command "#{bin_cmd('python')} #{new_resource.command_str}"
	  autostart true
	  autorestart true
  end
end

action :before_migrate do
end

action :before_restart do
end

# copy and pasted from 'python' cookbook 'pip' provider, because Chef sucks
def bin_cmd(cmd)
  if (new_resource.respond_to?("virtualenv") && new_resource.virtualenv)
    ::File.join(new_resource.virtualenv,"/bin/#{cmd}")
  elsif "#{node['python']['install_method']}".eql?("source")
    ::File.join("#{node['python']['prefix_dir']}","/bin/#{cmd}")
  else
    "#{cmd}"
  end
end