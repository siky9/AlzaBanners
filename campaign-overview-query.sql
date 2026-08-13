WITH naklady AS (
    SELECT bp.CampaignID,
           SUM(
               CASE bpos.PriceType
                   -- placeno za den: cena x delka kampane (umisteni nema vlastni datumy)
                   WHEN 'per_day' THEN
                       bpos.PriceAmount * (c.DateEnd - c.DateStart + 1)
                   -- placeno za proklik: cena x skutecny pocet prokliku
                   WHEN 'per_click' THEN
                       bpos.PriceAmount * COALESCE(bp.ClickCount, 0)
               END
           ) AS Naklady
    FROM BannerPlacement bp
             JOIN BannerPosition bpos ON bpos.UniqueID = bp.BannerPositionID
             JOIN Campaign c ON c.UniqueID = bp.CampaignID
    GROUP BY bp.CampaignID
),
vynosy AS (
    SELECT t.CampaignID,
           SUM(p.Margin) AS Vynosy
    FROM (
             -- kazdy nakup jen jednou za kampan, i kdyz prisel z vice banneru
             SELECT DISTINCT bp.CampaignID, pbp.PurchaseID
             FROM BannerPlacement bp
                      JOIN PurchaseBannerPlacement pbp
                           ON pbp.BannerPlacementID = bp.UniqueID
         ) t
             JOIN Purchase p ON p.UniqueID = t.PurchaseID
    GROUP BY t.CampaignID
)
SELECT c.UniqueID AS CampaignID,
       c.DateStart,
       c.DateEnd,
       COALESCE(v.Vynosy, 0)  AS Vynosy,
       COALESCE(n.Naklady, 0) AS Naklady,
       COALESCE(v.Vynosy, 0) - COALESCE(n.Naklady, 0) AS Bilance
FROM Campaign c
         LEFT JOIN vynosy v ON v.CampaignID = c.UniqueID
         LEFT JOIN naklady n ON n.CampaignID = c.UniqueID
ORDER BY Bilance DESC;