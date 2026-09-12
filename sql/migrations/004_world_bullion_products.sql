-- 004_world_bullion_products.sql
--
-- Almost entirely additive. Nothing is renamed, dropped, or restructured, and the
-- only schema change is one CHECK constraint:
--
--   1. Three new coinage alloys - Fine Silver 9999, Coin Gold 900 and
--      Ducat Gold 986 - each added because a real piece below is struck in it and
--      no existing alloy was the right fineness.
--   2. alloy_uses rows for the eleven coinage and bullion alloys that 003 added
--      without any, plus the three new ones. These were missing, not deliberately
--      empty: an alloy with no uses is excluded from every use filter in the UI.
--   3. Eleven mint products - six world bullion coins, four named rounds, and one
--      state-mint medal - and the six coins rows that belong to the coins.
--   4. chk_coins_no_value_without_currency, which forbids a face_value beside the
--      currency code 'XXX'. 'XXX' is ISO 4217 for "no currency involved", so an
--      amount next to it is a quantity of nothing. No existing row breaks it.
--   5. coins.face_value_currency_code widened from CHAR(3) to VARCHAR(3), so a
--      shorter historic abbreviation - 'Kr' for the Austro-Hungarian krone - is
--      stored as written instead of blank-padded to 'Kr '. No value changes.
--
-- Run 001, 002 and 003 first. Safe to run more than once.
--
-- No existing row is modified except the eleven alloys gaining use rows, and that
-- only adds to a junction table. Ids already in use are untouched.

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. Three more coinage alloys
-- ---------------------------------------------------------------------------

-- Same reason as in 003, and the same trap: the INSERT below does not list
-- primary_metal, and ON CONFLICT only rescues a UNIQUE violation. A NOT NULL
-- violation is raised while the candidate row is still being assembled, before
-- any conflict is detected, so inserting a new alloy with the column still
-- mandatory fails outright. It is derived and re-tightened at the end.
ALTER TABLE alloys ALTER COLUMN primary_metal DROP NOT NULL;

INSERT INTO alloys (name, color, alloy_family, description)
VALUES
    ('Fine Silver 9999', 'bright silver', 'PRECIOUS', 'Four-nines silver, the Perth Mint standard for its bullion coins.'),
    ('Coin Gold 900', 'rich gold', 'PRECIOUS', 'The 90 percent standard behind most pre-1933 European and US gold coins.'),
    ('Ducat Gold 986', 'rich gold', 'PRECIOUS', 'The 98.6 percent ducat standard, still struck for Austrian restrikes.')
ON CONFLICT (name) DO UPDATE SET
    color = EXCLUDED.color,
    alloy_family = EXCLUDED.alloy_family,
    description = EXCLUDED.description;

WITH alloy_component_data (alloy_name, element_symbol, pct) AS (
    VALUES
        ('Fine Silver 9999', 'Ag', 99.990),
        ('Fine Silver 9999', 'Cu', 0.010),
        -- Coin Gold 900 is the same 90/10 split as Coin Silver: the standard is
        -- about making a coin hard enough to circulate, not about which precious
        -- metal is being hardened.
        ('Coin Gold 900', 'Au', 90.000),
        ('Coin Gold 900', 'Cu', 10.000),
        ('Ducat Gold 986', 'Au', 98.600),
        ('Ducat Gold 986', 'Cu', 1.400)
)
INSERT INTO alloy_elements (alloy_id, atomic_number, percent_of_alloy)
SELECT
    a.alloy_id,
    e.atomic_number,
    d.pct
FROM alloy_component_data d
INNER JOIN alloys a ON a.name = d.alloy_name
INNER JOIN elements e ON e.symbol = d.element_symbol
ON CONFLICT (alloy_id, atomic_number)
DO UPDATE SET percent_of_alloy = EXCLUDED.percent_of_alloy;

-- ---------------------------------------------------------------------------
-- 2. The coinage and bullion uses that 003 left out
-- ---------------------------------------------------------------------------

