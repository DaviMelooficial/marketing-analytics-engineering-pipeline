SELECT
    date,
    campaign_id,
    impressions,
    clicks,
    cost
FROM {{ source('raw', 'raw_ads_costs') }}