-- 005_alloy_color_families.sql
--
-- One change: alloys gains color_family, so the catalog can be filtered and
-- sorted by how an alloy looks rather than only by what it is made of.
--
--   GRAY    aluminums, steels, cast irons
--   SILVER  sterling, stainless, pewters, cupronickels, titanium, and the white
--           metals - platinum, palladium, white gold
--   GOLD    the gold alloys and the yellow brasses
--   BRONZE  the bronzes, plus Shakudo and Weathering Steel
--   RED     the coppers, Red Brass, rose gold
--
-- Run 001 through 004 first. Safe to run more than once.
--
-- Existing rows are not rewritten: the column is added, filled from each alloy's
-- existing color text, and then made mandatory. No other column is touched.

BEGIN;

ALTER TABLE alloys ADD COLUMN IF NOT EXISTS color_family VARCHAR(10);

ALTER TABLE alloys DROP CONSTRAINT IF EXISTS chk_alloy_color_family;
ALTER TABLE alloys ADD CONSTRAINT chk_alloy_color_family CHECK (color_family IN (
    'GRAY', 'SILVER', 'GOLD', 'BRONZE', 'RED'
));

-- Every color string in the catalog, mapped explicitly. Listing all twenty-eight
-- beats pattern matching: 'reddish gold' and 'pale gold' both contain "gold" but
-- belong in different families, and 'white gold' is not gold-colored at all. An
-- explicit map also means a color nobody has classified fails loudly below rather
-- than landing wherever a LIKE happened to match first.
WITH color_family_map (color, family) AS (
    VALUES
        ('silver gray', 'GRAY'),
        ('dark gray', 'GRAY'),
        ('dull gray', 'GRAY'),

        ('bright silver', 'SILVER'),
        ('dull silver', 'SILVER'),
        ('silvery', 'SILVER'),
        ('silvery white', 'SILVER'),
        ('silver', 'SILVER'),
        ('dark silver', 'SILVER'),
        ('bluish silver', 'SILVER'),
        ('white gold', 'SILVER'),

        ('gold', 'GOLD'),
        ('rich gold', 'GOLD'),
        ('pale gold', 'GOLD'),
        ('yellow gold', 'GOLD'),
        ('yellow-gold', 'GOLD'),
        ('golden', 'GOLD'),
        ('yellow', 'GOLD'),
        ('reddish yellow', 'GOLD'),

        ('bronze', 'BRONZE'),
        ('dark bronze', 'BRONZE'),
        ('golden bronze', 'BRONZE'),
        ('yellow bronze', 'BRONZE'),
        ('rust brown', 'BRONZE'),
        ('dark purple-brown', 'BRONZE'),

        ('reddish', 'RED'),
        ('reddish gold', 'RED'),
        ('rose gold', 'RED')
)
UPDATE alloys a
SET color_family = m.family
FROM color_family_map m
WHERE m.color = a.color
  -- Only fill the blanks. Unlike primary_metal, which is a fact about mass
  -- fractions and is recomputed every run, this one is a judgement call an Admin
  -- is allowed to overrule - so replaying this migration must not quietly undo a
  -- correction someone made in the admin screen.
  AND a.color_family IS NULL;

-- Anything still empty has a color the map above does not cover, or no color at
-- all. Caught here so the failure names the alloy, rather than surfacing as a bare
-- NOT NULL violation from the statement below.
DO $$
DECLARE
    offenders text;
BEGIN
    SELECT string_agg(name || ' (' || coalesce(color, 'no color') || ')', ', ' ORDER BY name)
    INTO offenders
    FROM alloys
    WHERE color_family IS NULL;

    IF offenders IS NOT NULL THEN
        RAISE EXCEPTION
            'These alloys have a color with no color_family mapping: %', offenders;
    END IF;
END $$;

ALTER TABLE alloys ALTER COLUMN color_family SET NOT NULL;

COMMIT;
