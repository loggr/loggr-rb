require 'sucker_punch'
require 'loggr-rb/http'
require 'uri'

module Loggr

  class LogClient

    def self.post(e,async)
      if async
        LogJob.new.async.perform(e)
      else
        LogJob.new.perform(e)
      end
    end

    def post(e)
      logkey = ::Loggr::Config.log_key
      call_remote("post.loggr.net", "/1/logs/#{logkey}/events", create_params(e))
    end

    def create_params(e)
      apikey = ::Loggr::Config.api_key
      params = {"apikey" => apikey, "text" => e.text}
      params = params.merge({"link" => e.link}) if !e.link.nil?
      params = params.merge({"tags" => e.tags}) if !e.tags.nil?
      params = params.merge({"source" => e.source}) if !e.source.nil?
      params = params.merge({"geo" => e.geo}) if !e.geo.nil?
      params = params.merge({"value" => e.value}) if !e.value.nil?
      if e.datatype == DataType::HTML
        params = params.merge({"data" => sprintf("@html\r\n%s", e.data)}) if !e.data.nil?
      else
        params = params.merge({"data" => e.data}) if !e.data.nil?
      end
      return params
    end

    def call_remote(host, path, params)
      uri = URI("http://#{host}#{path}?#{URI.encode_www_form(params)}")
      req = Net::HTTP::Get.new(uri)
      req['Accept-Encoding'] = nil
      begin
        res = Net::HTTP.start(uri.host,uri.port) { |http|
          http.request(req)
        }
      rescue Exception => e
        Loggr.logger.error("Problem notifying Loggr about the event")
        Loggr.logger.error(e)
      end
    end

  end

  class LogJob
    include SuckerPunch::Job

    def perform(event)
      LogClient.new.post(event)
    end

  end

end
