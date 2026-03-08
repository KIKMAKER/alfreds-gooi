class ContactsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_subscription
  before_action :authorize_subscription_owner
  before_action :set_contact, only: [:show, :edit, :update, :destroy, :toggle_whatsapp]

  def index
    @contacts = @subscription.contacts.order(is_primary: :desc, created_at: :asc)
  end

  def show
  end

  def new
    @contact = @subscription.contacts.build
  end

  def create
    @contact = @subscription.contacts.build(contact_params)

    if @contact.save
      redirect_to subscription_contacts_path(@subscription),
                  notice: 'Contact added successfully.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @contact.update(contact_params)
      redirect_to subscription_contacts_path(@subscription),
                  notice: 'Contact updated successfully.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @contact.is_primary?
      redirect_to subscription_contacts_path(@subscription),
                  alert: 'Cannot delete primary contact.'
      return
    end

    @contact.destroy
    redirect_to subscription_contacts_path(@subscription),
                notice: 'Contact removed successfully.'
  end

  def toggle_whatsapp
    if @contact.whatsapp_opt_out?
      @contact.opt_in_to_whatsapp!
      message = 'WhatsApp reminders enabled'
    else
      @contact.opt_out_of_whatsapp!
      message = 'WhatsApp reminders disabled'
    end

    redirect_to subscription_contacts_path(@subscription), notice: message
  end

  private

  def set_subscription
    @subscription = Subscription.find(params[:subscription_id])
  end

  def authorize_subscription_owner
    unless @subscription.user == current_user || current_user.admin?
      redirect_to root_path, alert: 'Not authorized'
    end
  end

  def set_contact
    @contact = @subscription.contacts.find(params[:id])
  end

  def contact_params
    params.require(:contact).permit(:first_name, :last_name, :phone_number,
                                     :relationship, :whatsapp_opt_out)
  end
end
