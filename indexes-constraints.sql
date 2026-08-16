-- ---------------------------------------------------------------------
--  PK vazebni tabulky je (PurchaseID, BannerPlacementID) a umi tedy
--  odpovedet jen na "z kterych banneru prisel TENTO nakup".
--  Vsechny reporty se ptaji OPACNE - "ktere nakupy prisly z tohoto
--  umisteni" - a na to je PK s PurchaseID na prvnim miste nepouzitelny.
-- ---------------------------------------------------------------------
CREATE INDEX ix_pbp_placement
    ON PurchaseBannerPlacement (BannerPlacementID, PurchaseID);

-- ---------------------------------------------------------------------
--  Velka tabulka Purchase
-- ---------------------------------------------------------------------
-- Reporty za obdobi ("kolik jsme prodali v breznu")
CREATE INDEX ix_purchase_date ON Purchase (Date);

-- Pokryvajici index pro join pres PK vcetne ctenych sloupcu
CREATE INDEX ix_purchase_covering ON Purchase (UniqueID) INCLUDE (Date, Margin);

-- ---------------------------------------------------------------------
--  Cizi klice na BannerPlacement (vsechny tri)
--  Neindexovany FK zpomaluje i DELETE rodicovskeho radku -
--  databaze musi potomky prochazet sekvencne.
-- ---------------------------------------------------------------------
CREATE INDEX ix_placement_campaign
    ON BannerPlacement (CampaignID) INCLUDE (BannerPositionID, ClickCount);
CREATE INDEX ix_placement_position ON BannerPlacement (BannerPositionID);
CREATE INDEX ix_placement_banner   ON BannerPlacement (BannerID);
CREATE INDEX ix_position_web       ON BannerPosition (WebID);

-- ---------------------------------------------------------------------
--  Business logika
-- ---------------------------------------------------------------------
CREATE INDEX ix_campaign_dates ON Campaign (DateStart, DateEnd);   -- bezici kampane
CREATE INDEX ix_banner_size    ON Banner (Width, Height);          -- pravidlo shodne velikosti
CREATE INDEX ix_position_size  ON BannerPosition (Width, Height);  -- "kam se banner vejde"
CREATE INDEX ix_placement_banner_campaign
    ON BannerPlacement (BannerID, CampaignID) INCLUDE (ClickCount); -- ucinnost banneru
    
    
-- Marze nemuze prevysit cenu zakazky.
-- ZAPORNA ale byt SMI - prodej se ztratou je legitimni,
-- proto zamerne NENI "Margin >= 0".
ALTER TABLE Purchase
    ADD CONSTRAINT purchase_margin_ok CHECK (Margin <= TotalAmount);

ALTER TABLE Purchase
    ADD CONSTRAINT purchase_amount_ok CHECK (TotalAmount >= 0);

-- Tentyz banner do teze pozice v teze kampani nema smysl dvakrat
--   UNIQUE (BannerID, CampaignID, BannerPositionID)   -- v CREATE TABLE

-- ---------------------------------------------------------------------
--  Pravidla, ktera CHECK vynutit NEUMI (nesmi cist jine tabulky) -> triggery.
-- ---------------------------------------------------------------------

-- Banner lze umistit jen do pozice STEJNE velikosti (primo ze zadani)
CREATE OR REPLACE FUNCTION check_placement_size() RETURNS TRIGGER AS $$
DECLARE b_w INT; b_h INT; p_w INT; p_h INT;
BEGIN
    SELECT Width, Height INTO b_w, b_h FROM Banner WHERE UniqueID = NEW.BannerID;
    SELECT Width, Height INTO p_w, p_h FROM BannerPosition WHERE UniqueID = NEW.BannerPositionID;
    IF b_w <> p_w OR b_h <> p_h THEN
        RAISE EXCEPTION 'Rozmer banneru (%x%) nesouhlasi s rozmerem pozice (%x%)',
            b_w, b_h, p_w, p_h;
    END IF;
    RETURN NEW;
END; $$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_placement_size ON BannerPlacement;
CREATE TRIGGER trg_placement_size
    BEFORE INSERT OR UPDATE ON BannerPlacement
    FOR EACH ROW EXECUTE FUNCTION check_placement_size();

--  Jedna pozice = jeden banner v danem case.
CREATE OR REPLACE FUNCTION check_position_free() RETURNS TRIGGER AS $$
DECLARE kolize INT;
BEGIN
    SELECT COUNT(*) INTO kolize
    FROM BannerPlacement bp
             JOIN Campaign c  ON c.UniqueID = bp.CampaignID
             JOIN Campaign nc ON nc.UniqueID = NEW.CampaignID
    WHERE bp.BannerPositionID = NEW.BannerPositionID
      AND bp.ID IS DISTINCT FROM NEW.ID
      AND daterange(c.DateStart, c.DateEnd, '[]') && daterange(nc.DateStart, nc.DateEnd, '[]');
    IF kolize > 0 THEN
        RAISE EXCEPTION 'Pozice % je v tomto obdobi jiz obsazena (% kolizi)',
            NEW.BannerPositionID, kolize;
    END IF;
    RETURN NEW;
END; $$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_position_free ON BannerPlacement;
CREATE TRIGGER trg_position_free
    BEFORE INSERT OR UPDATE ON BannerPlacement
    FOR EACH ROW EXECUTE FUNCTION check_position_free();


