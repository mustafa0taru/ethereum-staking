-- Total Deposits - Count of all deposit transactions
-- Total ETH Staked - Sum of all ETH deposited (rounded to 4 decimals)
-- Avg Deposit Size - Average ETH amount per deposit (rounded to 4 decimals)
-- First Deposit Date - Timestamp of first deposit transaction
-- Last Deposit Date - Timestamp of most recent deposit transaction
-- Unique Depositors - Count of distinct addresses that made deposits
-- Total Withdrawals - Count of all withdrawal events
-- Total ETH Withdrawn - Sum of all ETH withdrawn (rounded to 4 decimals)
-- First Withdrawal Date - Timestamp of first withdrawal
-- Last Withdrawal Date - Timestamp of most recent withdrawal
-- Net Rewards Earned (ETH) - Calculated as: Total Withdrawn - Total Staked (rounded to 4 decimals)
-- Total ROI (%) - Calculated as: (Net Rewards / Total Staked) × 100 (rounded to 2 decimals)
-- Total Transactions - Count of all successful transactions with value > 0
-- Inbound Tx - Count of transactions received by the address
-- Outbound Tx - Count of transactions sent from the address
-- Total Inflows (ETH) - Sum of all ETH received (rounded to 4 decimals)
-- Total Outflows (ETH) - Sum of all ETH sent (rounded to 4 decimals)
-- Total Gas Spent (ETH) - Sum of all gas costs from outbound transactions (rounded to 4 decimals)


WITH 
deposit_summary AS (
    SELECT 
        COUNT(*) as total_deposits,
        SUM(amount_staked) as total_eth_staked,
        AVG(amount_staked) as avg_deposit_size,
        MIN(block_time) as first_deposit,
        MAX(block_time) as last_deposit,
        COUNT(DISTINCT tx_from) as unique_depositors
    FROM staking_ethereum.deposits
    WHERE withdrawal_address = 0xe3c44d4d25172ef2e0cdb9e09189a8ca4ed878f4
),

-- withdrawal
withdrawal_summary AS (
    SELECT 
        COUNT(*) as total_withdrawals,
        SUM(amount / 1e9) as total_eth_withdrawn,
        COUNT(DISTINCT validator_index) as active_validators,
        MIN(block_time) as first_withdrawal,
        MAX(block_time) as last_withdrawal
    FROM ethereum.withdrawals
    WHERE address = 0xe3c44d4d25172ef2e0cdb9e09189a8ca4ed878f4
),

-- transaction
transaction_summary AS (
    SELECT 
        COUNT(*) as total_transactions,
        SUM(CASE WHEN "to" = 0xe3c44d4d25172ef2e0cdb9e09189a8ca4ed878f4 THEN 1 ELSE 0 END) as inflow_count,
        SUM(CASE WHEN "from" = 0xe3c44d4d25172ef2e0cdb9e09189a8ca4ed878f4 THEN 1 ELSE 0 END) as outflow_count,
        ROUND(SUM(CASE WHEN "to" = 0xe3c44d4d25172ef2e0cdb9e09189a8ca4ed878f4 THEN value / 1e18 ELSE 0 END), 4) as total_inflows,
        ROUND(SUM(CASE WHEN "from" = 0xe3c44d4d25172ef2e0cdb9e09189a8ca4ed878f4 THEN value / 1e18 ELSE 0 END), 4) as total_outflows,
        ROUND(SUM(CASE WHEN "from" = 0xe3c44d4d25172ef2e0cdb9e09189a8ca4ed878f4 THEN (gas_used * gas_price) / 1e18 ELSE 0 END), 4) as total_gas_cost
    FROM ethereum.transactions
    WHERE ("to" = 0xe3c44d4d25172ef2e0cdb9e09189a8ca4ed878f4 
           OR "from" = 0xe3c44d4d25172ef2e0cdb9e09189a8ca4ed878f4)
        AND success = true
        AND value > 0
)

SELECT 
    -- deposit
    d.total_deposits as "Total Deposits",
    ROUND(d.total_eth_staked, 4) as "Total ETH Staked",
    ROUND(d.avg_deposit_size, 4) as "Avg Deposit Size",
    d.first_deposit as "First Deposit Date",
    d.last_deposit as "Last Deposit Date",
    
    -- validator
    w.active_validators as "Active Validators",
    
    -- withdrawals
    w.total_withdrawals as "Total Withdrawals",
    ROUND(w.total_eth_withdrawn, 4) as "Total ETH Withdrawn",
    w.first_withdrawal as "First Withdrawal Date",
    w.last_withdrawal as "Last Withdrawal Date",
    
    -- rewards calculation
    ROUND(w.total_eth_withdrawn - d.total_eth_staked, 4) as "Net Rewards Earned (ETH)",
    ROUND((w.total_eth_withdrawn - d.total_eth_staked) / d.total_eth_staked * 100, 2) as "Total ROI (%)",
    
    -- transactions
    t.total_transactions as "Total Transactions",
    t.inflow_count as "Inbound Tx",
    t.outflow_count as "Outbound Tx",
    t.total_inflows as "Total Inflows (ETH)",
    t.total_outflows as "Total Outflows (ETH)",
    t.total_gas_cost as "Total Gas Spent (ETH)"
    
