include Chef::Resource::ApplicationBase

attribute :wsgi_file_path, :kind_of => String, :default => "conf/django.wsgi"
attribute :django_settings_module, :kind_of => String, :default => "settings"
attribute :python_version, :kind_of => String, :default => '2.7'
# Actually defaults to "django.wsgi.erb", but nil means it wasn't set by the user
attribute :wsgi_template, :kind_of => [String, NilClass], :default => nil

def wsgi_file_base
  ::File.basename(wsgi_file_path)
end

def virtualenv
  "#{path}/shared/env"
end