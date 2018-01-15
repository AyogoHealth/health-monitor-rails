module HealthMonitor
  class HealthController < ActionController::Base
    protect_from_forgery with: :exception

    if Rails.version.starts_with? '3'
      before_filter :authenticate_with_basic_auth
    else
      before_action :authenticate_with_basic_auth
    end

    def check
      @statuses = statuses
      ok = @statuses[:results]
        .map { |s| s[:status] == "OK" }
        .include?(false) == false

      status = ok ? 200 : 500

      respond_to do |format|
        format.html do
          render status: status
        end
        format.json do
          render json: statuses.to_json, status: status
        end
        format.xml do
          render xml: statuses.to_xml, status: status
        end
      end
    end

    private

    def statuses
      res = HealthMonitor.check(request: request)
      res.merge(env_vars)
    end

    def env_vars
      v = HealthMonitor.configuration.environment_variables || {}
      v.empty? ? {} : { environment_variables: v }
    end

    def authenticate_with_basic_auth
      return true unless HealthMonitor.configuration.basic_auth_credentials

      credentials = HealthMonitor.configuration.basic_auth_credentials
      authenticate_or_request_with_http_basic do |name, password|
        name == credentials[:username] && password == credentials[:password]
      end
    end
  end
end
