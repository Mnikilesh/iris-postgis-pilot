-- BESS vertical: parcels within 500m of a substation in the same country,
-- excluding parcels that overlap a screening layer (flood risk, protected area).
-- Uses idx_parcel_geog / idx_substation_geog and idx_screening_layer_geom.
SELECT
    p.country_code, p.region_code, p.parcel_code,
    s.substation_code,
    round(ST_Distance(p.geom::geography, s.geom::geography)::numeric, 1) AS distance_m
FROM iris_core.parcel p
JOIN iris_core.substation s
    ON s.country_code = p.country_code
   AND ST_DWithin(p.geom::geography, s.geom::geography, 500)
WHERE p.country_code = 'GB'
  AND NOT EXISTS (
      SELECT 1 FROM iris_core.screening_layer sl
      WHERE sl.country_code = p.country_code
        AND sl.layer_code IN ('FLOOD_RISK', 'PROTECTED_AREA')
        AND ST_Intersects(sl.geom, p.geom)
  )
ORDER BY distance_m;
