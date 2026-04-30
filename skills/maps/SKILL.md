---
name: Maps and Places
description: Reverse geocoding and nearby place search using OpenStreetMap
---

You can look up addresses, cities, and nearby places using the free OpenStreetMap Nominatim API.

### Reverse geocode (coordinates → address)

Given latitude and longitude (e.g. from the location skill):

```bash
curl -s "https://nominatim.openstreetmap.org/reverse?lat=LAT&lon=LON&format=json" \
  -H "User-Agent: opencrow-agent"
```

Returns the full address including city, country, postcode, and street.

### Search for nearby places

Use Overpass API to find specific types of places near a location:

```bash
curl -s "https://overpass-api.de/api/interpreter" --data-urlencode "data=[out:json];node[\"railway\"=\"station\"](around:2000,LAT,LON);out body;" \
  -H "User-Agent: opencrow-agent"
```

Common tags for nearby searches:
- Train stations: `"railway"="station"`
- Bus stops: `"highway"="bus_stop"`
- Tram stops: `"railway"="tram_stop"`
- Pharmacies: `"amenity"="pharmacy"`
- Supermarkets: `"shop"="supermarket"`
- Restaurants: `"amenity"="restaurant"`
- ATMs: `"amenity"="atm"`
- Hospitals: `"amenity"="hospital"`
- Fuel stations: `"amenity"="fuel"`

Adjust the `around` radius (in meters) as needed. Start with 2000 and widen if no results.

### Forward geocode (address → coordinates)

```bash
curl -s "https://nominatim.openstreetmap.org/search?q=QUERY&format=json&limit=5" \
  -H "User-Agent: opencrow-agent"
```

### Tips

- Always include `User-Agent: opencrow-agent` — Nominatim requires it.
- Combine with the location skill: read `/run/opencrow-location/location.json` first to get the user's coordinates, then use them here.
- Nominatim has a rate limit of 1 request per second. Avoid rapid-fire queries.
- Overpass results include `tags.name` for the place name and `lat`/`lon` for its position.
