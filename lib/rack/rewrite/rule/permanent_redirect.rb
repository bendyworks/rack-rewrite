module Rack
  class Rewrite
    class Rule
      class PermanentRedirect
        def initialize(interpreted_to, additional_headers)
          @interpreted_to = interpreted_to
          @additional_headers = additional_headers
        end

        def run
          [301, {'Location' => @interpreted_to, 'Content-Type' => Rack::Mime.mime_type(::File.extname(@interpreted_to))}.merge!(@additional_headers), [redirect_message(@interpreted_to)]]
        end

        private
        def redirect_message(location)
          %Q(Redirecting to <a href="#{location}">#{location}</a>)
        end
      end
    end
  end
end
