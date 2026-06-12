class BlockSurveyMailer < ApplicationMailer
  def invite(block, recipient_email)
    @block        = block
    @survey_url   = block_survey_url(block.slug)
    @annual_kg    = Block.annual_kg_per_household
    @annual_co2e  = Block.annual_co2e_per_household

    mail(
      to:      recipient_email,
      subject: "Composting at #{block.name} — quick survey for residents"
    )
  end
end
