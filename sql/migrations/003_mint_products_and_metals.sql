-- 003_mint_products_and_metals.sql
--
-- Three changes, none of them destructive:
--
--   1. alloys gains primary_metal - the single metal an alloy is mostly made of,
--      derived from alloy_elements rather than typed in. Finer than alloy_family,
--      which collapses gold, silver, platinum and palladium into PRECIOUS.
--   2. coins is restructured into a supertype and a subtype. The old table is
--      RENAMED to mint_products (so every existing row and its id survive) and a
--      new, narrow coins table is created holding only the legal-tender facts.
--   3. mint_product_components records how layered pieces are actually built -
--      clad, plated, bimetallic.
--
-- Run 001 and 002 first. Safe to run more than once.
--
-- Existing data is preserved, not recreated: the seven coins keep their ids, and
-- their face values move into the new coins table before the old columns are
-- dropped. Nothing is deleted except two columns whose contents were copied.

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. alloys.primary_metal
-- ---------------------------------------------------------------------------

-- Nullable to begin with. It is populated further down, from the compositions,
-- and only then made NOT NULL.
ALTER TABLE alloys ADD COLUMN IF NOT EXISTS primary_metal VARCHAR(20);

-- Deliberately relaxed on every run, including a re-run where the column is
-- already NOT NULL. The alloys INSERT further down does not list primary_metal,
-- and ON CONFLICT only rescues UNIQUE violations - a NOT NULL violation is
-- raised while the proposed row is still being built, before the conflict is
-- ever detected. Without this, replaying the migration fails outright. It is
-- made NOT NULL again once the derivation below has filled it in.
ALTER TABLE alloys ALTER COLUMN primary_metal DROP NOT NULL;

ALTER TABLE alloys DROP CONSTRAINT IF EXISTS chk_alloy_primary_metal;
ALTER TABLE alloys ADD CONSTRAINT chk_alloy_primary_metal CHECK (primary_metal IN (
    'ALUMINUM', 'COPPER', 'GOLD', 'IRON', 'MAGNESIUM', 'NICKEL',
    'PALLADIUM', 'PLATINUM', 'SILVER', 'TIN', 'TITANIUM', 'ZINC'
));

-- ---------------------------------------------------------------------------
-- 2. coins -> mint_products + coins
-- ---------------------------------------------------------------------------

-- A rename is not repeatable, so the whole structural step is guarded on whether
-- it has already happened. Checking for the new table by name is enough: either
-- this block has run or it has not.
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = current_schema() AND table_name = 'mint_products'
    ) THEN
        RAISE NOTICE 'mint_products already exists; skipping the structural rename.';
        RETURN;
    END IF;

    -- Keep the rows and their ids; only the name and shape change.
    ALTER TABLE coins RENAME TO mint_products;
    ALTER TABLE mint_products RENAME COLUMN coin_id TO mint_product_id;
    -- "country" stops being accurate once a private mint can issue a bar.
    ALTER TABLE mint_products RENAME COLUMN country TO issuer;

    ALTER TABLE mint_products
        ADD COLUMN product_type VARCHAR(20) NOT NULL DEFAULT 'COIN',
        ADD COLUMN fine_metal_weight_g NUMERIC(10,4);

    -- Everything already in the table is a coin, so the DEFAULT above backfilled
    -- correctly. New rows must say what they are.
    ALTER TABLE mint_products ALTER COLUMN product_type DROP DEFAULT;

    ALTER TABLE mint_products RENAME CONSTRAINT fk_coins_alloy TO fk_mint_products_alloy;

    -- The original CHECK allowed 500-3000, which rules out a Roman denarius.
    ALTER TABLE mint_products DROP CONSTRAINT IF EXISTS chk_coins_year_introduced;
    ALTER TABLE mint_products ADD CONSTRAINT chk_mint_products_year
        CHECK (year_introduced IS NULL OR year_introduced BETWEEN -3000 AND 3000);

    ALTER TABLE mint_products ADD CONSTRAINT chk_mint_products_type CHECK (product_type IN (
        'COIN', 'ROUND', 'BAR', 'INGOT', 'MEDAL', 'TOKEN', 'NOTE'
    ));

    ALTER TABLE mint_products ADD CONSTRAINT chk_mint_products_weights
        CHECK (fine_metal_weight_g IS NULL
               OR gross_weight_g IS NULL
               OR fine_metal_weight_g <= gross_weight_g);

    -- Redundant against the primary key, but the coins subtype needs a composite
    -- key to point at.
    ALTER TABLE mint_products ADD CONSTRAINT uq_mint_products_type
        UNIQUE (mint_product_id, product_type);

    -- The seed upserts by name. The original coins table had no unique name, so
    -- without this the seed below would insert a SECOND "Morgan Silver Dollar"
    -- next to the one already in the table.
    ALTER TABLE mint_products ADD CONSTRAINT mint_products_name_key UNIQUE (name);

    CREATE TABLE coins (
        mint_product_id INTEGER PRIMARY KEY,
        product_type VARCHAR(20) NOT NULL DEFAULT 'COIN',
        face_value NUMERIC(12,2),
        face_value_currency_code CHAR(3) NOT NULL,
        is_legal_tender BOOLEAN NOT NULL DEFAULT TRUE,

        CONSTRAINT chk_coins_product_type CHECK (product_type = 'COIN'),

        CONSTRAINT fk_coins_mint_product
            FOREIGN KEY (mint_product_id, product_type)
            REFERENCES mint_products (mint_product_id, product_type)
            ON UPDATE CASCADE
            ON DELETE CASCADE
    );

    -- Move the legal-tender facts across BEFORE dropping the old columns. Every
    -- pre-existing row is a coin, and all seven already carry a currency code.
    INSERT INTO coins (mint_product_id, face_value, face_value_currency_code)
    SELECT mint_product_id, face_value, face_value_currency_code
    FROM mint_products;

    ALTER TABLE mint_products
        DROP COLUMN face_value,
        DROP COLUMN face_value_currency_code;
END $$;

