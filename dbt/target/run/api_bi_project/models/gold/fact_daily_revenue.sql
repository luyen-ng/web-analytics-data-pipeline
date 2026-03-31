
  
    

  create  table "db"."gold"."fact_daily_revenue__dbt_tmp"
  
  
    as
  
  (
    with payments as (
  select * from "db"."silver"."silver_payments"
)
select
  order_day,
  product,
  country,
  sum(net_revenue) as net_revenue,
  count(*) as orders
from payments
group by order_day, product, country
  );
  