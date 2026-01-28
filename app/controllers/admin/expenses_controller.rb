class Admin::ExpensesController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin
  before_action :set_expense, only: [:edit, :update, :destroy, :verify]

  def index
    @expenses = Expense.order(transaction_date: :desc)

    # Filters
    @expenses = @expenses.where(category: params[:category]) if params[:category].present?
    @expenses = @expenses.where(verified: params[:verified]) if params[:verified].present?

    # Date range filter
    if params[:start_date].present? && params[:end_date].present?
      @expenses = @expenses.where(transaction_date: params[:start_date]..params[:end_date])
    end

    # Limit to most recent 100 expenses (can add pagination gem later if needed)
    @expenses = @expenses.limit(100)
  end

  def new
    @expense = Expense.new
  end

  def create
    @expense = Expense.new(expense_params)

    if @expense.save
      # Trigger metrics recalculation in background
      CalculateFinancialMetricsJob.perform_later(@expense.accounting_year, @expense.accounting_month)

      redirect_to admin_expenses_path, notice: "Expense added successfully"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @expense.update(expense_params)
      # Trigger metrics recalculation
      CalculateFinancialMetricsJob.perform_later(@expense.accounting_year, @expense.accounting_month)

      redirect_to admin_expenses_path, notice: "Expense updated successfully"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    year = @expense.accounting_year
    month = @expense.accounting_month

    @expense.destroy

    # Trigger metrics recalculation
    CalculateFinancialMetricsJob.perform_later(year, month)

    redirect_to admin_expenses_path, notice: "Expense deleted successfully"
  end

  def verify
    @expense.verify!(current_user)
    redirect_to admin_expenses_path, notice: "Expense verified"
  end

  def import
    # Show CSV upload form
  end

  def parse_csv

    unless params[:csv_file].present?
      redirect_to import_admin_expenses_path, alert: "Please select a CSV file"
      return
    end

    parser = BankStatementParser.new(params[:csv_file])
    @parsed_expenses = parser.parse

    if parser.errors.any?
      flash.now[:alert] = "Errors parsing CSV: #{parser.errors.join(', ')}"
    end

    @expense_import = ExpenseImport.new(
      filename: params[:csv_file].original_filename,
      user: current_user,
      total_rows: @parsed_expenses.count
    )

    render :preview
  end

  def confirm_import
    import = ExpenseImport.create!(
      user: current_user,
      filename: params[:expense_import][:filename],
      total_rows: 0,
      imported_rows: 0,
      skipped_rows: 0
    )

    imported_count = 0
    skipped_count = 0
    affected_months = Set.new

    params[:expenses].each do |index, expense_data|
      next unless expense_data[:include] == "1"

      begin
        expense = Expense.create!(
          expense_import: import,
          transaction_date: expense_data[:transaction_date],
          amount: expense_data[:amount],
          category: expense_data[:category],
          description: expense_data[:description],
          vendor: expense_data[:vendor],
          reference_number: expense_data[:reference_number]
        )

        imported_count += 1
        affected_months << [expense.accounting_year, expense.accounting_month]
      rescue => e
        Rails.logger.error "Failed to import expense: #{e.message}"
        skipped_count += 1
      end
    end

    # Update import record
    import.update!(
      total_rows: imported_count + skipped_count,
      imported_rows: imported_count,
      skipped_rows: skipped_count
    )

    # Trigger metrics recalculation for all affected months
    affected_months.each do |year, month|
      CalculateFinancialMetricsJob.perform_later(year, month)
    end

    redirect_to admin_expenses_path, notice: "Imported #{imported_count} expenses (#{skipped_count} skipped)"
  end

  private

  def set_expense
    @expense = Expense.find(params[:id])
  end

  def expense_params
    params.require(:expense).permit(
      :transaction_date, :amount, :category, :description,
      :vendor, :payment_method, :reference_number, :notes
    )
  end

  def require_admin
    redirect_to root_path, alert: "Unauthorized" unless current_user.admin?
  end
end
