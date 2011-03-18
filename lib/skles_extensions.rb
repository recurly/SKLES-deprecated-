# Monkey-patch Savon::SOAP::Request to use a customizable HTTPI adapter.

module Savon
  def self.http_adapter
    @http_adapter
  end
  
  def self.http_adapter=(adapter)
    @http_adapter = adapter
  end
end

class Savon::SOAP::Request
  def response
    @response ||= with_logging { HTTPI.post request, Savon.http_adapter }
  end
end

class Savon::WSDL::Request
  def response
    @response ||= with_logging { HTTPI.get request, Savon.http_adapter }
  end
end
