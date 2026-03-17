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
end
