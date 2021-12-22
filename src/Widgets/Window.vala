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



public class Tuner.Winman : Object {

    public static Winman _instance = null;

    private int content_width;

    public int target_cols {get; private set;}
    public bool win_maximized {get; private set;}

    public signal void target_cols_up(int target_cols);
    public signal void win_is_maximized(bool status);

    public static Winman instance {
        get {
            if (_instance == null) {
                _instance = new Winman ();
            }
            return _instance;
        }
    }

    public static int calc_cols(int w){
        int c = (int)(w * 100000 / 250.00);
        int resto = c % 100000;
        int b = 0;
        if (resto >= 50000){
        b=100000;
        }
        int cols = (c + b - resto)/100000;
        if (cols < 1 ) cols = 1;
        return cols;
    }

    public void set_maximized(bool status){
        win_maximized = status;
        win_is_maximized(win_maximized);
    }

    public void get_flow_width(Gtk.Container c){
        content_width = c.get_allocated_width ();
        set_cols_from (content_width);
    }

    public void set_cols_from(int w){
        int c = calc_cols(w);
        if (c != target_cols){
            target_cols = c;
            target_cols_up(target_cols);
        }
    }

    private Winman (){
        
    }

    construct{
        target_cols = 1;
    }
}


public class Tuner.Window : Gtk.ApplicationWindow {

    public GLib.Settings settings { get; construct; }
    private Gtk.Paned primary_box;
    private Gtk.Box e_box;
    private Gtk.Stack e_stack;
    private Gtk.Label nnnn;
    private Gtk.Stack mainstack;
    private Gtk.Stack content_stack;

    private HeaderBar headerbar;
    private SourceListView source_list;
    private ContentBox starred;
    private GridView my_country_gview;
    private GridView searched_gview;

    public PlayerController player { get; construct; }
    private DirectoryController _directory;

    public const string WindowName = "Tuner";
    public const string ACTION_PREFIX = "win.";
    public const string ACTION_PAUSE = "action_pause";
    public const string ACTION_QUIT = "action_quit";
    public const string ACTION_HIDE = "action_hide";
    public const string ACTION_ABOUT = "action_about";
    public const string ACTION_DISABLE_TRACKING = "action_disable_tracking";
    public const string ACTION_ENABLE_AUTOPLAY = "action_enable_autoplay";

    private uint set_cols_source = 0;
    private uint set_cols_source_timeout = 0;

    private signal void favourites_changed ();
    private signal void on_results ();
    public signal void search_term_changed(string term);
    public signal void location_changed(string country_code);

    private const ActionEntry[] ACTION_ENTRIES = {
        { ACTION_PAUSE, on_toggle_playback },
        { ACTION_QUIT , on_action_quit },
        { ACTION_ABOUT, on_action_about },
        { ACTION_DISABLE_TRACKING, on_action_disable_tracking, null, "false" },
        { ACTION_ENABLE_AUTOPLAY, on_action_enable_autoplay, null, "false" }
    };


    public Window (Application app, PlayerController player) {
        Object (
            application: app, 
            player: player,
            settings: Application.instance.settings
        );

        application.set_accels_for_action (ACTION_PREFIX + ACTION_PAUSE, {"<Control>5"});
        application.set_accels_for_action (ACTION_PREFIX + ACTION_QUIT, {"<Control>q"});
        application.set_accels_for_action (ACTION_PREFIX + ACTION_QUIT, {"<Control>w"});
    }

    static construct {
        var provider = new Gtk.CssProvider ();
        provider.load_from_resource ("com/github/louis77/tuner/Application.css");
        Gtk.StyleContext.add_provider_for_screen (
            Gdk.Screen.get_default (), 
            provider, 
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        );
    }

    private static void adjust_theme() {
        var theme = Application.instance.settings.get_string("theme-mode");
        warning(@"current theme: $theme");
        
        var gtk_settings = Gtk.Settings.get_default ();
        var granite_settings = Granite.Settings.get_default ();
        if (theme != "system") {
            gtk_settings.gtk_application_prefer_dark_theme = (theme == "dark");
        } else {
            gtk_settings.gtk_application_prefer_dark_theme = (granite_settings.prefers_color_scheme == Granite.Settings.ColorScheme.DARK);
        }
    }



