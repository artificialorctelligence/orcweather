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

const radiusMiles = 50.0;
const metersPerMile = 1609.344;
