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

public class Tuner.HeaderBar : Gtk.HeaderBar {

    private const string DEFAULT_ICON_NAME = "internet-radio-symbolic";
    public enum PlayState {
        PAUSE_ACTIVE,
        PAUSE_INACTIVE,
        PLAY_ACTIVE,
        PLAY_INACTIVE
    }

    public Gtk.Button play_button { get; set; }


    public Gtk.VolumeButton volume_button;

    private Gtk.Button star_button;
    private Model.Station _station;
    private Gtk.Label _title_label;
    private RevealLabel _subtitle_label;
    private Gtk.Image _favicon_image;

    public signal void star_clicked (Model.Station s);
    public signal void searched_for (string text);
    public signal void searched_for_thr (string text);
    private uint search_source = 0;

    public signal void search_focused ();

    construct {
        show_close_button = true;

        var station_info = new Gtk.Grid ();
        station_info.width_request = 200;
        station_info.column_spacing = 10;

        _title_label = new Gtk.Label (_("Choose a station"));
        _title_label.get_style_context ().add_class (Granite.STYLE_CLASS_H4_LABEL);
        _title_label.ellipsize = Pango.EllipsizeMode.MIDDLE;
        _subtitle_label = new RevealLabel ();
        _favicon_image = new Gtk.Image.from_icon_name (DEFAULT_ICON_NAME, Gtk.IconSize.DIALOG);

        station_info.attach (_favicon_image, 0, 0, 1, 2);
        station_info.attach (_title_label, 1, 0, 1, 1);
        station_info.attach (_subtitle_label, 1, 1, 1, 1);

        custom_title = station_info;
        play_button = new Gtk.Button ();
        play_button.valign = Gtk.Align.CENTER;
        play_button.action_name = Window.ACTION_PREFIX + Window.ACTION_PAUSE;
        play_button.image = new Gtk.Image.from_icon_name (
            "media-playback-pause-symbolic",
            Gtk.IconSize.LARGE_TOOLBAR
        );
        play_button.sensitive = false;
        pack_start (play_button);

        var prefs_button = new Gtk.MenuButton ();
        prefs_button.image = new Gtk.Image.from_icon_name ("open-menu", Gtk.IconSize.LARGE_TOOLBAR);
        prefs_button.valign = Gtk.Align.CENTER;
        prefs_button.sensitive = true;
        prefs_button.tooltip_text = _("Preferences");
        prefs_button.popover = new Tuner.PreferencesPopover();;
        pack_end (prefs_button);

        var searchentry = new Gtk.SearchEntry ();
        searchentry.valign = Gtk.Align.CENTER;
        searchentry.placeholder_text = _("Station name");
        searchentry.search_changed.connect ((e) => {

            if (search_source != 0){
                Source.remove(search_source);
            }
            search_source = Timeout.add (1024, () => {
                searched_for (e.text);
                search_source = 0;
                return false;
            });
            
        });

        searchentry.activate.connect ((e) => {
            if (search_source != 0){
                Source.remove(search_source);
            }
            searched_for (e.text);
            search_source = 0;
        });

        searchentry.focus_in_event.connect ((e) => {
            search_focused ();
            return true;
        });


        pack_end (searchentry);

        star_button = new Gtk.Button.from_icon_name (
            "non-starred",
            Gtk.IconSize.LARGE_TOOLBAR
        );
        star_button.valign = Gtk.Align.CENTER;
        star_button.sensitive = false;
        star_button.tooltip_text = _("Star this station");
        star_button.clicked.connect (() => {
            star_clicked (_station);
        });
        pack_start (star_button);

        volume_button = new Gtk.VolumeButton ();
        volume_button.value = Application.instance.settings.get_double ("volume");
        volume_button.value_changed.connect ((value) => {
            Application.instance.settings.set_double ("volume", value);
        });
        pack_start (volume_button);

    }

    public new string title {
        get {
            return _title_label.label;
        }
        set {
            _title_label.label = value;
        }
    }

    public new string subtitle {
        get {
            return _subtitle_label.label;
        }
        set {
            _subtitle_label.label = value;
        }
    }

    public Gtk.Image favicon {
        get {
            return _favicon_image;
        }
        set {
            _favicon_image = value;
        }
    }

    public void handle_station_change () {
        if (!_station.starred) {
            star_button.image = new Gtk.Image.from_icon_name ("non-starred",    Gtk.IconSize.LARGE_TOOLBAR);
        } else {
            star_button.image = new Gtk.Image.from_icon_name ("starred",    Gtk.IconSize.LARGE_TOOLBAR);
        }
    }

    public void update_from_station (Model.Station station) {
        if (_station != null) {
            _station.notify.disconnect (handle_station_change);
        }
        _station = station;
        _station.notify.connect ( (sender, property) => {
            handle_station_change ();
        });
        title = station.title;
        subtitle = _("Playing");
        load_favicon (station.id, station.favicon_url);
        handle_station_change ();
    }

    private void load_favicon (string id, string url) {
        //We can make icon from cache as it should be downloaded.
        //TODO: sv
        IconTask.make_icon(id, "", favicon, false);
        return;
    }


    public void on_player_state_changed (Gst.PlayerState? state, bool can_play) {
        
        if (state == null){
            Gdk.threads_add_idle (() => {
                play_button.image = new Gtk.Image.from_icon_name (
                    "media-playback-pause-symbolic",
                    Gtk.IconSize.LARGE_TOOLBAR
                );
                play_button.sensitive = false;
                star_button.sensitive = false;
                return false;
            });
        }
        else if (state == Gst.PlayerState.BUFFERING || state == Gst.PlayerState.PLAYING){
            Gdk.threads_add_idle (() => {
                play_button.image = new Gtk.Image.from_icon_name (
                    "media-playback-pause-symbolic",
                    Gtk.IconSize.LARGE_TOOLBAR
                );
                play_button.sensitive = true;
                star_button.sensitive = true;
                return false;
            });
        }
        else if (can_play){
            Gdk.threads_add_idle (() => {
                play_button.image = new Gtk.Image.from_icon_name (
                    "media-playback-start-symbolic",
                    Gtk.IconSize.LARGE_TOOLBAR
                );
                play_button.sensitive = true;
                star_button.sensitive = true;
                return false;
            });
        }
        else{
            Gdk.threads_add_idle (() => {
                play_button.image = new Gtk.Image.from_icon_name (
                    "media-playback-start-symbolic",
                    Gtk.IconSize.LARGE_TOOLBAR
                );
                play_button.sensitive = false;
                star_button.sensitive = false;
                return false;
            });
        }
    }

  


}
