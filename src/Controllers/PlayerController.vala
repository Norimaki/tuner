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

public struct streamdata {
    public string? title;
    public string? genre;
    public int? min_max_bitrate;
}

public class Tuner.PlayerController : Object {
    private Model.Station _station;
    private Gst.PlayerState? _current_state = Gst.PlayerState.STOPPED;
    public Gst.Player player;

    public signal void station_changed (Model.Station station);
    public signal void state_changed (Gst.PlayerState state);
    public signal void title_changed (string title);
    public signal void volume_changed (double volume);
    public signal void media_info_updated (streamdata sd);
    public signal void uri_changed (string uri);
   
    private uint media_info_updated_throttling_source;

    construct {

        media_info_updated_throttling_source = 0;

        player = new Gst.Player (null, null);
        player.state_changed.connect ((state) => {
            // Don't forward flickering between playing and buffering
            if (!(current_state == Gst.PlayerState.PLAYING && state == Gst.PlayerState.BUFFERING) && !(state == current_state)) {
                state_changed (state);
                current_state = state;
            }
        });
        player.media_info_updated.connect ((obj) => {
            if (media_info_updated_throttling_source == 0) {
                streamdata sd = extract_metadata_from_stream (obj);
                if (sd.title != null || sd.genre != null || sd.min_max_bitrate != null){
                    media_info_updated(sd);
                }
                if (sd.title != null){
                    media_info_updated_throttling_source = Timeout.add (1024, () => {
                        media_info_updated_throttling_source = 0;
                        return false;
                    }); 
                }
            }
        });
        player.volume_changed.connect ((obj) => {
            volume_changed(obj.volume);
        });
        player.uri_loaded.connect ((uri) => {
            uri_changed(uri);
        });
    }

    public Gst.PlayerState? current_state { 
        get {
            return _current_state;
        }

        set {
            _current_state = value;
        }
    }

    public Model.Station station {
        get {
            return _station;
        }

        set {
            _station = value;
            play_station (_station);
        }
    }

    public double volume {
        get { return player.volume; }
        set { player.volume = value; }
    }

    public void play_station (Model.Station station) {
        player.uri = station.url;
        player.play ();
        station_changed (station);
    }

    //cambiar
    public bool can_play () {
        return _station != null;
    }
    //por
    public bool has_station () {
        return _station != null;
    }

    public void play_pause () {
        switch (_current_state) {
            case Gst.PlayerState.PLAYING:
            case Gst.PlayerState.BUFFERING:
                player.pause ();
            break;
            default:
                player.play ();
                break;
        }
    }


    private streamdata extract_metadata_from_stream (Gst.PlayerMediaInfo media_info) {

        streamdata sd = { null, null, null };
        string? title = null;
        string? genre = null;
        int? max_bitrate = null;

        var audiostreams = media_info.get_audio_streams ().copy ();
        foreach (var stream in audiostreams) {
            max_bitrate  = stream.get_max_bitrate ();
            if (sd.min_max_bitrate == null || (max_bitrate != null && max_bitrate < sd.min_max_bitrate)){
                sd.min_max_bitrate = max_bitrate;
            }

            var tags = stream.get_tags ();
            tags.foreach ((list, tag) => { 
                if (tag == "title") {
                    list.get_string(tag, out title);
                    if (title != null && (sd.title == null || sd.title == "")){
                        sd.title = title;
                    }
                }
                else if (tag == "genre"){
                   list.get_string(tag, out genre);
                    if (genre != null && (sd.genre == null || sd.genre == "")){
                        sd.genre = genre;
                    }
                }
                else{
                    //debug (@"#mpris tags=$(tag)");
                }
            });
        }

        if (sd.genre != null && (sd.genre == "null" || sd.genre == "(null)")){
            sd.genre = null;
        }

        if (sd.min_max_bitrate != null){
            int resto = sd.min_max_bitrate % 1000;
            if (resto<500){
                sd.min_max_bitrate = sd.min_max_bitrate - resto;
            }
            else{
                sd.min_max_bitrate = sd.min_max_bitrate - resto + 1000;
            }
        }
        return sd;
    }
}