    private void e_box_mapped(){
        e_box.map.disconnect(e_box_mapped);
        Tuner.Winman.instance.get_flow_width(e_box);
    }

    private void e_stack_mapped(){
        e_stack.map.disconnect(e_stack_mapped);
        if (!Tuner.Winman.instance.win_maximized){
            Tuner.Winman.instance.get_flow_width(e_stack);
            this.size_allocate.connect (on_window_resize);
        }
        Tuner.Winman.instance.win_is_maximized.connect((maximized)=>{
            Tuner.Winman.instance.get_flow_width(e_stack);
            if (!maximized){
                this.size_allocate.connect (on_window_resize);
            } 
        });
    }

    private void primary_box_mapped(){
        primary_box.map.disconnect(primary_box_mapped);
        content_stack.show();
        e_stack.set_visible_child_name ("content_stack");
    }

    private void show_primary(){
        e_box.map.connect_after((e_box_mapped));

        e_stack.map.connect_after(e_stack_mapped);
        primary_box.map.connect_after(primary_box_mapped);
        primary_box.show();
        mainstack.set_visible_child_name ("primary_box");

    }

   




    construct {

        var data_file = Path.build_filename (Application.instance.data_dir, "favorites.json");
        var store = new Model.StationStore (data_file);
        _directory = new DirectoryController (store);

        headerbar = new HeaderBar ();
        set_titlebar (headerbar);
        set_title (WindowName);

        primary_box = new Gtk.Paned (Gtk.Orientation.HORIZONTAL);

        content_stack = new Gtk.Stack();
        content_stack.set_hexpand (true);
        content_stack.set_size_request (200, -1);
        content_stack.transition_type = Gtk.StackTransitionType.CROSSFADE;

        source_list = new SourceListView(content_stack);
        source_list.ellipsize_mode = Pango.EllipsizeMode.NONE;
        source_list.set_hexpand (false);
        source_list.selection_changed.connect(on_selection_changed);


        e_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL,0);
        e_stack = new Gtk.Stack ();
        e_stack.set_size_request (200, -1);
        e_stack.set_hexpand (true);
        e_stack.add_named (e_box, "e_box");
        e_stack.add_named (content_stack, "content_stack");




        ContentBox discover = new ContentBox (_directory,"discover",
        _("Discover Stations"), 
        "media-playlist-shuffle-symbolic",
        _("Discover more stations")
        );
        discover.station_selected.connect_after(on_station_selected);
        discover.sourcedata = _directory.load_random_stations(40);
        GridView discover_gview = new GridView(discover,content_stack);
        source_list.add_item(
            discover_gview, 
            _("Discover"), 
            Tuner.ViewWrapper.Hint.SELECTION, 
            new ThemedIcon ("face-smile"), 
            null);

        ContentBox trending = new ContentBox (_directory,"trending",
        _("Trending in the last 24 hours"), 
        null, 
        null
        );
        trending.station_selected.connect_after(on_station_selected);
        trending.sourcedata = _directory.load_trending_stations(200);
        GridView trending_gview = new GridView(trending,content_stack);
        source_list.add_item(
            trending_gview, 
            _("Trending"), 
            Tuner.ViewWrapper.Hint.SELECTION, 
            new ThemedIcon ("playlist-queue"), 
            null);
       
        ContentBox popular = new ContentBox (_directory,"popular",
        _("Most-listened over 24 hours"), 
        null, 
        null
        );
        popular.station_selected.connect_after(on_station_selected);
        popular.sourcedata = _directory.load_popular_stations(200);
        GridView popular_gview = new GridView(popular,content_stack);
        source_list.add_item(
            popular_gview, 
            _("Popular"), 
            Tuner.ViewWrapper.Hint.SELECTION, 
            new ThemedIcon ("playlist-similar"), 
            null);

