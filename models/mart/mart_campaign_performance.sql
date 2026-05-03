WITH base AS (

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
        revenue

    FROM {{ ref('int_campaign_daily_performance') }}

),

final AS (

    SELECT
        date,
        campaign_id,
        campaign_name,
        channel,
        country,

        impressions,
        clicks,
        ROUND(cost, 2) AS cost,
        sessions,
        pageviews,
        ROUND(revenue, 2) AS revenue,

        ROUND(revenue - cost, 2) AS profit,

        ROUND(
            CASE 
                WHEN impressions > 0 
                    THEN clicks::FLOAT / impressions 
                ELSE 0 
            END,
            4
        ) AS ctr,

        ROUND(
            CASE 
                WHEN clicks > 0 
                    THEN cost / clicks 
                ELSE 0 
            END,
            2
        ) AS cpc,

        ROUND(
            CASE 
                WHEN cost > 0 
                    THEN revenue / cost 
                ELSE 0 
            END,
            2
        ) AS roas,

        ROUND(
            CASE 
                WHEN sessions > 0 
                    THEN (revenue / sessions) * 1000 
                ELSE 0 
            END,
            2
        ) AS rpm,

        ROUND(
            CASE 
                WHEN sessions > 0 
                    THEN pageviews::FLOAT / sessions 
                ELSE 0 
            END,
            2
        ) AS pages_per_session

    FROM base

)

SELECT *
FROM final