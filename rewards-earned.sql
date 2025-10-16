-- Total Reward Events - Count of all individual reward withdrawals (< 1 ETH each)
-- Total Rewards Earned (ETH) - Sum of all ETH earned as rewards (rounded to 4 decimals)
-- Average Reward per Event (ETH) - Mean ETH amount per reward event (rounded to 6 decimals)
-- Validators Earning Rewards - Count of unique validators receiving rewards
-- Total ETH Staked - Sum of all ETH deposited by the address (rounded to 2 decimals)
-- Total ETH Withdrawn - Sum of all ETH withdrawn by the address (rounded to 2 decimals)
-- Rewards ROI (%) - Percentage return from rewards only: (Total Rewards / Total Staked) × 100 (rounded to 2 decimals)
-- Net Position ROI (%) - Net return after withdrawals: ((Total Withdrawn - Total Staked) / Total Staked) × 100 (rounded to 2 decimals)
-- Estimated APR (%) - Annualized rate of return based on total rewards and staking duration (rounded to 2 decimals)
-- First Reward Date - Timestamp of the earliest reward withdrawal
-- Most Recent Reward - Timestamp of the latest reward event
-- Days Earning Rewards - Number of days between first and most recent reward
-- Performance Rating - Classification based on APR:
--   > 5% → Excellent
--   3–5% → Good
--   < 3% → Below Average

WITH deposit_data AS (
    SELECT 
        SUM(amount_staked) as total_staked,
        MIN(block_time) as first_deposit
    FROM staking_ethereum.deposits
    WHERE withdrawal_address = 0xe3c44d4d25172ef2e0cdb9e09189a8ca4ed878f4
),

reward_data AS (
    SELECT 
        COUNT(*) as reward_events,
        SUM(amount / 1e9) as total_rewards,
        AVG(amount / 1e9) as avg_reward,
        MIN(block_time) as first_reward,
        MAX(block_time) as last_reward,
        COUNT(DISTINCT validator_index) as validators_earning
    FROM ethereum.withdrawals
    WHERE address = 0xe3c44d4d25172ef2e0cdb9e09189a8ca4ed878f4
        AND amount / 1e9 < 1  -- Only reward withdrawals (< 1 ETH)
),

all_withdrawals AS (
    SELECT SUM(amount / 1e9) as total_withdrawn
    FROM ethereum.withdrawals
    WHERE address = 0xe3c44d4d25172ef2e0cdb9e09189a8ca4ed878f4
)

SELECT 
    r.reward_events as "Total Reward Events",
    ROUND(r.total_rewards, 4) as "Total Rewards Earned (ETH)",
    ROUND(r.avg_reward, 6) as "Average Reward per Event (ETH)",
    r.validators_earning as "Validators Earning Rewards",
    ROUND(d.total_staked, 2) as "Total ETH Staked",
    ROUND(w.total_withdrawn, 2) as "Total ETH Withdrawn",
    ROUND(r.total_rewards / d.total_staked * 100, 2) as "Rewards ROI (%)",
    ROUND((w.total_withdrawn - d.total_staked) / d.total_staked * 100, 2) as "Net Position ROI (%)",
    ROUND(
        (r.total_rewards / d.total_staked) * 
        (365.25 / GREATEST(DATE_DIFF('day', r.first_reward, CURRENT_DATE), 1)) * 100, 
        2
    ) as "Estimated APR (%)",
    r.first_reward as "First Reward Date",
    r.last_reward as "Most Recent Reward",
    DATE_DIFF('day', r.first_reward, r.last_reward) as "Days Earning Rewards",
    CASE 
        WHEN (r.total_rewards / d.total_staked) * (365.25 / GREATEST(DATE_DIFF('day', r.first_reward, CURRENT_DATE), 1)) * 100 > 5
        THEN 'Excellent (Above 5% APR)'
        WHEN (r.total_rewards / d.total_staked) * (365.25 / GREATEST(DATE_DIFF('day', r.first_reward, CURRENT_DATE), 1)) * 100 > 3
        THEN 'Good (3-5% APR)'
        ELSE 'Below Average (Under 3%)'
    END as "Performance Rating"
FROM deposit_data d, reward_data r, all_withdrawals w;


-- Date - Date truncated to day level
-- Events - Count of reward withdrawal events for that day
-- Validators - Count of unique validators that earned rewards that day
-- Daily Rewards (ETH) - Total ETH earned as rewards for that day (rounded to 6 decimals)
-- Avg per Validator - Average ETH reward per validator on that day (rounded to 6 decimals)
-- 7-Day Moving Avg - Rolling 7-day average of daily rewards (rounded to 6 decimals)
-- 30-Day Moving Avg - Rolling 30-day average of daily rewards (rounded to 6 decimals)

WITH daily_rewards AS (
    SELECT 
        DATE_TRUNC('day', block_time) as day,
        COUNT(*) as events,
        COUNT(DISTINCT validator_index) as validators,
        SUM(amount / 1e9) as rewards
    FROM ethereum.withdrawals
    WHERE address = 0xe3c44d4d25172ef2e0cdb9e09189a8ca4ed878f4
        AND amount / 1e9 < 1  -- Only rewards
        AND block_time >= CURRENT_DATE - INTERVAL '90' DAY
    GROUP BY 1
)

SELECT 
    day as "Date",
    events as "Events",
    validators as "Validators",
    ROUND(rewards, 6) as "Daily Rewards (ETH)",
    ROUND(rewards / validators, 6) as "Avg per Validator",
    ROUND(AVG(rewards) OVER (ORDER BY day ROWS BETWEEN 6 PRECEDING AND CURRENT ROW), 6) as "7-Day Moving Avg",
    ROUND(AVG(rewards) OVER (ORDER BY day ROWS BETWEEN 29 PRECEDING AND CURRENT ROW), 6) as "30-Day Moving Avg"
FROM daily_rewards
ORDER BY day DESC;