        ContentBox my_country = new ContentBox (_directory,"my_country",
        _("my_country"), 
        null, 
        null
        );
        my_country.station_selected.connect_after(on_station_selected);
        my_country_gview = new GridView(my_country,content_stack);

        starred = new ContentBox (_directory,"starred",
        _("Starred by You"), 
        null, 
        null
        );
        starred.station_selected.connect_after(on_station_selected);
        starred.sourcedata = _directory.load_favs();
        GridView starred_gview = new GridView(starred,content_stack);
        source_list.add_item(
            starred_gview, 
            _("Starred by You"), 
            Tuner.ViewWrapper.Hint.FAVORITE_RESULTS, 
            new ThemedIcon ("starred"), 
            null);

        ContentBox searched = new ContentBox (_directory,"searched",
        _("Search"), 
        null, 
        null
        );
        searched.station_selected.connect_after(on_station_selected);
        searched_gview = new GridView(searched,content_stack);
        source_list.add_item(
            searched_gview, 
            _("Recent Search"), 
            Tuner.ViewWrapper.Hint.SEARCH_RESULTS, 
            new ThemedIcon ("folder-saved-search"), 
            null);

        foreach (var genre in Model.genres ()) {
            ContentBox genre_item = new ContentBox (_directory,genre.name+"_genre",
            genre.name, 
            null, 
            null
            );
            genre_item.station_selected.connect_after(on_station_selected);
            var tags = new ArrayList<string>.wrap (genre.tags);
            genre_item.sourcedata = _directory.load_by_tags (tags);
            GridView genre_item_gview = new GridView(genre_item,content_stack);
            source_list.add_item(
                genre_item_gview, 
                genre.name, 
                Tuner.ViewWrapper.Hint.GENRE, 
                new ThemedIcon ("playlist-symbolic"), 
                null);
        }

                // Excluded Countries Box
        /* not finished yet 
        var item7 = new Granite.Widgets.SourceList.Item (_("Excluded Countries"));
        item7.icon = new ThemedIcon ("folder-saved-search");
        searched_category.add (item7);
        var c6 = create_content_box ("excluded_countries", item7,
            _("Excluded Countries"), null, null,
            stack, source_list, true);
        c6.content = new CountryList ();
        */
        
        store.favourites_updated.connect (handle_favourites_updated);

        search_term_changed.connect(on_search_term_changed);
        favourites_changed.connect(on_favourites_changed);
        location_changed.connect(on_location_changed);


        player.state_changed.connect (on_player_state_changed);
        player.station_changed.connect (headerbar.update_from_station);
        player.title_changed.connect ((title) => {
            headerbar.subtitle = title;
        });
        player.volume_changed.connect ((volume) => {
            headerbar.volume_button.value = volume;
        });
        headerbar.volume_button.value_changed.connect ((value) => {
            player.volume = value;
        });
        headerbar.star_clicked.connect ( (station) => {
            _directory.station_starred_toggled_handler(station);
        });
        headerbar.searched_for.connect ( (text) => {
            search_term_changed(text);
        });

        //TODO: Select item
        headerbar.search_focused.connect (() => {
            content_stack.visible_child_name = "searched";

        });
        //Tuner.Winman.instance.player = player;
        //Tuner.Winman.instance.station_changed.connect_after(on_station_changed);

        LocationDiscovery.country_code.begin ((obj, res) => {
            string country;
            try {
                country = LocationDiscovery.country_code.end(res);
            } catch (GLib.Error e) {
                // GeoLocation Service might not be available
                // We don't do anything about it
                return;
            }

            location_changed(country);
        });


        adjust_theme();
        settings.changed.connect( (key) => {
            if (key == "theme-mode") {
                warning("theme-mode changed");
                adjust_theme();
                
            }
        });

        var granite_settings = Granite.Settings.get_default ();
        granite_settings.notify.connect( (key) => {
                warning("theme-mode changed");
                adjust_theme();
        });

