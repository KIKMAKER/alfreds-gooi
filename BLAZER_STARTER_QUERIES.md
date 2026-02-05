# Blazer Starter Queries for Alfred's Gooi

Access the analytics dashboard at: `/admin/analytics`

## 📊 Visitor Analytics

### Most Visited Pages (Last 7 Days)
```sql
SELECT
  landing_page,
  COUNT(*) as visit_count
FROM ahoy_visits
WHERE started_at >= NOW() - INTERVAL '7 days'
GROUP BY landing_page
ORDER BY visit_count DESC
LIMIT 20;
```

### New vs Returning Visitors (Last 30 Days)
```sql
SELECT
  CASE WHEN visits_count = 1 THEN 'New' ELSE 'Returning' END as visitor_type,
  COUNT(*) as count
FROM (
  SELECT visitor_token, COUNT(*) as visits_count
  FROM ahoy_visits
  WHERE started_at >= NOW() - INTERVAL '30 days'
  GROUP BY visitor_token
) subquery
GROUP BY visitor_type;
```

### Traffic by Device (Last 30 Days)
```sql
SELECT
  device_type,
  COUNT(*) as visit_count,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as percentage
FROM ahoy_visits
WHERE started_at >= NOW() - INTERVAL '30 days'
GROUP BY device_type
ORDER BY visit_count DESC;
```

### Traffic by Browser (Last 30 Days)
```sql
SELECT
  browser,
  COUNT(*) as visit_count
FROM ahoy_visits
WHERE started_at >= NOW() - INTERVAL '30 days'
  AND browser IS NOT NULL
GROUP BY browser
ORDER BY visit_count DESC
LIMIT 10;
```

### Visits by Location (Top Cities)
```sql
SELECT
  city,
  country,
  COUNT(*) as visit_count
FROM ahoy_visits
WHERE city IS NOT NULL
  AND started_at >= NOW() - INTERVAL '30 days'
GROUP BY city, country
ORDER BY visit_count DESC
LIMIT 20;
```

## 🎯 User Behavior

### Pages Before Sign Up (Conversion Funnel)
```sql
SELECT
  v.landing_page,
  COUNT(DISTINCT v.visitor_token) as visitors,
  COUNT(DISTINCT u.id) as signups,
  ROUND(COUNT(DISTINCT u.id) * 100.0 / COUNT(DISTINCT v.visitor_token), 2) as conversion_rate
FROM ahoy_visits v
LEFT JOIN users u ON v.user_id = u.id
WHERE v.started_at >= NOW() - INTERVAL '30 days'
GROUP BY v.landing_page
ORDER BY signups DESC;
```

### User Activity by Plan Type
```sql
SELECT
  s.plan,
  COUNT(DISTINCT v.user_id) as active_users,
  COUNT(*) as total_visits,
  ROUND(AVG(EXTRACT(EPOCH FROM (v.ended_at - v.started_at)))) as avg_session_duration_seconds
FROM ahoy_visits v
JOIN users u ON v.user_id = u.id
JOIN subscriptions s ON s.user_id = u.id
WHERE v.started_at >= NOW() - INTERVAL '30 days'
  AND s.status = 'active'
GROUP BY s.plan
ORDER BY active_users DESC;
```

### Users Who Haven't Logged In (30 Days)
```sql
SELECT
  u.id,
  u.first_name,
  u.email,
  MAX(v.started_at) as last_visit,
  s.plan,
  s.status
FROM users u
LEFT JOIN ahoy_visits v ON v.user_id = u.id
LEFT JOIN subscriptions s ON s.user_id = u.id
WHERE s.status = 'active'
GROUP BY u.id, u.first_name, u.email, s.plan, s.status
HAVING MAX(v.started_at) < NOW() - INTERVAL '30 days' OR MAX(v.started_at) IS NULL
ORDER BY last_visit DESC NULLS LAST;
```

## 📈 Subscription Insights

### Subscription Sign-ups by Referrer
```sql
SELECT
  v.referring_domain,
  COUNT(DISTINCT s.id) as subscriptions_created,
  COUNT(DISTINCT s.user_id) as unique_users
FROM subscriptions s
JOIN users u ON s.user_id = u.id
JOIN ahoy_visits v ON v.user_id = u.id
WHERE s.created_at >= NOW() - INTERVAL '90 days'
  AND v.started_at <= s.created_at
GROUP BY v.referring_domain
ORDER BY subscriptions_created DESC
LIMIT 15;
```

### Time from First Visit to Subscription
```sql
SELECT
  CASE
    WHEN signup_delay_hours < 1 THEN 'Less than 1 hour'
    WHEN signup_delay_hours < 24 THEN '1-24 hours'
    WHEN signup_delay_hours < 168 THEN '1-7 days'
    WHEN signup_delay_hours < 720 THEN '1-30 days'
    ELSE 'More than 30 days'
  END as time_to_signup,
  COUNT(*) as count
FROM (
  SELECT
    s.id,
    EXTRACT(EPOCH FROM (s.created_at - first_visit.started_at)) / 3600 as signup_delay_hours
  FROM subscriptions s
  JOIN (
    SELECT
      user_id,
      MIN(started_at) as started_at
    FROM ahoy_visits
    WHERE user_id IS NOT NULL
    GROUP BY user_id
  ) first_visit ON first_visit.user_id = s.user_id
  WHERE s.created_at >= NOW() - INTERVAL '90 days'
) delays
GROUP BY time_to_signup
ORDER BY
  CASE time_to_signup
    WHEN 'Less than 1 hour' THEN 1
    WHEN '1-24 hours' THEN 2
    WHEN '1-7 days' THEN 3
    WHEN '1-30 days' THEN 4
    ELSE 5
  END;
```

