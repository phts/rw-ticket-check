require 'rbconfig'

module Utils
  def self.windows?
    RbConfig::CONFIG['host_os'] =~ /mswin|mingw|cygwin/
  end
end
