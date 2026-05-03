WITH base AS (

    SELECT
        date,
        campaign_id
    FROM {{ ref('stg_ads_costs') }}

    UNION

    SELECT
        date,
        campaign_id
    FROM {{ ref('stg_site_revenue') }}

),

final AS (

    SELECT
        b.date,
        b.campaign_id,

        camp.campaign_name,
        camp.channel,
        camp.country,

        COALESCE(c.impressions, 0) AS impressions,
        COALESCE(c.clicks, 0) AS clicks,
        COALESCE(c.cost, 0) AS cost,

        COALESCE(r.sessions, 0) AS sessions,
        COALESCE(r.pageviews, 0) AS pageviews,
        COALESCE(r.revenue, 0) AS revenue

    FROM base b

    LEFT JOIN {{ ref('stg_ads_costs') }} c
        ON b.date = c.date
        AND b.campaign_id = c.campaign_id

    LEFT JOIN {{ ref('stg_site_revenue') }} r
        ON b.date = r.date
        AND b.campaign_id = r.campaign_id

    LEFT JOIN {{ ref('stg_ads_campaigns') }} camp
        ON b.campaign_id = camp.campaign_id

)

SELECT *
FROM final