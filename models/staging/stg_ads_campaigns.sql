SELECT
    campaign_id,
    campaign_name,
    LOWER(channel) AS channel,
    UPPER(country) AS country,
    start_date,
    status
FROM {{ source('raw', 'raw_ads_campaigns') }}