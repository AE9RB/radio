require 'eventmachine'
require 'thin'
require 'rack'

class Radio
  class Server
    
    def self.start
      
       app = Rack::Builder.new do
         use Rack::CommonLogger
         use Rack::ShowExceptions
         use Rack::Lint
         run Radio::HTTP.new
       end

      EventMachine.run {
        Rack::Handler::Thin.run app, :Port => 8080, :Host => '0.0.0.0'
      }

    end
    
  end
end
