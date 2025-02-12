require 'rack/mime'
require 'rack/rewrite/rule/permanent_redirect'
require 'rack/rewrite/rule/temporary_redirect'

module Rack
  class Rewrite
    class Rule #:nodoc:
      attr_reader :rule_type, :from, :to, :options
      def initialize(rule_type, from, to, options={}) #:nodoc:
        @rule_type, @from, @to, @options = rule_type, from, to, normalize_options(options)
      end

      def matches?(rack_env) #:nodoc:
        return false if options[:if].respond_to?(:call) && !options[:if].call(rack_env)
        path = build_path_from_env(rack_env)

        self.match_options?(rack_env) && string_matches?(path, self.from)
      end

      # Either (a) return a Rack response (short-circuiting the Rack stack), or
      # (b) alter env as necessary and return true
      def apply!(env) #:nodoc:
        interpreted_to = self.interpret_to(env)
        additional_headers = @options[:headers] || {}
        case self.rule_type
        when :r301
          Rack::Rewrite::Rule::PermanentRedirect.new(interpreted_to, additional_headers).run
        when :r302
          Rack::Rewrite::Rule::TemporaryRedirect.new(interpreted_to, additional_headers).run
        when :rewrite
          env['REQUEST_URI'] = interpreted_to
          if q_index = interpreted_to.index('?')
            env['PATH_INFO'] = interpreted_to[0..q_index-1]
            env['QUERY_STRING'] = interpreted_to[q_index+1..interpreted_to.size-1]
          else
            env['PATH_INFO'] = interpreted_to
            env['QUERY_STRING'] = ''
          end
          true
        when :send_file
          [200, {
            'Content-Length' => ::File.size(interpreted_to).to_s,
            'Content-Type'   => Rack::Mime.mime_type(::File.extname(interpreted_to))
            }.merge!(additional_headers), [::File.read(interpreted_to)]]
        when :x_send_file
          [200, {
            'X-Sendfile'     => interpreted_to,
            'Content-Length' => ::File.size(interpreted_to).to_s,
            'Content-Type'   => Rack::Mime.mime_type(::File.extname(interpreted_to))
            }.merge!(additional_headers), []]
        else
          raise Exception.new("Unsupported rule: #{self.rule_type}")
        end
      end

      protected
        def interpret_to(env) #:nodoc:
          path = build_path_from_env(env)
          return interpret_to_proc(path, env) if self.to.is_a?(Proc)
          return computed_to(path) if compute_to?(path)
          self.to
        end

        def is_a_regexp?(obj)
          obj.is_a?(Regexp) || (Object.const_defined?(:Oniguruma) && obj.is_a?(Oniguruma::ORegexp))
        end

        def match_options?(env, path = build_path_from_env(env))
          matches = []
          request = Rack::Request.new(env)

          # negative matches
          matches << !string_matches?(path, options[:not]) if options[:not]

          # possitive matches
          matches << string_matches?(env['REQUEST_METHOD'], options[:method]) if options[:method]
          matches << string_matches?(request.host, options[:host]) if options[:host]

          matches.all?
        end

      private
        def normalize_options(arg)
          options = arg.respond_to?(:call) ? {:if => arg} : arg
          options.symbolize_keys! if options.respond_to? :symbolize_keys!
          options.freeze
        end

        def interpret_to_proc(path, env)
          return self.to.call(match(path), env) if self.from.is_a?(Regexp)
          self.to.call(self.from, env)
        end

        def compute_to?(path)
          self.is_a_regexp?(from) && match(path)
        end

        def match(path)
          self.from.match(path)
        end

        def string_matches?(string, matcher)
          if self.is_a_regexp?(matcher)
            string =~ matcher
          elsif matcher.is_a?(String)
            string == matcher
          else
            false
          end
        end

        def computed_to(path)
          # is there a better way to do this?
          computed_to = self.to.dup
          computed_to.gsub!("$&",match(path).to_s)
          (match(path).size - 1).downto(1) do |num|
            computed_to.gsub!("$#{num}", match(path)[num].to_s)
          end
          return computed_to
        end

        # Construct the URL (without domain) from PATH_INFO and QUERY_STRING
        def build_path_from_env(env)
          path = env['PATH_INFO']
          path += "?#{env['QUERY_STRING']}" unless env['QUERY_STRING'].nil? || env['QUERY_STRING'].empty?
          path
        end

        def redirect_message(location)
          %Q(Redirecting to <a href="#{location}">#{location}</a>)
        end
    end
  end
end
