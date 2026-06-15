class BlockSurveyMailer < ApplicationMailer
  def pitch(block, quotation, recipient_name, recipient_email)
    @block          = block
    @quotation      = quotation
    @recipient_name = recipient_name
    @deck_url       = estate_deck_url
    @quotation_url  = quotation_url(quotation)
    @survey_url     = block_survey_url(block.slug)

    mail(
      to:      recipient_email,
      subject: "#{block.name} — organic waste collection proposal from Gooi"
    )
  end
end
