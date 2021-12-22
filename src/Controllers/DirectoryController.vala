/*
* Copyright (c) 2020-2021 Louis Brauer <louis@brauer.family>
*
* This file is part of Tuner.
*
* Tuner is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*
* Tuner is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License
* along with Tuner.  If not, see <http://www.gnu.org/licenses/>.
*
*/

using Gee;

public errordomain SourceError {
    UNAVAILABLE
}

public delegate ArrayList<RadioBrowser.Station> Tuner.FetchType(uint offset, uint limit) throws SourceError;

public class Tuner.DirectoryController : Object {
    public RadioBrowser.Client? provider { get; set; }
    public Model.StationStore store { get; set; }

    public signal void tags_updated (ArrayList<RadioBrowser.Tag> tags);

    public DirectoryController (Model.StationStore store) {
        try {
            var client = new RadioBrowser.Client ();
            this.provider = client;
        } catch (RadioBrowser.DataError e) {
            critical (@"RadioBrowser unavailable");
        }
        
        this.store = store;

        // migrate from <= 1.2.3 settings to json based store
        this.migrate_favourites ();
    }

    //used by headerbar. Maybe useless if implement sv on headebar.
    public void station_starred_toggled_handler (Model.Station s){

        //Tuner.DebugNot.create("fav","station_starred_toggled_handler");
        if (s.starred) {
            store.remove (s);
        } else {
            store.add (s); //store toogle starred
        }
    }

    public void starred_toggled_handler (Model.Station_View sv){
        station_starred_toggled_handler(sv.instance);
        //store.toogle(sv.ss.station); //use it if we delete station_starred_changed_handler
    }

    public ArrayList<Model.Station_View> stations_to_views (owned ArrayList<Model.Station> stations){
        ArrayList<Model.Station_View> r = new ArrayList<Model.Station_View>();

        foreach (Model.Station station in stations) {
            var sv = new Model.Station_View.with_station (station);
            if (sv.instance != station){
                station = sv.instance; //No funciona aun.
            }
            sv.station_starred_toggled.connect(starred_toggled_handler);
            r.add (sv); 
           // Tuner.DebugNot.create("f",station.id);

       
        }  
        return r;
    }

    public StationSource load_station_uuid (string uuid) {
        string[] lps_arr = { uuid }; 
        var params = RadioBrowser.SearchParams() {
            uuids = new ArrayList<string>.wrap (lps_arr)
        };
        var source = new RadioSource(1, params, provider, store);
        return source;
    }

    public StationSource load_random_stations (uint limit) {
        var params = RadioBrowser.SearchParams() {
            text  = "",
            countrycode = "",
            tags  = new ArrayList<string>(),
            order = RadioBrowser.SortOrder.RANDOM
        };
        var source = new RadioSource(limit, params, provider, store);
        return source;
    }

    public StationSource load_trending_stations (uint limit) {
        var params = RadioBrowser.SearchParams() {
            text    = "",
            countrycode = "",
            tags    = new ArrayList<string>(),
            order   = RadioBrowser.SortOrder.CLICKTREND,
            reverse = true
        };
        var source = new RadioSource(limit, params, provider, store);
        return source;
    }

    public StationSource load_popular_stations (uint limit) {
        var params = RadioBrowser.SearchParams() {
            text    = "",
            countrycode = "",
            tags    = new ArrayList<string>(),
            order   = RadioBrowser.SortOrder.CLICKCOUNT,
            reverse = true
        };
        var source = new RadioSource(limit, params, provider, store);
        return source;
    }

    public StationSource load_by_country (uint limit, string countrycode) {
        var params = RadioBrowser.SearchParams () {
            text        = "",
            countrycode = countrycode,
            tags  = new ArrayList<string>(),
            order   = RadioBrowser.SortOrder.CLICKCOUNT,
            reverse = true
        };
        var source = new RadioSource(limit, params, provider, store);
        return source;
    }

    public StationSource load_search_stations (owned string utext, uint limit) {
        var params = RadioBrowser.SearchParams() {
            text    = utext,
            countrycode = "",
            tags    = new ArrayList<string>(),
            order   = RadioBrowser.SortOrder.CLICKCOUNT,
            reverse = true
        };
        var source = new RadioSource(limit, params, provider, store); 
        return source;
    }

    public ArrayList<Model.Station>? get_stored () {
        try {
           return _store.get_all ();
        } catch (SourceError e) {
           return null;
        }
    }

