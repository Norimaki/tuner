using Gee;

public class Tuner.Model.Station_Source : Object {

    public Station station { get; private set; }
    private static TreeMap <string,Station_Source> Station_Collection;
    private GenericArray<Station_View> Station_Views;
    public Gtk.Image icon { get; private set; }

    public IconTask icon_task { get; private set; }

    private static void init(){
        Station_Collection = new TreeMap <string,Station_Source> ();
    }

    public static Station_Source create (Station s){
        return new Station_Source (s);
    }

    public static Station_Source get_source ( Station s){
        if (Station_Collection == null){
               init();
        }
        if (Station_Collection.has_key (s.id)){
            var ss = Station_Collection.get (s.id);
            if (ss.station != s){
                s = null;
            }
            return ss;
        }
        else{
            var ss = Station_Source.create (s);
            Station_Collection.set (s.id, ss);
            return ss;
        }
    }

    public static void remove_source(Station_Source ss){
        assert (Station_Collection != null);
        IconTaskLoader.cancel(ss.icon_task);   

       // if (Station_Collection.has_key(ss.station.id)){
         //   Station_Collection.unset(ss.station.id);
       // }
        //debug (@"#gui Station_Collection.size $(Station_Collection.size.to_string ("%d"))");
        //warning (@"#gui Station_Collection.size $(Station_Collection.size.to_string ("%d"))");
    }


    private Station_Source (Station s) {
        this.station = s;
        this.Station_Views = new GenericArray<Station_View> ();
        this.icon_task = new IconTask (station.id, station.favicon_url,null);
    }

    public void add_view(Station_View sv){
        sv.destroy.connect(remove_view);
        this.Station_Views.add(sv);
    }

    public void remove_view(Station_View sv){
        this.Station_Views.remove(sv);
        if (Station_Views.length <=0){
        //warning (@"#gui Station_Collection.size $(Station_Collection.size.to_string ("%d"))");

            Model.Station_Source.remove_source(this);
        }
    }
}
