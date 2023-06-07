SELECT [column],
    COUNT(*) as Count
FROM table
GROUP BY [column]
HAVING COUNT(*) > 1;