CREATE TABLE IF NOT EXISTS mint_product_components (
    mint_product_id INTEGER NOT NULL,
    alloy_id INTEGER NOT NULL,
    component_role VARCHAR(20) NOT NULL,
    percent_of_weight NUMERIC(6,3),

    CONSTRAINT pk_mint_product_components
        PRIMARY KEY (mint_product_id, alloy_id, component_role),

    CONSTRAINT fk_mint_product_components_product
        FOREIGN KEY (mint_product_id)
        REFERENCES mint_products (mint_product_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_mint_product_components_alloy
        FOREIGN KEY (alloy_id)
        REFERENCES alloys (alloy_id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_mint_product_component_role CHECK (component_role IN (
        'CORE', 'CLADDING', 'PLATING', 'RING', 'CENTER', 'LEAF'
    )),

    CONSTRAINT chk_mint_product_component_percent
        CHECK (percent_of_weight IS NULL
               OR (percent_of_weight > 0 AND percent_of_weight <= 100))
);

CREATE INDEX IF NOT EXISTS idx_mint_products_alloy_id ON mint_products (alloy_id);
CREATE INDEX IF NOT EXISTS idx_mint_products_product_type ON mint_products (product_type);
CREATE INDEX IF NOT EXISTS idx_mint_product_components_alloy_id ON mint_product_components (alloy_id);

-- ---------------------------------------------------------------------------
-- 3. Seed data. These blocks are copied verbatim from sql/metals-db.sql.
-- ---------------------------------------------------------------------------

-- Alloy master rows. alloy_family is the base metal by mass fraction, so a few
-- entries land somewhere their name does not suggest: Nickel Silver is COPPER
-- and contains no silver at all, Invar 36 is FERROUS despite being known as a
-- nickel alloy, and Shakudo is COPPER with only a few percent gold.
INSERT INTO alloys (name, color, alloy_family, description)
VALUES
    ('Fine Gold 24K', 'gold', 'PRECIOUS', 'High-purity investment gold for bullion and premium coins.'),
    ('22K Gold Coin Alloy', 'rich gold', 'PRECIOUS', 'Durable coin gold with added strength compared to 24K.'),
    ('18K Yellow Gold', 'yellow gold', 'PRECIOUS', 'Jewelry alloy balancing color and wear resistance.'),
    ('18K Rose Gold', 'rose gold', 'PRECIOUS', 'Jewelry alloy with higher copper content for warm red tone.'),
    ('18K White Gold (Palladium)', 'white gold', 'PRECIOUS', 'Nickel-free white gold variant used in fine jewelry.'),
    ('14K Yellow Gold', 'yellow gold', 'PRECIOUS', 'Hard-wearing everyday jewelry gold at 58.5 percent purity.'),
    ('10K Yellow Gold', 'pale gold', 'PRECIOUS', 'Budget jewelry gold with high durability and low gold content.'),
    ('Electrum', 'pale gold', 'PRECIOUS', 'Naturally occurring gold-silver alloy used in the earliest coinage.'),
    ('Sterling Silver', 'bright silver', 'PRECIOUS', 'Standard jewelry and silverware alloy.'),
    ('Coin Silver', 'silver', 'PRECIOUS', 'Traditional coinage silver composition.'),
    ('Britannia Silver', 'bright silver', 'PRECIOUS', 'Higher-purity silver standard for premium silver goods.'),
    ('Platinum 950', 'silvery white', 'PRECIOUS', 'Fine jewelry platinum alloy with improved hardness.'),
    ('Palladium 950', 'silvery white', 'PRECIOUS', 'Light, hypoallergenic white metal for wedding bands.'),
    ('Yellow Brass', 'yellow', 'COPPER', 'General-purpose brass for hardware, fittings, and decorative parts.'),
    ('Red Brass', 'reddish gold', 'COPPER', 'Corrosion-resistant brass for plumbing fittings and valves.'),
    ('Naval Brass', 'yellow-gold', 'COPPER', 'Brass designed for marine service and saltwater resistance.'),
    ('Leaded Free-Cutting Brass', 'yellow', 'COPPER', 'Machinable brass for precision turned components.'),
    ('Gilding Metal', 'reddish yellow', 'COPPER', 'Copper-rich brass used for cladding and decorative parts.'),
    ('Tin Bronze', 'bronze', 'COPPER', 'General bronze for castings, bushings, and decorative work.'),
    ('Phosphor Bronze', 'bronze', 'COPPER', 'Springy bronze for contacts, springs, and wear-resistant parts.'),
    ('Aluminum Bronze', 'golden bronze', 'COPPER', 'Strong corrosion-resistant bronze for marine and industrial parts.'),
    ('Silicon Bronze', 'bronze', 'COPPER', 'Corrosion-resistant bronze for fasteners and architectural hardware.'),
    ('Manganese Bronze', 'yellow bronze', 'COPPER', 'High-strength bronze family used for propellers and shafts.'),
    ('Leaded Bronze', 'bronze', 'COPPER', 'Bearing bronze with improved anti-friction behavior.'),
    ('Bell Metal', 'dark bronze', 'COPPER', 'Resonant bronze for bells and musical castings.'),
    ('Cupronickel 90/10', 'silvery', 'COPPER', 'Seawater-resistant copper-nickel for condenser and marine piping.'),
    ('Cupronickel 70/30', 'silvery', 'COPPER', 'Higher-nickel cupronickel for demanding marine heat exchangers.'),
    ('Nickel Silver', 'silvery', 'COPPER', 'Silver-looking copper alloy with no silver in it; flatware and instruments.'),
    ('Beryllium Copper', 'reddish gold', 'COPPER', 'Hardenable copper for springs, connectors, and non-sparking tools.'),
    ('Chromium Copper', 'reddish', 'COPPER', 'Strong, highly conductive copper for resistance welding electrodes.'),
    ('Shakudo', 'dark purple-brown', 'COPPER', 'Japanese copper alloy with a little gold that patinates to deep purple.'),
    ('Traditional Lead Pewter', 'dull silver', 'TIN', 'Historical pewter for decorative artifacts (not food-safe).'),
    ('Lead-Free Pewter', 'bright silver', 'TIN', 'Modern pewter for decorative and giftware applications.'),
    ('Sn63/Pb37 Eutectic Solder', 'dull silver', 'TIN', 'Classic electronics solder with a single sharp melting point.'),
    ('SAC305 Lead-Free Solder', 'dull silver', 'TIN', 'Tin-silver-copper solder that replaced leaded solder in electronics.'),
    ('Aluminum 3003', 'silver gray', 'ALUMINUM', 'Formable sheet alloy for cookware and general fabrication.'),
    ('Aluminum 5052', 'silver gray', 'ALUMINUM', 'Corrosion-resistant aluminum for marine and sheet applications.'),
    ('Aluminum 6061', 'silver gray', 'ALUMINUM', 'General-purpose structural aluminum for machining and fabrication.'),
    ('Aluminum 7075', 'silver gray', 'ALUMINUM', 'High-strength aluminum for aerospace and tooling.'),
    ('Aluminum 2024', 'silver gray', 'ALUMINUM', 'High-strength aluminum used in aircraft structures.'),
    ('A356 Cast Aluminum', 'silver gray', 'ALUMINUM', 'Cast aluminum alloy for wheels and complex cast parts.'),
    ('1018 Mild Steel', 'dark gray', 'FERROUS', 'Low-carbon workhorse steel for shafts, brackets, and weldments.'),
    ('1045 Medium Carbon Steel', 'dark gray', 'FERROUS', 'Medium-carbon steel for gears, axles, and heat-treated parts.'),
    ('4140 Chromoly Steel', 'dark gray', 'FERROUS', 'Tough alloy steel for tooling, shafts, and roll cages.'),
    ('304 Stainless Steel', 'bright silver', 'FERROUS', 'The common austenitic stainless for kitchens and architecture.'),
    ('316 Stainless Steel', 'bright silver', 'FERROUS', 'Molybdenum-bearing stainless with better chloride resistance.'),
    ('430 Stainless Steel', 'silver', 'FERROUS', 'Magnetic ferritic stainless for trim and appliance panels.'),
    ('17-4 PH Stainless Steel', 'silver', 'FERROUS', 'Precipitation-hardening stainless for high-strength shafts and valves.'),
    ('M2 High-Speed Steel', 'dark gray', 'FERROUS', 'Tool steel that keeps its edge hot; drills, taps, and milling cutters.'),
    ('Gray Cast Iron', 'dull gray', 'FERROUS', 'Graphite-flake iron for engine blocks, cookware, and machine bases.'),
    ('Ductile Cast Iron', 'dull gray', 'FERROUS', 'Magnesium-treated iron with spheroidal graphite and real toughness.'),
    ('Weathering Steel', 'rust brown', 'FERROUS', 'Corten-type steel that forms a stable rust layer instead of needing paint.'),
    ('Invar 36', 'silver gray', 'FERROUS', 'Iron-nickel alloy that barely expands when heated; precision instruments.'),
    ('Inconel 718', 'silver gray', 'NICKEL', 'Age-hardened superalloy for turbine discs and rocket hardware.'),
    ('Hastelloy C-276', 'silver gray', 'NICKEL', 'Nickel-molybdenum alloy for aggressive chemical service.'),
    ('Monel 400', 'silver gray', 'NICKEL', 'Nickel-copper alloy prized for seawater and acid resistance.'),
    ('Nichrome 80/20', 'silver gray', 'NICKEL', 'Resistance heating wire for toasters, kilns, and hot-wire cutters.'),
    ('Nitinol', 'silver gray', 'NICKEL', 'Shape-memory alloy that springs back to form when warmed.'),
    ('Ti-6Al-4V', 'dark silver', 'TITANIUM', 'The workhorse titanium alloy: aerospace structure and implants.'),
    ('CP Titanium Grade 2', 'dark silver', 'TITANIUM', 'Commercially pure titanium for chemical vessels and medical parts.'),
    ('Zamak 3', 'silver gray', 'ZINC', 'The default zinc die-casting alloy for housings and hardware.'),
    ('Zamak 5', 'silver gray', 'ZINC', 'Copper-bearing zinc die-cast alloy with higher strength.'),
    ('AZ91D Magnesium', 'dull silver', 'MAGNESIUM', 'Common magnesium die-casting alloy for light housings.'),
    ('AZ31B Magnesium', 'dull silver', 'MAGNESIUM', 'Wrought magnesium sheet and extrusion alloy.'),
    -- Coinage and bullion alloys. Circulating coins are mostly base metal, and
    -- clad coins need the plating and the core as separate alloys.
    ('Commercial Pure Copper', 'reddish', 'COPPER', 'Unalloyed copper used for coin cores, plating, and bullion rounds.'),
    ('Cupronickel 75/25', 'silvery', 'COPPER', 'The US five cent alloy, also the cladding on US dimes and quarters.'),
    ('Nickel Brass', 'pale gold', 'COPPER', 'Hard brass for circulating coins such as the euro ring and old UK threepence.'),
    ('Nordic Gold', 'golden', 'COPPER', 'Tarnish-resistant gold-colored coinage alloy used for euro cent coins.'),
    ('Manganese Brass', 'golden', 'COPPER', 'Golden dollar cladding, chosen to match an older coin on vending sensors.'),
    ('Coinage Zinc Core', 'bluish silver', 'ZINC', 'The zinc core inside a modern copper-plated US cent.'),
    ('Coinage Steel Core', 'dark gray', 'FERROUS', 'Low-carbon steel core used under plating in low-value circulating coins.'),
    ('Coinage Aluminum', 'silver gray', 'ALUMINUM', 'Near-pure aluminum for very low denomination circulating coins.'),
    ('Fine Silver 999', 'bright silver', 'PRECIOUS', 'Investment-grade silver for rounds and bars.'),
    ('Fine Platinum 9995', 'silvery white', 'PRECIOUS', 'Investment-grade platinum for bars and coins.'),
    ('Fine Palladium 9995', 'silvery white', 'PRECIOUS', 'Investment-grade palladium for bars and coins.')
ON CONFLICT (name) DO UPDATE SET
    color = EXCLUDED.color,
    alloy_family = EXCLUDED.alloy_family,
    description = EXCLUDED.description;

-- Alloy composition rows.
WITH alloy_component_data (alloy_name, element_symbol, pct) AS (
    VALUES
        ('Fine Gold 24K', 'Au', 99.990),
        ('Fine Gold 24K', 'Cu', 0.010),

        ('22K Gold Coin Alloy', 'Au', 91.670),
        ('22K Gold Coin Alloy', 'Ag', 5.000),
        ('22K Gold Coin Alloy', 'Cu', 3.330),

        ('18K Yellow Gold', 'Au', 75.000),
        ('18K Yellow Gold', 'Ag', 12.500),
        ('18K Yellow Gold', 'Cu', 12.500),

        ('18K Rose Gold', 'Au', 75.000),
        ('18K Rose Gold', 'Cu', 22.250),
        ('18K Rose Gold', 'Ag', 2.750),

        ('18K White Gold (Palladium)', 'Au', 75.000),
        ('18K White Gold (Palladium)', 'Pd', 15.000),
        ('18K White Gold (Palladium)', 'Ag', 10.000),

        ('Sterling Silver', 'Ag', 92.500),
        ('Sterling Silver', 'Cu', 7.500),

        ('Coin Silver', 'Ag', 90.000),
        ('Coin Silver', 'Cu', 10.000),

        ('Britannia Silver', 'Ag', 95.800),
        ('Britannia Silver', 'Cu', 4.200),

        ('Platinum 950', 'Pt', 95.000),
        ('Platinum 950', 'Ir', 5.000),

        ('Yellow Brass', 'Cu', 67.000),
        ('Yellow Brass', 'Zn', 33.000),

        ('Red Brass', 'Cu', 85.000),
        ('Red Brass', 'Zn', 15.000),

        ('Naval Brass', 'Cu', 60.000),
        ('Naval Brass', 'Zn', 39.000),
        ('Naval Brass', 'Sn', 1.000),

        ('Leaded Free-Cutting Brass', 'Cu', 61.500),
        ('Leaded Free-Cutting Brass', 'Zn', 35.500),
        ('Leaded Free-Cutting Brass', 'Pb', 3.000),

        ('Gilding Metal', 'Cu', 95.000),
        ('Gilding Metal', 'Zn', 5.000),

        ('Tin Bronze', 'Cu', 90.000),
        ('Tin Bronze', 'Sn', 10.000),

        ('Phosphor Bronze', 'Cu', 94.800),
        ('Phosphor Bronze', 'Sn', 5.000),
        ('Phosphor Bronze', 'P', 0.200),

        ('Aluminum Bronze', 'Cu', 90.000),
        ('Aluminum Bronze', 'Al', 10.000),

        ('Silicon Bronze', 'Cu', 96.000),
        ('Silicon Bronze', 'Si', 3.000),
        ('Silicon Bronze', 'Mn', 1.000),

        ('Manganese Bronze', 'Cu', 60.000),
        ('Manganese Bronze', 'Zn', 38.000),
        ('Manganese Bronze', 'Mn', 2.000),

        ('Leaded Bronze', 'Cu', 80.000),
        ('Leaded Bronze', 'Sn', 10.000),
        ('Leaded Bronze', 'Pb', 10.000),

        ('Bell Metal', 'Cu', 78.000),
        ('Bell Metal', 'Sn', 22.000),

        ('Traditional Lead Pewter', 'Sn', 70.000),
        ('Traditional Lead Pewter', 'Pb', 30.000),

        ('Lead-Free Pewter', 'Sn', 92.000),
        ('Lead-Free Pewter', 'Sb', 6.000),
        ('Lead-Free Pewter', 'Cu', 2.000),

        ('Aluminum 3003', 'Al', 98.600),
        ('Aluminum 3003', 'Mn', 1.200),
        ('Aluminum 3003', 'Cu', 0.200),

        ('Aluminum 5052', 'Al', 97.250),
        ('Aluminum 5052', 'Mg', 2.500),
        ('Aluminum 5052', 'Cr', 0.250),

        ('Aluminum 6061', 'Al', 97.900),
        ('Aluminum 6061', 'Mg', 1.000),
        ('Aluminum 6061', 'Si', 0.600),
        ('Aluminum 6061', 'Cu', 0.300),
        ('Aluminum 6061', 'Cr', 0.200),

        ('Aluminum 7075', 'Al', 90.000),
        ('Aluminum 7075', 'Zn', 5.600),
        ('Aluminum 7075', 'Mg', 2.500),
        ('Aluminum 7075', 'Cu', 1.600),
        ('Aluminum 7075', 'Cr', 0.300),

        ('Aluminum 2024', 'Al', 93.500),
        ('Aluminum 2024', 'Cu', 4.400),
        ('Aluminum 2024', 'Mg', 1.500),
        ('Aluminum 2024', 'Mn', 0.600),

        ('A356 Cast Aluminum', 'Al', 92.500),
        ('A356 Cast Aluminum', 'Si', 7.000),
        ('A356 Cast Aluminum', 'Mg', 0.500),

        -- Precious additions.
        ('14K Yellow Gold', 'Au', 58.500),
        ('14K Yellow Gold', 'Ag', 25.000),
        ('14K Yellow Gold', 'Cu', 16.500),
        ('10K Yellow Gold', 'Au', 41.700),
        ('10K Yellow Gold', 'Ag', 20.000),
        ('10K Yellow Gold', 'Cu', 38.300),
        ('Electrum', 'Au', 55.000),
        ('Electrum', 'Ag', 44.000),
        ('Electrum', 'Cu', 1.000),
        ('Palladium 950', 'Pd', 95.000),
        ('Palladium 950', 'Ru', 5.000),

        -- Copper additions. Nickel Silver is the teaching case: no silver.
        ('Cupronickel 90/10', 'Cu', 88.600),
        ('Cupronickel 90/10', 'Ni', 10.000),
        ('Cupronickel 90/10', 'Fe', 1.400),
        ('Cupronickel 70/30', 'Cu', 69.500),
        ('Cupronickel 70/30', 'Ni', 30.000),
        ('Cupronickel 70/30', 'Mn', 0.500),
        ('Nickel Silver', 'Cu', 60.000),
        ('Nickel Silver', 'Zn', 20.000),
        ('Nickel Silver', 'Ni', 20.000),
        ('Beryllium Copper', 'Cu', 97.900),
        ('Beryllium Copper', 'Be', 1.900),
        ('Beryllium Copper', 'Co', 0.200),
        ('Chromium Copper', 'Cu', 99.100),
        ('Chromium Copper', 'Cr', 0.900),
        ('Shakudo', 'Cu', 96.000),
        ('Shakudo', 'Au', 4.000),

        -- Solders.
        ('Sn63/Pb37 Eutectic Solder', 'Sn', 63.000),
        ('Sn63/Pb37 Eutectic Solder', 'Pb', 37.000),
        ('SAC305 Lead-Free Solder', 'Sn', 96.500),
        ('SAC305 Lead-Free Solder', 'Ag', 3.000),
        ('SAC305 Lead-Free Solder', 'Cu', 0.500),

        -- Steels and cast irons. Only possible now that Fe, C and V are seeded.
        ('1018 Mild Steel', 'Fe', 99.030),
        ('1018 Mild Steel', 'C', 0.180),
        ('1018 Mild Steel', 'Mn', 0.750),
        ('1018 Mild Steel', 'P', 0.020),
        ('1018 Mild Steel', 'S', 0.020),
        ('1045 Medium Carbon Steel', 'Fe', 98.760),
        ('1045 Medium Carbon Steel', 'C', 0.450),
        ('1045 Medium Carbon Steel', 'Mn', 0.750),
        ('1045 Medium Carbon Steel', 'P', 0.020),
        ('1045 Medium Carbon Steel', 'S', 0.020),
        ('4140 Chromoly Steel', 'Fe', 97.320),
        ('4140 Chromoly Steel', 'C', 0.400),
        ('4140 Chromoly Steel', 'Si', 0.250),
        ('4140 Chromoly Steel', 'Mn', 0.880),
        ('4140 Chromoly Steel', 'Cr', 0.950),
        ('4140 Chromoly Steel', 'Mo', 0.200),
        ('304 Stainless Steel', 'Fe', 71.180),
        ('304 Stainless Steel', 'Cr', 18.000),
        ('304 Stainless Steel', 'Ni', 8.000),
        ('304 Stainless Steel', 'Mn', 2.000),
        ('304 Stainless Steel', 'Si', 0.750),
        ('304 Stainless Steel', 'C', 0.070),
        ('316 Stainless Steel', 'Fe', 68.680),
        ('316 Stainless Steel', 'Cr', 16.500),
        ('316 Stainless Steel', 'Ni', 10.000),
        ('316 Stainless Steel', 'Mo', 2.000),
        ('316 Stainless Steel', 'Mn', 2.000),
        ('316 Stainless Steel', 'Si', 0.750),
        ('316 Stainless Steel', 'C', 0.070),
        ('430 Stainless Steel', 'Fe', 81.150),
        ('430 Stainless Steel', 'Cr', 17.000),
        ('430 Stainless Steel', 'Mn', 1.000),
        ('430 Stainless Steel', 'Si', 0.750),
        ('430 Stainless Steel', 'C', 0.100),
        ('17-4 PH Stainless Steel', 'Fe', 73.630),
        ('17-4 PH Stainless Steel', 'Cr', 16.000),
        ('17-4 PH Stainless Steel', 'Ni', 4.000),
        ('17-4 PH Stainless Steel', 'Cu', 4.000),
        ('17-4 PH Stainless Steel', 'Mn', 1.000),
        ('17-4 PH Stainless Steel', 'Si', 1.000),
        ('17-4 PH Stainless Steel', 'Nb', 0.300),
        ('17-4 PH Stainless Steel', 'C', 0.070),
        ('M2 High-Speed Steel', 'Fe', 82.150),
        ('M2 High-Speed Steel', 'W', 6.000),
        ('M2 High-Speed Steel', 'Mo', 5.000),
        ('M2 High-Speed Steel', 'Cr', 4.000),
        ('M2 High-Speed Steel', 'V', 2.000),
        ('M2 High-Speed Steel', 'C', 0.850),
        ('Gray Cast Iron', 'Fe', 93.800),
        ('Gray Cast Iron', 'C', 3.400),
        ('Gray Cast Iron', 'Si', 2.200),
        ('Gray Cast Iron', 'Mn', 0.600),
        ('Ductile Cast Iron', 'Fe', 93.560),
        ('Ductile Cast Iron', 'C', 3.600),
        ('Ductile Cast Iron', 'Si', 2.500),
        ('Ductile Cast Iron', 'Mn', 0.300),
        ('Ductile Cast Iron', 'Mg', 0.040),
        ('Weathering Steel', 'Fe', 97.700),
        ('Weathering Steel', 'Cr', 0.650),
        ('Weathering Steel', 'Si', 0.400),
        ('Weathering Steel', 'Mn', 0.400),
        ('Weathering Steel', 'Cu', 0.350),
        ('Weathering Steel', 'Ni', 0.300),
        ('Weathering Steel', 'C', 0.100),
        ('Weathering Steel', 'P', 0.100),
        ('Invar 36', 'Fe', 63.800),
        ('Invar 36', 'Ni', 36.000),
        ('Invar 36', 'Mn', 0.200),

        -- Nickel alloys and superalloys.
        ('Inconel 718', 'Ni', 53.000),
        ('Inconel 718', 'Cr', 19.000),
        ('Inconel 718', 'Fe', 18.500),
        ('Inconel 718', 'Nb', 5.100),
        ('Inconel 718', 'Mo', 3.000),
        ('Inconel 718', 'Ti', 0.900),
        ('Inconel 718', 'Al', 0.500),
        ('Hastelloy C-276', 'Ni', 57.000),
        ('Hastelloy C-276', 'Mo', 16.000),
        ('Hastelloy C-276', 'Cr', 15.500),
        ('Hastelloy C-276', 'Fe', 5.500),
        ('Hastelloy C-276', 'W', 3.500),
        ('Hastelloy C-276', 'Co', 2.500),
        ('Monel 400', 'Ni', 66.500),
        ('Monel 400', 'Cu', 31.500),
        ('Monel 400', 'Fe', 1.500),
        ('Monel 400', 'Mn', 0.500),
        ('Nichrome 80/20', 'Ni', 80.000),
        ('Nichrome 80/20', 'Cr', 20.000),
        ('Nitinol', 'Ni', 55.000),
        ('Nitinol', 'Ti', 45.000),

        -- Titanium.
        ('Ti-6Al-4V', 'Ti', 90.000),
        ('Ti-6Al-4V', 'Al', 6.000),
        ('Ti-6Al-4V', 'V', 4.000),
        ('CP Titanium Grade 2', 'Ti', 99.600),
        ('CP Titanium Grade 2', 'Fe', 0.300),
        ('CP Titanium Grade 2', 'C', 0.100),

        -- Zinc and magnesium die-casting alloys.
        ('Zamak 3', 'Zn', 95.900),
        ('Zamak 3', 'Al', 4.000),
        ('Zamak 3', 'Cu', 0.060),
        ('Zamak 3', 'Mg', 0.040),
        ('Zamak 5', 'Zn', 94.950),
        ('Zamak 5', 'Al', 4.000),
        ('Zamak 5', 'Cu', 1.000),
        ('Zamak 5', 'Mg', 0.050),
        ('AZ91D Magnesium', 'Mg', 90.000),
        ('AZ91D Magnesium', 'Al', 9.000),
        ('AZ91D Magnesium', 'Zn', 0.700),
        ('AZ91D Magnesium', 'Mn', 0.300),
        ('AZ31B Magnesium', 'Mg', 96.000),
        ('AZ31B Magnesium', 'Al', 3.000),
        ('AZ31B Magnesium', 'Zn', 1.000),

        -- Coinage and bullion alloys.
        ('Commercial Pure Copper', 'Cu', 99.950),
        ('Commercial Pure Copper', 'O', 0.050),
        ('Cupronickel 75/25', 'Cu', 75.000),
        ('Cupronickel 75/25', 'Ni', 25.000),
        ('Nickel Brass', 'Cu', 75.000),
        ('Nickel Brass', 'Zn', 20.000),
        ('Nickel Brass', 'Ni', 5.000),
        ('Nordic Gold', 'Cu', 89.000),
        ('Nordic Gold', 'Al', 5.000),
        ('Nordic Gold', 'Zn', 5.000),
        ('Nordic Gold', 'Sn', 1.000),
        ('Manganese Brass', 'Cu', 77.000),
        ('Manganese Brass', 'Zn', 12.000),
        ('Manganese Brass', 'Mn', 7.000),
        ('Manganese Brass', 'Ni', 4.000),
        ('Coinage Zinc Core', 'Zn', 99.200),
        ('Coinage Zinc Core', 'Cu', 0.800),
        ('Coinage Steel Core', 'Fe', 99.600),
        ('Coinage Steel Core', 'Mn', 0.320),
        ('Coinage Steel Core', 'C', 0.080),
        ('Coinage Aluminum', 'Al', 99.500),
        ('Coinage Aluminum', 'Fe', 0.300),
        ('Coinage Aluminum', 'Si', 0.200),
        ('Fine Silver 999', 'Ag', 99.900),
        ('Fine Silver 999', 'Cu', 0.100),
        ('Fine Platinum 9995', 'Pt', 99.950),
        ('Fine Platinum 9995', 'Ir', 0.050),
        ('Fine Palladium 9995', 'Pd', 99.950),
        ('Fine Palladium 9995', 'Ru', 0.050)
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

-- Guard rail. The INSERT above joins the component list to elements by symbol,
-- so a symbol that does not exist is dropped by the join instead of raising a
-- foreign key error: the seed would "succeed" while quietly storing an alloy
-- with missing metal. Checking that every composition still sums to 100 turns
-- that silence into a failure.
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

-- Derive primary_metal from the composition rather than repeating it by hand.
-- DISTINCT ON with the ORDER BY below picks the single element with the largest
-- mass fraction for each alloy.
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

-- Now that it is populated, make it mandatory. Anything added later has to pass
-- the CHECK and cannot be left empty.
ALTER TABLE alloys ALTER COLUMN primary_metal SET NOT NULL;

-- The families were typed by hand, so confirm each one still agrees with the
-- metal just computed. This is the assertion that keeps "COPPER family" and
-- "mostly copper" from drifting apart - and it is what catches a brass being
-- filed under PRECIOUS by accident.
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
        -- PRECIOUS is the one family that spans several metals.
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

-- What each alloy is used for. Several alloys carry three or four uses, which
-- is the whole reason this is a table and not a column.
WITH alloy_use_data (alloy_name, use_code) AS (
    VALUES
        ('Fine Gold 24K', 'BULLION'),
        ('Fine Gold 24K', 'COINAGE'),
        ('22K Gold Coin Alloy', 'COINAGE'),
        ('22K Gold Coin Alloy', 'JEWELRY'),
        ('18K Yellow Gold', 'JEWELRY'),
        ('18K Rose Gold', 'JEWELRY'),
        ('18K White Gold (Palladium)', 'JEWELRY'),
        ('14K Yellow Gold', 'JEWELRY'),
        ('10K Yellow Gold', 'JEWELRY'),
        ('Electrum', 'COINAGE'),
        ('Electrum', 'DECORATIVE'),
        ('Sterling Silver', 'JEWELRY'),
        ('Sterling Silver', 'DECORATIVE'),
        ('Coin Silver', 'COINAGE'),
        ('Britannia Silver', 'DECORATIVE'),
        ('Britannia Silver', 'JEWELRY'),
        ('Platinum 950', 'JEWELRY'),
        ('Palladium 950', 'JEWELRY'),

        ('Yellow Brass', 'FASTENERS'),
        ('Yellow Brass', 'DECORATIVE'),
        ('Red Brass', 'MARINE'),
        ('Red Brass', 'DECORATIVE'),
        ('Naval Brass', 'MARINE'),
        ('Leaded Free-Cutting Brass', 'FASTENERS'),
        ('Leaded Free-Cutting Brass', 'TOOLING'),
        ('Gilding Metal', 'DECORATIVE'),
        ('Tin Bronze', 'BEARING'),
        ('Tin Bronze', 'DECORATIVE'),
        ('Phosphor Bronze', 'ELECTRICAL'),
        ('Phosphor Bronze', 'BEARING'),
        ('Aluminum Bronze', 'MARINE'),
        ('Aluminum Bronze', 'BEARING'),
        ('Silicon Bronze', 'FASTENERS'),
        ('Silicon Bronze', 'MARINE'),
        ('Manganese Bronze', 'MARINE'),
        ('Manganese Bronze', 'STRUCTURAL'),
        ('Leaded Bronze', 'BEARING'),
        ('Bell Metal', 'MUSICAL'),
        ('Bell Metal', 'DECORATIVE'),
        ('Cupronickel 90/10', 'MARINE'),
        ('Cupronickel 70/30', 'MARINE'),
        ('Nickel Silver', 'MUSICAL'),
        ('Nickel Silver', 'DECORATIVE'),
        ('Nickel Silver', 'INSTRUMENTATION'),
        ('Beryllium Copper', 'ELECTRICAL'),
        ('Beryllium Copper', 'TOOLING'),
        ('Chromium Copper', 'ELECTRICAL'),
        ('Chromium Copper', 'TOOLING'),
        ('Shakudo', 'DECORATIVE'),
        ('Shakudo', 'JEWELRY'),

        ('Traditional Lead Pewter', 'DECORATIVE'),
        ('Lead-Free Pewter', 'DECORATIVE'),
        ('Sn63/Pb37 Eutectic Solder', 'SOLDERING'),
        ('Sn63/Pb37 Eutectic Solder', 'ELECTRICAL'),
        ('SAC305 Lead-Free Solder', 'SOLDERING'),
        ('SAC305 Lead-Free Solder', 'ELECTRICAL'),

        ('Aluminum 3003', 'COOKWARE'),
        ('Aluminum 3003', 'STRUCTURAL'),
        ('Aluminum 5052', 'MARINE'),
        ('Aluminum 5052', 'STRUCTURAL'),
        ('Aluminum 6061', 'STRUCTURAL'),
        ('Aluminum 6061', 'MARINE'),
        ('Aluminum 6061', 'TOOLING'),
        ('Aluminum 7075', 'AEROSPACE'),
        ('Aluminum 7075', 'TOOLING'),
        ('Aluminum 2024', 'AEROSPACE'),
        ('Aluminum 2024', 'STRUCTURAL'),
        ('A356 Cast Aluminum', 'STRUCTURAL'),
        ('A356 Cast Aluminum', 'AEROSPACE'),

        ('1018 Mild Steel', 'STRUCTURAL'),
        ('1018 Mild Steel', 'FASTENERS'),
        ('1045 Medium Carbon Steel', 'STRUCTURAL'),
        ('1045 Medium Carbon Steel', 'TOOLING'),
        ('4140 Chromoly Steel', 'STRUCTURAL'),
        ('4140 Chromoly Steel', 'TOOLING'),
        ('4140 Chromoly Steel', 'AEROSPACE'),
        ('304 Stainless Steel', 'STRUCTURAL'),
        ('304 Stainless Steel', 'COOKWARE'),
        ('304 Stainless Steel', 'MEDICAL'),
        ('316 Stainless Steel', 'MARINE'),
        ('316 Stainless Steel', 'MEDICAL'),
        ('316 Stainless Steel', 'STRUCTURAL'),
        ('430 Stainless Steel', 'DECORATIVE'),
        ('430 Stainless Steel', 'COOKWARE'),
        ('17-4 PH Stainless Steel', 'AEROSPACE'),
        ('17-4 PH Stainless Steel', 'STRUCTURAL'),
        ('17-4 PH Stainless Steel', 'MARINE'),
        ('M2 High-Speed Steel', 'TOOLING'),
        ('Gray Cast Iron', 'STRUCTURAL'),
        ('Gray Cast Iron', 'COOKWARE'),
        ('Ductile Cast Iron', 'STRUCTURAL'),
        ('Weathering Steel', 'STRUCTURAL'),
        ('Weathering Steel', 'DECORATIVE'),
        ('Invar 36', 'INSTRUMENTATION'),

        ('Inconel 718', 'HIGH_TEMPERATURE'),
        ('Inconel 718', 'AEROSPACE'),
        ('Hastelloy C-276', 'HIGH_TEMPERATURE'),
        ('Hastelloy C-276', 'MARINE'),
        ('Monel 400', 'MARINE'),
        ('Monel 400', 'HIGH_TEMPERATURE'),
        ('Nichrome 80/20', 'ELECTRICAL'),
        ('Nichrome 80/20', 'HIGH_TEMPERATURE'),
        ('Nitinol', 'MEDICAL'),
        ('Nitinol', 'INSTRUMENTATION'),

        ('Ti-6Al-4V', 'AEROSPACE'),
        ('Ti-6Al-4V', 'MEDICAL'),
        ('Ti-6Al-4V', 'STRUCTURAL'),
        ('CP Titanium Grade 2', 'MEDICAL'),
        ('CP Titanium Grade 2', 'MARINE'),

        ('Zamak 3', 'DECORATIVE'),
        ('Zamak 3', 'STRUCTURAL'),
        ('Zamak 5', 'STRUCTURAL'),
        ('Zamak 5', 'DECORATIVE'),
        ('AZ91D Magnesium', 'STRUCTURAL'),
        ('AZ91D Magnesium', 'AEROSPACE'),
        ('AZ31B Magnesium', 'STRUCTURAL'),
        ('AZ31B Magnesium', 'AEROSPACE')
)
INSERT INTO alloy_uses (alloy_id, use_code)
SELECT
    a.alloy_id,
    d.use_code
FROM alloy_use_data d
INNER JOIN alloys a ON a.name = d.alloy_name
ON CONFLICT (alloy_id, use_code) DO NOTHING;

-- Mint products: coins, rounds, bars, ingots, medals, tokens, and goldbacks.
-- Uses alloy names already seeded above.
--
-- alloy_id is the predominant alloy BY WEIGHT, which is occasionally not the one
-- you see: a clad US quarter is mostly its pure copper core, not the cupronickel
-- on the outside. Layers are recorded in mint_product_components below.
--
-- fine_metal_weight_g is filled in only where it means something - bullion and
-- precious coins. For a circulating base-metal coin nobody asks how much copper
-- is in it, so it stays NULL rather than carrying a number no one wants.
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
        -- Precious bullion coins.
        ('American Gold Eagle (1 oz)', 'COIN', 'United States', 'United States Mint', 1986, 33.9305, 31.1035, '22K Gold Coin Alloy'),
        ('American Silver Eagle (1 oz)', 'COIN', 'United States', 'United States Mint', 1986, 31.1035, 31.1035, 'Fine Silver 999'),
        ('American Platinum Eagle (1 oz)', 'COIN', 'United States', 'United States Mint', 1997, 31.1035, 31.1035, 'Fine Platinum 9995'),
        ('Krugerrand (1 oz)', 'COIN', 'South Africa', 'South African Mint', 1967, 33.9300, 31.1035, '22K Gold Coin Alloy'),
        ('Gold Britannia (1 oz)', 'COIN', 'United Kingdom', 'The Royal Mint', 1987, 34.0500, 31.1035, '22K Gold Coin Alloy'),
        ('Gold Maple Leaf (1 oz)', 'COIN', 'Canada', 'Royal Canadian Mint', 1979, 31.1035, 31.1035, 'Fine Gold 24K'),
        ('Silver Maple Leaf (1 oz)', 'COIN', 'Canada', 'Royal Canadian Mint', 1988, 31.1035, 31.1035, 'Fine Silver 999'),

        -- Historic US silver.
        ('Morgan Silver Dollar', 'COIN', 'United States', 'United States Mint', 1878, 26.7300, 24.0570, 'Coin Silver'),
        ('Peace Silver Dollar', 'COIN', 'United States', 'United States Mint', 1921, 26.7300, 24.0570, 'Coin Silver'),
        ('Franklin Half Dollar', 'COIN', 'United States', 'United States Mint', 1948, 12.5000, 11.2500, 'Coin Silver'),

        -- Circulating US base metal. The cent and the clad coins are layered.
        ('Lincoln Cent (Copper-Plated Zinc)', 'COIN', 'United States', 'United States Mint', 1982, 2.5000, NULL, 'Coinage Zinc Core'),
        ('Jefferson Nickel', 'COIN', 'United States', 'United States Mint', 1938, 5.0000, NULL, 'Cupronickel 75/25'),
        ('Roosevelt Dime (Clad)', 'COIN', 'United States', 'United States Mint', 1965, 2.2680, NULL, 'Commercial Pure Copper'),
        ('Washington Quarter (Clad)', 'COIN', 'United States', 'United States Mint', 1965, 5.6700, NULL, 'Commercial Pure Copper'),
        ('Sacagawea Dollar', 'COIN', 'United States', 'United States Mint', 2000, 8.1000, NULL, 'Manganese Brass'),

        -- Circulating Europe, including two bimetallic coins.
        ('2 Euro', 'COIN', 'Euro area', 'Various national mints', 2002, 8.5000, NULL, 'Nickel Brass'),
        ('1 Euro', 'COIN', 'Euro area', 'Various national mints', 2002, 7.5000, NULL, 'Cupronickel 75/25'),
        ('20 Euro Cent', 'COIN', 'Euro area', 'Various national mints', 2002, 5.7400, NULL, 'Nordic Gold'),
        ('1 Euro Cent', 'COIN', 'Euro area', 'Various national mints', 2002, 2.3000, NULL, 'Coinage Steel Core'),
        ('Two Pounds', 'COIN', 'United Kingdom', 'The Royal Mint', 1998, 12.0000, NULL, 'Nickel Brass'),
        ('Brass Threepence', 'COIN', 'United Kingdom', 'The Royal Mint', 1937, 6.8000, NULL, 'Nickel Brass'),
        ('1 Lira', 'COIN', 'Italy', 'Istituto Poligrafico e Zecca dello Stato', 1946, 0.6250, NULL, 'Coinage Aluminum'),

        -- Ancient and colonial. Both predate ISO currency codes.
        ('Roman Denarius', 'COIN', 'Roman Republic', 'Rome', -211, 3.9000, 3.7378, 'Britannia Silver'),
        ('8 Reales', 'COIN', 'Spanish Empire', 'Mexico City Mint', 1732, 27.0700, 24.3630, 'Coin Silver'),

        -- Privately minted rounds. Coin-shaped, but not money.
        ('1 oz Silver Round', 'ROUND', NULL, 'Private mint', NULL, 31.1035, 31.1035, 'Fine Silver 999'),
        ('1 oz Copper Round', 'ROUND', NULL, 'Private mint', NULL, 31.1035, 31.1035, 'Commercial Pure Copper'),

        -- Bars.
        ('1 oz Gold Bar', 'BAR', NULL, 'Private mint', NULL, 31.1035, 31.1035, 'Fine Gold 24K'),
        ('10 oz Silver Bar', 'BAR', NULL, 'Private mint', NULL, 311.0350, 311.0350, 'Fine Silver 999'),
        ('1 kg Silver Bar', 'BAR', NULL, 'Private mint', NULL, 1000.0000, 1000.0000, 'Fine Silver 999'),
        ('1 oz Platinum Bar', 'BAR', NULL, 'Private mint', NULL, 31.1035, 31.1035, 'Fine Platinum 9995'),
        ('100 g Palladium Bar', 'BAR', NULL, 'Private mint', NULL, 100.0000, 100.0000, 'Fine Palladium 9995'),
        ('Copper Ingot (5 lb)', 'INGOT', NULL, 'Private refiner', NULL, 2267.9600, 2267.9600, 'Commercial Pure Copper'),

        -- Not currency, not bullion.
        ('Bronze Commemorative Medal', 'MEDAL', NULL, 'Private mint', NULL, 45.0000, NULL, 'Tin Bronze'),
        ('Brass Arcade Token', 'TOKEN', NULL, 'Private mint', NULL, 4.5000, NULL, 'Yellow Brass'),

        -- Goldbacks: polymer notes carrying a measured gold leaf. Gross weight is
        -- mostly polymer, so fine_metal_weight_g is the only figure that matters -
        -- one "goldback" is 1/1000 troy ounce of 24K gold.
        ('Utah Goldback 1', 'NOTE', 'Utah', 'Goldback Inc.', 2019, NULL, 0.0311, 'Fine Gold 24K'),
        ('Utah Goldback 50', 'NOTE', 'Utah', 'Goldback Inc.', 2019, NULL, 1.5552, 'Fine Gold 24K'),
        ('Nevada Goldback 5', 'NOTE', 'Nevada', 'Goldback Inc.', 2020, NULL, 0.1555, 'Fine Gold 24K')
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

-- The coin subtype. Only the legal tender pieces get a row here; rounds, bars,
-- medals, tokens and goldbacks deliberately have none.
--
-- face_value_currency_code uses 'XXX', the ISO 4217 code for "no currency", for
-- pieces that predate the standard. is_legal_tender records whether the piece
-- would still be accepted as money today - historic US coins technically would,
-- a Roman denarius would not.
INSERT INTO coins (mint_product_id, face_value, face_value_currency_code, is_legal_tender)
SELECT
    p.mint_product_id,
    v.face_value,
    v.face_value_currency_code,
    v.is_legal_tender
FROM (
    VALUES
        ('American Gold Eagle (1 oz)', 50.00, 'USD', TRUE),
        ('American Silver Eagle (1 oz)', 1.00, 'USD', TRUE),
        ('American Platinum Eagle (1 oz)', 100.00, 'USD', TRUE),
        -- No denomination is struck on a Krugerrand; its value is the gold price.
        ('Krugerrand (1 oz)', NULL, 'ZAR', TRUE),
        ('Gold Britannia (1 oz)', 100.00, 'GBP', TRUE),
        ('Gold Maple Leaf (1 oz)', 50.00, 'CAD', TRUE),
        ('Silver Maple Leaf (1 oz)', 5.00, 'CAD', TRUE),
        ('Morgan Silver Dollar', 1.00, 'USD', TRUE),
        ('Peace Silver Dollar', 1.00, 'USD', TRUE),
        ('Franklin Half Dollar', 0.50, 'USD', TRUE),
        ('Lincoln Cent (Copper-Plated Zinc)', 0.01, 'USD', TRUE),
        ('Jefferson Nickel', 0.05, 'USD', TRUE),
        ('Roosevelt Dime (Clad)', 0.10, 'USD', TRUE),
        ('Washington Quarter (Clad)', 0.25, 'USD', TRUE),
        ('Sacagawea Dollar', 1.00, 'USD', TRUE),
        ('2 Euro', 2.00, 'EUR', TRUE),
        ('1 Euro', 1.00, 'EUR', TRUE),
        ('20 Euro Cent', 0.20, 'EUR', TRUE),
        ('1 Euro Cent', 0.01, 'EUR', TRUE),
        ('Two Pounds', 2.00, 'GBP', TRUE),
        -- Pre-decimal threepence, expressed in decimal pounds.
        ('Brass Threepence', 0.0125, 'GBP', FALSE),
        ('1 Lira', 1.00, 'ITL', FALSE),
        ('Roman Denarius', NULL, 'XXX', FALSE),
        ('8 Reales', NULL, 'XXX', FALSE)
) AS v(name, face_value, face_value_currency_code, is_legal_tender)
INNER JOIN mint_products p ON p.name = v.name
ON CONFLICT (mint_product_id) DO UPDATE SET
    face_value = EXCLUDED.face_value,
    face_value_currency_code = EXCLUDED.face_value_currency_code,
    is_legal_tender = EXCLUDED.is_legal_tender;

-- How the layered pieces are built. Percentages are derived from each coin's
-- published overall composition: for the clad quarter, cupronickel cladding is
-- 25 percent nickel and the coin is 8.33 percent nickel overall, so the cladding
-- must be 8.33 / 25 = one third of the weight. Where no such figure can be
-- worked out - the bimetallic ring-to-centre split - the percentage is left NULL
-- rather than guessed.
WITH component_data (product_name, alloy_name, component_role, percent_of_weight) AS (
    VALUES
        -- 97.5% Zn overall, core is 99.2% Zn: 97.5 / 99.2 = 98.286% core.
        ('Lincoln Cent (Copper-Plated Zinc)', 'Coinage Zinc Core', 'CORE', 98.286),
        ('Lincoln Cent (Copper-Plated Zinc)', 'Commercial Pure Copper', 'PLATING', 1.714),

        -- 8.33% Ni overall, cladding is 25% Ni: one third cladding, two thirds core.
        ('Roosevelt Dime (Clad)', 'Cupronickel 75/25', 'CLADDING', 33.333),
        ('Roosevelt Dime (Clad)', 'Commercial Pure Copper', 'CORE', 66.667),
        ('Washington Quarter (Clad)', 'Cupronickel 75/25', 'CLADDING', 33.333),
        ('Washington Quarter (Clad)', 'Commercial Pure Copper', 'CORE', 66.667),

        -- 2% Ni overall, manganese brass is 4% Ni: an even split. The two halves
        -- weigh the same, so "predominant alloy" is a coin toss here - alloy_id
        -- names the brass because that is the part you can see.
        ('Sacagawea Dollar', 'Manganese Brass', 'CLADDING', 50.000),
        ('Sacagawea Dollar', 'Commercial Pure Copper', 'CORE', 50.000),

        -- Bimetallic. Ring and centre swap alloys between the 1 and 2 euro.
        ('2 Euro', 'Nickel Brass', 'RING', NULL),
        ('2 Euro', 'Cupronickel 75/25', 'CENTER', NULL),
        ('1 Euro', 'Cupronickel 75/25', 'RING', NULL),
        ('1 Euro', 'Nickel Brass', 'CENTER', NULL),
        ('Two Pounds', 'Nickel Brass', 'RING', NULL),
        ('Two Pounds', 'Cupronickel 75/25', 'CENTER', NULL),

        -- Copper-plated steel.
        ('1 Euro Cent', 'Coinage Steel Core', 'CORE', NULL),
        ('1 Euro Cent', 'Commercial Pure Copper', 'PLATING', NULL)
)
INSERT INTO mint_product_components (mint_product_id, alloy_id, component_role, percent_of_weight)
SELECT
    p.mint_product_id,
    a.alloy_id,
    d.component_role,
    d.percent_of_weight
FROM component_data d
INNER JOIN mint_products p ON p.name = d.product_name
INNER JOIN alloys a ON a.name = d.alloy_name
ON CONFLICT (mint_product_id, alloy_id, component_role)
DO UPDATE SET percent_of_weight = EXCLUDED.percent_of_weight;

-- Same guard as the alloy compositions, for the same reason: both joins above
-- would silently drop a row whose product or alloy name is misspelled. Layer
-- weights only have to add up where they were stated at all.
DO $$
DECLARE
    offenders text;
BEGIN
    SELECT string_agg(name || ' (' || total || '%)', ', ' ORDER BY name)
    INTO offenders
    FROM (
        SELECT p.name, sum(c.percent_of_weight) AS total
        FROM mint_products p
        INNER JOIN mint_product_components c ON c.mint_product_id = p.mint_product_id
        GROUP BY p.name
        HAVING count(*) FILTER (WHERE c.percent_of_weight IS NULL) = 0
           AND sum(c.percent_of_weight) <> 100
    ) AS broken;

    IF offenders IS NOT NULL THEN
        RAISE EXCEPTION
            'Stated component weights must sum to 100 percent. Broken: %', offenders;
    END IF;
END $$;

COMMIT;
