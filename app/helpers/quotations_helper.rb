module QuotationsHelper
  def status_color(status)
    case status.to_s
    when 'draft' then 'secondary'
    when 'sent' then 'primary'
    when 'accepted' then 'success'
    when 'rejected' then 'danger'
    when 'expired' then 'warning'
    else 'secondary'
    end
  end
end
