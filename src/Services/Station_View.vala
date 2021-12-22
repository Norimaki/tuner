public class Tuner.Model.Station_View__ : Object {

    public Station instance;
    public Station_Source ss;
    public signal void station_starred_toggled();
    public signal void destroy();
    public IconTask icon_task { get; private set; }

    public Station_View () {
        this.instance = null;
        this.ss = null;
    }

    public Station_View.with_station (Station s) {
        this.ss = Model.Station_Source.get_source(s);
        this.instance = ss.station;
        this.icon_task = ss.icon_task; //Avoid acces ss directly.
        ss.add_view(this);
    }

    /*
    We can't use this destructor to remove a view.
    It is called AFTER we remove a view from its source. 
    So other must call sv.destroy() signal to remove it.
    When using sv into a Gtk.Widget, we can use its destroy signal.
        Widget.destroy.connect (() => {
            sv.destroy();
        });

    Otherwise, we should call it explicitly:
        sv = new Station_view (station);
        ...
        sv.destroy();
    
    Destroying means we remove a needless source from the Station Collection.
    We don't want it grows indefinitely (just now there are around 29000 stations).
    
    ~Station_View (){
        debug(@"#gui DESTROY");
    }
 */
    

}