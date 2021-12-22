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
//using GLib;
namespace Tuner.DBus {

    const string ServerName = "org.mpris.MediaPlayer2.Tuner";
    const string ServerPath = "/org/mpris/MediaPlayer2";    
    const string INTERFACE_NAME = "org.mpris.MediaPlayer2.Player";
    const string DbusPath = "/com/github/louis77/tuner";
    const string NOTRACK = "/org/mpris/MediaPlayer2/TrackList/NoTrack";

    private bool is_initialized = false;

    protected TrackListRecent tracklist;

    public void initialize () {
        if (is_initialized) {
            // App is already running, do nothing
            return;
        }

        var owner_id = Bus.own_name(
            BusType.SESSION,
            ServerName,
            BusNameOwnerFlags.NONE,
            onBusAcquired,
            () => {
                is_initialized = true;
            },
            () => warning (@"Could not acquire name $ServerName, the DBus interface will not be available")
        );

        if (owner_id == 0) {
            warning ("Could not initialize MPRIS session.\n");
        }
    }

    void onBusAcquired (DBusConnection conn) {
        try {
            tracklist = new TrackListRecent();
            conn.register_object<IMediaPlayer2> (ServerPath, new MediaPlayer ());
            conn.register_object<IMediaPlayer2Player> (ServerPath, new MediaPlayerPlayer (conn));
        } catch (IOError e) {
            error (@"Could not acquire path $ServerPath: $(e.message)");
        }
        info (@"DBus Server is now listening on $ServerName $ServerPath…\n");
    }

    //public class MediaPlayer2TrackList : Object, DBus.IMediaPlayer2TrackList {
    public class MediaPlayer2TrackList : Object {

        private Variant _tracks;

        //string[] b = {"n","v"};
        //Variant var3 = new Variant.objv (b);
        //Constructs an array of object paths Variant from the given array of strings.

        //ObjectPath[]
        public Variant tracks {        
            get {
                return this._tracks;
            }
        }  

        public bool can_edit_tracks {        
            get {
                return false;
            }
        }  

        public void add_track (string Uri, ObjectPath AfterTrack, bool SetAsCurrent) {
        }
    }

    public class TrackListRecent : Object {

        private string[] _tracks;
        private const uint8 N_TRACKS = 5;
        private uint8 _count = 0;

        protected HashTable<string,string> uri_to_id =  new HashTable<string, string> (str_hash, str_equal);

        public TrackListRecent(){
            _tracks.resize (N_TRACKS);
            _tracks[N_TRACKS-1]=NOTRACK;
       }


        public string add_track (string Uri) {
            if (this.uri_to_id.contains (Uri)){
                return this.uri_to_id.get (Uri);
            }
            else{
                uint8 index = _count+1;
                _count = (_count+1) % N_TRACKS;
                string tail = _tracks[N_TRACKS-1];
                _tracks.move (0, 1, N_TRACKS-1);
                _tracks[0]=DbusPath+"/playlist/"+index.to_string ("%d");
                this.uri_to_id.foreach_remove ((key, val) => {
                    if (val == tail){
                        return true; 
                    }
                    return false;
                });
                this.uri_to_id.insert (Uri, _tracks[0]);
                return _tracks[0];
            }
        }
    }



    public class MediaPlayer : Object, DBus.IMediaPlayer2 {
        public void raise() throws DBusError, IOError {
            debug ("DBus Raise() requested");
            var now = new DateTime.now_local ();
            var timestamp = (uint32) now.to_unix ();
            Application.instance.window.present_with_time (timestamp);
        }

        public void quit() throws DBusError, IOError {
            debug ("DBus Quit() requested");
        }

        public bool can_quit {
            get {
                return true;
            }
        }

        public bool can_raise {
            get {
                return true;
            }
        }

        public bool has_track_list {
            get {
                return false;
            }
        }

        public string desktop_entry {
            owned get {
                return ((Gtk.Application) GLib.Application.get_default ()).application_id;
            }
        }

        public string identity {
            owned get {
                return "tuner@exe";
            }
        }

