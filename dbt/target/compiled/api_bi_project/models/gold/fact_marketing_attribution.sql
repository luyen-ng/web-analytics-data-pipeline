with ss as (
  select * from "db"."silver"."silver_sessions"
)
select
  session_day,
  source,
  medium,
  coalesce(campaign,'') as campaign,
  sum(converted::int) as conversions,
  avg((not bounced)::int)::float as engagement_rate
from ss
group by session_day, source, medium, coalesce(campaign,'')