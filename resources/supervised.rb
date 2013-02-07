include Chef::Resource::ApplicationBase

attribute :virtualenv_options, :kind_of => String, :default => "--distribute"
attribute :code_dir, :kind_of => String, :default => ""
attribute :command_str, :kind_of => String, :default => ""


def virtualenv
  "#{path}/shared/env"
end

# make possible to define a before_symlink block in user recipe
def before_symlink(arg=nil, &block)
  arg ||= block
  set_or_return(:before_symlink, arg, :kind_of => [Proc, String])
end