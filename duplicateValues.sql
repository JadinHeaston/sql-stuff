SELECT column,
    COUNT(*)
FROM table
GROUP BY column
HAVING COUNT(*) > 1;