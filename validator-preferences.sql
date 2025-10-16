
--   - Total Validators
--   - Fully Exited Validators
--   - Active Validators
--   - Avg Withdrawals per Validator
--   - Avg Rewards per Validator (ETH)
--   - Total Rewards from All Validators
--   - First Validator Activity
--   - Most Recent Activity
--   - Avg Days Active per Validator

WITH validator_stats AS (
    SELECT 
        validator_index,
        COUNT(*) as withdrawals,
        SUM(CASE WHEN amount / 1e9 < 1 THEN amount / 1e9 ELSE 0 END) as rewards,
        MAX(amount / 1e9) as max_withdrawal,
        MIN(block_time) as first_activity,
        MAX(block_time) as last_activity
    FROM ethereum.withdrawals
    WHERE address = 0xe3c44d4d25172ef2e0cdb9e09189a8ca4ed878f4
    GROUP BY 1
)

SELECT 
    COUNT(*) as "Total Validators",
    SUM(CASE WHEN max_withdrawal >= 30 THEN 1 ELSE 0 END) as "Fully Exited Validators",
    SUM(CASE WHEN max_withdrawal < 30 THEN 1 ELSE 0 END) as "Active Validators",
    ROUND(AVG(withdrawals), 1) as "Avg Withdrawals per Validator",
    ROUND(AVG(rewards), 6) as "Avg Rewards per Validator (ETH)",
    ROUND(SUM(rewards), 2) as "Total Rewards from All Validators",
    MIN(first_activity) as "First Validator Activity",
    MAX(last_activity) as "Most Recent Activity",
    ROUND(AVG(DATE_DIFF('day', first_activity, last_activity)), 0) as "Avg Days Active per Validator"
FROM validator_stats;


--   - Entity/Staking Service
--   - Category
--   - Deposit Count
--   - Total ETH Staked
--   - Avg Deposit Size
--   - Unique Addresses
--   - First Deposit
--   - Last Deposit
--   - % of Total Stake

SELECT 
    COALESCE(entity, 'Direct Deposit') as "Entity/Staking Service",
    COALESCE(entity_category, 'Unknown') as "Category",
    COUNT(*) as "Deposit Count",
    ROUND(SUM(amount_staked), 2) as "Total ETH Staked",
    ROUND(AVG(amount_staked), 2) as "Avg Deposit Size",
    COUNT(DISTINCT tx_from) as "Unique Addresses",
    MIN(block_time) as "First Deposit",
    MAX(block_time) as "Last Deposit",
    ROUND(SUM(amount_staked) / SUM(SUM(amount_staked)) OVER () * 100, 2) as "% of Total Stake"
FROM staking_ethereum.deposits
WHERE withdrawal_address = 0xe3c44d4d25172ef2e0cdb9e09189a8ca4ed878f4
GROUP BY 1, 2
ORDER BY 4 DESC;



--   - Validator Status
--   - Validator Count
--   - Avg Total Withdrawn (ETH)
--   - Avg Rewards Earned (ETH)
--   - Total ETH Withdrawn
--   - Total Rewards
--   - Avg Withdrawals
--   - Earliest Activity
--   - Latest Activity


WITH validator_classification AS (
    SELECT 
        validator_index,
        COUNT(*) as withdrawal_count,
        SUM(amount / 1e9) as total_withdrawn,
        SUM(CASE WHEN amount / 1e9 < 1 THEN amount / 1e9 ELSE 0 END) as rewards_earned,
        MAX(amount / 1e9) as max_withdrawal,
        MIN(block_time) as first_activity,
        MAX(block_time) as last_activity
    FROM ethereum.withdrawals
    WHERE address = 0xe3c44d4d25172ef2e0cdb9e09189a8ca4ed878f4
    GROUP BY 1
)