        public string[] supported_uri_schemes {
            owned get {
                return {"http", "https"};
            }
        }

        public string[] supported_mime_types {
            owned get {
                return {"audio/*"};
            }
        }

        public bool fullscreen { get; set; default = false; }
        public bool can_set_fullscreen {
            get {
                debug ("CanSetFullscreen() requested");
                return true;
            }
        }
    }

    public class MSGxLL : GLib.Object{

        private string _future;
        public string future {
            owned get {
                return _future;
            }
            set {
                _future = value;
            }
        }



        [CCode (notify = false)]
        public string other;

        public MSGxLL () {
            
        }


        public int cancel (uint timeout_source) {
            Source.remove (timeout_source);
            return 0;
        }



        public int send (string k,string str, uint timeout_source) {

            
            if (timeout_source == 0){
                timeout_source=Timeout.add (2048, () => {

                    var Notification = new GLib.Notification (k);
                    Notification.set_body (str);
                    var Icon = new GLib.ThemedIcon ("dialog-information");
                    Notification.set_icon (Icon);
                    Application.instance.send_notification (null, Notification);        

                    future = str;
                    timeout_source=0;
                    return false;
                });
                return (int) timeout_source;
            }
            else{
                return -1;
            }


           
        }

      
    }

    

    public class Sender : Object{
        private static HashTable<string,MutableVar> changes;
        private static DBusConnection conn;
        private static uint send_source;

        public static void init (DBusConnection c){
            changes = new HashTable<string, MutableVar> (str_hash, str_equal);
            conn = c;
            send_source = 0;
        }
        public static void add (string key, MutableVar val){
            changes.insert(key, val);
            send();
        }
        public static void remove (string key){
            if (changes.contains (key)){
            changes.remove(key);
            }
            send();
        }
        public static MutableVar get_key (string key){
            return changes.get(key);
        }
        private static bool send (){
            if (send_source == 0){
                send_source = Timeout.add (1024, () => {
                    Idle.add (send_dbus);
                    return false;
                });
            }
            return true;
        }
        private static bool send_dbus (){
            if (changes.length < 1){
                send_source = 0;
                return false;
            }

            var invalidated_builder = new VariantBuilder (new VariantType ("as"));
            var builder = new VariantBuilder (VariantType.ARRAY);

            foreach (string name in changes.get_keys ()) {
                MutableVar n = changes.lookup (name);
                Variant variant = n.get_value ();
                n.confirm();
                changes.remove (name);
                builder.add ("{sv}", name, variant);
            }

            try {
                conn.emit_signal (null,
                                "/org/mpris/MediaPlayer2",
                                "org.freedesktop.DBus.Properties",
                                "PropertiesChanged",
                                new Variant ("(sa{sv}as)",
                                            INTERFACE_NAME,
                                            builder,
                                            invalidated_builder)
                                );
            } catch (Error e) {
                debug (@"Could not send MPRIS property change: $(e.message)");
            }  
            send_source = 0;
            return false;
        }
    }

    public class MutableVar : Object {
        private string key;
        private Variant value;
        private Variant confirmed;
 
        public MutableVar (string key, Variant variant){
            this.key = key;
            this.value = variant;
            this.confirmed = variant;
        }
        public Variant get_value(){
            return this.value;
        }
        public void set_value (Variant value){
            this.value = value;
            if (!this.value.equal(this.confirmed)){
                Sender.add (this.key, this);
            }
            else{
                Sender.remove (this.key);
            }
        }
        public void confirm(){
            this.confirmed = this.value;
        }
    }

    public class MediaPlayerPlayer : Object, DBus.IMediaPlayer2Player {
        //[DBus (visible = false)]
        bool _c_playing;                // Control var
        bool _c_uri_changed;             // Control var
        bool _c_runned_autoplay;             // Control var
        bool _c_station_loaded;

