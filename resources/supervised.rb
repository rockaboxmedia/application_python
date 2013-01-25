include Chef::Resource::ApplicationBase

attribute :virtualenv_options, :kind_of => String, :default => "--distribute"


def virtualenv
  "#{path}/shared/env"
end

def python_path
  "#{release_path}/python/"# only valid after application symlinking action
end
