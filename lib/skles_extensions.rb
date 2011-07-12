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

class Savon::Wasabi::Document
  def resolve_document
    case document
      when /^http[s]?:/ then HTTPI.get(request, Savon.http_adapter).body
      when /^</         then document
      else                   File.read(document)
    end
  end
end