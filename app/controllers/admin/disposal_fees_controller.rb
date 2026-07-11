class Admin::DisposalFeesController < Admin::BaseController
  def index
    @report = DisposalFeesReport.new
    @rows   = @report.rows
  end
end