        MutableVar z_playbackstatus;    // Used by DBus
        MutableVar z_can_play;          // Used by DBus
        MutableVar z_can_pause;         // Used by DBus
        MutableVar z_metadata;          // Used by DBus
        Variant _metadata_notrack;      // No-track Metadata. Used by z_metadata
        Variant _metadata_track;        // Current track Metadata. Used by z_metadata
        VariantDict _h_metadata_vd;     // Helper to build a{sv}. Reusable

        MutableVar z_metadata_2;          // Used by DBus
        Variant _metadata_2;

        [DBus (visible = false)]
        public unowned DBusConnection conn { get; construct set; }

        public MediaPlayerPlayer (DBusConnection conn) {

            Object (conn: conn);

            Sender.init(conn);

            _c_playing = false;
            _c_uri_changed = false;
            _c_runned_autoplay = false;
            _c_station_loaded = false;
            MutableVar z_test = new MutableVar(
                "Test",
                new Variant.int32(0)
            );
            z_playbackstatus = new MutableVar(
                "PlaybackStatus", 
                new Variant.string ("Stopped")
            );
            z_can_play = new MutableVar(
                "CanPlay", 
                new Variant.boolean (false)
            );
            z_can_pause = new MutableVar(
                "CanPause",
                new Variant.boolean (false)
            );
            _h_metadata_vd = new VariantDict();
            _h_metadata_vd.insert_value (
                "mpris:trackid", 
                new Variant.string (NOTRACK)
            );
            _metadata_track = _h_metadata_vd.end();
            var _h_metadata_vd_notrack = new VariantDict();
            _h_metadata_vd_notrack.insert_value (
                "mpris:trackid", 
                new Variant.string (NOTRACK)
            );
            _metadata_notrack = _h_metadata_vd_notrack.end();
            z_metadata = new MutableVar("Metadata", _metadata_notrack);

            Application.instance.player.state_changed.connect ((state) => {

                switch (state) {
                case Gst.PlayerState.PLAYING:
                debug (@"#v7 on PLAYING");
                    _c_playing = true;
                    z_playbackstatus.set_value (new Variant.string ("Playing"));
                    break;
                case Gst.PlayerState.BUFFERING:
                    _c_playing = true;
                    break;
                case Gst.PlayerState.STOPPED:
                debug (@"#v7 on STOPPED");
                    _c_playing = false;

                    /* 
                    if (send_source == 0){
                        send_source = Timeout.add (1024, () => {
                            
                            return false;
                        });
                    }
                    */
                    z_metadata.set_value(_metadata_notrack);
                    z_playbackstatus.set_value (new Variant.string ("Stopped"));
                    break;
                case Gst.PlayerState.PAUSED:
                debug (@"#v7 on PAUSED");
                    _c_playing = false;
                    z_playbackstatus.set_value (new Variant.string ("Paused"));
                    break;
                }

                //z_test.set_value (new Variant.int32(GLib.Random.int_range(0,1000000)));

            });
            Application.instance.player.player.uri_loaded.connect ((uri) => {
                debug (@"#v7 ######uri_loaded");
            });
             Application.instance.player.uri_changed.connect ((uri) => {
                debug (@"#v7 uri_changed");
            });
            //Application.instance.player.title_changed.connect ((title) => {
            //    debug (@"#v7 tilte_changed");
            //});
            Application.instance.player.media_info_updated.connect ((sd) => {
                if (_c_playing && _c_station_loaded){
                    debug (@"#v7 title_changed:_c_playing && _c_station_loaded");

                    _h_metadata_vd = new VariantDict(_metadata_track);
                    if (sd.title == null){
                        sd.title = "";
                    }
                    Variant meta_title = new Variant.string (sd.title);
                    _h_metadata_vd.insert_value ("xesam:title", meta_title);

                    if (sd.genre != null){
                        Variant meta_genre = new Variant.string (sd.genre);
                        _h_metadata_vd.insert_value ("xesam:genre", meta_genre);
                    }
                    if (sd.min_max_bitrate != null){
                        Variant meta_min_max_bitrate = new Variant.int32 (sd.min_max_bitrate);
                        _h_metadata_vd.insert_value ("bitrate", meta_min_max_bitrate);
                    }
                    _metadata_track = _h_metadata_vd.end();
                    z_metadata.set_value (_metadata_track);
                }
            });   
          
            Application.instance.player.station_changed.connect ((station) => {
                debug (@"#v7 station_changed $(station.title)");

                _c_station_loaded = true;
                z_playbackstatus.set_value (new Variant.string ("Playing"));

                string uri = station.url;

                //var url = Application.instance.player.player.uri;
                z_can_play.set_value (new Variant.boolean (true));
                z_can_pause.set_value (new Variant.boolean (true));

                var s_meta_trackid = tracklist.add_track (uri);
                _h_metadata_vd = new VariantDict(_metadata_track);
                _h_metadata_vd.insert_value ("mpris:trackid",new Variant.object_path(s_meta_trackid));
                _h_metadata_vd.insert_value ("xesam:url", new Variant.string (uri));
                _h_metadata_vd.insert_value ("xesam:artist",new Variant.string (station.title));
                if (_h_metadata_vd.contains ("xesam:title")){
                    _h_metadata_vd.remove ("xesam:title");
                }
                if (_h_metadata_vd.contains ("xesam:genre")){
                    _h_metadata_vd.remove ("xesam:genre");
                }
                if (_h_metadata_vd.contains ("bitrate")){
                    _h_metadata_vd.remove ("bitrate");
                }
                _metadata_track = _h_metadata_vd.end();
                z_metadata.set_value (_metadata_track);
            }); 
        }
     


       

