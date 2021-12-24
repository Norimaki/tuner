public delegate void IconTaskDelegate (IconTask icon_task);

public struct Priority {
    public uint32 major;
    public uint32 minor;
}

public class IconTask : Object {

    private static Soup.Session _session;
    private static string _cache_dir;
    private static string _lock_tmp_dir;

	public string id;
    public string url;

    public bool check_is_image;
    public bool check_size;

    //public bool queued;
    public bool started;
    public bool finallized;
    public bool exit;
    private Cancellable cancellable;
    public IconTaskDelegate? cb;
    public Priority priority;



    public signal void finished();

    public static void init (string cache_dir, string lock_tmp_dir){
        if (_cache_dir == null) _cache_dir = cache_dir;
        if (_lock_tmp_dir == null) _lock_tmp_dir = lock_tmp_dir;

        if (_session == null) {
            IconTask._session = new Soup.Session ();
            IconTask._session.user_agent = @"$(Tuner.Application.APP_ID)/$(Tuner.Application.APP_VERSION)";
            IconTask._session.timeout = 3;
        }
    }

    private static string get_cache_path(string id){
        if (id == null || id._strip () == "") error ("Bad id");
        if (_cache_dir == null) error ("cache_dir can't be null");
        return Path.build_filename (_cache_dir,id);
    }

    private static string get_lock_path(string id){
        if (id == null || id._strip () == "") error ("Bad id");
        if (_lock_tmp_dir == null) error ("lock_tmp_dir can't be null");
        return Path.build_filename (_lock_tmp_dir,id);
    }

    private static bool exists_in_cache (string id){
        if (FileUtils.test (get_cache_path(id), FileTest.EXISTS)) {
            return true;
        }
        return false;
    }

    /* 
    private static bool regular_in_cache (string id){
        if (FileUtils.test (get_cache_path(id), FileTest.IS_REGULAR)) {
            return true;
        }
        return false;
    }
*/
    private static void make_loading_icon (Gtk.Image icon){
        icon.set_from_icon_name ("content-loading", Gtk.IconSize.DIALOG);
    }

    private static void make_default_icon (Gtk.Image icon){
        icon.set_from_icon_name ("internet-radio", Gtk.IconSize.DIALOG);
    }

    private static void make_cached_icon (string path, Gtk.Image icon, bool with_default=false){
        var file = File.new_for_path (path);

        try {
            GLib.FileInfo info = file.query_info(GLib.FileAttribute.STANDARD_SIZE,FileQueryInfoFlags.NONE);
            if (info.get_size () < 1){
                if (with_default) make_default_icon(icon);
                return;
            }
        } catch (Error e) {
            if (with_default) make_default_icon(icon);
            return;
        }

        Gdk.Pixbuf pixbuf;
        try {

            //We don't need it if we start with a clean cache.
            //Required if we mix versions.
            var stream = file.read ();
            pixbuf = new Gdk.Pixbuf.from_stream_at_scale (stream, 48, 48, true, null);
            //pixbuf = new Gdk.Pixbuf.from_file (file.get_path ());
        } catch (Error e) {
            warning (@"error loading favicon: %s %s", path, e.message);
            if (with_default) make_default_icon(icon);
            return;
        }

        icon.set_from_pixbuf (pixbuf);
    }

    public static void make_icon (string id, string url, Gtk.Image icon, bool with_loading=true){
        icon.clear();

/* 
        if (regular_in_cache(id)){
            make_cached_icon(get_cache_path(id), icon);
        }
        else{
            if (url._strip () == "" || !with_loading){
                make_default_icon(icon);
            }
            else{
                make_loading_icon(icon);
            }
        }
*/



            if (url._strip () == "" || !with_loading){
                make_default_icon(icon);
                make_cached_icon(get_cache_path(id), icon);
            }
            else{
                make_loading_icon(icon);
            }
     

        /* 
        if (url._strip () == "" || !with_loading){
            make_default_icon(icon);
        }
        else{
            make_loading_icon(icon);
        }
        make_cached_icon(get_cache_path(id), icon);
        */
        icon.set_pixel_size (48);
        icon.halign = Gtk.Align.CENTER;
        icon.valign = Gtk.Align.CENTER;
        icon.set_size_request (48, 48);
    }