    public void migrate_favourites () {
        var settings = Application.instance.settings;
        var starred_stations = settings.get_strv ("starred-stations");
        if (starred_stations.length > 0) {
            warning ("Found settings-based favourites, migrating...");
            var params = RadioBrowser.SearchParams() {
                uuids = new ArrayList<string>.wrap (starred_stations)
            };
            var source = new RadioSource(99999, params, provider, store); 
            try {
                foreach (var station in source.next ()) {
                    store.import (station);
                }  
                store.save();
                settings.set_strv ("starred-stations", null);  
                warning ("Migration completed, settings deleted");     
            } catch (SourceError e) {
                warning ("Error while trying to migrate favourites, aborting...");
            }
        }
    }

    public StationSource load_by_tags (owned ArrayList<string> utags) {
        var params = RadioBrowser.SearchParams() {
            text    = "",
            countrycode = "",
            tags    = utags,
            order   = RadioBrowser.SortOrder.VOTES,
            reverse = true
        };
        var source = new RadioSource(40, params, provider, store);
        return source;
    }

    public StationSource load_favs () {
        var source = new FavoritesSource(store);
        return source;
    }

    public void count_station_click (Model.Station station) {
        if (!Application.instance.settings.get_boolean ("do-not-track")) {
            debug (@"Send listening event for station $(station.id)");
            provider.track (station.id);
        } else {
            debug ("do-not-track enabled, will not send listening event");
        }
    }

    public void load_tags () {
        try {
            var tags = provider.get_tags ();
            tags_updated (tags);
        } catch (RadioBrowser.DataError e) {
            warning (@"unable to load tags: $(e.message)");
        }
    }

}

public abstract class Tuner.StationSource : Object {
    protected abstract bool more  { get; protected set; }
    protected abstract Model.StationStore store  { get; protected set; }

    private StationSource (){
        Object();
        this.more = false;
    } 
    
    public bool has_more () {
        return this.more;
    }
    public abstract ArrayList<Model.Station>? fresh () ;

    public abstract ArrayList<Model.Station>? next () throws SourceError;

}
public class Tuner.FavoritesSource : StationSource {

    public override bool more { get; protected set; }
    protected override Model.StationStore store  { get; protected set; }

    public FavoritesSource (Model.StationStore favstore){
        Object ();
        store = favstore;
        more = false;
    }

    public override ArrayList<Model.Station>? fresh () {
        try {
            store.load();
            var r =  this.store.get_all (); 
            return r;  
        } catch (SourceError e) {
           return null;
        }
    }

    public override ArrayList<Model.Station>? next () throws SourceError{
        try {
            //store.load();
            return this.store.get_all ();   
        } catch (SourceError e) {
            throw new SourceError.UNAVAILABLE("Directory Error");
            //return null;
        }
    }
}

public class Tuner.RadioSource : StationSource {

    protected override bool more  { get; protected set; }
    protected override Model.StationStore store  { get; protected set; }

    private uint _offset = 0;
    private uint _page_size = 20;
    private RadioBrowser.SearchParams _params;
    private RadioBrowser.Client _client;

    public RadioSource (uint limit, 
                          RadioBrowser.SearchParams params, 
                          RadioBrowser.Client client,
                          Model.StationStore favstore) {
        Object ();
        // This disables paging for now
        _page_size = limit;
        _params = params;
        _client = client;
        store = favstore;
        more = true;
    }

    public override ArrayList<Model.Station>? fresh () {
        try {
            return next ();
        } catch (SourceError e) {
            return null;
        }
    }

    public override ArrayList<Model.Station>? next () throws SourceError {

        // Fetch one more to determine if source has more items than page size 
        try {
            var raw_stations = _client.search (_params, _page_size + 1, _offset);
            // TODO Place filter here?
            //var filtered_stations = raw_stations.filter (filterByCountry);
            var filtered_stations = raw_stations.iterator ();

            var stations = convert_stations (filtered_stations);
            _offset += _page_size;
            more = stations.size > _page_size;
            if (more) stations.remove_at( (int)_page_size);
            return stations;    
        } catch (RadioBrowser.DataError e) {
            throw new SourceError.UNAVAILABLE("Directory Error");
        }
    }

    private ArrayList<Model.Station> convert_stations (Iterator<RadioBrowser.Station> raw_stations) {
        var stations = new ArrayList<Model.Station> ();
        
        while (raw_stations.next()) {
            var station = raw_stations.get ();
            var s = new Model.Station (
                station.stationuuid,
                station.name,
                Model.Countries.get_by_code(station.countrycode, station.country),
                station.url_resolved);
            if (_store.contains (s)) {
                s.starred = true;
            }
            else{
               s.starred = false;
            }
            s.favicon_url = station.favicon;
            s.clickcount = station.clickcount;
            s.homepage = station.homepage;
            s.codec = station.codec;
            s.bitrate = station.bitrate;

            stations.add (s);
        }
        return stations;
    }
}
