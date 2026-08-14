WITH dny (Dow, Nazev) AS (
    -- pevny seznam zaruci 7 radku i pro dny bez dat
             SELECT 1, 'Pondeli'
    UNION ALL SELECT 2, 'Utery'
    UNION ALL SELECT 3, 'Streda'
    UNION ALL SELECT 4, 'Ctvrtek'
    UNION ALL SELECT 5, 'Patek'
    UNION ALL SELECT 6, 'Sobota'
    UNION ALL SELECT 7, 'Nedele'
),
naklady AS (
    -- kazde umisteni se rozepise na jednotlive dny trvani kampane;
    -- za kazdy takovy den se plati PriceAmount
    SELECT EXTRACT(ISODOW FROM den)::int AS Dow,
           SUM(bpos.PriceAmount)         AS Naklady
    FROM BannerPlacement bp
             JOIN BannerPosition bpos ON bpos.UniqueID = bp.BannerPositionID
             JOIN Campaign c ON c.UniqueID = bp.CampaignID
             CROSS JOIN LATERAL generate_series(
                     c.DateStart, c.DateEnd, INTERVAL '1 day'
                 ) AS den
    WHERE bpos.PriceType = 1
    GROUP BY 1
),
vynosy AS (
    SELECT EXTRACT(ISODOW FROM p.Date)::int AS Dow,
           SUM(p.Margin)                    AS Vynosy
    FROM (
             -- kazdy nakup jen jednou, i kdyz prisel z vice dennich banneru
             SELECT DISTINCT pbp.PurchaseID
             FROM PurchaseBannerPlacement pbp
                      JOIN BannerPlacement bp ON bp.UniqueID = pbp.BannerPlacementID
                      JOIN BannerPosition bpos ON bpos.UniqueID = bp.BannerPositionID
             WHERE bpos.PriceType = 1
         ) t
             JOIN Purchase p ON p.UniqueID = t.PurchaseID
    GROUP BY 1
)
SELECT d.Nazev                                            AS DenVTydnu,
       COALESCE(v.Vynosy, 0)                              AS Vynosy,
       COALESCE(n.Naklady, 0)                             AS Naklady,
       COALESCE(v.Vynosy, 0) - COALESCE(n.Naklady, 0)     AS Bilance
FROM dny d
         LEFT JOIN naklady n ON n.Dow = d.Dow
         LEFT JOIN vynosy v ON v.Dow = d.Dow
ORDER BY d.Dow;