    public IconTask.with_exit () {
        this.priority = {uint32.MAX, uint32.MAX};
        this.exit = true;
    }

    public IconTask (string id, string url, owned IconTaskDelegate? cb) {
        this.id = id;
        this.url = url;

        this.check_is_image = false;
        this.check_size = false;

        //this.queued = false;
        this.started = false;
        this.finallized = false;
        this.exit = false;

        this.cancellable = new Cancellable();
		this.cb = (owned) cb; //Not using now.

        if (exists_in_cache (id) || url._strip () == ""){
            this.finallized = true;
            //If just now exists, icon will be downloaded twice.
            //One will fails to saving (lock).
        }
	}

    public void download_icon (){

        if (finallized) return; 

        GLib.File lock_file = File.new_for_path (get_lock_path (id));
        GLib.FileIOStream? stream_lock = null;
        GLib.FileIOStream? stream_out = null;

        try {
            stream_lock = lock_file.create_readwrite (FileCreateFlags.PRIVATE);
            if (stream_lock != null) stream_lock.close ();
            stream_lock = null;
        } catch (Error e) {
            this.finallized = true;
            warning (@"unable to create lock file for id: %s %s", id, e.message);
            return;
        }

        var message = new Soup.Message ("GET", (url));

        cancellable.cancelled.connect (()=>{
            _session.cancel_message (message, 500);
        });

        if (check_is_image){
            // If we verify image before saving, we don't need it
            bool is_redirect = false;
            bool is_image = false;
            message.got_headers.connect_after (() => {
                message.response_headers.foreach ((name, val) => {
                    if (name == "Location"){
                        is_redirect = true;
                    }
                    else if (name == "Content-Type" && val.has_prefix ("image/") ){
                        is_image = true;
                    }
                });

                if (!is_redirect && !is_image){
                    _session.cancel_message (message, 500);
                }
            });
        }

        if (check_size){
            //if we set a timeout, we don't need this.
            size_t ct = 0;
            message.got_chunk.connect_after ((chunk) => {
                ct = ct + chunk.length;
                if (ct > 1024*1024){
                    _session.cancel_message (message, 500);
                }
            });
        }

        /* 
        message.starting.connect (() => {
            ct = 0;
            is_redirect = false;
            is_image = false;
        });
        */

        if (cancellable.is_cancelled ()) {
            this.finallized = true;
        }
        else if (message != null) {
            _session.send_message (message);

            if (cancellable.is_cancelled ()) {
                this.finallized = true;
            }

            if (message.response_body.data.length<=0){
                this.finallized = true;
            }

            if (message.status_code != 200){
                this.finallized = true;
            }
        }
        else{
            this.finallized = true;
        }

       

        if (finallized) {
            try {
                if (stream_lock != null) stream_lock.close ();
            }
            catch (Error e) {} 
            try {
                lock_file.delete();
            }
            catch (Error e) {} 
            return;
        }

        MemoryInputStream data_stream = new MemoryInputStream.from_data (message.response_body.data);
        GLib.File file = File.new_for_path (get_cache_path (id));
        Gdk.Pixbuf? pxbuf = null;
        
        try {
            pxbuf = new Gdk.Pixbuf.from_stream_at_scale (data_stream, 48, 48, true, null);
            try {
                pxbuf.save (file.get_path (),"png");
            } catch (Error e) {
                warning (@"unable to save cached file for id: %s %s", id, e.message);
            } 
        } catch (Error e) {
            try {
                stream_out = file.create_readwrite (FileCreateFlags.PRIVATE);
                if (stream_out != null) stream_out.close ();
            } catch (Error e) {
                warning (@"unable to set 0 size cached file for id: %s %s", id, e.message);
            }
            warning (@"unsupported format: %s %s", get_cache_path(id), e.message);
        }


        try {
            lock_file.delete();
        }
        catch (Error e) {} 
        this.finallized = true;
    }

    public void cancel_job () {
        cancellable.cancel ();
        this.started = false;
    }

    public void do_job () {
        download_icon();
        if (cb != null) cb(this);
        finished();
    }
}
