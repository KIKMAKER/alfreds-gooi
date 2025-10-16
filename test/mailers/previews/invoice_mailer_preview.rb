class InvoiceMailerPreview < ActionMailer::Preview
  def invoice_created
    # create user
    user = User.first || User.create!(
      email: "test@example.com",
      password: "password",
      first_name: "John"
    )

    # subscription
    subscription = Subscription.first || Subscription.create!(
      user: user,
      plan: "standard",
      status: "active"
    )

    # create invoice
    invoice = Invoice.first || Invoice.create!(
      subscription: subscription,  # This is crucial for your mailer
      total_amount: 12500,
      due_date: Date.today + 15.days,
      number: "INV-001"
    )

    # call mailer
    InvoiceMailer.with(invoice: invoice).invoice_created
  end
end
