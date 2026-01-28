class Expense < ApplicationRecord
  # Associations
  belongs_to :expense_import, optional: true
  belongs_to :verified_by, class_name: 'User', optional: true

  # Enums
  enum :category, {
    # COGS (Cost of Goods Sold)
    buckets: 0,
    bags: 1,
    starter_kits: 2,
    packaging: 3,

    # Operational Costs
    fuel: 10,
    vehicle_maintenance: 11,
    vehicle_insurance: 12,
    tolls_parking: 13,
    staff_food: 14,

    # Fixed Costs
    salaries_wages: 20,
    rent: 21,
    utilities: 22,
    insurance_general: 23,
    software_subscriptions: 24,

    # Marketing & Sales
    marketing: 30,
    advertising: 31,

    # Administrative
    office_supplies: 40,
    professional_fees: 41,
    bank_fees: 42,
    airtime_data: 43,

    # Other
    other: 99
  }

  # Validations
  validates :transaction_date, presence: true
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :category, presence: true
  validates :accounting_month, presence: true, inclusion: { in: 1..12 }
  validates :accounting_year, presence: true

  # Callbacks
  before_validation :set_accounting_period, if: -> { transaction_date.present? && (accounting_month.nil? || accounting_year.nil?) }

  # Scopes
  scope :verified, -> { where(verified: true) }
  scope :unverified, -> { where(verified: false) }
  scope :for_month, ->(year, month) { where(accounting_year: year, accounting_month: month) }
  scope :for_year, ->(year) { where(accounting_year: year) }
  scope :cogs, -> { where(category: [0, 1, 2, 3]) }
  scope :operational, -> { where(category: [10, 11, 12, 13, 14]) }
  scope :fixed_costs, -> { where(category: [20, 21, 22, 23, 24]) }
  scope :marketing_costs, -> { where(category: [30, 31]) }
  scope :admin_costs, -> { where(category: [40, 41, 42, 43]) }

  # Instance Methods
  def verify!(user)
    update!(verified: true, verified_by: user)
  end

  def category_group
    case category.to_sym
    when :buckets, :bags, :starter_kits, :packaging
      :cogs
    when :fuel, :vehicle_maintenance, :vehicle_insurance, :tolls_parking, :staff_food
      :operational
    when :salaries_wages, :rent, :utilities, :insurance_general, :software_subscriptions
      :fixed
    when :marketing, :advertising
      :marketing
    when :office_supplies, :professional_fees, :bank_fees, :airtime_data
      :admin
    else
      :other
    end
  end

  private

  def set_accounting_period
    self.accounting_month = transaction_date.month
    self.accounting_year = transaction_date.year
  end
end