-- COINAGE is for metal meant to circulate as money; BULLION is for metal held
-- for what it weighs. Several of these are both, which is the case a junction
-- table exists to express - a Gold Eagle is legal tender nobody spends.
WITH alloy_use_data (alloy_name, use_code) AS (
    VALUES
        ('Commercial Pure Copper', 'COINAGE'),
        ('Commercial Pure Copper', 'BULLION'),
        ('Commercial Pure Copper', 'ELECTRICAL'),
        ('Cupronickel 75/25', 'COINAGE'),
        ('Cupronickel 75/25', 'MARINE'),
        ('Nickel Brass', 'COINAGE'),
        ('Nordic Gold', 'COINAGE'),
        ('Manganese Brass', 'COINAGE'),
        ('Coinage Zinc Core', 'COINAGE'),
        ('Coinage Steel Core', 'COINAGE'),
        ('Coinage Aluminum', 'COINAGE'),
        ('Fine Silver 999', 'BULLION'),
        ('Fine Silver 999', 'COINAGE'),
        ('Fine Platinum 9995', 'BULLION'),
        ('Fine Platinum 9995', 'COINAGE'),
        ('Fine Palladium 9995', 'BULLION'),
        ('Fine Palladium 9995', 'COINAGE'),
        ('Fine Silver 9999', 'BULLION'),
        ('Fine Silver 9999', 'COINAGE'),
        ('Coin Gold 900', 'COINAGE'),
        ('Ducat Gold 986', 'COINAGE'),
        ('Ducat Gold 986', 'BULLION')
)
INSERT INTO alloy_uses (alloy_id, use_code)
SELECT
    a.alloy_id,
    d.use_code
FROM alloy_use_data d
INNER JOIN alloys a ON a.name = d.alloy_name
ON CONFLICT (alloy_id, use_code) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 3. Eleven mint products
-- ---------------------------------------------------------------------------

INSERT INTO mint_products (
    name,
    product_type,
    issuer,
    mint,
    year_introduced,
    gross_weight_g,
    fine_metal_weight_g,
    alloy_id
)
SELECT
    v.name,
    v.product_type,
    v.issuer,
    v.mint,
    v.year_introduced,
    v.gross_weight_g,
    v.fine_metal_weight_g,
    a.alloy_id
FROM (
    VALUES
        -- Modern world bullion coins. year_introduced is the year this dated issue
        -- was struck, not when the series began: for an annual issue like the
        -- Lunar or the Philharmonic, each year is its own product and design.
        ('2027 Gold Lunar Goat (1 oz)', 'COIN', 'Australia', 'The Perth Mint', 2027, 31.1035, 31.1035, 'Fine Gold 24K'),
        ('2026 Silver Kookaburra (1 oz)', 'COIN', 'Australia', 'The Perth Mint', 2026, 31.1035, 31.1035, 'Fine Silver 9999'),
        ('2025 Silver Lunar Snake, Dragon Privy (1 oz)', 'COIN', 'Australia', 'The Perth Mint', 2025, 31.1035, 31.1035, 'Fine Silver 9999'),
        ('2026 Silver Vienna Philharmonic (1 oz)', 'COIN', 'Austria', 'Austrian Mint', 2026, 31.1035, 31.1035, 'Fine Silver 999'),

        -- Historic European gold, still sold as bullion. Neither is pure: both are
        -- hardened with copper so they could survive circulation, which is why the
        -- gross weight is noticeably higher than the gold in it.
        ('Austrian 1 Ducat (1915 Restrike)', 'COIN', 'Austria', 'Austrian Mint', 1915, 3.4909, 3.4420, 'Ducat Gold 986'),
        ('20 Franc Swiss Vreneli', 'COIN', 'Switzerland', 'Swissmint', 1897, 6.4516, 5.8065, 'Coin Gold 900'),

        -- Named rounds. Same metal as the coins above and often the same weight,
        -- but no issuer and no coins row, because nobody declared them money.
        ('Tara Tree of Life Silver Round (1 oz)', 'ROUND', NULL, 'Private mint', NULL, 31.1035, 31.1035, 'Fine Silver 999'),
        ('Tara Tree of Life Gold Round (1 oz)', 'ROUND', NULL, 'Private mint', NULL, 31.1035, 31.1035, 'Fine Gold 24K'),
        ('Year of the Snake Silver Round (1 oz)', 'ROUND', NULL, 'Private mint', NULL, 31.1035, 31.1035, 'Fine Silver 999'),
        ('Aztec Calendar Copper Round (5 oz)', 'ROUND', NULL, 'Private mint', NULL, 155.5175, 155.5175, 'Commercial Pure Copper'),

        -- A state mint striking investment-grade silver that is still not money.
        -- KOMSCO is South Korea's official mint, but Korean law does not authorise
        -- these as legal tender, so KOMSCO issues them as medals - which is why
        -- this is a MEDAL with a fine weight and no coins row. product_type records
        -- legal status, not shape: this is as round as the rounds above.
        ('2022 South Korean Silver Phoenix (1 oz)', 'MEDAL', NULL, 'KOMSCO', 2022, 31.1035, 31.1035, 'Fine Silver 999')
) AS v(
    name,
    product_type,
    issuer,
    mint,
    year_introduced,
    gross_weight_g,
    fine_metal_weight_g,
    alloy_name
)
INNER JOIN alloys a ON a.name = v.alloy_name
ON CONFLICT (name) DO UPDATE SET
    product_type = EXCLUDED.product_type,
    issuer = EXCLUDED.issuer,
    mint = EXCLUDED.mint,
    year_introduced = EXCLUDED.year_introduced,
    gross_weight_g = EXCLUDED.gross_weight_g,
    fine_metal_weight_g = EXCLUDED.fine_metal_weight_g,
    alloy_id = EXCLUDED.alloy_id;