SELECT 
    CASE 
        WHEN max_withdrawal >= 32.5 THEN 'Fully Exited (32+ ETH)'
        WHEN max_withdrawal >= 16 AND max_withdrawal < 32.5 THEN 'Partial Exit (16-32 ETH)'
        WHEN rewards_earned > 0 AND max_withdrawal < 16 THEN 'Active (Earning Rewards)'
        ELSE 'Other Status'
    END as "Validator Status",
    COUNT(*) as "Validator Count",
    ROUND(AVG(total_withdrawn), 4) as "Avg Total Withdrawn (ETH)",
    ROUND(AVG(rewards_earned), 6) as "Avg Rewards Earned (ETH)",
    ROUND(SUM(total_withdrawn), 2) as "Total ETH Withdrawn",
    ROUND(SUM(rewards_earned), 2) as "Total Rewards",
    ROUND(AVG(withdrawal_count), 1) as "Avg Withdrawals",
    MIN(first_activity) as "Earliest Activity",
    MAX(last_activity) as "Latest Activity"
FROM validator_classification
GROUP BY 1
ORDER BY 2 DESC;


--   - Validator Index
--   - Rewards Earned (ETH)
--   - Withdrawals
--   - Days Active
--   - Annualized Rewards (ETH/year)
--   - Rewards as % of 32 ETH
--   - Status
--   - First Activity
--   - Last Activity


WITH validator_performance AS (
    SELECT 
        validator_index,
        COUNT(*) as withdrawal_count,
        SUM(CASE WHEN amount / 1e9 < 1 THEN amount / 1e9 ELSE 0 END) as pure_rewards,
        MAX(amount / 1e9) as max_withdrawal,
        MIN(block_time) as first_withdrawal,
        MAX(block_time) as last_withdrawal,
        DATE_DIFF('day', MIN(block_time), MAX(block_time)) + 1 as days_active
    FROM ethereum.withdrawals
    WHERE address = 0xe3c44d4d25172ef2e0cdb9e09189a8ca4ed878f4
    GROUP BY 1
    HAVING SUM(CASE WHEN amount / 1e9 < 1 THEN amount / 1e9 ELSE 0 END) > 0
)

SELECT 
    validator_index as "Validator Index",
    ROUND(pure_rewards, 6) as "Rewards Earned (ETH)",
    withdrawal_count as "Withdrawals",
    days_active as "Days Active",
    ROUND(pure_rewards / days_active * 365.25, 6) as "Annualized Rewards (ETH/year)",
    ROUND(pure_rewards / 32 * 100, 4) as "Rewards as % of 32 ETH",
    CASE 
        WHEN max_withdrawal >= 30 THEN 'EXITED'
        ELSE 'ACTIVE'
    END as "Status",
    first_withdrawal as "First Activity",
    last_withdrawal as "Last Activity"
FROM validator_performance
ORDER BY pure_rewards DESC
LIMIT 10;



--   - Cohort (First Activity Quarter)
--   - Validators in Cohort
--   - Exited
--   - Still Active
--   - Total Rewards (ETH)
--   - Avg Rewards per Validator
--   - Avg Withdrawals per Validator
--   - Avg ROI per Validator (%)


WITH validator_cohorts AS (
    SELECT 
        validator_index,
        DATE_TRUNC('quarter', MIN(block_time)) as cohort_quarter,
        COUNT(*) as withdrawals,
        SUM(CASE WHEN amount / 1e9 < 1 THEN amount / 1e9 ELSE 0 END) as rewards,
        MAX(amount / 1e9) as max_withdrawal
    FROM ethereum.withdrawals
    WHERE address = 0xe3c44d4d25172ef2e0cdb9e09189a8ca4ed878f4
    GROUP BY 1
)

SELECT 
    cohort_quarter as "Cohort (First Activity Quarter)",
    COUNT(*) as "Validators in Cohort",
    SUM(CASE WHEN max_withdrawal >= 30 THEN 1 ELSE 0 END) as "Exited",
    SUM(CASE WHEN max_withdrawal < 30 THEN 1 ELSE 0 END) as "Still Active",
    ROUND(SUM(rewards), 2) as "Total Rewards (ETH)",
    ROUND(AVG(rewards), 6) as "Avg Rewards per Validator",
    ROUND(AVG(withdrawals), 1) as "Avg Withdrawals per Validator",
    ROUND(SUM(rewards) / COUNT(*) / 32 * 100, 4) as "Avg ROI per Validator (%)"
FROM validator_cohorts
GROUP BY 1
ORDER BY 1 DESC;
