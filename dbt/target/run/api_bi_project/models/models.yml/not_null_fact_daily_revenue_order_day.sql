select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select order_day
from "db"."gold"."fact_daily_revenue"
where order_day is null



      
    ) dbt_internal_test