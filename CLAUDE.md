# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Alfred's Gooi is a Rails 7.1 fullstack application for managing a household kitchen scrap collection service operating weekly across Cape Town. The name "gooi" is Afrikaans for "throw/fling" and colloquially means "can I have" or "let's do it".

## Tech Stack

- **Framework**: Rails 7.1.0, Ruby 3.3.5
- **Database**: PostgreSQL with separate databases for primary and queue data
- **Background Jobs**: Solid Queue (configured via `bin/jobs` and separate queue database)
- **Frontend**: Hotwire (Turbo + Stimulus), Bootstrap 5.2, importmap-rails
- **Authentication**: Devise
- **Email**: Postmark Rails
- **Geocoding**: Geocoder gem

## Core Domain Model

The application centers around a weekly collection service with these key models:

### Subscription
- Belongs to a User
- Has many Collections and Invoices
- Three plans: `once_off`, `Standard`, `XL`
- Five statuses: `pending`, `active`, `pause`, `completed`, `legacy`
- Suburb-based collection day assignment (Tuesday/Wednesday/Thursday routes)
- Key suburb constants: `TUESDAY_SUBURBS`, `WEDNESDAY_SUBURBS`, `THURSDAY_SUBURBS`
- Geocoded by street address with automatic suburb canonicalization
- Collections are scheduled based on collection_day enum (Date::DAYNAMES)

### Collection
- Belongs to Subscription and DriversDay (both optional)
- Ordered using acts_as_list (scoped to drivers_day)
- Tracks: bags, buckets, skip status, is_done status, customer notes
- Use `mark_skipped!` method (not bare updates) to skip collections - sends email notification
- Collections are assigned to specific dates and organized into a driver's route

### DriversDay
- Belongs to User (the driver)
- Has many Collections and Buckets
- Tracks route execution: start_time, end_time, start_kms, end_kms
- Automatically sends weekly stats email on Thursday completion
- Buckets track weight (weight_kg) and can be marked as half-full
- Methods: `recalc_totals!`, `full_equivalent_count`, `avg_net_kg_per_bucket`

### User
- Uses Devise for authentication
- Has many Subscriptions and DriversDays
- Role-based access (standard users vs drivers/admins)

## Route Organization

Collections are geographically organized by suburb into three collection days:
- **Tuesday**: Southern suburbs (Bergvliet, Claremont, Kenilworth, etc.) and False Bay (Kalk Bay, Muizenberg, etc.)
- **Wednesday**: Atlantic Seaboard (Camps Bay, Sea Point, Hout Bay, etc.) + Constantia
- **Thursday**: City Bowl (Gardens, Tamboerskloof, Observatory, etc.)

See `app/models/subscription.rb:40-42` for complete suburb lists.

## Key Background Jobs

Located in `app/jobs/`:
- `CreateCollectionsJob` - Main job for creating collections
- `CreateTodayCollectionsJob` - Creates collections for current day
- `CreateNextWeekCollectionsJob` - Pre-creates next week's collections
- `CreateTomorrowCollectionsJob` - Creates tomorrow's collections
- `CreateFirstCollectionJob` - Initial collection for new subscription
- `CheckSubscriptionsForCompletionJob` - Marks subscriptions as completed when duration reached

Jobs are processed by Solid Queue (not Sidekiq).

## Important Services

Located in `app/services/`:
- `RouteOptimiser` - Optimizes collection routes for efficiency
- `InvoiceBuilder` - Creates invoices with proper item calculation
- `WeeklyStats` - Generates weekly statistics reports
- `Subscriptions::*` - Subscription-specific business logic

## Development Commands

### Database Setup
```bash
rails db:create
rails db:migrate
```

### Running the Application
```bash
# Start web server
bundle exec puma -C config/puma.rb

# Start background job worker (required for collection scheduling)
bin/jobs

# Or use Procfile for both:
foreman start
```

### Running Tests
```bash
# Run all tests
rails test

# Run specific test file
rails test test/models/subscription_test.rb

# Run specific test
rails test test/models/subscription_test.rb:10
```

### Code Quality
```bash
# Run RuboCop linter
rubocop

# Auto-fix issues
rubocop -a
```

### Console
```bash
rails console
```

## Admin Interface

Admin routes are namespaced under `/admin`:
- `/admin/logistics` - Logistics overview
- `/admin/collections` - Collection management
- `/admin/users` - User management with subscription renewal
- `/admin/discount_codes` - Discount code management

## Key Controller Actions

### Collections
- `optimise_route` - Uses RouteOptimiser service to order collections
- `perform_create_today_collections` - Manually trigger today's collection creation
- `perform_create_next_week_collections` - Manually trigger next week's collection creation
- `skip_today` - Skip collections for the day (uses mark_skipped!)
- Collection position updates use `acts_as_list` for ordering within a drivers_day

### Subscriptions
- `reassign_collections` - Moves collections forward when schedule changes
- `pause`/`unpause`/`clear_holiday` - Pause subscription management
- `holiday_dates` - Set temporary holiday dates
- `want_bags` - Request additional bags

### DriversDay
- `start`/`drop_off`/`end` - Driver workflow steps
- `vamos` - Ready to start route
- `collections` - View/manage route collections
- `missing_customers` - Handle missed collections
- `whatsapp_message` - Generate message for customer communication

## Email Notifications

Mailers in `app/mailers/`:
- `CollectionMailer` - Collection skipped notifications
- `SubscriptionMailer` - Subscription lifecycle emails
- `InvoiceMailer` - Invoice sending
- `InterestMailer` - New interest notification
- `WeeklyStatsMailer` - Thursday weekly statistics report
- `DailySnapshotMailer` - Daily impact snapshot link sent when DriversDay completed
- `UserMailer` - General user communications

Configured to use Postmark Rails for delivery.

## Database Considerations

- Uses multi-database configuration with separate queue database
- Queue migrations in `db/queue_migrate/`, primary migrations in `db/migrate/`
- Solid Queue tables prefixed with `solid_queue_*`
- Run migrations: `rails db:migrate` (handles both databases)

## Critical Implementation Notes

1. **Always use `mark_skipped!` instead of `update(skip: true)`** on collections to ensure skip notification emails are sent
2. **Collection creation is date-based** - collections belong to specific dates and are assigned to drivers_days for route organization
3. **Suburb validation is strict** - only suburbs in `Subscription::SUBURBS` constant are allowed
4. **Collection day auto-assignment** - suburb determines collection_day via `set_collection_day` callback
5. **acts_as_list ordering** - collections within a drivers_day use position-based ordering
6. **Geocoding happens automatically** on street_address changes
7. **Thursday completion triggers weekly stats** - DriversDay sends report when end_time set on Thursday
