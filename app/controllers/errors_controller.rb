class ErrorsController < ApplicationController
  layout "application"

  def show
    # Accept code from route defaults or infer from request
    code = (params[:code] || request.path.split("/").last).to_i
    code = 500 unless [403, 404, 422, 500].include?(code)

    @code = code
    raise
    @title, @message, @cta = content_for(code)
    render template: "errors/#{code}", status: code
  rescue => _
    @code = 500
    @title, @message, @cta = content_for(500)
    render template: "errors/500", status: 500
  end

  private

  def content_for(code)
    case code
    when 404
      ["Page not found",
       "Looks like this page has already been composted—or never existed.",
       { primary: ["Back home", :root_path],
         secondary: ["Where we collect", :root_path] }]
    when 422
      ["We couldn't process that",
       "Please try again. If the issue persists, refresh and resubmit.",
       { primary: ["Back home", :root_path],
         secondary: ["Contact us", "mailto:howzit@gooi.me"] }]
    when 403
      ["Access denied",
       "You don't have permission to view this page.",
       { primary: ["Back home", :root_path] }]
    else # 500
      ["Something went wrong",
       "Our bad. We're on it. Try again in a moment.",
       { primary: ["Back home", :root_path],
         secondary: ["Contact us", "mailto:howzit@gooi.me"] }]
    end
  end
end
