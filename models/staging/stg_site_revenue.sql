SELECT
    date,
    campaign_id,
    sessions,
    pageviews,
    revenue
FROM {{ source('raw', 'raw_site_revenue') }}