FROM deposit_summary d, withdrawal_summary w, transaction_summary t;

-- Date - Date truncated to day level
-- Daily Deposits - Count of deposits made on that day
-- ETH Deposited - Total ETH deposited on that day (rounded to 4 decimals)
-- Unique Depositors - Count of distinct addresses that deposited on that day
-- Cumulative ETH Staked - Running total of all ETH staked up to that day (rounded to 2 decimals)

SELECT 
    DATE_TRUNC('day', block_time) as "Date",
    COUNT(*) as "Daily Deposits",
    ROUND(SUM(amount_staked), 4) as "ETH Deposited",
    COUNT(DISTINCT tx_from) as "Unique Depositors",
    ROUND(SUM(SUM(amount_staked)) OVER (ORDER BY DATE_TRUNC('day', block_time)), 2) as "Cumulative ETH Staked"
FROM staking_ethereum.deposits
WHERE withdrawal_address = 0xe3c44d4d25172ef2e0cdb9e09189a8ca4ed878f4
GROUP BY 1
ORDER BY 1;

-- Month - Month truncated to month level
-- Deposits - Count of deposit transactions in that month
-- ETH Deposited - Total ETH deposited in that month (rounded to 2 decimals)
-- Unique Depositors - Count of distinct depositor addresses in that month
-- Unique Entities - Count of distinct staking entities/pools used in that month
-- Avg Deposit Size - Average ETH per deposit in that month (rounded to 2 decimals)
-- Cumulative ETH - Running total of all ETH staked through that month (rounded to 2 decimals)
-- Previous Month ETH - ETH deposited in the previous month
-- MoM Change (ETH) - Absolute change from previous month (rounded to 2 decimals)
-- MoM Growth % - Percentage change from previous month (rounded to 2 decimals)
-- Year-over-Year (YoY) Growth Metrics
-- Same Month Last Year - ETH deposited in the same month 12 months ago
-- YoY Growth % - Percentage change compared to same month last year (rounded to 2 decimals)
-- Trend - Visual indicator showing:

WITH monthly_deposits AS (
    SELECT 
        DATE_TRUNC('month', block_time) as month,
        COUNT(*) as deposit_count,
        SUM(amount_staked) as eth_deposited,
        AVG(amount_staked) as avg_deposit_size,
        COUNT(DISTINCT tx_from) as unique_depositors,
        COUNT(DISTINCT entity) as unique_entities,
        MIN(block_time) as first_deposit_in_month,
        MAX(block_time) as last_deposit_in_month
    FROM staking_ethereum.deposits
    WHERE withdrawal_address = 0xe3c44d4d25172ef2e0cdb9e09189a8ca4ed878f4
    GROUP BY 1
)

SELECT 
    month as "Month",
    deposit_count as "Deposits",
    ROUND(eth_deposited, 2) as "ETH Deposited",
    unique_depositors as "Unique Depositors",
    unique_entities as "Unique Entities",
    ROUND(avg_deposit_size, 2) as "Avg Deposit Size",
    
    -- cumulative
    ROUND(SUM(eth_deposited) OVER (ORDER BY month), 2) as "Cumulative ETH",
    
    -- month-over-month growth
    LAG(eth_deposited) OVER (ORDER BY month) as "Previous Month ETH",
    ROUND(eth_deposited - LAG(eth_deposited) OVER (ORDER BY month), 2) as "MoM Change (ETH)",
    ROUND(
        (eth_deposited - LAG(eth_deposited) OVER (ORDER BY month)) / 
        NULLIF(LAG(eth_deposited) OVER (ORDER BY month), 0) * 100, 
        2
    ) as "MoM Growth %",
    
    -- year-over-year comparison
    LAG(eth_deposited, 12) OVER (ORDER BY month) as "Same Month Last Year",
    ROUND(
        (eth_deposited - LAG(eth_deposited, 12) OVER (ORDER BY month)) / 
        NULLIF(LAG(eth_deposited, 12) OVER (ORDER BY month), 0) * 100, 
        2
    ) as "YoY Growth %",
    
    -- activity indicator
    CASE 
        WHEN eth_deposited > LAG(eth_deposited) OVER (ORDER BY month) THEN '📈 Increasing'
        WHEN eth_deposited < LAG(eth_deposited) OVER (ORDER BY month) THEN '📉 Decreasing'
        WHEN eth_deposited = LAG(eth_deposited) OVER (ORDER BY month) THEN '➡️ Stable'
        ELSE '🆕 First Month'
    END as "Trend"
    
FROM monthly_deposits
ORDER BY month DESC;