        public void next() throws DBusError, IOError {
            // debug ("DBus Next() requested");
        }

        public void previous() throws DBusError, IOError {
            // debug ("DBus Previous() requested");
        }

        public void pause() throws DBusError, IOError {
            //  debug ("DBus Pause() requested");
            Application.instance.player.player.pause();
        }

        public void play_pause() throws DBusError, IOError {
            //  debug ("DBus PlayPause() requested");
            Application.instance.player.play_pause();
        }

        public void stop() throws DBusError, IOError {
            //  debug ("DBus stop() requested");
            Application.instance.player.player.stop();
        }

        public void play() throws DBusError, IOError {
            //  debug ("DBus Play() requested");
            Application.instance.player.player.play ();
        }

        public void seek(int64 Offset) throws DBusError, IOError {
            //  debug ("DBus Seek() requested");
        }

        public void set_position(ObjectPath TrackId, int64 Position) throws DBusError, IOError {
            //  debug ("DBus SetPosition() requested");
        }

        public void open_uri(string uri) throws DBusError, IOError {
            //  debug ("DBus OpenUri() requested");
        }

        // Already defined in the interface
        // public signal void seeked(int64 Position);

        public Variant playback_status {
            owned get {
                assert(z_playbackstatus.get_value().is_of_type (VariantType.STRING));
                return z_playbackstatus.get_value();
            }
        }

        public string loop_status {
            owned get {
                return "None";
            }
        }

        public double rate { get; set; }
        public bool shuffle { get; set; }

        public Variant metadata { 
            owned get {
                assert(z_metadata.get_value().is_of_type (VariantType.VARDICT));
                return z_metadata.get_value();
            }
        }
        public double volume { owned get; set; }
        public int64 position { get; }
        public double minimum_rate {  get; set; }
	    public double maximum_rate {  get; set; }

	    public bool can_go_next {
	        get {
    	        //  debug ("CanGoNext() requested");
	            return false;
	        }
	    }

	    public bool can_go_previous {
	        get {
    	        //  debug ("CanGoPrevious() requested");
	            return false;
	        }
	    }

        public Variant can_play  {
	        owned get {
                assert(z_can_play.get_value().is_of_type (VariantType.BOOLEAN));
                return z_can_play.get_value();
            }
        }

	    public Variant can_pause {
	        owned get {
                assert(z_can_pause.get_value().is_of_type (VariantType.BOOLEAN));
                return z_can_pause.get_value();
            }
        }

	    public bool can_seek {
	        get {
                return false;
            }
        }
	    public bool can_control {
	        get {
                return true;
            }
        }
    }
    
  
   




}
