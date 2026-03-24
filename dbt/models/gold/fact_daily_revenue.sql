with payments as (
  select * from {{ ref('silver_payments') }}
)
select
  order_day,
  product,
  country,
  sum(net_revenue) as net_revenue,
  count(*) as orders
from payments
group by order_day, product, country
