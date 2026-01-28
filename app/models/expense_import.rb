class ExpenseImport < ApplicationRecord
  # Associations
  belongs_to :user
  has_many :expenses, dependent: :nullify

  # Validations
  validates :filename, presence: true

  # Instance Methods
  def success_rate
    return 0 if total_rows.to_i.zero?
    (imported_rows.to_f / total_rows * 100).round(1)
  end

  def status_summary
    "#{imported_rows}/#{total_rows} imported (#{skipped_rows} skipped)"
  end
end
