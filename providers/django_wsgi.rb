action :before_compile do
  new_resource.symlink_before_migrate.update({
    new_resource.wsgi_file_base => new_resource.wsgi_file_path,
  })
end

action :before_deploy do
  create_wsgi_file
end

# these blocks need to be here to avoid spurious errors
action :before_migrate do
end

action :before_symlink do
end

action :before_restart do
end

action :after_restart do
end


def create_wsgi_file
  template "#{new_resource.path}/shared/#{new_resource.wsgi_file_base}" do
    source new_resource.wsgi_template || "django.wsgi.erb"
    cookbook new_resource.wsgi_template ? String(new_resource.cookbook_name) : "application_python"
    owner "root"
    group "root"
    mode 0644
    variables(
      :site_packages => ::File.join(new_resource.virtualenv, "lib/python#{new_resource.python_version}/site-packages/"),
      :app_path => new_resource.release_path,
      :django_settings_module => new_resource.django_settings_module
    )
  end
end