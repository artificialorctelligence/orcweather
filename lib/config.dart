/// Every external endpoint the app talks to, in one place.
/// Swap the base map by changing [baseTileUrl] + [baseAttribution] only.
library;

const appUserAgent = 'orcweather (github.com/artificialorctelligence/orcweather)';
const applicationId = 'com.artificialorctelligence.orcweather';

// Base map. OSM's public tiles are for prototyping/personal use only —
// see docs/orclab-research/map-openstreetmap. Move to another provider before shipping.
const baseTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const baseAttribution = '© OpenStreetMap contributors';

const librewxrHost = 'https://api.librewxr.net';
const librewxrColorScheme = 2; // "Universal Blue"
const librewxrAttribution = 'Weather data via LibreWXR (librewxr.net)';

const nwsHost = 'https://api.weather.gov';

// USDOT Work Zone Data Exchange feed registry (Socrata JSON, no key).
const wzdxRegistryUrl = 'https://datahub.transportation.gov/resource/69qe-yiui.json?\$limit=500';

const radiusMiles = 50.0; // data + circle
const defaultViewMiles = 30.0; // what the recenter button fits on screen
const metersPerMile = 1609.344;

// Illinois DOT reported winter road conditions (ArcGIS FeatureServer layer, no key).
const idotWinterRoadsUrl =
    'https://services2.arcgis.com/aIrBD8yn1TDTEXoz/arcgis/rest/services/IL_DOT_Winter_Road_Conditions_/FeatureServer/2';
