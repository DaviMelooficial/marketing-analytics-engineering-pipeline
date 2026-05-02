SELECT
    date,
    campaign_id,
    campaign_name,
    channel,
    country,

    impressions,
    clicks,
    cost,
    sessions,
    pageviews,
    revenue,

    (revenue - cost) AS profit,

    CASE WHEN impressions > 0 THEN clicks / impressions ELSE 0 END AS ctr,

    CASE WHEN clicks > 0 THEN cost / clicks ELSE 0 END AS cpc,

    CASE WHEN cost > 0 THEN revenue / cost ELSE 0 END AS roas,

    CASE WHEN sessions > 0 THEN revenue / sessions * 1000 ELSE 0 END AS rpm,

    CASE WHEN sessions > 0 THEN pageviews / sessions ELSE 0 END AS pages_per_session

FROM {{ ref('int_campaign_daily_performance') }}