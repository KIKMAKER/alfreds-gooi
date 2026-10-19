class Admin::DisposalFeesController < Admin::BaseController
  def index
    @report   = DisposalFeesReport.new
    @rows     = @report.rows
    @payments = DisposalPayment.all.index_by { |p| [p.drop_off_site_id, p.period] }
  end
end
