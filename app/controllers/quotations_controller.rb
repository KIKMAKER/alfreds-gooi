class QuotationsController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[show pdf]
  before_action :set_quotation, only: %i[show pdf]

  def show
  end

  def pdf
    begin
      pdf = QuotationPdfGenerator.new(@quotation).generate
      send_data pdf.render,
                filename: "quotation_#{@quotation.number || @quotation.id}.pdf",
                type: 'application/pdf',
                disposition: 'inline'
    rescue StandardError => e
      redirect_to quotation_path(@quotation), alert: "Error generating PDF: #{e.message}"
    end
  end

  private

  def set_quotation
    @quotation = Quotation.find(params[:id])
  end

  def quotation_params
    params.require(:quotation).permit(
      :user_id,
      :subscription_id,
      :prospect_name,
      :prospect_email,
      :prospect_phone,
      :prospect_company,
      :notes,
      :duration_months,
      :created_date,
      :expires_at,
      :status,
      :quote_type,
      :event_date,
      :event_name,
      :event_venue,
      quotation_items_attributes: [:id, :product_id, :quantity, :amount, :_destroy]
    )
  end

  def create_quotation_items(quotation)
    return unless params[:quotation][:quotation_items_attributes]

    params[:quotation][:quotation_items_attributes].each do |key, product_hash|
      if product_hash.class == Array
        product = Product.find(product_hash[1]["product_id"].to_i)
        quantity = product_hash[1]["quantity"].to_f
      else
        product = Product.find(product_hash[:product_id].to_i)
        quantity = product_hash[:quantity].to_f
      end
      next if quantity.blank? || quantity <= 0

      quotation.quotation_items.create!(
        product_id: product.id,
        quantity: quantity,
        amount: product.price  # Denormalize price at creation time
      )
    end
  end

  def authenticate_admin!
    unless current_user&.admin?
      redirect_to root_path, alert: "You must be an admin to access this page."
    end
  end
end
