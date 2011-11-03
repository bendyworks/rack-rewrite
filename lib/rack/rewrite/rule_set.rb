require 'lib/rack/rewrite/rule'

module Rack
  class Rewrite
    class RuleSet
      attr_reader :rules
      def initialize #:nodoc:
        @rules = []
      end

      protected
        # We're explicitly defining private functions for our DSL rather than
        # using method_missing

        # Creates a rewrite rule that will simply rewrite the REQUEST_URI,
        # PATH_INFO, and QUERY_STRING headers of the Rack environment.  The
        # user's browser will continue to show the initially requested URL.
        #
        #  rewrite '/wiki/John_Trupiano', '/john'
        #  rewrite %r{/wiki/(\w+)_\w+}, '/$1'
        #  rewrite %r{(.*)}, '/maintenance.html', :if => lambda { File.exists?('maintenance.html') }
        def rewrite(*args)
          add_rule :rewrite, *args
        end

        # Creates a redirect rule that will send a 301 when matching.
        #
        #  r301 '/wiki/John_Trupiano', '/john'
        #  r301 '/contact-us.php', '/contact-us'
        def r301(*args)
          add_rule :r301, *args
        end

        # Creates a redirect rule that will send a 302 when matching.
        #
        #  r302 '/wiki/John_Trupiano', '/john'
        #  r302 '/wiki/(.*)', 'http://www.google.com/?q=$1'
        def r302(*args)
          add_rule :r302, *args
        end

        # Creates a rule that will render a file if matched.
        #
        #  send_file /*/, 'public/system/maintenance.html',
        #    :if => Proc.new { File.exists?('public/system/maintenance.html') }
        def send_file(*args)
          add_rule :send_file, *args
        end

        # Creates a rule that will render a file using x-send-file
        # if matched.
        #
        #  x_send_file /*/, 'public/system/maintenance.html',
        #    :if => Proc.new { File.exists?('public/system/maintenance.html') }
        def x_send_file(*args)
          add_rule :x_send_file, *args
        end

      private
        def add_rule(method, from, to, options = {}) #:nodoc:
          @rules << Rule.new(method.to_sym, from, to, options)
        end

    end
  end
end