## 💰 Revenue Analytics

### Revenue by Traffic Source
```sql
SELECT
  COALESCE(v.utm_source, v.referring_domain, 'Direct') as source,
  COUNT(DISTINCT i.id) as invoices,
  SUM(i.total_amount) as total_revenue,
  ROUND(AVG(i.total_amount), 2) as avg_invoice_value
FROM invoices i
JOIN subscriptions s ON i.subscription_id = s.id
LEFT JOIN ahoy_visits v ON v.user_id = s.user_id
WHERE i.created_at >= NOW() - INTERVAL '90 days'
  AND i.paid = true
  AND v.started_at <= i.created_at
GROUP BY source
ORDER BY total_revenue DESC;
```

### Users Who Viewed Pricing But Didn't Subscribe
```sql
SELECT DISTINCT
  u.id,
  u.first_name,
  u.email,
  v.started_at as last_visit
FROM ahoy_visits v
JOIN users u ON v.user_id = u.id
LEFT JOIN subscriptions s ON s.user_id = u.id
WHERE v.landing_page LIKE '%pricing%'
  OR v.landing_page LIKE '%shop%'
  AND v.started_at >= NOW() - INTERVAL '30 days'
  AND s.id IS NULL
ORDER BY last_visit DESC;
```

## 🚀 Engagement Tracking

### Daily Active Users (Last 30 Days)
```sql
SELECT
  DATE(started_at) as date,
  COUNT(DISTINCT user_id) as daily_active_users
FROM ahoy_visits
WHERE started_at >= NOW() - INTERVAL '30 days'
  AND user_id IS NOT NULL
GROUP BY DATE(started_at)
ORDER BY date DESC;
```

### Page Views per Session
```sql
SELECT
  views_per_session,
  COUNT(*) as session_count
FROM (
  SELECT
    visit_token,
    COUNT(*) as views_per_session
  FROM ahoy_events
  WHERE time >= NOW() - INTERVAL '30 days'
    AND name = '$view'
  GROUP BY visit_token
) subquery
GROUP BY views_per_session
ORDER BY views_per_session;
```

## 📱 Custom Event Tracking Examples

Once you start tracking custom events with Ahoy, use these queries:

### Track Button Clicks
```ruby
# In your controller or view
ahoy.track "Clicked Upgrade Button", plan: "XL"
```

```sql
SELECT
  DATE(time) as date,
  COUNT(*) as clicks
FROM ahoy_events
WHERE name = 'Clicked Upgrade Button'
  AND time >= NOW() - INTERVAL '30 days'
GROUP BY DATE(time)
ORDER BY date DESC;
```

### Track Feature Usage
```ruby
# Track when users pause subscriptions
ahoy.track "Paused Subscription", subscription_id: @subscription.id, reason: params[:reason]
```

```sql
SELECT
  properties->>'reason' as pause_reason,
  COUNT(*) as count
FROM ahoy_events
WHERE name = 'Paused Subscription'
  AND time >= NOW() - INTERVAL '90 days'
GROUP BY pause_reason
ORDER BY count DESC;
```

## 🔧 Tips for Using Blazer

1. **Save queries**: Click "Save" after writing a query to reuse it
2. **Create dashboards**: Combine multiple queries into a single dashboard
3. **Schedule checks**: Set up alerts for important metrics (e.g., "No signups in 24 hours")
4. **Use smart variables**: Add `{plan}` to your queries to create dropdowns
5. **Export data**: Download results as CSV for further analysis

## 🎯 Recommended Custom Events to Track

Add these to your app:
```ruby
# Subscription actions
ahoy.track "Started Subscription", plan: @subscription.plan, duration: @subscription.duration
ahoy.track "Paused Subscription", subscription_id: @subscription.id
ahoy.track "Cancelled Subscription", subscription_id: @subscription.id, reason: params[:reason]

# Invoice actions
ahoy.track "Viewed Invoice", invoice_id: @invoice.id
ahoy.track "Downloaded Invoice PDF", invoice_id: @invoice.id
ahoy.track "Paid Invoice", invoice_id: @invoice.id, amount: @invoice.total_amount

# Engagement
ahoy.track "Requested Bags", subscription_id: @subscription.id, quantity: params[:quantity]
ahoy.track "Added Customer Note", collection_id: @collection.id
ahoy.track "Viewed Collections History"

# Referrals
ahoy.track "Viewed Referral Page"
ahoy.track "Copied Referral Link", code: current_user.referral_code
```