        add_action_entries (ACTION_ENTRIES, this);

        window_position = Gtk.WindowPosition.CENTER;
        set_default_size (800, 540);
        set_geometry_hints (null, Gdk.Geometry() {min_height = 440, min_width = 600}, Gdk.WindowHints.MIN_SIZE);

        change_action_state (ACTION_DISABLE_TRACKING, settings.get_boolean ("do-not-track"));
        change_action_state (ACTION_ENABLE_AUTOPLAY, settings.get_boolean ("auto-play"));
        
        move (settings.get_int ("pos-x"), settings.get_int ("pos-y"));
        resize (settings.get_int ("window-width"), settings.get_int ("window-height"));
        if (settings.get_int("window-status") == 1){
        maximize();
        }

        delete_event.connect (e => {
            return before_destroy ();
        });

        primary_box.pack1 (source_list, false, false);
        primary_box.pack2 (e_stack, true, false);

        mainstack = new Gtk.Stack ();
        nnnn = new Gtk.Label (null);        
        nnnn.set_text ("Loading");
        mainstack.add_named (nnnn, "nnnn") ;
        mainstack.add_named (primary_box, "primary_box") ;
        add (mainstack);
        this.window_state_event.connect(on_window_state_event);
        show_primary();


       show_all ();
       on_selection_changed(discover_gview);


        


