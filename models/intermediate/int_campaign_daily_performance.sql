SELECT
    c.date,
    c.campaign_id,
    camp.campaign_name,
    camp.channel,
    camp.country,

    c.impressions,
    c.clicks,
    c.cost,

    r.sessions,
    r.pageviews,
    r.revenue

FROM {{ ref('stg_ads_costs') }} c
LEFT JOIN {{ ref('stg_site_revenue') }} r
    ON c.date = r.date
    AND c.campaign_id = r.campaign_id
LEFT JOIN {{ ref('stg_ads_campaigns') }} camp
    ON c.campaign_id = camp.campaign_id