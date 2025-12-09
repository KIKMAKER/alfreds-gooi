class InvoiceMailerPreview < ActionMailer::Preview
  def invoice_created
    # user
    user = User.first || User.create!(
      email: "test@example.com",
      password: "password",
      first_name: "John"
    )

    # subscription
    subscription = Subscription.first || Subscription.create!(
      user: user,
      plan: "Standard",
      status: "active"
    )

    # create invoice
    invoice = Invoice.first || Invoice.create!(
      subscription: subscription,
      total_amount: 12500,
      due_date: Date.today + 15.days,
      number: "INV-001"
    )

    # call mailer
    InvoiceMailer.with(invoice: invoice).invoice_created
  end
end