-- Widen the currency code from CHAR(3) so a shorter historic abbreviation can be
-- stored exactly. 'Kr', the Austro-Hungarian krone, is two characters; CHAR(3)
-- blank-pads it to 'Kr ', which compares equal to 'Kr' in SQL and even reports
-- length 2, but the padding is real and escapes the moment the value leaves the
-- database - to_json returns "Kr ", so the API would ship a trailing space.
--
-- Every existing value is a three-letter ISO code, so none of them change, and
-- re-running this is a no-op once the type is already VARCHAR(3).
ALTER TABLE coins ALTER COLUMN face_value_currency_code TYPE VARCHAR(3);

-- Only the six legal tender pieces. The four rounds and the medal get no row
-- here at all, and that absence is what records they are not money.
INSERT INTO coins (mint_product_id, face_value, face_value_currency_code, is_legal_tender)
SELECT
    p.mint_product_id,
    v.face_value,
    v.face_value_currency_code,
    v.is_legal_tender
FROM (
    VALUES
        ('2027 Gold Lunar Goat (1 oz)', 100.00, 'AUD', TRUE),
        ('2026 Silver Kookaburra (1 oz)', 1.00, 'AUD', TRUE),
        ('2025 Silver Lunar Snake, Dragon Privy (1 oz)', 1.00, 'AUD', TRUE),
        ('2026 Silver Vienna Philharmonic (1 oz)', 1.50, 'EUR', TRUE),
        -- Swiss gold francs were never demonetised, so a Vreneli struck in 1897 is
        -- still worth 20 francs at a Swiss counter - roughly one five-hundredth of
        -- the gold in it.
        ('20 Franc Swiss Vreneli', 20.00, 'CHF', TRUE),
        -- Denominated in the Austro-Hungarian krone, the currency circulating in
        -- 1915, the year these restrikes are dated. The krone gave way to the
        -- schilling in 1925 and never received an ISO 4217 code, so it is recorded
        -- by its historic abbreviation 'Kr' - two characters, which is why the
        -- column is widened to VARCHAR(3) above. is_legal_tender is FALSE: the
        -- krone has not been money for a century.
        ('Austrian 1 Ducat (1915 Restrike)', 1.00, 'Kr', FALSE)
) AS v(name, face_value, face_value_currency_code, is_legal_tender)
INNER JOIN mint_products p ON p.name = v.name
ON CONFLICT (mint_product_id) DO UPDATE SET
    face_value = EXCLUDED.face_value,
    face_value_currency_code = EXCLUDED.face_value_currency_code,
    is_legal_tender = EXCLUDED.is_legal_tender;

-- Make the 'XXX' rule something the database enforces rather than something a
-- comment asks for. 'XXX' is ISO 4217 for "no currency involved", so an amount
-- beside it is a quantity of nothing - and the admin screens can write this table,
-- so a comment would not have stopped anyone recreating it.
--
-- This has to come after the upsert above, not before: applied first, it would be
-- rejected by the very row it exists to prevent. Dropped and re-added so replaying
-- the migration does not fail on a constraint that is already there.
ALTER TABLE coins DROP CONSTRAINT IF EXISTS chk_coins_no_value_without_currency;
ALTER TABLE coins ADD CONSTRAINT chk_coins_no_value_without_currency
    CHECK (face_value_currency_code <> 'XXX' OR face_value IS NULL);

-- ---------------------------------------------------------------------------
-- Derive primary_metal for the new alloys, then re-tighten the column
-- ---------------------------------------------------------------------------

