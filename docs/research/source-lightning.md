# Lightning strikes — the one free source, and why it needs a server

**Checked against live sources on 2026-09-15.** No Orclab project has shipped a lightning layer
yet; researched knowledge (BACKLOG #33 sense), the first real use (orcweather #11) corrects it.

## Not usable: Blitzortung and everything built on it (blitzortung.org/en/contact.php, confirmed live 2026-09-15)

The community network behind lightningmaps.org and the "Blitzortung Lightning Monitor" apps.
Its own terms: *"The use of our raw lightning data is allowed only to the participants of the
project or to those we explicitly have allowed it."* *"It is not allowed to use our lightning
data for storm warning systems, for plausibility checks of overvoltage damages, or risk
analysis … even if the data are not obtained directly from our site but from third-party
websites."* External projects *"may not represent commercial interests"*, must be *"freely
accessible"*, and *"Do not setup yet another visualization of online data."* Raw data download
is *"only for the contributors"*. A weather app that warns drivers is a storm-warning use; a
station kit does not change that. Images marked CC BY-SA 4.0 may be embedded — pictures, not
data.

## Paid: Xweather (Vaisala) lightning API, others

Commercial, keyed, metered. Real-time strikes and forecasts; the honest choice for a product
with revenue. Not evaluated in detail.

## Not a source: NWS `api.weather.gov`

No lightning endpoint (weather-gov/api discussion #714). NWS alerts cover thunderstorms as
warnings, not strikes.

## Free and public domain: NOAA GOES Geostationary Lightning Mapper (GLM)

NOAA Open Data Dissemination publishes GOES-East (**GOES-19**, CONUS and the Atlantic) and
GOES-West (**GOES-18**) GLM Level-2 "LCFA" (Lightning Cluster-Filter Algorithm) files on public
S3 buckets with no key:

- Listing: `https://noaa-goes19.s3.amazonaws.com/?list-type=2&prefix=GLM-L2-LCFA/YYYY/DDD/HH/`
  (`DDD` = day of year, UTC). Object names like
  `OR_GLM-L2-LCFA_G19_s20262590242000_e20262590242200_c20262590242221.nc` — `s`/`e` are the
  20-second coverage window, `c` the creation time (**~20 s after the window ends**).
- **One file per 20 s, ~400 KB (G19) / ~290 KB (G18)**: 180 files/hour/satellite.
- Format: netCDF-4 (HDF5). Read with `h5py` (or `netCDF4`/`xarray`). Datasets: `flash_lat`,
  `flash_lon` (**scaled int16 — apply `scale_factor` and `add_offset` attributes**),
  `flash_time_offset_of_first_event`, `flash_energy` (J), `flash_area`; also `group_*` and
  `event_*` at finer granularity. Global attrs `time_coverage_start` / `time_coverage_end`.
- Live check 2026-09-16 02:42 UTC: 375 flashes in one G19 file, lat −21.5…42.0; 32 within
  300 km of Peoria, nearest 16 km.
- Caveats: **flashes, not ground strikes** — GLM sees total lightning (in-cloud + cloud-to-ground)
  from orbit, ~8–14 km pixels, so positions are storm-scale, not street-scale. Coverage ends
  around 54°N; GOES-19 sees the whole CONUS. Public domain (US Government work); attribution
  "NOAA GOES GLM" is courtesy, not licence.

### Why this is a server job

A phone consuming it directly would download ~1.2 MB/min of HDF5 per user and parse it in-app.
The shape that works: a small poller on the project's own server (orcweather's proxy, BACKLOG
#10) lists the current hour's prefix every 20 s, downloads new objects, extracts
`(lat, lon, time)` for flashes, keeps a rolling window (15–30 min) in memory, and serves
`GET /lightning?bbox=w,s,e,n&minutes=15` as GeoJSON points with an age property. Fifteen lines
of `h5py` + `numpy` for the parse; the S3 listing is plain HTTPS XML.

```python
import h5py, numpy as np
f = h5py.File(path)
lat = f['flash_lat'][:].astype(float); lon = f['flash_lon'][:].astype(float)
for name, arr in (('flash_lat', lat), ('flash_lon', lon)):
    a = f[name].attrs
    if 'scale_factor' in a: arr *= float(a['scale_factor']); arr += float(a.get('add_offset', 0))
```

## Sources (live on 2026-09-15/16)

- Blitzortung terms: `https://www.blitzortung.org/en/contact.php`; archive page: `https://www.blitzortung.org/en/archive_data.php`; apps page: `https://www.lightningmaps.org/apps?lang=en`
- NWS API has no lightning: `https://github.com/weather-gov/api/discussions/714`
- GOES on AWS: `https://noaa-goes19.s3.amazonaws.com/` (bucket listing), `https://registry.opendata.aws/noaa-goes/`
- Xweather lightning (paid): `https://www.xweather.com/products/weather-api/lightning`