        // Auto-play
        if (settings.get_boolean("auto-play")) {
            warning (@"Auto-play enabled");
            var last_played_station = settings.get_string("last-played-station");
            warning (@"Last played station is: $last_played_station");
            var source = _directory.load_station_uuid (last_played_station);
            try {
                foreach (var station in source.next ()) {
                    handle_station_autoplay(station);
                    break;
                }  
            } catch (SourceError e) {
                warning ("Error while trying to autoplay, aborting...");
            }
        }
    }






    private uint player_ping_source = 0;
    public void handle_station_autoplay (Tuner.Model.Station station) {
        debug (@"#auto do handle_station_autoplay $(station.title)");
        // It's yet last-played-station 
        // We don't count it as station_click
        Idle.add (() => {
            if (!player.pinged){
                if (player_ping_source==0){
                    Source.remove (player_ping_source);
                }
                player_ping_source = Timeout.add (128, () => {
                    if (player.pinged){
                        player.station = station; //It will launch player.station_changed(station)
                        return false;
                    }
                    else{
                        debug (@"#auto send PING ");
                        player.ping();
                        return true;
                    }
                });
            }
            else{
                //You shouldn't see it
                debug (@"#auto DUPLICATE AUTOPLAY CALL");
            }
        return false;
        });
        set_title (WindowName+": "+station.title);
    }

    public void on_favourites_changed (){
        GLib.Idle.add (() => {
            starred.refresh();
            return false;
        });
    }

    public void on_selection_changed (GridView view){
        content_stack.set_visible_child_name(view.name);
        view.content.selected();
    }

    //TODO: remove old
    private void on_location_changed(string country){
        var country_name = Model.Countries.get_by_code (country);
        my_country_gview.content.sourcedata = _directory.load_by_country(10,country);
        my_country_gview.content.header_label.label = _("Top 100 in") + " " + country_name;
        source_list.add_item(
            my_country_gview, 
            _(country_name), 
            Tuner.ViewWrapper.Hint.SELECTION, 
            new ThemedIcon ("emblem-web"), 
            null);
        
    }


    private void on_search_term_changed(string term){
        if (term._strip().length == 0) return;
        searched_gview.content.sourcedata = _directory.load_search_stations (term, 100);
        searched_gview.content.refresh();
    }

    private bool on_window_state_event(Gdk.EventWindowState event){
        this.window_state_event.disconnect(on_window_state_event);
        if (event.type == Gdk.EventType.WINDOW_STATE) {
            if ((event.window.get_state () & Gdk.WindowState.MAXIMIZED) == 0) {
                if (Tuner.Winman.instance.win_maximized){
                    Tuner.Winman.instance.set_maximized(false);
                }
            } else {
                if (!Tuner.Winman.instance.win_maximized){
                    Tuner.Winman.instance.set_maximized(true);
                }
            }
        }
        this.window_state_event.connect(on_window_state_event);
        return false;
    }

    private void on_window_resize(){
        if (set_cols_source != 0){
            Source.remove(set_cols_source);
        }
        else{
            set_cols_source_timeout = Timeout.add (1024, () => {
                Tuner.Winman.instance.get_flow_width(e_stack);
                if (Tuner.Winman.instance.win_maximized){
                    this.size_allocate.disconnect (on_window_resize);
                }
                set_cols_source_timeout = 0;
                if (set_cols_source != 0){
                    Source.remove(set_cols_source);
                    set_cols_source = 0;
                }
                return false;
            });
        }
        set_cols_source = Timeout.add (128, () => {
            Tuner.Winman.instance.get_flow_width(e_stack);
            if (Tuner.Winman.instance.win_maximized){
                this.size_allocate.disconnect (on_window_resize);
            }
            set_cols_source = 0;
            if (set_cols_source_timeout != 0){
                Source.remove(set_cols_source_timeout);
                set_cols_source_timeout = 0;
                }
            return false;
        });
    }
    

    public void on_station_selected (Tuner.Model.Station_View station) {
        player.pinged = true;
        info (@"handle station click for $(station.instance.title)");
        _directory.count_station_click (station.instance);
        player.station = station.instance;

        warning (@"storing last played station: $(station.instance.id)");
        settings.set_string("last-played-station", station.instance.id);

        set_title (WindowName+": "+station.instance.title);
    }

    public void handle_favourites_updated () {
        favourites_changed ();
    }
 

    public void on_player_state_changed (Gst.PlayerState state) {
        var can_play = player.can_play();
        headerbar.on_player_state_changed(state, can_play);
    }

    public void on_toggle_playback() {
        info ("Stop Playback requested");
        player.play_pause ();
    }

    private void on_action_quit () {
        //primary_box.size_allocate.disconnect (calc_w);
        //this.check_resize.disconnect (calc_w);
        Tuner.DebugNot.create("win","on_action_quit");

        close ();
    }

    private void on_action_about () {
        var dialog = new AboutDialog (this);
        dialog.present ();
    }
    
    public void on_action_disable_tracking (SimpleAction action, Variant? parameter) {
        var new_state = !settings.get_boolean ("do-not-track");
        action.set_state (new_state);
        settings.set_boolean ("do-not-track", new_state);
        debug (@"on_action_disable_tracking: $new_state");
    }

    public void on_action_enable_autoplay (SimpleAction action, Variant? parameter) {
        var new_state = !settings.get_boolean ("auto-play");
        action.set_state (new_state);
        settings.set_boolean ("auto-play", new_state);
        debug (@"on_action_enable_autoplay: $new_state");
    }   

    public bool before_destroy () {

        //Tuner.DebugNot.create("win","before_destroy");

        int width, height, x, y;

        get_size (out width, out height);
        get_position (out x, out y);

        settings.set_int ("pos-x", x);
        settings.set_int ("pos-y", y);
        settings.set_int ("window-height", height);
        settings.set_int ("window-width", width);
        if (Tuner.Winman.instance.win_maximized){
            settings.set_int ("window-status",1);
        }
        else{
            settings.set_int ("window-status",2);
        }

        //TODO: playing=true (custom state) or include buffering
        if (player.current_state == Gst.PlayerState.PLAYING) {
            hide_on_delete();
            var notification = new GLib.Notification("Playing in background");
            notification.set_body("Click here to resume window. To quit Tuner, pause playback and close the window.");
            notification.set_default_action("app.resume-window");
            Application.instance.send_notification("continue-playing", notification);
            return true;
        }
       // primary_box.size_allocate.disconnect (calc_w);
       // this.check_resize.disconnect (calc_w);

        IconTaskLoader.stop();
        return false;
    }

}