UPDATE alloys a
SET primary_metal = upper(majority.metal_name)
FROM (
    SELECT DISTINCT ON (ae.alloy_id)
           ae.alloy_id,
           e.name AS metal_name
    FROM alloy_elements ae
    INNER JOIN elements e ON e.atomic_number = ae.atomic_number
    ORDER BY ae.alloy_id, ae.percent_of_alloy DESC, e.atomic_number
) AS majority
WHERE majority.alloy_id = a.alloy_id;

ALTER TABLE alloys ALTER COLUMN primary_metal SET NOT NULL;

-- ---------------------------------------------------------------------------
-- Post-conditions
-- ---------------------------------------------------------------------------

-- Every INSERT above joins by name, and an INNER JOIN drops what it cannot
-- match instead of raising a foreign key error. A typo in an alloy name would
-- therefore leave the product simply absent and the migration reporting success,
-- which is how 002 once "succeeded" while storing a mild steel with no iron in
-- it. Counting what actually landed is the only thing that catches it.
DO $$
DECLARE
    missing text;
BEGIN
    SELECT string_agg(expected.name, ', ' ORDER BY expected.name)
    INTO missing
    FROM (
        VALUES
            ('2027 Gold Lunar Goat (1 oz)'),
            ('2026 Silver Kookaburra (1 oz)'),
            ('2025 Silver Lunar Snake, Dragon Privy (1 oz)'),
            ('2026 Silver Vienna Philharmonic (1 oz)'),
            ('Austrian 1 Ducat (1915 Restrike)'),
            ('20 Franc Swiss Vreneli'),
            ('Tara Tree of Life Silver Round (1 oz)'),
            ('Tara Tree of Life Gold Round (1 oz)'),
            ('Year of the Snake Silver Round (1 oz)'),
            ('Aztec Calendar Copper Round (5 oz)'),
            ('2022 South Korean Silver Phoenix (1 oz)')
    ) AS expected(name)
    WHERE NOT EXISTS (
        SELECT 1 FROM mint_products p WHERE p.name = expected.name
    );

    IF missing IS NOT NULL THEN
        RAISE EXCEPTION
            'These mint products did not land, so an alloy name above is wrong: %',
            missing;
    END IF;
END $$;

-- The same guard the seed runs, for the same reason: the composition INSERT joins
-- elements by symbol, so a bad symbol is dropped by the join rather than
-- rejected. An alloy whose percentages no longer sum to 100 is missing metal.
DO $$
DECLARE
    offenders text;
BEGIN
    SELECT string_agg(name || ' (' || total || '%)', ', ' ORDER BY name)
    INTO offenders
    FROM (
        SELECT a.name, coalesce(sum(ae.percent_of_alloy), 0) AS total
        FROM alloys a
        LEFT JOIN alloy_elements ae ON ae.alloy_id = a.alloy_id
        GROUP BY a.name
        HAVING coalesce(sum(ae.percent_of_alloy), 0) <> 100
    ) AS broken;

    IF offenders IS NOT NULL THEN
        RAISE EXCEPTION
            'Alloy compositions must sum to 100 percent. Broken: %', offenders;
    END IF;
END $$;

-- And confirm the hand-typed family still agrees with the metal just computed,
-- so a gold alloy cannot end up filed under COPPER.
DO $$
DECLARE
    mismatches text;
BEGIN
    SELECT string_agg(name || ' (' || alloy_family || ' / ' || primary_metal || ')', ', ' ORDER BY name)
    INTO mismatches
    FROM alloys
    WHERE (alloy_family, primary_metal) NOT IN (
        ('ALUMINUM', 'ALUMINUM'),
        ('COPPER', 'COPPER'),
        ('FERROUS', 'IRON'),
        ('MAGNESIUM', 'MAGNESIUM'),
        ('NICKEL', 'NICKEL'),
        ('TIN', 'TIN'),
        ('TITANIUM', 'TITANIUM'),
        ('ZINC', 'ZINC'),
        ('PRECIOUS', 'GOLD'),
        ('PRECIOUS', 'SILVER'),
        ('PRECIOUS', 'PLATINUM'),
        ('PRECIOUS', 'PALLADIUM')
    );

    IF mismatches IS NOT NULL THEN
        RAISE EXCEPTION
            'alloy_family disagrees with the majority element. Offenders: %', mismatches;
    END IF;
END $$;

COMMIT;
