
USE instagram_db;

--  Total users

SELECT * FROM users;

--  Username with every post

SELECT
    p.post_id,
    u.username,
    p.caption,
    p.created_at
FROM posts p
JOIN users u ON p.user_id = u.user_id;

--  Total likes on each post

SELECT
    p.post_id,
    p.caption,
    COUNT(l.user_id) AS total_likes
FROM posts p
LEFT JOIN likes l ON p.post_id = l.post_id
GROUP BY p.post_id, p.caption
ORDER BY total_likes DESC;

--  Total posts per user

SELECT
    u.username,
    COUNT(p.post_id) AS total_posts
FROM users u
LEFT JOIN posts p ON u.user_id = p.user_id
GROUP BY u.user_id, u.username
ORDER BY total_posts DESC;

--  The post with the most likes

SELECT
    p.post_id,
    p.caption,
    COUNT(l.user_id) AS total_likes
FROM posts p
LEFT JOIN likes l ON p.post_id = l.post_id
GROUP BY p.post_id, p.caption
ORDER BY total_likes DESC
LIMIT 1;


--  Each user's followers

SELECT
    u.username,
    COUNT(f.follower_id) AS total_followers
FROM users u
LEFT JOIN follows f ON u.user_id = f.following_id
GROUP BY u.user_id, u.username
ORDER BY total_followers DESC;

--  Total comments on each post

SELECT
    p.post_id,
    p.caption,
    COUNT(c.comment_id) AS total_comments
FROM posts p
LEFT JOIN comments c ON p.post_id = c.post_id
GROUP BY p.post_id, p.caption
ORDER BY total_comments DESC;

-- Posts with more than average likes

SELECT
    p.post_id,
    p.caption,
    (
        SELECT COUNT(*)
        FROM likes l
        WHERE l.post_id = p.post_id
    ) AS total_likes
FROM posts p
WHERE (
    SELECT COUNT(*)
    FROM likes l
    WHERE l.post_id = p.post_id
) > (
    SELECT AVG(like_count)
    FROM (
        SELECT COUNT(*) AS like_count
        FROM likes
        GROUP BY post_id
    ) AS post_likes
);

-- Users who have not created a single post

SELECT
    u.user_id,
    u.username
FROM users u
WHERE NOT EXISTS (
    SELECT 1
    FROM posts p
    WHERE p.user_id = u.user_id
);

-- Count the likes for each post and identify the top posts.

WITH post_likes AS (
    SELECT
        p.post_id,
        p.caption,
        COUNT(l.user_id) AS total_likes
    FROM posts p
    LEFT JOIN likes l
        ON p.post_id = l.post_id
    GROUP BY p.post_id, p.caption
)
SELECT *
FROM post_likes
WHERE total_likes >= 2
ORDER BY total_likes DESC;


-- User engagement report from multiple CTEs

WITH post_counts AS (
    SELECT
        user_id,
        COUNT(*) AS total_posts
    FROM posts
    GROUP BY user_id
),
like_counts AS (
    SELECT
        p.user_id,
        COUNT(l.user_id) AS total_likes_received
    FROM posts p
    LEFT JOIN likes l
        ON p.post_id = l.post_id
    GROUP BY p.user_id
)
SELECT
    u.username,
    COALESCE(pc.total_posts, 0) AS total_posts,
    COALESCE(lc.total_likes_received, 0)
        AS total_likes_received
FROM users u
LEFT JOIN post_counts pc
    ON u.user_id = pc.user_id
LEFT JOIN like_counts lc
    ON u.user_id = lc.user_id
ORDER BY total_likes_received DESC;


-- Window function: Ranking of users

WITH user_engagement AS (
    SELECT
        u.user_id,
        u.username,
        COUNT(l.user_id) AS total_likes_received
    FROM users u
    LEFT JOIN posts p
        ON u.user_id = p.user_id
    LEFT JOIN likes l
        ON p.post_id = l.post_id
    GROUP BY u.user_id, u.username
)
SELECT
    username,
    total_likes_received,
    DENSE_RANK() OVER (
        ORDER BY total_likes_received DESC
    ) AS engagement_rank
FROM user_engagement;

-- User Engagement Category

SELECT
    u.username,
    COUNT(l.user_id) AS total_likes,
    CASE
        WHEN COUNT(l.user_id) >= 3 THEN 'High Engagement'
        WHEN COUNT(l.user_id) >= 1 THEN 'Medium Engagement'
        ELSE 'No Engagement'
    END AS engagement_level
FROM users u
LEFT JOIN posts p
    ON u.user_id = p.user_id
LEFT JOIN likes l
    ON p.post_id = l.post_id
GROUP BY u.user_id, u.username
ORDER BY total_likes DESC;


-- Monthly Post Trends

WITH monthly_posts AS (
    SELECT
        DATE_FORMAT(created_at, '%Y-%m') AS post_month,
        COUNT(*) AS total_posts
    FROM posts
    GROUP BY DATE_FORMAT(created_at, '%Y-%m')
)
SELECT
    post_month,
    total_posts
FROM monthly_posts
ORDER BY post_month;


-- Each user's top 3 most-liked posts


WITH post_ranking AS (
    SELECT
        p.user_id,
        u.username,
        p.post_id,
        p.caption,
        COUNT(l.user_id) AS total_likes,
        DENSE_RANK() OVER (
            PARTITION BY p.user_id
            ORDER BY COUNT(l.user_id) DESC
        ) AS post_rank
    FROM posts p
    JOIN users u
        ON p.user_id = u.user_id
    LEFT JOIN likes l
        ON p.post_id = l.post_id
    GROUP BY
        p.user_id,
        u.username,
        p.post_id,
        p.caption
)
SELECT *
FROM post_ranking
WHERE post_rank <= 3
ORDER BY username, post_rank;